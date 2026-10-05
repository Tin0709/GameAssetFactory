"""Face-only atlas edit through Blender MCP; preserve all non-face asset data."""
import bpy,json,hashlib
from pathlib import Path
OUT=Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/player/cuboid')
source=OUT/'player_cuboid_v4.blend';target=OUT/'player_cuboid_v5.blend'
if target.exists():raise RuntimeError('Refuse to overwrite existing v5')
source_sha=hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(source))
player=bpy.data.objects['Player_Cuboid_Base'];rig=bpy.data.objects['Player_Cuboid_Rig']
# Reuse only the strict structural-signature function, never execute the v4 builder.
s=(OUT/'texture_player_cuboid_v4.py').read_text()
fn='def asset_signature():'+s.split('def asset_signature():',1)[1].split('\nbefore=asset_signature()',1)[0]
exec(compile(fn,'asset_signature','exec'))
signature=asset_signature()
mat=player.data.materials[0];node=mat.node_tree.nodes.get('Image Texture');old=node.image
original=list(old.pixels);pixels=original.copy()
skin=(180,126,83);ivory=(214,209,181);iris=(31,51,52)
nose=(190,139,95);mouth=(160,106,69)
def put(x,y,c):
    i=((63-(8+y))*64+8+x)*4;pixels[i:i+4]=[v/255 for v in c]+[1]
# The existing hair occupies rows 0-3. It is never changed.
for y in range(4,8):
    for x in range(8):put(x,y,skin)
# Reflection about X=3.5. Eye pupils X=2 and 5, whites X=1 and 6.
for x in (1,6):put(x,4,ivory)
for x in (2,5):put(x,4,iris)
for x in (3,4):put(x,5,nose);put(x,6,mouth)
changed=[]
for i in range(64*64):
    if any(abs(pixels[i*4+c]-original[i*4+c])>1e-6 for c in range(4)):
        x=i%64;y=63-i//64
        assert 8<=x<16 and 12<=y<16,(x,y)
        changed.append([x,y])
assert changed
for y in range(4,8):
    for x in range(4):
        a=((63-8-y)*64+8+x)*4;b=((63-8-y)*64+8+7-x)*4
        assert pixels[a:a+4]==pixels[b:b+4]
img=bpy.data.images.new('Player_Cuboid_V5_Face_Atlas_64',width=64,height=64,alpha=True)
img.colorspace_settings.name=old.colorspace_settings.name;img.pixels.foreach_set(pixels);img.update()
img.filepath_raw=str(OUT/'player_cuboid_v5_atlas_64.png');img.file_format='PNG';img.save();img.pack()
node.image=img
if old.users==0:bpy.data.images.remove(old)
assert node.interpolation=='Closest' and signature==asset_signature()
scene=bpy.context.scene;scene.camera=bpy.data.objects['V3 Isometric Camera'];scene.render.filepath=str(OUT/'player_cuboid_v5_isometric.png')
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(target))
bpy.ops.wm.open_mainfile(filepath=str(target));player=bpy.data.objects['Player_Cuboid_Base'];rig=bpy.data.objects['Player_Cuboid_Rig']
assert signature==asset_signature()
im=bpy.data.images['Player_Cuboid_V5_Face_Atlas_64'];saved=list(im.pixels)
saved_changes=[]
for i in range(64*64):
    if any(abs(saved[i*4+c]-original[i*4+c])>1e-6 for c in range(4)):
        x=i%64;y=63-i//64;assert 8<=x<16 and 12<=y<16;saved_changes.append([x,y])
assert saved_changes==changed and im.packed_file
assert source_sha==hashlib.sha256(source.read_bytes()).hexdigest()
report={'file':str(target),'texture_resolution':[64,64],'material_count':len(bpy.data.materials),'changed_texels':len(changed),'changed_texel_coordinates_top_left_origin':changed,
 'face_layout_zero_based':{'centerline_x':3.5,'eye_row_y':4,'pupil_columns_x':[2,5],'white_columns_x':[1,6],'nose_columns_x':[3,4],'nose_row_y':5,'mouth_columns_x':[3,4],'mouth_row_y':6},
 'hair_unchanged':True,'all_non_face_texels_unchanged':True,'geometry_rig_uv_weights_unchanged':True,'material_shader_unchanged':True,'structure_signature':signature,'v4_sha256':source_sha,'v4_unchanged':True,'atlas_packed':True,'nearest_sampling':True,'saved_file_reopened_and_verified':True}
(OUT/'asset_report_v5.json').write_text(json.dumps(report,indent=2))
result=report
