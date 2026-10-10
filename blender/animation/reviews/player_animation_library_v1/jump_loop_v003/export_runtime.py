"""Read-only V003 continuous pose export over the full-arm V002 runtime asset.

Preserves its binary geometry, skin, UV, materials and all 40 older clips.
Only the preview carrier's vertical support correction is baked into Hips;
ballistic height and forward travel belong to the gameplay controller.
"""
import bpy, json, struct, hashlib, math
from pathlib import Path
from mathutils import Matrix, Quaternion, Vector

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]
SOURCE=HERE.parent/'player_animation_library_v1.blend'
BASE=ROOT/'game_mobile_3d/assets/characters/jump_set_v002/player_r15_jump_set_v002.glb'
OUT=ROOT/'game_mobile_3d/assets/characters/jump_loop_v003'
HZ=120
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
protected={str(p.relative_to(ROOT)):sha(p) for p in [SOURCE,BASE]}
assert Path(bpy.data.filepath).resolve()==SOURCE.resolve()
raw=BASE.read_bytes();size=struct.unpack_from('<I',raw,12)[0]
doc=json.loads(raw[20:20+size]);binary=bytearray(raw[28+size:])
old_animations=json.dumps(doc['animations'],sort_keys=True)
old_meshes=json.dumps(doc['meshes'],sort_keys=True)
names={n['name']:i for i,n in enumerate(doc['nodes'])}
parents={c:i for i,n in enumerate(doc['nodes']) for c in n.get('children',[])}
types={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
formats={5121:'B',5123:'H',5126:'f'}
def read(index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
    width=types[a['type']];fmt=formats[a['componentType']]
    stride=v.get('byteStride',width*struct.calcsize(fmt));offset=v.get('byteOffset',0)+a.get('byteOffset',0)
    return [list(struct.unpack_from('<'+fmt*width,binary,offset+i*stride)) for i in range(a['count'])]
def append(values,kind):
    while len(binary)%4:binary.append(0)
    offset=len(binary);flat=[x for row in values for x in row]
    binary.extend(struct.pack('<'+'f'*len(flat),*flat))
    view=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':4*len(flat)})
    a={'bufferView':view,'componentType':5126,'count':len(values),'type':kind}
    if kind=='SCALAR':a.update(min=[min(flat)],max=[max(flat)])
    index=len(doc['accessors']);doc['accessors'].append(a);return index
def node_matrix(node):
    q=node.get('rotation',[0,0,0,1])
    return Matrix.LocRotScale(Vector(node.get('translation',[0,0,0])),Quaternion((q[3],*q[:3])),Vector(node.get('scale',[1,1,1])))
def global_rest(i):
    local=node_matrix(doc['nodes'][i]);return global_rest(parents[i])@local if i in parents else local
def error(a,b):return max(abs(a[r][c]-b[r][c]) for r in range(4) for c in range(4))
aliases={'Arm.L':'UpperArm.L','Arm.R':'UpperArm.R'}
bones=['Hips','Spine','Chest','Neck','Head','Leg.L','Leg.R','Arm.L','Arm.R','ForeArm.L','ForeArm.R']
cases=json.loads((HERE/'manifest.json').read_text())['cases']
records={};reports={};scene=bpy.data.scenes.new('V003_RUNTIME_EXPORT_ONLY');bpy.context.window.scene=scene
C=Matrix.Rotation(-math.pi/2,4,'X')
for kind,cfg in cases.items():
    rig=bpy.data.objects[cfg['rig']];mesh=bpy.data.objects[cfg['mesh']];action=bpy.data.actions[cfg['action']]
    assert tuple(action.frame_range)==(1,cfg['period']+1)
    for name in bones:
        b=rig.data.bones[aliases.get(name,name)]
        assert error(b.parent.matrix_local.inverted()@b.matrix_local,node_matrix(doc['nodes'][names[name]]))<1e-6,name
    clone=rig.copy();clone.data=rig.data.copy();clone.parent=None;clone.matrix_world=Matrix.Identity(4)
    clone.animation_data_clear();scene.collection.objects.link(clone);clone.animation_data_create()
    clone.animation_data.action=action;clone.animation_data.action_slot=action.slots[0]
    carrier=bpy.data.objects[cfg['carrier']]
    curve=next(c for l in carrier.animation_data.action.layers for s in l.strips for bag in s.channelbags for c in bag.fcurves if c.data_path=='location' and c.array_index==2)
    take=cfg['take']/30;contact=cfg['land']/30;end=cfg['period']/30
    corners=[]
    for v in mesh.data.vertices:
        group=next(mesh.vertex_groups[w.group].name for w in v.groups if w.weight>.999)
        group={'UpperArm.L':'Arm.L','UpperArm.R':'Arm.R'}.get(group,group)
        corners.append((C@v.co,group))
    samples=[];previous={};max_error=0.0;clearance=1e6
    for index in range(round(end*HZ)+1):
        time=index/HZ;frame=1+time*30
        scene.frame_set(int(frame),subframe=frame%1);bpy.context.view_layer.update()
        evaluated=clone.evaluated_get(bpy.context.evaluated_depsgraph_get())
        u=max(0,min(1,(time-take)/(contact-take)));arc=4*cfg['height']*u*(1-u) if take<time<contact else 0
        support=curve.evaluate(frame)-arc
        row={};runtime_globals={'Root':global_rest(names['Root'])}
        for name in bones:
            b=evaluated.pose.bones[aliases.get(name,name)];local=b.parent.matrix.inverted()@b.matrix
            q=local.to_quaternion().normalized()
            if name in previous and q.dot(previous[name])<0:q.negate()
            previous[name]=q.copy();p=local.translation.copy()
            if name=='Hips':p+=Vector((0,support,0))
            row[name]={'p':list(p),'q':[q.x,q.y,q.z,q.w]}
            parent=doc['nodes'][parents[names[name]]]['name']
            runtime_globals[name]=runtime_globals[parent]@Matrix.LocRotScale(p,q,Vector((1,1,1)))
        for v,group in corners:
            n=aliases.get(group,group)
            expected=C@evaluated.pose.bones[n].matrix@rig.data.bones[n].matrix_local.inverted()@C.inverted()@v+Vector((0,support,0))
            actual=runtime_globals[group]@global_rest(names[group]).inverted()@v
            max_error=max(max_error,(actual-expected).length)
            if group.startswith('Leg.'):clearance=min(clearance,actual.y+arc)
        samples.append(row)
    assert max_error<3e-6,(kind,max_error)
    assert clearance>-.0005,(kind,clearance)
    animation={'name':cfg['action'],'channels':[],'samplers':[],'extras':{'loop':True,'source_action':cfg['action']}}
    times=append([[i/HZ] for i in range(len(samples))],'SCALAR')
    for name in bones:
        for key,path,typ in [('p','translation','VEC3'),('q','rotation','VEC4')]:
            output=append([s[name][key] for s in samples],typ);sampler=len(animation['samplers'])
            animation['samplers'].append({'input':times,'output':output,'interpolation':'LINEAR'})
            animation['channels'].append({'sampler':sampler,'target':{'node':names[name],'path':path}})
    doc['animations'].append(animation)
    records[kind]={'action':cfg['action'],'length':end,'fps':30,'frames':[1,cfg['period']+1],'sample_rate_hz':HZ,'samples':samples,
                  'events':{'takeoff':take,'apex':(take+contact)/2,'contact':contact,'end':end},'apex_height':cfg['height']}
    reports[kind]={'action':cfg['action'],'samples':len(samples),'vertex_reconstruction_error_m':max_error,'minimum_source_sole_height_m':clearance,'tracks':len(animation['channels'])}
assert json.dumps(doc['animations'][:-2],sort_keys=True)==old_animations
assert json.dumps(doc['meshes'],sort_keys=True)==old_meshes
assert bytes(binary[:len(raw[28+size:])])==raw[28+size:]
doc['buffers']=[{'byteLength':len(binary)}]
encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4);binary+=b'\0'*((-len(binary))%4)
OUT.mkdir(parents=True,exist_ok=True);output=OUT/'player_r15_jump_loop_v003.glb'
output.write_bytes(struct.pack('<III',0x46546c67,2,28+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary)
(OUT/'source.json').write_text(json.dumps(records,separators=(',',':')))
assert all(sha(ROOT/p)==h for p,h in protected.items())
report={'protected_sha256':protected,'output_sha256':sha(output),'preserved_old_clips':40,'new_clips':reports,'geometry_skin_uv_material_binary_unchanged':True,'preview_carrier_exported':False,'root_motion':False,'vertical_support_correction_baked':True,'artistic_status':'AWAITING HUMAN REVIEW'}
(OUT/'export_validation.json').write_text(json.dumps(report,indent=2))
print('V003_EXPORT_PASS',json.dumps(report),flush=True)
