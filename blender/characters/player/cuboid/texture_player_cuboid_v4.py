"""Original survivor skin. Reference images are inspiration, never sampled/copied."""
import bpy,json,hashlib
from pathlib import Path
OUT=Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/player/cuboid')
source=OUT/'player_cuboid_v3.blend';target=OUT/'player_cuboid_v4.blend'
if target.exists():raise RuntimeError('Refuse to overwrite existing v4')
source_sha=hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(source))
player=bpy.data.objects['Player_Cuboid_Base'];rig=bpy.data.objects['Player_Cuboid_Rig']
def asset_signature():
    m=player.data
    data={'vertices':[list(v.co) for v in m.vertices],'faces':[list(p.vertices) for p in m.polygons],
          'uvs':[list(d.uv) for d in m.uv_layers.active.data],
          'weights':[[(g.group,g.weight) for g in v.groups] for v in m.vertices],
          'groups':[g.name for g in player.vertex_groups],'object_matrix':[list(row) for row in player.matrix_world],
          'rig_matrix':[list(row) for row in rig.matrix_world],
          'bones':[(b.name,b.parent.name if b.parent else None,[list(row) for row in b.matrix_local],b.length,b.use_deform) for b in rig.data.bones],
          'pose':[(p.name,list(p.location),list(p.rotation_euler),list(p.scale),p.rotation_mode,list(p.lock_location),list(p.lock_scale)) for p in rig.pose.bones],
          'modifiers':[(m.name,m.type,m.object.name if m.type=='ARMATURE' and m.object else None) for m in player.modifiers],
          'parent':player.parent.name,'actions':[a.name for a in bpy.data.actions]}
    return hashlib.sha256(json.dumps(data,sort_keys=True).encode()).hexdigest()
before=asset_signature()
# Existing canonical UV layout is retained, with exactly 64x64 pixels.
layouts={
 'Head':[(8,8,8,8),(0,8,8,8),(24,8,8,8),(16,8,8,8),(8,0,8,8),(16,0,8,8)],
 'Torso':[(20,20,8,12),(16,20,4,12),(32,20,8,12),(28,20,4,12),(20,16,8,4),(28,16,8,4)],
 'Arm.R':[(44,20,4,12),(40,20,4,12),(52,20,4,12),(48,20,4,12),(44,16,4,4),(48,16,4,4)],
 'Arm.L':[(36,52,4,12),(32,52,4,12),(44,52,4,12),(40,52,4,12),(36,48,4,4),(40,48,4,4)],
 'Leg.R':[(4,20,4,12),(0,20,4,12),(12,20,4,12),(8,20,4,12),(4,16,4,4),(8,16,4,4)],
 'Leg.L':[(20,52,4,12),(16,52,4,12),(28,52,4,12),(24,52,4,12),(20,48,4,4),(24,48,4,4)]}
skin=(180,126,83);skinlight=(190,139,95);skinshade=(160,106,69)
hair=(26,31,36);hairmid=(34,41,47);hairlight=(43,49,54)
blue=(43,73,104);bluehi=(52,86,118);bluedark=(32,57,82)
teal=(35,86,90);tealhi=(45,101,103)
sleeve=(34,48,61);sleevehi=(43,61,73);cloth=(113,141,138)
pants=(36,45,54);pantshi=(46,58,68);pantsdark=(28,36,44)
leather=(99,60,41);leatherhi=(123,78,49);leatherdark=(74,47,35)
sole=(53,41,33);accent=(38,195,202)
pixels=[0.0]*(64*64*4)
def put(ox,oy,x,y,c):
    i=((63-oy-y)*64+ox+x)*4;pixels[i:i+4]=[c[0]/255,c[1]/255,c[2]/255,1]
