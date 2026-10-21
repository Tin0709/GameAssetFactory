"""Native/reopen verification of the one Soldier library and its facial layer."""
import bpy,sys,json,math,hashlib
from pathlib import Path
D=Path(__file__).resolve().parent;sys.path.insert(0,str(D));import expression_model as model
LIB=D.parent/'showcase/SOLDIER_Asset_Library.blend'
bpy.ops.wm.open_mainfile(filepath=str(LIB),load_ui=True)
scene=bpy.data.scenes['SOLDIER_ASSET_LIBRARY'];assert 'Facial Expressions' in scene.view_layers,'Facial review must exist in the same scene'
ctrl=bpy.data.objects['SF_Face_Control'];face=bpy.data.objects['SF_Face_Mesh'];rig=bpy.data.objects['SF_Soldier_Rig']
assert len(face.data.polygons)<100 and len(face.data.materials)==1
assert face.modifiers[0].object==rig and face.vertex_groups.get('Head')
assert all(abs(v.groups[0].weight-1.)<1e-8 for v in face.data.vertices)
assert len(rig.data.bones)==10 and bpy.data.objects['BPK_Backpack_v001'].parent is None
assert len([a for a in bpy.data.actions if a.name.startswith('SOLDIER_Face_Preset_')])==18
assert all(bpy.data.actions['SOLDIER_Face_Preset_'+n]['review_status']=='Pending' for n in model.PRESETS)
assert all('mouth' not in k.name.lower() and 'nose' not in k.name.lower() for k in face.data.shape_keys.key_blocks)
print('SOLDIER_FACE_NATIVE_VERIFY_PASS')
