"""Exact 8/4/12 classic model-pixel proportions, authored through Blender MCP."""
import bpy, json, math, hashlib
from pathlib import Path
from mathutils import Vector
OUT=Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/player/cuboid')
target=OUT/'player_cuboid_v3.blend'
if target.exists(): raise RuntimeError('Refuse to overwrite existing v3')
source_hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [OUT/'player_cuboid_v1.blend',OUT/'player_cuboid_v2.blend']}
U=1.8/32
scene=bpy.data.scenes.new('Player_Cuboid_Classic_Asset');bpy.context.window.scene=scene
scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
asset=bpy.data.collections.new('PLAYER_CUBOID_V3');scene.collection.children.link(asset)
studio=bpy.data.collections.new('V3_PREVIEW_STUDIO');scene.collection.children.link(studio)
# Conventional 64x64 skin layout, coordinates measured from upper-left.
# Face order: front, right, back, left, top, bottom.
layouts={
 'Head':[(8,8,8,8),(0,8,8,8),(24,8,8,8),(16,8,8,8),(8,0,8,8),(16,0,8,8)],
 'Torso':[(20,20,8,12),(16,20,4,12),(32,20,8,12),(28,20,4,12),(20,16,8,4),(28,16,8,4)],
 'Arm.R':[(44,20,4,12),(40,20,4,12),(52,20,4,12),(48,20,4,12),(44,16,4,4),(48,16,4,4)],
 'Arm.L':[(36,52,4,12),(32,52,4,12),(44,52,4,12),(40,52,4,12),(36,48,4,4),(40,48,4,4)],
 'Leg.R':[(4,20,4,12),(0,20,4,12),(12,20,4,12),(8,20,4,12),(4,16,4,4),(8,16,4,4)],
 'Leg.L':[(20,52,4,12),(16,52,4,12),(28,52,4,12),(24,52,4,12),(20,48,4,4),(24,48,4,4)]}
skin=(181,127,84);skinshade=(164,108,68);hair=(28,34,37);hairhi=(37,43,45)
teal=(38,76,77);tealhi=(46,88,87);tealshade=(30,63,66);pants=(32,43,53);pantshi=(42,55,64)
boots=(89,52,36);bootshi=(114,70,45);sole=(59,40,31);cyan=(36,186,198)
pixels=[0.0]*(64*64*4)
# Fill unused/optional-layer areas transparently; base regions are fully opaque.
def setpixel(x,y,c):
    i=((63-y)*64+x)*4;pixels[i:i+4]=[c[0]/255,c[1]/255,c[2]/255,1]
for part,regions in layouts.items():
    for face,(ox,oy,w,h) in enumerate(regions):
        for y in range(h):
            for x in range(w):
                if part=='Head':
                    c=skin
                    if face in (2,4): c=hairhi if (x+2*y)%7==0 else hair
                    elif face in (1,3):
                        if y<3 or x<2: c=hair
                        elif x==2 and y in (4,5): c=skinshade
                    elif face==0:
                        if y<2 or (x==0 and y<5) or (x<3 and y==2):c=hair
                        if y==4 and x in (2,5):c=(30,43,44)
                        if y==6 and x in (3,4):c=(112,67,44)
                        if y==5 and x==4:c=skinshade
                elif part=='Torso':
                    c=teal
                    if face==0:
                        if y<2 and 2<=x<=5:c=skinshade
                        elif y==2 and 3<=x<=4:c=tealshade
                        elif y==4 and x==2:c=cyan
                        elif y==5 and x in (5,6):c=tealhi
                        elif y>=10:c=boots
                        if y==10 and x==4:c=(129,135,118)
                    elif face==2:
                        if y==2:c=tealhi
                        elif x==3 and y>3:c=tealshade
                        elif y>=10:c=boots
                    elif face in (1,3):
                        if y>=10:c=boots
                        elif x==0:c=tealshade
                    elif face==4:c=tealhi
                    elif face==5:c=pants
                elif part.startswith('Arm'):
                    c=teal
                    if face<4:
                        if y==7:c=tealshade
                        elif y==8:c=tealhi
                        elif y>=9:c=skin
                        elif x==0:c=tealshade
                        elif y==2:c=tealhi
                    elif face==4:c=tealhi
                    else:c=skinshade
                else:
                    c=pants
                    if face<4:
                        if x==0:c=pantshi
                        if y>=9:c=boots
                        if y==9:c=bootshi
                        if y==11:c=sole
                    elif face==5:c=sole
                setpixel(ox+x,oy+y,c)
