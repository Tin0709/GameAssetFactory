"""Versioned test-only UV correction from approved source; base GLB unchanged."""
import bpy,json,struct,math,hashlib
from pathlib import Path
from mathutils import Matrix,Vector
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
base=ROOT/'game_mobile_3d/assets/characters/jump_gif_v004/player_r15_jump_gif_v004.glb'
raw=base.read_bytes();n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n]);binary=bytearray(raw[28+n:])
manifest=json.loads((ROOT/'blender/animation/showcase/animation_manifest.json').read_text())
cfg=next(x for x in manifest['animations'] if x['action']=='Run_Expressive_v3_Test')
bpy.ops.wm.open_mainfile(filepath=str(ROOT/cfg['source']),load_ui=False)
mesh=bpy.data.objects[cfg['source_mesh']].data;obj=bpy.data.objects[cfg['source_mesh']]
C=Matrix.Rotation(-math.pi/2,3,'X');source=[]
for poly in mesh.polygons:
    normal=C@poly.normal
    for li in poly.loop_indices:
        vertex=mesh.vertices[mesh.loops[li].vertex_index]
        group=next(obj.vertex_groups[g.group].name for g in vertex.groups if g.weight>.999).replace('UpperArm.','Arm.')
        uv=mesh.uv_layers.active.data[li].uv
        source.append((C@vertex.co,normal,group,(uv.x,1-uv.y)))
formats={5126:'f',5123:'H',5121:'B'};widths={'VEC2':2,'VEC3':3,'VEC4':4}
def read(index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']];w=widths[a['type']];f=formats[a['componentType']]
    offset=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',w*struct.calcsize(f))
    return [struct.unpack_from('<'+f*w,binary,offset+i*stride) for i in range(a['count'])]
attrs=doc['meshes'][0]['primitives'][0]['attributes'];ps=read(attrs['POSITION']);ns=read(attrs['NORMAL']);js=read(attrs['JOINTS_0']);ws=read(attrs['WEIGHTS_0']);uvs=read(attrs['TEXCOORD_0'])
skin=doc['skins'][0]['joints'];a=doc['accessors'][attrs['TEXCOORD_0']];view=doc['bufferViews'][a['bufferView']];start=view.get('byteOffset',0)+a.get('byteOffset',0);stride=view.get('byteStride',8)
changed=0;max_diff=0;new=[]
for i,(p,normal,j,w,uv) in enumerate(zip(ps,ns,js,ws,uvs)):
    group=doc['nodes'][skin[j[max(range(4),key=lambda k:w[k])]]]['name']
    candidates=[s for s in source if s[2]==group and (s[0]-Vector(p)).length<2e-6 and s[1].dot(Vector(normal))>.999]
    assert candidates,(i,group,p,normal)
    target=candidates[0][3]
    assert all((Vector(target)-Vector(s[3])).length<1e-6 for s in candidates)
    diff=(Vector(uv)-Vector(target)).length;max_diff=max(max_diff,diff)
    if diff>1e-6:changed+=1
    struct.pack_into('<ff',binary,start+i*stride,*target);new.append(target)
# Assert all other binary data, including skin/geometry/material texture and all
# old animation tracks, remains byte-identical. Only the UV accessor is patched.
old=raw[28+n:];allowed={x for i in range(len(new)) for x in range(start+i*stride,start+i*stride+8)}
assert all(x==old[i] or i in allowed for i,x in enumerate(binary))
doc['buffers']=[{'byteLength':len(binary)}]
encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4)
output=HERE/'player_expressive_locomotion.glb'
output.write_bytes(struct.pack('<III',0x46546c67,2,28+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary)
(HERE/'model_export_validation.json').write_text(json.dumps({'base_sha256':hashlib.sha256(raw).hexdigest(),'output_sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'corrected_uv_vertices':changed,'max_old_to_approved_uv_difference':max_diff,'only_uv_accessor_changed':True,'geometry_skin_rig_texture_old_animations_unchanged':True,'source':cfg['source']},indent=2))
print('TEST_UV_EXPORT',changed,'vertices corrected; max UV difference',max_diff,flush=True)