for part,faces in layouts.items():
    for face,(ox,oy,w,h) in enumerate(faces):
        for y in range(h):
            for x in range(w):
                if part=='Head':
                    c=skin
                    if face==0:
                        # Offset broad crop, clear eyes and restrained calm face.
                        if y<2 or (y==2 and x<=2) or (y==3 and x==0):c=hair
                        if y==0 and 3<=x<=5:c=hairmid
                        if y==4 and x in (2,6):c=(214,209,181)
                        if y==4 and x in (3,5):c=(31,51,52)
                        if y==5 and x==4:c=skinshade
                        if y==6 and x in (3,4):c=(124,76,53)
                        if y==5 and x==1:c=skinlight
                    elif face in (1,3):
                        if y<3 or (x<=1 and y<6):c=hair
                        if y==1 and 2<=x<=5:c=hairmid
                        if y in (4,5) and x==2:c=skinshade
                        if y==5 and x==3:c=skinlight
                    elif face==2:
                        c=hair if y<6 else skinshade
                        if 1<=x<=3 and 1<=y<=2:c=hairmid
                        if x>=6 and 3<=y<=4:c=hairmid
                    elif face==4:
                        c=hair
                        if 1<=x<=3 and 1<=y<=2:c=hairmid
                        if 4<=x<=6 and 4<=y<=5:c=hairlight
                        if y==3 and x<=1:c=hairmid
                    else:c=skinshade
                elif part=='Torso':
                    c=blue
                    if face==0:
                        if y<2:c=teal
                        if y==0 and 3<=x<=4:c=skinshade
                        elif y==1 and 3<=x<=4:c=cloth
                        if 2<=y<=8 and 3<=x<=4:c=cloth
                        if y==8 and x in (0,1,6,7):c=bluehi
                        if y==4 and x==1:c=accent
                        if y<=5 and x==6:c=leather
                        if y==6 and x in (5,6):c=leatherhi
                        if y>=10:c=bluedark
                        if y==9:c=bluehi
                    elif face==2:
                        if y<2:c=teal
                        elif y==2:c=tealhi
                        if 3<=y<=8 and x==3:c=bluedark
                        if y<=8 and x==1:c=leather
                        if y==9:c=bluehi
                        elif y>=10:c=bluedark
                    elif face in (1,3):
                        if y<2:c=teal
                        if y==9:c=bluehi
                        elif y>=10:c=bluedark
                        # Small painted pouch on character-left side only.
                        if face==1 and 6<=y<=8 and 1<=x<=2:c=leather
                        if face==1 and y==6 and 1<=x<=2:c=leatherhi
                        if face==1 and y==7 and x==2:c=(171,143,90)
                    elif face==4:
                        c=teal
                        if x in (3,4):c=cloth
                        if x==6:c=leather
                    else:c=bluedark
                elif part.startswith('Arm'):
                    c=sleeve
                    if face<4:
                        if y<2:c=teal
                        if y==2:c=sleevehi
                        if 3<=y<=7 and x in (1,2):c=sleevehi
                        if y==8:c=leather
                        if y==9:c=leatherhi
                        if y>=10:c=skin
                        if y==11 and x==0:c=skinshade
                    elif face==4:c=teal
                    else:c=skinshade
                else:
                    c=pants
                    if face<4:
                        if x==0:c=pantsdark
                        if face==0 and 4<=y<=6 and x in (1,2):c=pantshi
                        if face==2 and y==1 and x in (1,2):c=pantshi
                        if y>=9:c=leather
                        if y==9:c=leatherdark
                        if y==10 and x in (1,2):c=leatherhi
                        if y==11:c=sole
                    elif face==4:c=pants
                    else:c=sole
                put(ox,oy,x,y,c)
img=bpy.data.images.new('Player_Cuboid_V4_Original_Atlas_64',width=64,height=64,alpha=True)
img.colorspace_settings.name='sRGB';img.pixels.foreach_set(pixels);img.update()
img.filepath_raw=str(OUT/'player_cuboid_v4_atlas_64.png');img.file_format='PNG';img.save();img.pack()
mat=player.data.materials[0];node=mat.node_tree.nodes.get('Image Texture');old=node.image;node.image=img;node.interpolation='Closest';node.extension='EXTEND'
shader=mat.node_tree.nodes.get('Principled BSDF');shader.inputs['Roughness'].default_value=.54;shader.inputs['Specular IOR Level'].default_value=.22;shader.inputs['Metallic'].default_value=0
mat.diffuse_color=(.14,.25,.30,1)
if old.users==0:bpy.data.images.remove(old)
player['skin_design']='Original blue field jacket, teal yoke, light undershirt, dark sleeves, charcoal knee-panel trousers, brown boots, side utility pouch, cyan chest marker. Sunny supplied for vibe only; no reference pixels sampled.'
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':area.spaces.active.shading.type='MATERIAL'
scene=bpy.context.scene;scene.camera=bpy.data.objects['V3 Isometric Camera'];scene.render.filepath=str(OUT/'player_cuboid_v4_isometric.png')
assert before==asset_signature()
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(target))
bpy.ops.wm.open_mainfile(filepath=str(target));player=bpy.data.objects['Player_Cuboid_Base'];rig=bpy.data.objects['Player_Cuboid_Rig']
assert before==asset_signature()
assert source_sha==hashlib.sha256(source.read_bytes()).hexdigest()
assert bpy.data.images['Player_Cuboid_V4_Original_Atlas_64'].packed_file
player.data.calc_loop_triangles()
report={'file':str(target),'texture_resolution':[64,64],'material_count':len(player.data.materials),'triangles':len(player.data.loop_triangles),'bone_count':len(rig.data.bones),'dimensions_m':[round(v,6) for v in player.dimensions],'roughness':.54,'specular_ior_level':.22,'metallic':0,'nearest_sampling':True,'packed_atlas':True,'geometry_rig_uv_weights_unchanged':True,'geometry_rig_signature':before,'v3_sha256':source_sha,'v3_unchanged':True,'original_pixel_art':True,'reference_pixels_sampled':False}
(OUT/'asset_report_v4.json').write_text(json.dumps(report,indent=2))
result=report
