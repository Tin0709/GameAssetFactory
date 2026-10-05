"""Revise only the cuboid player using the supplied Valorie image as visual reference."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
OUT=Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/player/cuboid')
target=OUT/'player_cuboid_v2.blend'
if target.exists(): raise RuntimeError('Refuse to overwrite existing v2')
bpy.ops.wm.open_mainfile(filepath=str(OUT/'player_cuboid_v1.blend'))
scene=bpy.context.scene
player=bpy.data.objects['Player_Cuboid_Base']; rig=bpy.data.objects['Player_Cuboid_Rig']
parts=json.loads(player['rigid_parts']); mesh=player.data
# Keep a detached snapshot for a later temporary comparison render.
old_mesh=mesh.copy(); old_mesh.name='V1_Comparison_Snapshot'
old_mat=mesh.materials[0].copy(); old_mat.name='V1_Comparison_Material'
old_mesh.materials.clear(); old_mesh.materials.append(old_mat)
old_img=old_mat.node_tree.nodes.get('Image Texture').image
old_img.name='V1_Comparison_Atlas'
specs={
 'Cube head':((0,0,1.84),(.42,.42,.42),[0,9,10,9,8,13]),
 'Neck':((0,0,1.630),(.14,.16,.034),13),
 'Jacket upper':((0,0,1.465),(.37,.205,.286),[1,2,2,2,3,2]),
 'Jacket lower':((0,0,1.164),(.37,.205,.308),[14,2,2,2,2,14]),
 'Pelvis':((0,0,.964),(.36,.205,.086),11),
}
for side,sgn in [('L',1),('R',-1)]:
    x=sgn*.276; lx=sgn*.098
    specs.update({
      'Upper sleeve '+side:((x,0,1.4425),(.166,.196,.331),[5,5,5,5,2,13]),
      'Lower sleeve '+side:((x,0,1.114),(.166,.196,.322),[15,15,15,15,13,6]),
      'Cuff '+side:((x,0,.941),(.166,.196,.020),3),
      'Block hand '+side:((x,0,.874),(.166,.196,.110),6),
      'Trouser thigh '+side:((lx,0,.716),(.176,.205,.404),4),
      'Trouser shin '+side:((lx,0,.408),(.176,.205,.204),[12,12,12,12,4,12]),
      'Boot shaft '+side:((lx,0,.237),(.176,.205,.132),[6,6,6,6,12,6]),
      'Chunky boot '+side:((lx,-.0225,.095),(.176,.250,.146),[7,7,7,7,6,7]),
      'Boot sole '+side:((lx,-.0225,.011),(.176,.250,.022),7),
    })
tilelist=[]
for part in parts:
    (x,y,z),(w,d,h),tiles=specs[part['part']]; w/=2; d/=2; h/=2
    coords=[(x-w,y-d,z-h),(x+w,y-d,z-h),(x+w,y+d,z-h),(x-w,y+d,z-h),
            (x-w,y-d,z+h),(x+w,y-d,z+h),(x+w,y+d,z+h),(x-w,y+d,z+h)]
    for i,c in enumerate(coords): mesh.vertices[part['first_vertex']+i].co=c
    tilelist.extend([tiles]*6 if isinstance(tiles,int) else tiles)
mesh.update()
uv=mesh.uv_layers.active
for p,t in zip(mesh.polygons,tilelist):
    ox=t%4*16; oy=t//4*16
    for li,(u,v) in zip(p.loop_indices,[(0,0),(1,0),(1,1),(0,1)]): uv.data[li].uv=((ox+1+14*u)/64,(oy+1+14*v)/64)

# Original pixel painting based on the supplied reference, one padded 64x64 atlas.
skin=(167,111,69); hair=(103,19,28); hairhi=(137,28,35); hairdark=(73,15,23)
teal=(31,57,68); tealhi=(43,72,84); cloth=(170,163,133)
leather=(119,56,36); leathhi=(145,73,46)
palette=[skin,teal,teal,cloth,(27,49,62),teal,leather,(91,45,32),hair,hair,hair,(25,40,49),cloth,skin,teal,skin]
pixels=[0.0]*(64*64*4)
def put(t,x,y,c):
    i=((t//4*16+y)*64+t%4*16+x)*4
    pixels[i:i+4]=[c[0]/255,c[1]/255,c[2]/255,1]
def rect(t,x0,y0,x1,y1,c):
    for y in range(y0,y1+1):
        for x in range(x0,x1+1): put(t,x,y,c)
for t,c in enumerate(palette):
    for y in range(16):
        for x in range(16): put(t,x,y,c)
# Front hair fringe, silver-blue headband, asymmetrical cheek locks, green eyes.
rect(0,1,11,14,15,hair); rect(0,1,9,4,11,hairdark)
rect(0,1,4,2,10,hairdark); rect(0,3,7,4,10,hair)
rect(0,5,10,14,11,(121,158,157)); rect(0,6,11,14,11,(158,183,170))
rect(0,1,12,3,14,hairhi); rect(0,8,13,10,14,hairhi)
rect(0,5,7,6,8,(205,211,182)); rect(0,11,7,12,8,(205,211,182))
rect(0,6,7,6,8,(20,68,49)); rect(0,11,7,11,8,(20,68,49))
rect(0,8,4,9,5,(145,84,51)); rect(0,8,2,10,2,(103,50,34))
# Hair side pixel strata, ear, headband continuation.
rect(9,2,1,5,5,skin); rect(9,3,4,6,7,skin); rect(9,1,1,3,2,hairdark)
rect(9,9,10,14,11,(110,145,145)); rect(9,4,12,7,14,hairhi)
rect(9,9,5,12,8,hairdark); rect(9,1,9,3,11,hairhi)
for t in (8,10):
    for x,y in [(2,3),(7,8),(10,12),(4,11),(11,4)]: rect(t,x,y,min(x+2,14),min(y+2,14),hairhi)
    rect(t,1,1,14,2,hairdark)
# Two hair locks are painted into the flat front rather than protruding geometry.
rect(1,5,12,10,14,cloth); rect(1,6,10,9,11,(144,145,124))
for x in (2,12):
    rect(1,x,2,x+1,14,hairdark)
    for y in (3,7,11): rect(1,x,y,x+1,y+1,hairhi)
rect(1,5,3,10,4,tealhi); rect(1,7,6,8,7,(40,171,183))
rect(2,1,12,14,13,tealhi); rect(2,7,2,7,11,(24,47,57))
rect(14,1,5,14,10,leather); rect(14,1,10,14,10,leathhi)
rect(14,6,5,8,10,(147,164,157)); rect(14,7,6,8,9,(66,91,93))
rect(14,1,1,14,2,(20,36,46)); rect(14,2,2,5,4,tealhi); rect(14,10,2,13,4,tealhi)
rect(11,2,7,6,10,tealhi); rect(11,9,7,13,10,(38,64,77))
rect(4,2,1,4,14,(37,67,82)); rect(4,11,1,13,13,(19,36,48))
rect(5,1,1,14,5,cloth); rect(5,1,6,14,7,(25,47,57)); rect(5,2,12,13,14,tealhi)
rect(12,1,1,14,3,(146,142,118)); rect(12,2,11,13,14,(182,174,140))
rect(15,1,1,14,8,leather); rect(15,2,2,5,6,leathhi); rect(15,1,12,14,14,cloth)
rect(6,1,1,14,2,(91,42,29)); rect(6,2,8,7,13,leathhi); rect(6,10,2,13,7,(103,47,31))
rect(7,1,1,14,3,(61,32,26)); rect(7,1,7,14,10,leathhi); rect(7,2,12,6,14,(121,61,40))
for t in range(16):
    for y in range(16):
        for x in range(16):
            if x in (0,15) or y in (0,15):
                sx=min(14,max(1,x)); sy=min(14,max(1,y))
                a=((t//4*16+sy)*64+t%4*16+sx)*4; b=((t//4*16+y)*64+t%4*16+x)*4
                pixels[b:b+4]=pixels[a:a+4]
img=bpy.data.images.new('Player_Cuboid_Atlas_64',width=64,height=64,alpha=True)
img.colorspace_settings.name='sRGB'; img.pixels.foreach_set(pixels); img.update()
img.filepath_raw=str(OUT/'player_cuboid_v2_atlas_64.png'); img.file_format='PNG'; img.save(); img.pack()
mat=mesh.materials[0]; mat.node_tree.nodes.get('Image Texture').image=img

# Reposition rest-bone pivots to the new limb seams; preserve names and weights.
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
def setbone(n,h,t):
    b=rig.data.edit_bones[n]; b.head=h; b.tail=t; b.align_roll(Vector((0,-1,0)))
setbone('Root',(0,0,0),(0,0,.18))
setbone('Hips',(0,0,.963),(0,0,1.01)); setbone('Spine',(0,0,1.01),(0,0,1.32))
setbone('Chest',(0,0,1.32),(0,0,1.608)); setbone('Neck',(0,0,1.608),(0,0,1.63))
setbone('Head',(0,0,1.63),(0,0,2.03))
for s,sgn in [('L',1),('R',-1)]:
    x=sgn*.276; lx=sgn*.098
    setbone('UpperArm.'+s,(x,0,1.61),(x,0,1.276)); setbone('Forearm.'+s,(x,0,1.276),(x,0,.930))
    setbone('Hand.'+s,(x,0,.930),(x,0,.819))
    setbone('Thigh.'+s,(lx,0,.92),(lx,0,.512)); setbone('Shin.'+s,(lx,0,.512),(lx,0,.169))
    setbone('Foot.'+s,(lx,0,.169),(lx,-.15,.06))
bpy.ops.object.mode_set(mode='OBJECT')
for pb in rig.pose.bones: pb.rotation_euler=(0,0,0)
player['design']='Valorie reference revision: taller slim proportions, flat dark teal tunic, red pixel hair, pale cuffs, brown gloves/belt/boots.'
player['forward_axis']='-Y forward, Z up, ground Z=0, height=2.05m'
player['reference']='C:/Users/ADMIN/Desktop/Valorie.webp; single three-quarter image, silhouette proportions visually estimated.'
cam=scene.camera
cam.location=(3.1,-6.5,3.0); cam.rotation_euler=(Vector((0,0,1.04))-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.ortho_scale=2.55
scene.render.filepath=str(OUT/'player_cuboid_v2_preview.png')
scene.render.film_transparent=True
bpy.context.view_layer.update()
# Pose tests use edge-length invariance, then reset the saved character to rest.
baseline=[(mesh.vertices[e.vertices[0]].co-mesh.vertices[e.vertices[1]].co).length for e in mesh.edges]
error=0
for pose in [{'UpperArm.L':(25,0,-12),'Forearm.L':(60,0,0),'Thigh.R':(-30,0,0),'Shin.R':(65,0,0),'Chest':(5,0,5),'Head':(-5,10,0)},
             {'UpperArm.R':(45,0,10),'Forearm.R':(85,0,0),'Thigh.L':(-45,0,0),'Shin.L':(90,0,0),'Spine':(4,0,-4)}]:
    for pb in rig.pose.bones: pb.rotation_euler=(0,0,0)
    for n,a in pose.items(): rig.pose.bones[n].rotation_euler=[math.radians(v) for v in a]
    bpy.context.view_layer.update()
    obj=player.evaluated_get(bpy.context.evaluated_depsgraph_get()); dm=obj.to_mesh()
    for e,b in zip(dm.edges,baseline): error=max(error,abs((dm.vertices[e.vertices[0]].co-dm.vertices[e.vertices[1]].co).length-b))
    obj.to_mesh_clear()
for pb in rig.pose.bones: pb.rotation_euler=(0,0,0)
bpy.context.view_layer.update()
assert error<1e-5
assert all(len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-7 for v in mesh.vertices)
assert len(bpy.data.actions)==0
mesh.calc_loop_triangles()
report={'triangles':len(mesh.loop_triangles),'vertices':len(mesh.vertices),'materials':len(mesh.materials),'bones':len(rig.data.bones),'texture':[64,64],'height_m':2.05,'max_rigid_pose_edge_error_m':error,'animations':0,
        'proportions':{'head_size':[.44,.42],'head_height_fraction':[.44/1.82,.42/2.05],'torso_width':[.47,.37],'torso_depth':[.29,.205],'torso_height':[.48,.598],'shoulder_outer_width':[.92,.718],'arm_width':[.212,.166],'arm_length':[.709,.791],'leg_width':[.209,.176],'leg_top_height':[.746,.918],'boot_width':[.233,.176],'boot_depth':[.378,.250]},
        'leg_profile':'constant 0.176m width; 0.205m depth from thigh through boot shaft, no knee or calf bulge','flat_torso':'upper and lower front faces share Y=-0.1025m; no projecting pockets or belly'}
(OUT/'asset_report_v2.json').write_text(json.dumps(report,indent=2))
# Exclude comparison snapshots from final saved file. Keep snapshot only in memory.
old_mesh.use_fake_user=False; old_mat.use_fake_user=False
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(target))
result=report
