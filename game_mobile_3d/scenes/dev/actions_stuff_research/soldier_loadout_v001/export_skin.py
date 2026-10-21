"""Read-only current Soldier export. No library, rig or Action is ever saved.
Body uses the original ten inverse binds. Flat head layers and authored facial
shape keys are separate dev render meshes, driven after the approved presenter.
"""
from pathlib import Path
import bpy,hashlib,json,sys,struct,shutil,math
from mathutils import Matrix,Vector
ROOT=Path(__file__).resolve().parents[5];OUT=Path(__file__).resolve().parent
SOURCE=ROOT/'blender/characters/soldier/showcase/SOLDIER_Asset_Library.blend'
F=ROOT/'blender/characters/soldier/facial';H=ROOT/'blender/characters/soldier/assets/haircards_v001'
sys.path.insert(0,str(F));import expression_model as model
RIFLE=ROOT/'blender/weapons/rifle_sand_block_v1/Rifle_Sand_Block_V1.glb'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
before={str(p.relative_to(ROOT)):sha(p) for p in [SOURCE,RIFLE,ROOT/'blender/weapons/rifle_sand_block_v1/Rifle_Sand_Block_V1.blend']}
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
reg=json.loads(bpy.data.scenes['SOLDIER_ASSET_LIBRARY']['soldier_registry']);entry=next(e for e in reg['entries'] if e['id']=='SOLDIER_Skin_v001')
rig=bpy.data.objects[entry['rig']];body=bpy.data.objects[entry['body']];clothes=bpy.data.objects[entry['clothing']]
C=Matrix.Rotation(-math.pi/2,4,'X')
def vec(v):return [round(float(x),9) for x in v]
def mesh_data(obj,parts=None):
 m=obj.data;tr=C@obj.matrix_world;verts=[];normals=[];uv=[];indices=[];source_indices=[];bone_ids=[]
 part_ids={vi:i for i,p in enumerate(parts or []) for vi in p['vertices']}
 for poly in m.polygons:
  first=len(verts)
  for li in poly.loop_indices:
   vi=m.loops[li].vertex_index;source_indices.append(vi);verts.append(vec(tr@m.vertices[vi].co));normals.append(vec(tr.to_3x3()@poly.normal));uv.append(vec(Vector((m.uv_layers.active.data[li].uv.x,1-m.uv_layers.active.data[li].uv.y))));bone_ids.append(part_ids.get(vi,0))
  for j in range(1,len(poly.vertices)-1):indices.extend([first,first+j,first+j+1])
 return dict(vertices=verts,normals=normals,uv=uv,indices=indices,part_ids=bone_ids),source_indices
head={}
for key,name in [('hair','SOLDIER_HairCards_v001'),('band','SOLDIER_Bandana_2D_v001')]:
 obj=bpy.data.objects[name];parts=json.loads(obj['parts_json']);data,_=mesh_data(obj,parts);records=[]
 for p in parts:
  pts=[C@obj.matrix_world@obj.data.vertices[i].co for i in p['vertices']]
  # Top edge is the fixed hinge. Each broad flat card remains rigid.
  edge=sorted(pts,key=lambda v:v.y,reverse=True)[:2];pivot=sum(edge,Vector())/2
  fixed=key=='band' and 'Tail.' not in p['name'] or key=='hair' and ('cap' in p['name'] or 'outer crown' in p['name'] or 'outer layer' in p['name'] or 'stepped outer fringe' in p['name'])
  records.append(dict(name=p['name'],pivot=vec(pivot),fixed=fixed))
 data['parts']=records;head[key]=data
face=bpy.data.objects['SF_Face_Mesh'];data,source_indices=mesh_data(face);data['shapes']={}
tr=C@face.matrix_world
for key in list(face.data.shape_keys.key_blocks)[1:]:data['shapes'][key.name]=[vec(tr@key.data[i].co) for i in source_indices]
head['face']=data
head['facial_model']={'neutral':model.NEUTRAL,'limits':model.LIMITS,'presets':model.PRESETS,'events':model.EVENTS,'situations':model.SITUATIONS}
# Save compact reviewed-geometry data and original pixel atlases; no image synthesis.
(OUT/'appearance.json').write_text(json.dumps(head,separators=(',',':'))+'\n')
for src,dst in [(H/'soldier_hair_bandana_atlas.png','head_atlas.png'),(F/'soldier_face_atlas.png','face_atlas.png')]:shutil.copy2(src,OUT/dst)
scene=bpy.data.scenes.new('EXPORT_ONLY');bpy.context.window.scene=scene
for obj in [rig,body,clothes]:scene.collection.objects.link(obj);obj.hide_set(False);obj.hide_viewport=False;obj.hide_render=False
rig.animation_data_clear()
for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
bpy.ops.object.select_all(action='DESELECT')
for obj in [body,clothes]:obj.select_set(True)
bpy.context.view_layer.objects.active=body;bpy.ops.object.join();mesh=bpy.context.object;mesh.name='Soldier_Skin_v001';rig.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'Soldier_Skin_v001.glb'),export_format='GLB',use_selection=True,export_animations=False,export_skins=True,export_yup=True,export_cameras=False,export_lights=False)
# glTF importer must use hard cutout, never translucent cloth overdraw.
p=OUT/'Soldier_Skin_v001.glb';raw=p.read_bytes();size,kind=struct.unpack_from('<II',raw,12);doc=json.loads(raw[20:20+size]);tail=raw[20+size:]
for mat in doc['materials']:
 if 'WC_Ragged' in mat.get('name',''):mat.update(alphaMode='MASK',alphaCutoff=.5,doubleSided=True)
encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4);p.write_bytes(struct.pack('<III',0x46546c67,2,20+len(encoded)+len(tail))+struct.pack('<II',len(encoded),kind)+encoded+tail)
shutil.copy2(RIFLE,OUT/RIFLE.name)
assert all(sha(ROOT/p)==h for p,h in before.items())
report={'research_only':True,'authorization':'Latest worn Soldier + secondary hair/tails + existing facial system in same gameplay lab, user2026-10-21','source_sha256':before,'body_triangles':sum(len(p.vertices)-2 for p in mesh.data.polygons),'head_triangles':sum(len(head[k]['indices'])//3 for k in ['hair','band','face']),'backpack_equipped':False,'source_actions_exported':False,'source_blend_saved':False}
(OUT/'sources.json').write_text(json.dumps(report,indent=2)+'\n');print('SOURCE_PRESERVED_EXPORT_OK',json.dumps(report),flush=True)