img=bpy.data.images.new('V3_Atlas_64',width=64,height=64,alpha=True)
img.colorspace_settings.name='sRGB';img.pixels.foreach_set(pixels);img.update()
img.filepath_raw=str(OUT/'player_cuboid_v3_atlas_64.png');img.file_format='PNG';img.save();img.pack()
mat=bpy.data.materials.new('V3_Survivor_Atlas_Material');mat.use_nodes=True
bsdf=mat.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=.58;bsdf.inputs['Metallic'].default_value=0;bsdf.inputs['Specular IOR Level'].default_value=.22
tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=img;tex.interpolation='Closest';tex.extension='EXTEND'
mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
verts=[];faces=[];rects=[];bindings=[];records=[]
def cuboid(part,bone,bounds,regions):
    x0,x1,y0,y1,z0,z1=[v*U for v in bounds];first=len(verts)
    verts.extend([(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),(x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)])
    for f in [(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7),(3,2,1,0)]:faces.append(tuple(first+i for i in f))
    rects.extend(regions);bindings.append((bone,list(range(first,first+8))))
    records.append({'part':part,'bone':bone,'first_vertex':first,'vertex_count':8,'bounds_model_units':bounds})
def half_regions(regions,upper):
    result=[]
    for i,(x,y,w,h) in enumerate(regions):
        # vertical side faces follow contiguous top/bottom halves of the same skin.
        if i<4:result.append((x,y if upper else y+6,w,6))
        else:result.append((x,y,w,h))
    return result
cuboid('Head','Head',[-4,4,-4,4,24,32],layouts['Head'])
cuboid('Torso','Chest',[-4,4,-2,2,12,24],layouts['Torso'])
for s,sgn in [('L',1),('R',-1)]:
    ax0,ax1=(4,8) if s=='L' else (-8,-4)
    lx0,lx1=(0,4) if s=='L' else (-4,0)
    cuboid('Arm.'+s+' upper','UpperArm.'+s,[ax0,ax1,-2,2,18,24],half_regions(layouts['Arm.'+s],True))
    cuboid('Arm.'+s+' lower','Forearm.'+s,[ax0,ax1,-2,2,12,18],half_regions(layouts['Arm.'+s],False))
    cuboid('Leg.'+s+' upper','Thigh.'+s,[lx0,lx1,-2,2,6,12],half_regions(layouts['Leg.'+s],True))
    cuboid('Leg.'+s+' lower','Shin.'+s,[lx0,lx1,-2,2,0,6],half_regions(layouts['Leg.'+s],False))
mesh=bpy.data.meshes.new('V3_Classic_Mesh');mesh.from_pydata(verts,[],faces);mesh.update()
player=bpy.data.objects.new('V3_Player_Base',mesh);asset.objects.link(player);mesh.materials.append(mat)
uv=mesh.uv_layers.new(name='Classic_64_Skin_UV')
for poly,(x,y,w,h) in zip(mesh.polygons,rects):
    for li,(u,v) in zip(poly.loop_indices,[(0,0),(1,0),(1,1),(0,1)]):
        # Tiny numerical inset; preserves the complete 1 model unit = 1 texel layout.
        e=.0001;uv.data[li].uv=((x+e+(w-2*e)*u)/64,1-(y+h-e-(h-2*e)*v)/64)
for n,inds in bindings:
    g=player.vertex_groups.get(n) or player.vertex_groups.new(name=n);g.add(inds,1,'REPLACE')
arm=bpy.data.armatures.new('V3_Classic_Rig_Data');rig=bpy.data.objects.new('V3_Player_Rig',arm);asset.objects.link(rig)
rig.show_in_front=True;arm.display_type='STICK'
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
def bone(n,h,t,parent=None,deform=True):
    b=arm.edit_bones.new(n);b.head=Vector(h)*U;b.tail=Vector(t)*U
    if parent:b.parent=arm.edit_bones[parent]
    b.use_deform=deform;b.align_roll(Vector((0,-1,0)))
