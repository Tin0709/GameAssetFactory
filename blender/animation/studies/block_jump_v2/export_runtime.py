"""Additive96Hz pose JSON export; no GLB/source save, no root/world animation.

Run Blender background onblock_jump_v2_review.blend. --validate-only audits written
JSON without sampling. Absolute parent-relative transforms matchR13 native loader.
"""
import bpy,json,sys,math,hashlib,struct
from pathlib import Path
from mathutils import Matrix,Quaternion,Vector
BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[3]
OUT=ROOT/'game_mobile_3d/assets/characters/jump_v2'
SOURCE=BASE/'block_jump_v2_review.blend'
ORIGINAL=ROOT/'blender/characters/player/cuboid/player_combat_strafe_r14_pass2_study.blend'
PRODUCTION=ROOT/'game_mobile_3d/assets/characters/r15/player_r15_combat_strafe_v1.glb'
BONES=['Hips','Leg.L','Leg.R','Spine','Chest','Neck','Head','Arm.L','Arm.R']
ALIASES={'Arm.L':'UpperArm.L','Arm.R':'UpperArm.R'}
HZ=96;FPS=24
CLIPS=['BlockJump_Up_V2','BlockHop_Down_V2','BlockJump_Up_V2_OppositeLead','BlockHop_Down_V2_OppositeLead']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def curves(a):return [c for layer in a.layers for strip in layer.strips for cb in strip.channelbags for c in cb.fcurves]
def action_hash(a):
    return hashlib.sha256(repr(([(c.data_path,c.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type) for k in c.keyframe_points]) for c in curves(a)],dict(a.items()))).encode()).hexdigest()
def matrix_error(a,b):return max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4))
def unpack(p):
    q=p['q'];return Matrix.LocRotScale(Vector(p['p']),Quaternion((q[3],q[0],q[1],q[2])),Vector((1,1,1)))
def glb_nodes(path):
    raw=path.read_bytes();size,kind=struct.unpack_from('<II',raw,12);assert kind==0x4e4f534a
    doc=json.loads(raw[20:20+size]);nodes=doc['nodes'];parents={i:k for k,n in enumerate(nodes) for i in n.get('children',[])}
    result={}
    for i,n in enumerate(nodes):
        if n.get('name') not in BONES+['Root','WeaponCarrier']:continue
        if 'matrix' in n:
            a=n['matrix'];mat=Matrix(tuple(tuple(a[col*4+row] for col in range(4)) for row in range(4)))
        else:
            q=n.get('rotation',[0,0,0,1]);mat=Matrix.LocRotScale(Vector(n.get('translation',[0,0,0])),Quaternion((q[3],q[0],q[1],q[2])),Vector(n.get('scale',[1,1,1])))
        result[n['name']]={'matrix':mat,'parent':nodes[parents[i]].get('name') if i in parents else None}
    assert len(result)==11,len(result)
    return result
def validate_json(record):
    assert record['sample_rate_hz']==HZ and record['bones']==BONES
    assert set(record['clips'])==set(CLIPS)
    runtime=glb_nodes(PRODUCTION);stats={}
    for n in BONES:
        assert record['rest'][n]['parent']==runtime[n]['parent']
        assert matrix_error(unpack(record['rest'][n]),runtime[n]['matrix'])<1e-6,n
    for name,c in record['clips'].items():
        assert c['sample_rate_hz']==HZ and c['loop'] is False
        assert len(c['samples'])==round(c['length']*HZ)+1
        assert c['bindings']['first_sample']==c['samples'][0]
        assert abs(c['bindings']['sample_times'][-1]-c['length'])<1e-9
        e=c['events'];assert 0<=e['takeoff']<e['hold_start']<e['contact']<=e['end']==c['length']
        qerror=0
        for i,sample in enumerate(c['samples']):
            assert list(sample)==BONES
            for n,v in sample.items():
                assert set(v)=={'p','q'} and len(v['p'])==3 and len(v['q'])==4
                assert all(math.isfinite(x) for x in v['p']+v['q'])
                qerror=max(qerror,abs(sum(x*x for x in v['q'])-1))
                assert qerror<1e-5
                if i:assert sum(x*y for x,y in zip(c['samples'][i-1][n]['q'],v['q']))>=-.000001
        stats[name]={'samples':len(c['samples']),'length':c['length'],'events':e,'max_quaternion_norm_squared_error':qerror}
    if 'protection' in record:
        assert all(sha(ROOT/p)==h for p,h in record['protection']['protected_file_sha256'].items())
    return stats
if '--validate-only' in sys.argv:
    record=json.loads((OUT/'source.json').read_text())
    print('JUMP_JSON_VALIDATION_PASS',json.dumps(validate_json(record)),flush=True)
    raise SystemExit
