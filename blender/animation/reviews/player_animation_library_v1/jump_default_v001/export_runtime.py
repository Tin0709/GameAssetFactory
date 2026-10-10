"""Read-only saved-source export: retain R15 geometry/UV/materials/all 36 clips.

Restore the two authored forearm joints and their original rigid vertex bindings
so the newly authored elbows survive export. No preview carrier/root motion.
Run background Blender on player_animation_library_v1.blend.
"""
import bpy, json, struct, hashlib, math
from pathlib import Path
from mathutils import Matrix, Quaternion, Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
SOURCE = HERE.parent / 'player_animation_library_v1.blend'
BASE = ROOT / 'game_mobile_3d/assets/characters/r15/player_r15_combat_strafe_v1.glb'
OUT = ROOT / 'game_mobile_3d/assets/characters/jump_default_v001'
HZ = 120
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
protected = {str(p.relative_to(ROOT)): sha(p) for p in [SOURCE, BASE]}
assert Path(bpy.data.filepath).resolve() == SOURCE.resolve()
rig = bpy.data.objects['JD1_Player_Rig']
mesh = bpy.data.objects['JD1_Player_Mesh']
action = bpy.data.actions['Jump_Default_v001']
assert tuple(action.frame_range) == (1, 25)
raw = BASE.read_bytes(); size = struct.unpack_from('<I', raw, 12)[0]
doc = json.loads(raw[20:20+size]); binary = bytearray(raw[28+size:])
old_animations = json.dumps(doc['animations'], sort_keys=True)
names = {n['name']: i for i,n in enumerate(doc['nodes'])}
skin = doc['skins'][0]
types = {'SCALAR':1, 'VEC2':2, 'VEC3':3, 'VEC4':4, 'MAT4':16}
formats = {5121:'B', 5123:'H', 5126:'f'}
def read(index):
    a = doc['accessors'][index]; v = doc['bufferViews'][a['bufferView']]
    width = types[a['type']]; fmt = formats[a['componentType']]
    stride = v.get('byteStride', width*struct.calcsize(fmt))
    offset = v.get('byteOffset',0)+a.get('byteOffset',0)
    return [list(struct.unpack_from('<'+fmt*width, binary, offset+i*stride)) for i in range(a['count'])]
def append(values, kind, component=5126):
    while len(binary)%4: binary.append(0)
    offset = len(binary); flat = [x for row in values for x in row]
    fmt = formats[component]; binary.extend(struct.pack('<'+fmt*len(flat), *flat))
    view = len(doc['bufferViews']); doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(flat)*struct.calcsize(fmt)})
    accessor = {'bufferView':view,'componentType':component,'count':len(values),'type':kind}
    if kind == 'SCALAR': accessor.update(min=[min(flat)],max=[max(flat)])
    index = len(doc['accessors']); doc['accessors'].append(accessor); return index
def node_matrix(node):
    q = node.get('rotation',[0,0,0,1])
    return Matrix.LocRotScale(Vector(node.get('translation',[0,0,0])),Quaternion((q[3],*q[:3])),Vector(node.get('scale',[1,1,1])))
def local_rest(bone):
    b = rig.data.bones[bone]
    return b.parent.matrix_local.inverted() @ b.matrix_local
def error(a,b): return max(abs(a[r][c]-b[r][c]) for r in range(4) for c in range(4))
aliases = {'Arm.L':'UpperArm.L','Arm.R':'UpperArm.R'}
for name in ['Hips','Spine','Chest','Neck','Head','Leg.L','Leg.R','Arm.L','Arm.R']:
    assert error(local_rest(aliases.get(name,name)),node_matrix(doc['nodes'][names[name]])) < 1e-6, name
for side in ['L','R']:
    name = 'ForeArm.'+side; local = local_rest(name)
    q = local.to_quaternion().normalized()
    names[name] = len(doc['nodes'])
    doc['nodes'].append({'name':name,'translation':list(local.translation),'rotation':[q.x,q.y,q.z,q.w]})
    doc['nodes'][names['Arm.'+side]].setdefault('children',[]).append(names[name])
    skin['joints'].append(names[name])
parents = {child:i for i,n in enumerate(doc['nodes']) for child in n.get('children',[])}
def global_rest(i):
    local = node_matrix(doc['nodes'][i])
    return global_rest(parents[i]) @ local if i in parents else local
inverse = read(skin['inverseBindMatrices'])
for side in ['L','R']:
    inv = global_rest(names['ForeArm.'+side]).inverted()
    inverse.append([inv[r][c] for c in range(4) for r in range(4)])
skin['inverseBindMatrices'] = append(inverse,'MAT4')
joint_names = {doc['nodes'][n]['name']:i for i,n in enumerate(skin['joints'])}

# Match original source polygon corners, including UVs at coincident elbow seams.
# Only the JOINTS accessor changes; POSITION/NORMAL/UV/indices/material stay native.
corners = []
for loop in mesh.data.loops:
    v = mesh.data.vertices[loop.vertex_index]; uv = mesh.data.uv_layers.active.data[loop.index].uv
    group = next(mesh.vertex_groups[w.group].name for w in v.groups if w.weight > .999)
    group = {'UpperArm.L':'Arm.L','UpperArm.R':'Arm.R'}.get(group,group)
    corners.append(([v.co.x,v.co.z,-v.co.y,uv.x,1-uv.y],group))