bone('Root',(0,0,0),(0,0,3),deform=False)
bone('Hips',(0,0,12),(0,0,14),'Root',False)
bone('Spine',(0,0,14),(0,0,19),'Hips',False)
bone('Chest',(0,0,19),(0,0,24),'Spine')
bone('Neck',(0,0,24),(0,0,25),'Chest',False)
bone('Head',(0,0,24),(0,0,32),'Neck')
for s,sgn in [('L',1),('R',-1)]:
    x=sgn*6;lx=sgn*2
    bone('UpperArm.'+s,(x,0,24),(x,0,18),'Chest')
    bone('Forearm.'+s,(x,0,18),(x,0,12),'UpperArm.'+s)
    bone('Hand.'+s,(x,0,12),(x,0,11),'Forearm.'+s,False)
    bone('Thigh.'+s,(lx,0,12),(lx,0,6),'Hips')
    bone('Shin.'+s,(lx,0,6),(lx,0,0),'Thigh.'+s)
    bone('Foot.'+s,(lx,0,0),(lx,-2,0),'Shin.'+s,False)
bpy.ops.object.mode_set(mode='OBJECT')
for pb in rig.pose.bones:
    pb.rotation_mode='XYZ';pb.lock_scale=(True,True,True)
    if pb.name!='Root':pb.lock_location=(True,True,True)
modifier=player.modifiers.new('Rigid classic articulation','ARMATURE');modifier.object=rig;modifier.use_deform_preserve_volume=False;player.parent=rig
player['rigid_parts']=json.dumps(records)
player['model_unit_m']=U
player['proportions']='32 units tall; head 8x8x8, torso 8x4x12, arms classic 4x4x12, legs 4x4x12. No silhouette layers.'
rig['animation_notes']='Rigid weights, no scaling. Flush 6+6 unit arm/leg sections allow elbow/knee rotation. Torso and head remain single rigid boxes. Hand/foot bones are attachment pivots, not separate geometry. No animations.'
world=bpy.data.worlds.new('V3_Preview_World');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.20,.25,.31,1);world.node_tree.nodes['Background'].inputs[1].default_value=.45;scene.world=world
def aim(o,at):o.rotation_euler=(Vector(at)-o.location).to_track_quat('-Z','Y').to_euler()
for n,pos,power,size,color in [('Key',(-3,-4,5),420,4,(1,.87,.73)),('Fill',(3,-2,3),230,3,(.72,.87,1)),('Rim',(1,3,4),340,3,(.82,.92,1))]:
    d=bpy.data.lights.new('V3 '+n,'AREA');d.energy=power;d.size=size;d.color=color;o=bpy.data.objects.new('V3 '+n,d);studio.objects.link(o);o.location=pos;aim(o,(0,0,.9))
camera_defs={'Front':((0,-6,.9),(.0,0,.9)),'Side':((6,0,.9),(0,0,.9)),'Isometric':((4,-4,4.166),(0,0,.9))}
for n,(pos,at) in camera_defs.items():
    d=bpy.data.cameras.new('V3 '+n+' Camera');d.type='ORTHO';d.ortho_scale=2.30;o=bpy.data.objects.new('V3 '+n+' Camera',d);studio.objects.link(o);o.location=pos;aim(o,at)
    if n=='Isometric':scene.camera=o
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=1000;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.view_settings.view_transform='AgX'
scene.render.filepath=str(OUT/'player_cuboid_v3_isometric.png');scene.frame_set(1)
bpy.context.view_layer.update();mesh.calc_loop_triangles()
report={'model_unit_m':U,'height_m':1.8,'width_front_m':.9,'overall_depth_m':.45,'triangles':len(mesh.loop_triangles),'vertices':len(mesh.vertices),'materials':1,'texture_resolution':[64,64],'bones':18,'rigid_geometry_sections':10,'animations':0,'outer_layers':False,
 'dimensions_m':{'head':[.45,.45,.45],'torso':[.45,.225,.675],'each_arm':[.225,.225,.675],'each_leg':[.225,.225,.675]},
 'z_ranges_m':{'legs':[0,.675],'torso_and_arms':[.675,1.35],'head':[1.35,1.8]},'earlier_version_sha256':source_hashes}
(OUT/'asset_report_v3.json').write_text(json.dumps(report,indent=2))
bpy.data.libraries.write(str(target),{scene},path_remap='RELATIVE',fake_user=True)
bpy.ops.wm.open_mainfile(filepath=str(target))
player=bpy.data.objects['V3_Player_Base'];rig=bpy.data.objects['V3_Player_Rig'];player.name='Player_Cuboid_Base';rig.name='Player_Cuboid_Rig';player.data.name='Player_Cuboid_Base_Mesh';rig.data.name='Player_Cuboid_Rig_Data';img=bpy.data.images['V3_Atlas_64'];img.name='Player_Cuboid_Atlas_64';player.data.materials[0].name='Player_Cuboid_Atlas_Material'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(target))
result=report