assert Path(bpy.data.filepath).resolve()==SOURCE.resolve(),'Open the saved V2 study in background first'
protected_paths=[SOURCE,ORIGINAL,BASE.parent/'block_jump_v1/block_jump_v1_review.blend']
protected_paths+=list((ROOT/'game_mobile_3d/assets/characters').rglob('*.glb'))
protected_paths += [ROOT/'game_mobile_3d/assets/characters/r13/source.json',ROOT/'game_mobile_3d/assets/characters/r15/source.json']
protected_files={str(p.relative_to(ROOT)).replace('\\','/'):sha(p) for p in protected_paths}
protected_actions={a.name:action_hash(a) for a in bpy.data.actions}
source=bpy.data.objects['BlockJump_Study_Rig']
mesh=bpy.data.objects['BlockJump_SelectedFullBody']
with bpy.data.libraries.load(str(ORIGINAL),link=False) as (a,b):b.objects=['Player_Cuboid_Rig']
proto=b.objects[0]
assert len(proto.data.bones)==11
runtime_rest=glb_nodes(PRODUCTION)
rest={};rest_errors={}
for n in BONES:
    author=source.data.bones[ALIASES.get(n,n)];production=proto.data.bones[n]
    assert author.parent.name==production.parent.name==runtime_rest[n]['parent']
    err=matrix_error(author.matrix_local,production.matrix_local);assert err<1e-6,(n,err)
    local=production.parent.matrix_local.inverted()@production.matrix_local
    q=local.to_quaternion().normalized();p=list(local.translation)
    rest[n]={'p':p,'q':[q.x,q.y,q.z,q.w],'parent':production.parent.name,'source_bone':author.name}
    glb_err=matrix_error(local,runtime_rest[n]['matrix']);assert glb_err<1e-6,(n,glb_err)
    rest_errors[n]={'source_production_global_rest_matrix_error':err,'native_glb_local_rest_matrix_error':glb_err}
for side in ['L','R']:
    upper=source.data.bones['UpperArm.'+side];fore=source.data.bones['ForeArm.'+side];whole=proto.data.bones['Arm.'+side]
    assert fore.parent==upper and fore.use_connect
    assert (upper.head_local-whole.head_local).length<1e-6
    assert (fore.tail_local-whole.tail_local).length<1e-6
    assert abs(upper.length+fore.length-whole.length)<1e-6
scene=bpy.data.scenes.new('JUMP_V2_EXPORT_ONLY');scene.render.fps=FPS
rig=source.copy();rig.data=source.data.copy();rig.animation_data_clear();rig.parent=None;rig.matrix_world=Matrix.Identity(4)
scene.collection.objects.link(rig);bpy.context.window.scene=scene
assert not rig.constraints
rig.animation_data_create()
record={'schema_version':1,'source':str(SOURCE),'source_sha256':sha(SOURCE),'original_source':str(ORIGINAL),'original_source_sha256':sha(ORIGINAL),'source_rig':source.name,'production_glb':str(PRODUCTION),'production_glb_sha256':sha(PRODUCTION),'production_rig':proto.name,'sample_rate_hz':HZ,'bones':BONES,'bone_aliases':ALIASES,'transform_space':'absolute parent-relative bone-local transforms; rest included; R13 native JSON convention','quaternion_order':'xyzw','root_motion':False,'preview_world_travel_exported':False,'rest':rest,'clips':{}}
checks={'rest_errors':rest_errors,'maximum_global_pose_reconstruction_error':0.0,'maximum_rigid_vertex_reconstruction_error_m':0.0,'maximum_forearm_local_angle_radians':0.0,'maximum_unit_scale_error':0.0,'maximum_shoulder_inset_error_m':0.0,'minimum_leg_plateau_split_degrees':999.0,'sample_count':0,'preview_parent_influence':0.0}
groups={g.name:g.index for g in mesh.vertex_groups}
vertex_bindings=[(v.co.copy(),next(g.name for g in mesh.vertex_groups if any(x.group==g.index and x.weight>.999 for x in v.groups))) for v in mesh.data.vertices]
def globals_from_sample(sample):
    result={'Root':proto.data.bones['Root'].matrix_local.copy()}
    remaining=set(BONES)
    while remaining:
        done=[]
        for n in remaining:
            parent=rest[n]['parent']
            if parent in result:result[n]=result[parent]@unpack(sample[n]);done.append(n)
        assert done,'Unexpected disconnected export hierarchy'
        remaining.difference_update(done)
    return result
