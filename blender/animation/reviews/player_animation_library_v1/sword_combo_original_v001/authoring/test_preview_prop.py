"""Native regression for the actual sword assembly and exclusive prop selection."""
import bpy, sys, json
from pathlib import Path
from mathutils import Matrix
ROOT=Path(__file__).resolve().parents[6]
sys.path.insert(0,str(ROOT/'blender/animation/showcase'))
import gaf_animation_library as ui

scene=bpy.context.scene
arm=bpy.data.armatures.new('PropTest_Rest')
rig=bpy.data.objects.new('PropTest_Rig',arm);scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT');bone=arm.edit_bones.new('WeaponCarrier');bone.head=(0,0,0);bone.tail=(0,.18,0)
bpy.ops.object.mode_set(mode='OBJECT')
source=ROOT/'blender/weapons/sword_sand_block_v1/Sword_Sand_Block_V1.blend'
with bpy.data.libraries.load(str(source),link=False) as (src,dst):dst.collections=['WEAPON_EXPORT']
c=dst.collections[0];c.name='GAF_Sword_Sand_Block_V1_Preview';scene.collection.children.link(c)
o=next(x for x in c.all_objects if x.name=='Sword_Sand_Block_V1');o.name='GAF_Sword_Sand_Block_V1_Attachment'
o.parent=rig;o.parent_type='BONE';o.parent_bone='WeaponCarrier';o.matrix_parent_inverse=Matrix.Translation((0,-.18,0));o.matrix_basis=Matrix.Identity(4)
entry={'preview_prop':'sword_sand_block_v1'}
ui.validate_preview_prop(entry,rig)
rifle=bpy.data.collections.new('GAF_Rifle_V2_Preview');scene.collection.children.link(rifle)
ui.show_preview_prop(scene,entry)
assert not c.hide_render and rifle.hide_render
ui.show_preview_prop(scene,{'preview_prop':'rifle_stylized_v2'})
assert c.hide_render and not rifle.hide_render
ui.show_preview_prop(scene,{})
assert c.hide_render and rifle.hide_render
print('SWORD_PROP_REGRESSION_PASS',json.dumps({'real_sword_meshes':sum(x.type=='MESH' for x in c.all_objects),'exclusive_visibility':True}),flush=True)