primitive = doc['meshes'][0]['primitives'][0]; attrs = primitive['attributes']
positions = read(attrs['POSITION']); uv = read(attrs['TEXCOORD_0']); joints = read(attrs['JOINTS_0'])
weights = read(attrs['WEIGHTS_0']); bound = {}
normals = read(attrs['NORMAL']); indices = [v[0] for v in read(primitive['indices'])]
adjacent = [[] for _ in positions]
for k in range(0,len(indices),3):
    tri=indices[k:k+3]; height=sum(positions[v][1] for v in tri)/3
    for v in tri: adjacent[v].append(height)
for i,(p,t) in enumerate(zip(positions,uv)):
    matches = {group for corner,group in corners if max(abs(a-b) for a,b in zip(p+t,corner)) < 2e-6}
    if len(matches)==2 and all(n.startswith(('Arm.','ForeArm.')) for n in matches):
        # Shared elbow coordinates/UV: the indexed face belongs to one cuboid.
        height=sum(adjacent[i])/len(adjacent[i]); elbow=rig.data.bones['ForeArm.L'].head_local.z
        lower=height<elbow-1e-6 or (abs(height-elbow)<1e-6 and normals[i][1]>.9)
        matches={n for n in matches if n.startswith('ForeArm.')==lower}
    assert len(matches)==1,(i,p,t,matches)
    group = matches.pop(); bound[group] = bound.get(group,0)+1
    assert abs(weights[i][0]-1)<1e-7 and sum(weights[i][1:])<1e-7
    joints[i][0] = joint_names[group]
assert bound['ForeArm.L']==bound['ForeArm.R']==24
attrs['JOINTS_0'] = append(joints,'VEC4',5121)

scene = bpy.data.scenes.new('JUMP_DEFAULT_RUNTIME_EXPORT_ONLY')
clone = rig.copy(); clone.data = rig.data.copy(); clone.parent=None
clone.matrix_world=Matrix.Identity(4); clone.animation_data_clear(); scene.collection.objects.link(clone)
bpy.context.window.scene=scene; clone.animation_data_create()
clone.animation_data.action=action; clone.animation_data.action_slot=action.slots[0]
bones = ['Hips','Spine','Chest','Neck','Head','Leg.L','Leg.R','Arm.L','Arm.R','ForeArm.L','ForeArm.R']
samples=[]; previous={}; max_error=0.0
C = Matrix.Rotation(-math.pi/2,4,'X')
for index in range(97):
    time=index/HZ; frame=1+time*30
    scene.frame_set(int(frame),subframe=frame%1); bpy.context.view_layer.update()
    evaluated=clone.evaluated_get(bpy.context.evaluated_depsgraph_get()); row={}
    runtime_globals={'Root':global_rest(names['Root'])}
    for name in bones:
        b=evaluated.pose.bones[aliases.get(name,name)]; local=b.parent.matrix.inverted()@b.matrix
        q=local.to_quaternion().normalized()
        if name in previous and q.dot(previous[name])<0:q.negate()
        previous[name]=q.copy(); row[name]={'p':list(local.translation),'q':[q.x,q.y,q.z,q.w]}
        parent=doc['nodes'][parents[names[name]]]['name']
        runtime_globals[name]=runtime_globals[parent]@Matrix.LocRotScale(local.translation,q,Vector((1,1,1)))
    for corner,group in corners:
        v=Vector(corner[:3]); source_name=aliases.get(group,group)
        expected=C@evaluated.pose.bones[source_name].matrix@rig.data.bones[source_name].matrix_local.inverted()@C.inverted()@v
        actual=runtime_globals[group]@global_rest(names[group]).inverted()@v
        max_error=max(max_error,(actual-expected).length)
    samples.append(row)
assert max_error < 3e-6,max_error
animation={'name':'Jump_Default_v001','channels':[],'samplers':[],'extras':{'loop':False,'source_action':'Jump_Default_v001'}}
times=append([[i/HZ] for i in range(len(samples))],'SCALAR')
for name in bones:
    for key,path,kind in [('p','translation','VEC3'),('q','rotation','VEC4')]:
        output=append([s[name][key] for s in samples],kind); sampler=len(animation['samplers'])
        animation['samplers'].append({'input':times,'output':output,'interpolation':'LINEAR'})
        animation['channels'].append({'sampler':sampler,'target':{'node':names[name],'path':path}})
assert json.dumps(doc['animations'],sort_keys=True)==old_animations
doc['animations'].append(animation); doc['buffers']=[{'byteLength':len(binary)}]
encoded=json.dumps(doc,separators=(',',':')).encode(); encoded+=b' '*((-len(encoded))%4)
binary+=b'\0'*((-len(binary))%4)
OUT.mkdir(parents=True,exist_ok=True); output=OUT/'player_r15_jump_default_v001.glb'
output.write_bytes(struct.pack('<III',0x46546c67,2,28+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary)
record={'action':'Jump_Default_v001','length':.8,'fps':30,'frames':[1,25],'sample_rate_hz':HZ,'samples':samples,'events':{'takeoff':4/30,'apex':11/30,'contact':18/30,'end':.8},'apex_height':.63}
(OUT/'source.json').write_text(json.dumps(record,separators=(',',':')))
assert all(sha(ROOT/p)==h for p,h in protected.items())
report={'source':str(SOURCE),'protected_sha256':protected,'output_sha256':sha(output),'preserved_old_clips':len(doc['animations'])-1,'new_clip':'Jump_Default_v001','sample_count':len(samples),'maximum_vertex_reconstruction_error_m':max_error,'vertex_bindings':bound,'unchanged_geometry_uv_normals_indices_materials':True,'preview_carrier_exported':False,'root_motion':False,'artistic_status':'AWAITING HUMAN REVIEW'}
(OUT/'export_validation.json').write_text(json.dumps(report,indent=2))
print('JUMP_DEFAULT_EXPORT_PASS',json.dumps(report),flush=True)