for name in CLIPS:
    action=bpy.data.actions[name];start,end=tuple(action.frame_range);length=(end-start)/FPS
    assert start==1 and end in [19,21]
    paths=sorted(set(c.data_path for c in curves(action)))
    assert not any('pose.bones["Root"]' in p or p.endswith('scale') for p in paths)
    rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
    samples=[];times=[];previous={}
    is_up=name.startswith('BlockJump_Up')
    events={'takeoff':2/FPS,'hold_start':5/FPS,'contact':(15 if is_up else 13)/FPS,'end':length}
    for index in range(round(length*HZ)+1):
        t=index/HZ;frame=start+t*FPS
        for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4);bone.rotation_mode='QUATERNION'
        scene.frame_set(int(frame),subframe=frame%1);bpy.context.view_layer.update()
        evaluated=rig.evaluated_get(bpy.context.evaluated_depsgraph_get())
        row={}
        for n in BONES:
            bone=evaluated.pose.bones[ALIASES.get(n,n)];local=bone.parent.matrix.inverted()@bone.matrix
            q=local.to_quaternion().normalized()
            if n in previous and q.dot(previous[n])<0:q.negate()
            previous[n]=q.copy();row[n]={'p':list(local.translation),'q':[q.x,q.y,q.z,q.w]}
            scale_error=max(abs(x-1) for x in local.to_scale());checks['maximum_unit_scale_error']=max(checks['maximum_unit_scale_error'],scale_error)
            assert scale_error<1e-5
        for side in ['L','R']:
            fore=evaluated.pose.bones['ForeArm.'+side];angle=fore.matrix_basis.to_quaternion().angle
            checks['maximum_forearm_local_angle_radians']=max(checks['maximum_forearm_local_angle_radians'],angle);assert angle<1e-5
            expect=-.032 if side=='L' else .032
            inset_error=abs(row['Arm.'+side]['p'][0]-rest['Arm.'+side]['p'][0]-expect)
            checks['maximum_shoulder_inset_error_m']=max(checks['maximum_shoulder_inset_error_m'],inset_error);assert inset_error<1e-6
        assert matrix_error(evaluated.pose.bones['Root'].matrix_basis,Matrix.Identity(4))<1e-7
        reconstructed=globals_from_sample(row)
        for n in BONES:
            err=matrix_error(reconstructed[n],evaluated.pose.bones[ALIASES.get(n,n)].matrix)
            checks['maximum_global_pose_reconstruction_error']=max(checks['maximum_global_pose_reconstruction_error'],err);assert err<2e-6,(name,index,n,err)
        for point,group in vertex_bindings:
            runtime_name='Arm.'+group.split('.')[-1] if group.startswith(('UpperArm.','ForeArm.')) else group
            source_pos=evaluated.pose.bones[group].matrix@source.data.bones[group].matrix_local.inverted()@point
            runtime_pos=reconstructed[runtime_name]@proto.data.bones[runtime_name].matrix_local.inverted()@point
            err=(source_pos-runtime_pos).length;checks['maximum_rigid_vertex_reconstruction_error_m']=max(checks['maximum_rigid_vertex_reconstruction_error_m'],err);assert err<2e-6
        if events['hold_start']<=t<=events['contact']:
            directions=[(reconstructed['Leg.'+s].translation-reconstructed['Leg.'+s]@Vector((0,.675,0))).normalized() for s in ['L','R']]
            split=math.degrees(math.acos(max(-1,min(1,directions[0].dot(directions[1])))))
            checks['minimum_leg_plateau_split_degrees']=min(checks['minimum_leg_plateau_split_degrees'],split);assert split>35
        samples.append(row);times.append(t);checks['sample_count']+=1
    record['clips'][name]={'action':name,'action_sha256':protected_actions[name],'frames':[start,end],'fps':FPS,'length':length,'loop':False,'sample_rate_hz':HZ,'entry_phase_offset_frames':8 if name.endswith('_OppositeLead') else 0,'events':events,'samples':samples,'bindings':{'first_sample':samples[0],'sample_times':times,'sample_index_time_rule':'index / sample_rate_hz; inclusive closing sample'}}
assert all(action_hash(bpy.data.actions[n])==h for n,h in protected_actions.items())
assert all(sha(ROOT/p)==h for p,h in protected_files.items())
record['protection']={'all_saved_sources_and_old_character_glbs_unchanged':True,'all_loaded_original_actions_unchanged':True,'protected_file_sha256':protected_files,'no_old_animation_replaced':True,'no_root_weaponcarrier_scale_or_previewtravel_channels':True,'arms_straight_and_full_length_compatible':True,'shoulder_inset_m':.032}
stats=validate_json(record)
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'source.json').write_text(json.dumps(record,separators=(',',':')))
readback=json.loads((OUT/'source.json').read_text());validate_json(readback)
report={'status':'EXPORT_VALIDATED_RUNTIME_POSES_ONLY','source_json_sha256':sha(OUT/'source.json'),'sample_rate_hz':HZ,'clips':stats,'checks':checks,'production_rest_compatible':True,'json_readback_validated':True,'source_and_old_glb_protection':record['protection'],'runtime_visual_review_required':True}
(OUT/'export_validation.json').write_text(json.dumps(report,indent=2))
print('JUMP_V2_EXPORT_PASS',json.dumps({'clips':stats,'checks':checks}),flush=True)
