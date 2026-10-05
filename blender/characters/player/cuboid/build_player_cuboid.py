"""Fresh cuboid asset; run through Blender MCP. No previous assets are edited."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector

OUT = Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/player/cuboid')
OUT.mkdir(parents=True, exist_ok=True)
target = OUT/'player_cuboid_v1.blend'
if target.exists():
    raise RuntimeError('Fresh build refuses to overwrite an existing player_cuboid_v1.blend')
scene = bpy.data.scenes.new('Player_Cuboid_Asset')
bpy.context.window.scene = scene
scene.unit_settings.system='METRIC'
asset=bpy.data.collections.new('PLAYER_CUBOID')
scene.collection.children.link(asset)
studio=bpy.data.collections.new('PREVIEW_STUDIO')
scene.collection.children.link(studio)

# Sixteen padded 16px tiles, with intentional shared UVs for matching surfaces.
palette=[(187,143,91),(208,153,92),(179,124,65),(49,59,65),
         (44,55,64),(57,69,77),(78,58,45),(42,34,30),
         (29,36,42),(204,161,113),(163,120,78),(37,45,52),
         (119,86,53),(196,145,94),(159,109,57),(102,77,51)]
pixels=[0.0]*(64*64*4)
def put(tile,x,y,c):
    ox=(tile%4)*16; oy=(tile//4)*16
    i=((oy+y)*64+ox+x)*4
    pixels[i:i+4]=[c[0]/255,c[1]/255,c[2]/255,1.0]
def rect(tile,x0,y0,x1,y1,c):
    for y in range(y0,y1+1):
        for x in range(x0,x1+1): put(tile,x,y,c)
for t,c in enumerate(palette):
    for y in range(16):
        for x in range(16):
            # Very restrained hand-painted cloth/skin tone variation.
            k=2 if (x*7+y*3+t)%19==0 else 0
            put(t,x,y,tuple(min(255,n+k) for n in c))
# Face: dark asymmetric crop, two eyes, tiny nose and a calm mouth.
rect(0,1,12,14,15,(29,36,42)); rect(0,1,10,3,12,(29,36,42))
rect(0,4,11,6,12,(29,36,42)); rect(0,1,7,1,11,(37,45,52))
rect(0,4,8,5,8,(239,224,191)); rect(0,10,8,11,8,(239,224,191))
put(0,5,8,(24,32,36)); put(0,10,8,(24,32,36))
rect(0,7,5,8,6,(169,116,75)); rect(0,6,3,9,3,(104,70,49))
# Jacket front: high charcoal collar, off-center zipper, one cyan signal patch.
rect(1,1,12,14,14,(49,59,65)); rect(1,5,10,10,12,(49,59,65))
rect(1,7,1,7,10,(110,82,49)); rect(1,8,1,8,10,(221,170,105))
rect(1,2,7,4,9,(24,165,183)); rect(1,2,9,4,9,(70,213,222))
rect(1,10,3,13,6,(170,118,63)); rect(1,10,6,13,6,(224,173,110))
rect(1,1,1,14,1,(164,112,61))
# Lower front jacket uses broad hem and discrete pockets.
rect(14,1,1,14,2,(145,98,53)); rect(14,7,1,8,14,(115,80,47))
rect(14,2,7,5,10,(144,98,51)); rect(14,10,7,13,10,(144,98,51))
rect(14,2,10,5,10,(197,142,76)); rect(14,10,10,13,10,(197,142,76))
# Jacket back: yoke and center seam, no extra cyan.
rect(2,1,12,14,13,(205,149,81)); rect(2,7,2,7,11,(165,111,57))
rect(2,1,1,14,1,(146,98,52))
# Pants/knee fabric and boots with pixel bands and laces.
rect(4,2,2,3,14,(53,65,75)); rect(4,11,1,12,10,(34,45,53))
rect(5,3,6,12,9,(46,58,67)); rect(5,3,9,12,9,(66,78,83))
rect(6,1,12,14,14,(112,80,53)); rect(6,5,3,10,11,(50,42,35))
for y in (5,7,9): rect(6,6,y,9,y,(146,116,77))
rect(7,1,1,14,3,(30,29,27)); rect(7,2,11,13,13,(63,49,38))
rect(9,1,12,14,15,(29,36,42)); rect(9,1,8,3,12,(29,36,42))
rect(10,1,1,14,15,(29,36,42)); rect(10,1,1,14,3,(163,120,78))
rect(11,1,1,14,2,(23,29,34))
rect(12,1,1,14,3,(85,59,40)); rect(12,2,12,13,14,(168,118,66))
rect(15,1,1,14,2,(75,54,37)); rect(15,1,13,14,14,(153,109,65))
# Extend inner texels into tile gutters to avoid bleed.
for t in range(16):
    ox=(t%4)*16; oy=(t//4)*16
    for y in range(16):
        for x in range(16):
            if x in (0,15) or y in (0,15):
                sx=min(14,max(1,x)); sy=min(14,max(1,y))
                a=((oy+sy)*64+ox+sx)*4; b=((oy+y)*64+ox+x)*4
                pixels[b:b+4]=pixels[a:a+4]
img=bpy.data.images.new('Player_Cuboid_Atlas_64',width=64,height=64,alpha=True)
img.colorspace_settings.name='sRGB'
img.pixels.foreach_set(pixels); img.update()
img.filepath_raw=str(OUT/'player_cuboid_atlas_64.png'); img.file_format='PNG'; img.save(); img.pack()
mat=bpy.data.materials.new('Player_Cuboid_Atlas_Material'); mat.use_nodes=True
bsdf=mat.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Roughness'].default_value=.57
bsdf.inputs['Metallic'].default_value=0
bsdf.inputs['Specular IOR Level'].default_value=.25
tex=mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=img; tex.interpolation='Closest'; tex.extension='EXTEND'
mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])

verts=[]; faces=[]; tilelist=[]; bindings=[]; part_ranges=[]
def box(name,center,size,bone,tiles):
    x,y,z=center; w,d,h=[v/2 for v in size]; start=len(verts)
    verts.extend([(x-w,y-d,z-h),(x+w,y-d,z-h),(x+w,y+d,z-h),(x-w,y+d,z-h),
                  (x-w,y-d,z+h),(x+w,y-d,z+h),(x+w,y+d,z+h),(x-w,y+d,z+h)])
    # Front, right, back, left, top, bottom. Forward is -Y.
    for f in [(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7),(3,2,1,0)]:
        faces.append(tuple(start+i for i in f))
    tilelist.extend([tiles]*6 if isinstance(tiles,int) else tiles)
    bindings.append((bone,list(range(start,start+8))))
    part_ranges.append({'part':name,'bone':bone,'first_vertex':start,'vertex_count':8})
# Height 1.82m. Everything is an un-beveled rectangular solid.
box('Cube head',(0,0,1.60),(.44,.44,.44),'Head',[0,9,10,9,8,9])
box('Neck',(0,0,1.362),(.17,.18,.036),'Neck',13)
box('Jacket upper',(0,0,1.217),(.47,.29,.252),'Chest',[1,2,2,2,3,2])
box('Jacket lower',(0,0,.976),(.47,.29,.222),'Spine',[14,2,2,2,2,14])
box('Pelvis',(0,0,.805),(.43,.27,.112),'Hips',11)
for side,sgn in [('L',1),('R',-1)]:
    x=sgn*.354
    box('Upper sleeve '+side,(x,0,1.187),(.212,.276,.290),'UpperArm.'+side,[2,2,2,2,2,2])
    box('Lower sleeve '+side,(x,0,.900),(.204,.266,.276),'Forearm.'+side,[14,2,2,2,2,3])
    box('Cuff '+side,(x,0,.749),(.210,.272,.020),'Forearm.'+side,3)
    box('Block hand '+side,(x,-.003,.682),(.193,.246,.110),'Hand.'+side,13)
    lx=sgn*.116
    box('Trouser thigh '+side,(lx,0,.607),(.209,.258,.278),'Thigh.'+side,4)
    box('Trouser shin '+side,(lx,0,.385),(.206,.252,.158),'Shin.'+side,[5,4,4,4,4,4])
    box('Boot shaft '+side,(lx,0,.231),(.221,.276,.144),'Shin.'+side,[6,12,12,12,12,12])
    box('Chunky boot '+side,(lx,-.049,.090),(.233,.378,.128),'Foot.'+side,[7,12,12,12,6,7])
    box('Boot sole '+side,(lx,-.049,.013),(.233,.378,.026),'Foot.'+side,7)
mesh=bpy.data.meshes.new('Player_Cuboid_Base_Mesh'); mesh.from_pydata(verts,[],faces); mesh.update()
player=bpy.data.objects.new('Player_Cuboid_Base',mesh); asset.objects.link(player); mesh.materials.append(mat)
uv=mesh.uv_layers.new(name='Pixel_Atlas_UV')
for p,t in zip(mesh.polygons,tilelist):
    ox=(t%4)*16; oy=(t//4)*16
    for li,(u,v) in zip(p.loop_indices,[(0,0),(1,0),(1,1),(0,1)]):
        uv.data[li].uv=((ox+1+14*u)/64,(oy+1+14*v)/64)
for bone,inds in bindings:
    group=player.vertex_groups.get(bone) or player.vertex_groups.new(name=bone)
    group.add(inds,1.0,'REPLACE')

arm=bpy.data.armatures.new('Player_Cuboid_Rig_Data')
rig=bpy.data.objects.new('Player_Cuboid_Rig',arm); asset.objects.link(rig); rig.show_in_front=True
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
def bone(name,head,tail,parent=None,deform=True):
    b=arm.edit_bones.new(name); b.head=head; b.tail=tail
    if parent: b.parent=arm.edit_bones[parent]
    b.use_deform=deform
    b.align_roll(Vector((0,-1,0)))
bone('Root',(0,0,0),(0,0,.18),deform=False)
bone('Hips',(0,0,.804),(0,0,.866),'Root')
bone('Spine',(0,0,.866),(0,0,1.089),'Hips')
bone('Chest',(0,0,1.089),(0,0,1.341),'Spine')
bone('Neck',(0,0,1.341),(0,0,1.38),'Chest')
bone('Head',(0,0,1.38),(0,0,1.80),'Neck')
for s,sgn in [('L',1),('R',-1)]:
    x=sgn*.354; lx=sgn*.116
    bone('UpperArm.'+s,(x,0,1.336),(x,0,1.04),'Chest')
    bone('Forearm.'+s,(x,0,1.04),(x,0,.758),'UpperArm.'+s)
    bone('Hand.'+s,(x,0,.758),(x,0,.631),'Forearm.'+s)
    bone('Thigh.'+s,(lx,0,.749),(lx,0,.466),'Hips')
    bone('Shin.'+s,(lx,0,.466),(lx,0,.158),'Thigh.'+s)
    bone('Foot.'+s,(lx,0,.158),(lx,-.20,.07),'Shin.'+s)
bpy.ops.object.mode_set(mode='OBJECT')
arm.display_type='STICK'
for pb in rig.pose.bones:
    pb.rotation_mode='XYZ'; pb.lock_scale=(True,True,True)
    if pb.name!='Root': pb.lock_location=(True,True,True)
mod=player.modifiers.new('Rigid block articulation','ARMATURE'); mod.object=rig; mod.use_deform_preserve_volume=False
player.parent=rig
player['design']='Original ochre field jacket survivor, pixel crop hair, cyan chest signal patch.'
player['rigid_parts']=json.dumps(part_ranges)
player['forward_axis']='-Y; Z up. Ground at Z=0. Height=1.82m.'
player['uv_workflow']='64x64 sRGB padded atlas; nearest filtering; matching surfaces deliberately share tiles.'
rig['animation_notes']='18-bone FK hierarchy. Every vertex has one weight of 1.0. Disconnected cuboids preserve volume. Root locomotion; hips/spine/chest/head secondary motion; elbows and knees bend as rigid segments. No animations.'
rig['joint_notes']='Small rest seams preserve crisp blocks; deep bends can reveal seams, expected for rigid cuboid articulation. Test wide poses when authoring future animations.'

world=bpy.data.worlds.new('Cuboid_Preview_World'); world.use_nodes=True; world.node_tree.nodes['Background'].inputs[0].default_value=(.20,.25,.31,1); world.node_tree.nodes['Background'].inputs[1].default_value=.45; scene.world=world
def aim(obj,at): obj.rotation_euler=(Vector(at)-obj.location).to_track_quat('-Z','Y').to_euler()
def light(name,pos,power,size,color):
    data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size; data.color=color
    obj=bpy.data.objects.new(name,data); studio.objects.link(obj); obj.location=pos; aim(obj,(0,0,1)); return obj
light('Preview key',(-3,-4,5),420,4,(1.0,.87,.73))
light('Preview fill',(3,-2,3),230,3,(.72,.87,1.0))
light('Preview rim',(1,3,4),340,3,(.82,.92,1.0))
camdata=bpy.data.cameras.new('Cuboid_Preview_Camera'); cam=bpy.data.objects.new('Cuboid_Preview_Camera',camdata); studio.objects.link(cam)
cam.location=(3.1,-6.5,3.0); aim(cam,(0,0,.93)); camdata.type='ORTHO'; camdata.ortho_scale=2.45; scene.camera=cam
scene.render.engine='CYCLES'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.film_transparent=True; scene.render.image_settings.file_format='PNG'; scene.render.image_settings.color_mode='RGBA'
scene.render.filepath=str(OUT/'player_cuboid_v1_preview.png')
scene.view_settings.view_transform='AgX'
scene.frame_set(1)
bpy.context.view_layer.update(); mesh.calc_loop_triangles()
report={'mesh':player.name,'rig':rig.name,'triangles':len(mesh.loop_triangles),'vertices':len(mesh.vertices),'cuboids':len(part_ranges),'texture_resolution':[64,64],'materials':len(mesh.materials),'bones':len(arm.bones),'height_m':1.82,'animations':0,'rigid_weighting':True,'hierarchy':{b.name:b.parent.name if b.parent else None for b in arm.bones}}
(OUT/'asset_report.json').write_text(json.dumps(report,indent=2))
# Library-write only this new scene and its dependencies, excluding startup objects.
bpy.data.libraries.write(str(target),{scene},path_remap='RELATIVE',fake_user=True)
result=report
