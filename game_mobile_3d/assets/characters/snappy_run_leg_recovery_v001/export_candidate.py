"""Read-only export of the separately registered Pending Run candidate; no Blender datablock is saved."""
import bpy, json, math, hashlib, struct, sys
from pathlib import Path
from mathutils import Matrix, Quaternion, Vector
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
MANIFEST=ROOT/'blender/animation/showcase/animation_manifest.json'
BASE=ROOT/'game_mobile_3d/assets/characters/jump_gif_v004/player_r15_jump_gif_v004.glb'
NAMES=['Run_Snappy_LegRecovery_Test_v001']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
raw=BASE.read_bytes();n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n])
nodes={x['name']:x for x in doc['nodes']}
def mat(x):
    q=x.get('rotation',[0,0,0,1])
    return Matrix.LocRotScale(Vector(x.get('translation',[0,0,0])),Quaternion((q[3],*q[:3])),Vector(x.get('scale',[1,1,1])))
def err(a,b):return max(abs(a[r][c]-b[r][c]) for r in range(4) for c in range(4))
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
aliases={'UpperArm.L':'Arm.L','UpperArm.R':'Arm.R'}
manifest=json.loads(MANIFEST.read_text());records={};report={}
# Export can proceed independently while another task finishes library registration.
authoring=ROOT/'blender/animation/reviews/player_animation_library_v1/run_snappy_leg_recovery_v001/authoring.json'
meta=json.loads(authoring.read_text())
if not any(e['action']==NAMES[0] for e in manifest['animations']):
    entry=next(e.copy() for e in manifest['animations'] if e['action']=='Run_Snappy_Test_v001')
    entry.update(action=NAMES[0],source=str(authoring.parent.relative_to(ROOT)/'run_snappy_leg_recovery_review.blend'),source_sha256=meta['source_sha256'],action_sha256=meta['action_sha256'],status='pending')
    manifest['animations'].append(entry)

C=Matrix.Rotation(-math.pi/2,4,'X');HZ=120
for name in NAMES:
    cfg=next(x for x in manifest['animations'] if x['action']==name)
    source=ROOT/cfg['source'];assert sha(source)==cfg['source_sha256'],name
    bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False)
    rig=bpy.data.objects[cfg['source_rig']];mesh=bpy.data.objects[cfg['source_mesh']]
    rig.parent=None;rig.matrix_world=Matrix.Identity(4)
    action=bpy.data.actions[name];assert ui.action_signature(action)==cfg['action_sha256'];rig.animation_data_clear();rig.animation_data_create()
    rig.animation_data.action=action
    rig.animation_data.action_slot=next(s for s in action.slots if s.identifier==cfg['slot_identifier'])
    scene=bpy.context.scene;duration=(cfg['end']-cfg['start']+1)/cfg['fps']
    bones=[b for b in rig.data.bones if b.name!='Root']
    rest_error=0
    for b in bones:
        runtime=aliases.get(b.name,b.name)
        local=b.parent.matrix_local.inverted()@b.matrix_local
        rest_error=max(rest_error,err(local,mat(nodes[runtime])))
    assert rest_error<1e-6,(name,rest_error)
    sole={}
    vertices=[]
    for v in mesh.data.vertices:
        groups=[mesh.vertex_groups[g.group].name for g in v.groups if g.weight>.999]
        assert len(groups)==1
        group=groups[0];vertices.append((v.co.copy(),group))
        if group.startswith('Leg.'):
            sole.setdefault(group,[]).append(list(rig.data.bones[group].matrix_local.inverted()@v.co))
    sole={k:[list(v) for v in {tuple(round(x,7) for x in p) for p in vs} if v[1]>.6] for k,vs in sole.items()}
    samples=[];previous={};max_reconstruction=0;feet={'L':[],'R':[]};hips=[]
    for index in range(round(duration*HZ)+1):
        frame=cfg['start']+index/HZ*cfg['fps']
        scene.frame_set(int(frame),subframe=frame%1);bpy.context.view_layer.update()
        evaluated=rig.evaluated_get(bpy.context.evaluated_depsgraph_get());row={};globals={'Root':C@rig.data.bones['Root'].matrix_local}
        for b in bones:
            pbone=evaluated.pose.bones[b.name];local=pbone.parent.matrix.inverted()@pbone.matrix
            p,q,scale=local.decompose();assert max(abs(x-1) for x in scale)<1e-5
            if b.name in previous and q.dot(previous[b.name])<0:q.negate()
            previous[b.name]=q.copy();runtime=aliases.get(b.name,b.name)
            row[runtime]=[list(p),[q.x,q.y,q.z,q.w]]
            globals[b.name]=globals[b.parent.name]@local
        for co,group in vertices:
            expected=C@evaluated.pose.bones[group].matrix@rig.data.bones[group].matrix_local.inverted()@co
            actual=globals[group]@rig.data.bones[group].matrix_local.inverted()@co
            max_reconstruction=max(max_reconstruction,(expected-actual).length)
        samples.append(row)
        for side in ['L','R']:feet[side].append(min((globals['Leg.'+side]@Vector(p)).y for p in sole['Leg.'+side]))
        hips.append(globals['Hips'].translation.y)
    endpoint_p=max((Vector(samples[0][b][0])-Vector(samples[-1][b][0])).length for b in samples[0])
    endpoint_q=max(Quaternion((samples[0][b][1][3],*samples[0][b][1][:3])).rotation_difference(Quaternion((samples[-1][b][1][3],*samples[-1][b][1][:3]))).angle for b in samples[0])
    assert endpoint_p<1e-5 and endpoint_q<.001,(name,endpoint_p,endpoint_q)
    assert max_reconstruction<3e-6
    records[name]={'duration':duration,'hz':HZ,'samples':samples,'sole_corners':sole,'sole_height_samples':feet,'hip_height_samples':hips,'support_duty':cfg['support_duty'],'nominal_speed_m_s':cfg.get('nominal_speed_m_s',.9 if 'Walk' in name else 2.31),'source':cfg['source'],'source_sha256':sha(source),'action_sha256':cfg['action_sha256'],'slot':cfg['slot_identifier']}
    report[name]={'duration':duration,'samples':len(samples),'rest_error':rest_error,'reconstruction_error_m':max_reconstruction,'loop_position_error_m':endpoint_p,'loop_rotation_error_rad':endpoint_q,'source_sha256':sha(source),'action_sha256':cfg['action_sha256'],'hip_range_m':[min(hips),max(hips)],'feet_near_floor_samples':{k:sum(z<.002 for z in zs) for k,zs in feet.items()}}
    assert sha(source)==cfg['source_sha256']
(HERE/'recovery_samples.json').write_text(json.dumps(records,separators=(',',':')))
(HERE/'export_validation.json').write_text(json.dumps({'clips':report,'base_model':str(BASE.relative_to(ROOT)),'base_model_sha256':sha(BASE),'rig_modified':False,'root_motion':False,'new_character_actions':True},indent=2))
print('SNAPPY_READ_ONLY_EXPORT_PASS',json.dumps(report),flush=True)
