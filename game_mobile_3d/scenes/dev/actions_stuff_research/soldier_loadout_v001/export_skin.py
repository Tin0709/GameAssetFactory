"""Read-only export of the existing Soldier collection; never saves Blender sources."""
from pathlib import Path
import bpy, hashlib, json, shutil
from mathutils import Matrix
ROOT=Path(__file__).resolve().parents[5]
OUT=Path(__file__).resolve().parent
SOURCE=ROOT/'blender/characters/soldier/showcase/SOLDIER_Asset_Library.blend'
RIFLE=ROOT/'blender/weapons/rifle_sand_block_v1/Rifle_Sand_Block_V1.glb'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
before={str(p.relative_to(ROOT)):sha(p) for p in [SOURCE,RIFLE,ROOT/'blender/weapons/rifle_sand_block_v1/Rifle_Sand_Block_V1.blend']}
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
collection=bpy.data.collections['SOLDIER_Skin_v001_PENDING']
rig=next(o for o in collection.all_objects if o.type=='ARMATURE')
meshes=[o for o in collection.all_objects if o.type=='MESH']
# A temporary scene/view layer avoids the library's deliberately excluded assets.
scene=bpy.data.scenes.new('EXPORT_ONLY');bpy.context.window.scene=scene
for obj in [rig]+meshes:scene.collection.objects.link(obj);obj.hide_set(False);obj.hide_viewport=False;obj.hide_render=False
rig.animation_data_clear()
for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
bpy.ops.object.select_all(action='DESELECT')
for obj in meshes:obj.select_set(True)
bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join()
mesh=bpy.context.object;mesh.name='Soldier_Skin_v001';rig.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'Soldier_Skin_v001.glb'),export_format='GLB',use_selection=True,export_animations=False,export_skins=True,export_yup=True,export_cameras=False,export_lights=False)
shutil.copy2(RIFLE,OUT/RIFLE.name)
assert all(sha(ROOT/p)==h for p,h in before.items())
(OUT/'sources.json').write_text(json.dumps({'research_only':True,'authorization':'User requested existing skin and Sand Block rifle in existing gameplay lab 2026-10-21','source_sha256':before,'skin_triangles':sum(len(p.vertices)-2 for p in mesh.data.polygons),'backpack_equipped':False},indent=2)+'\n')
print('SOURCE_PRESERVED_EXPORT_OK')
