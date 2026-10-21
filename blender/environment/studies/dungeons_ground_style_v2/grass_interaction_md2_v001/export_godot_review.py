"""Read-only source extraction for the authorized SAME Godot development lab."""
import bpy
import hashlib
import json
from pathlib import Path

D=Path(__file__).resolve().parent;R=D.parents[4];LIB=D.parent/'dungeons_ground_style_v2.blend'
OUT=R/'game_mobile_3d/scenes/dev/actions_stuff_research/grass_md2_v001/assets';OUT.mkdir(parents=True,exist_ok=True)
before=hashlib.sha256(LIB.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(LIB));s=bpy.context.scene
wind=json.loads(s['md2_wind_review']);names=wind['masters'][:4]+wind['masters'][5:9]
images={}
def texture(material):
    image=next(n.image for n in material.node_tree.nodes if n.type=='TEX_IMAGE' and n.image)
    if image.name not in images:
        name='atlas_%02d.png'%len(images);assert image.packed_file
        (OUT/name).write_bytes(image.packed_file.data);images[image.name]=name
    return images[image.name]
def vec(v):return [float(v[0]),float(v[2]),float(-v[1])]
def mesh_record(obj,family):
    mesh=obj.data;mesh.calc_loop_triangles();uv=mesh.uv_layers.active.data
    surfaces=[]
    for mi,mat in enumerate(mesh.materials):
        vertices=[];normals=[];uvs=[];roots=[];colors=[]
        for tri in mesh.loop_triangles:
            if tri.material_index!=mi:continue
            for loop_index in [tri.loops[0],tri.loops[2],tri.loops[1]]:
                vi=mesh.loops[loop_index].vertex_index
                vertices.append(vec(mesh.vertices[vi].co));normals.append(vec(tri.normal));u=uv[loop_index].uv
                uvs.append([float(u.x),1.-float(u.y)])
                if family!='ground':
                    root=mesh.attributes['md2_wind_root'].data[vi].vector
                    roots.append([float(root.x),float(-root.y)])
                    colors.append([mesh.attributes['md2_wind_t'].data[vi].value,mesh.attributes['md2_wind_length'].data[vi].value,mesh.attributes['md2_wind_phase'].data[vi].value/6.283185307179586,1.])
        if vertices:surfaces.append({'atlas':texture(mat),'vertices':vertices,'normals':normals,'uv':uvs,'roots':roots,'colors':colors})
    return {'name':obj['wind_source'] if family!='ground' else obj.name,'family':family,'surfaces':surfaces}
data={'source_library_sha256':before,'research_only':True,'meshes':[mesh_record(bpy.data.objects[n],'short' if i<4 else 'tall') for i,n in enumerate(names)],
      'ground':mesh_record(bpy.data.objects['ENV_GrassBlock_DI_V3'],'ground'),'metadata':'Rest geometry only. UV2=local root XZ. COLOR=height fraction, blade length, card phase,1. No baked Wind/Action.'}
(OUT/'grass_data.json').write_text(json.dumps(data,separators=(',',':'))+'\n')
assert hashlib.sha256(LIB.read_bytes()).hexdigest()==before
print('MD2_REVIEW_EXPORTED',len(data['meshes']),'variants',len(images),'packed original images; source unchanged',flush=True)
