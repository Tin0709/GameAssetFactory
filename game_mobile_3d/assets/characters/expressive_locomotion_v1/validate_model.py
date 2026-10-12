"""Compare the reused runtime model to all three approved Blender sources."""
import bpy,json,struct,hashlib,math
from pathlib import Path
from mathutils import Matrix,Vector
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
BASE=ROOT/'game_mobile_3d/assets/characters/jump_gif_v004/player_r15_jump_gif_v004.glb'
raw=BASE.read_bytes();size=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+size]);binary=raw[28+size:]
widths={'VEC2':2,'VEC3':3,'VEC4':4};formats={5126:'f',5123:'H',5121:'B'}
def read(index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']];w=widths[a['type']];f=formats[a['componentType']]
    start=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',w*struct.calcsize(f))
    return [struct.unpack_from('<'+f*w,binary,start+i*stride) for i in range(a['count'])]
attrs=doc['meshes'][0]['primitives'][0]['attributes'];positions=read(attrs['POSITION']);joints=read(attrs['JOINTS_0']);weights=read(attrs['WEIGHTS_0'])
skin=doc['skins'][0]['joints'];runtime=[]
for p,js,ws in zip(positions,joints,weights):
    assert max(ws)>.99999
    group=doc['nodes'][skin[js[max(range(4),key=lambda i:ws[i])]]]['name']
    runtime.append((Vector(p),group))
image=doc['images'][0];view=doc['bufferViews'][image['bufferView']]
png=binary[view['byteOffset']:view['byteOffset']+view['byteLength']]
png_sha=hashlib.sha256(png).hexdigest();C=Matrix.Rotation(-math.pi/2,4,'X')
manifest=json.loads((ROOT/'blender/animation/showcase/animation_manifest.json').read_text());report={}
for name in ['Idle_Expressive_Test_v3','Walk_Expressive_Test','Run_Expressive_v3_Test']:
    cfg=next(x for x in manifest['animations'] if x['action']==name)
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/cfg['source']),load_ui=False)
    mesh=bpy.data.objects[cfg['source_mesh']];source=[]
    for v in mesh.data.vertices:
        group=next(mesh.vertex_groups[g.group].name for g in v.groups if g.weight>.99999)
        group=group.replace('UpperArm.','Arm.');source.append((C@v.co,group))
    e1=max(min((p-q).length for q,h in source if h==g) for p,g in runtime)
    e2=max(min((p-q).length for q,h in runtime if h==g) for p,g in source)
    textures=[]
    for slot in mesh.material_slots:
        for node in slot.material.node_tree.nodes:
            if node.type=='TEX_IMAGE' and node.image:
                im=node.image
                payload=bytes(im.packed_file.data) if im.packed_file else Path(bpy.path.abspath(im.filepath)).read_bytes()
                textures.append(hashlib.sha256(payload).hexdigest())
    assert max(e1,e2)<2e-6,(name,e1,e2)
    assert png_sha in textures,(name,png_sha,textures)
    report[name]={'max_rest_vertex_error_m':max(e1,e2),'runtime_vertices':len(runtime),'source_vertices':len(source),'embedded_atlas_byte_identical':True,'texture_sha256':png_sha}
(HERE/'geometry_material_validation.json').write_text(json.dumps(report,indent=2))
print('MODEL_APPEARANCE_PASS',json.dumps(report),flush=True)
