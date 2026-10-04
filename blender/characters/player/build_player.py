"""Player authoring recipe, executed through Blender MCP in a copy of base_scene."""
import bpy, math, json
from mathutils import Vector
from pathlib import Path

OUT = Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/player')
OUT.mkdir(parents=True, exist_ok=True)
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'player_base.blend'))
scene = bpy.context.scene
scene.name = 'Player_Asset'
asset = bpy.data.collections['ASSET']
# Only the newly saved player copy is edited. The source file is never saved.
for obj in list(asset.all_objects):
    bpy.data.objects.remove(obj, do_unlink=True)
for action in list(bpy.data.actions):
    if action.users == 0:
        bpy.data.actions.remove(action)
scene.frame_set(1)
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
parts = []
mats = []
for name, color in [
    ('Player_Skin', (0.63,0.34,0.19,1)),
    ('Player_Hair_Ink', (0.035,0.045,0.052,1)),
    ('Player_Jacket_Sage', (0.115,0.27,0.245,1)),
    ('Player_Trousers', (0.055,0.078,0.105,1)),
    ('Player_Leather', (0.32,0.16,0.065,1)),
    ('Player_Cyan', (0.025,0.68,0.8,1)),
]:
    mat=bpy.data.materials.new(name)
    mat.diffuse_color=color
    mat.use_nodes=True
    shader=mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=color
    shader.inputs['Roughness'].default_value=0.82
    shader.inputs['Metallic'].default_value=0
    if name=='Player_Cyan':
        shader.inputs['Emission Color'].default_value=color
        shader.inputs['Emission Strength'].default_value=0.35
    mats.append(mat)

def finish(obj,name,material,weights):
    obj.name=name
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    asset.objects.link(obj)
    obj.data.materials.append(mats[material])
    for v in obj.data.vertices:
        for bone,weight in weights(obj.matrix_world @ v.co).items():
            if weight > 0.00001:
                group=obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
                group.add([v.index],weight,'REPLACE')
    parts.append(obj)
    return obj

def rigid(bone):
    return lambda p: {bone:1.0}

def blend(p, centers):
    # Piecewise smooth interpolation, maximum two joint influences per vertex.
    if p<=centers[0][0]: return {centers[0][1]:1.0}
    if p>=centers[-1][0]: return {centers[-1][1]:1.0}
    for (a,ba),(b,bb) in zip(centers,centers[1:]):
        if a<=p<=b:
            t=(p-a)/(b-a)
            t=t*t*(3-2*t)
            return {ba:1-t,bb:t} if ba!=bb else {ba:1.0}

def box(name,location,dimensions,material,bone,bevel=0.02,segments=2,rotation=None,weights=None):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.mesh.primitive_cube_add(size=1,location=location)
    obj=bpy.context.object
    obj.dimensions=dimensions
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=obj.modifiers.new('Soft silhouette chamfer','BEVEL')
        mod.width=bevel
        mod.segments=segments
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if rotation: obj.rotation_euler=rotation
    bpy.context.view_layer.update()
    return finish(obj,name,material,weights or rigid(bone))

def loft(name,rings,material,weights):
    # Eight-sided rectangular rings retain planar faces and beveled corners.
    verts=[]
    for x,y,z,w,d in rings:
        c=0.27
        for a,b in [(-1+c,-1),(1-c,-1),(1,-1+c),(1,1-c),(1-c,1),(-1+c,1),(-1,1-c),(-1,-1+c)]:
            verts.append((x+a*w/2,y+b*d/2,z))
    faces=[tuple(reversed(range(8)))]
    for row in range(len(rings)-1):
        for j in range(8):
            a=row*8+j; b=row*8+(j+1)%8
            faces.append((a,b,b+8,a+8))
    faces.append(tuple(range(len(verts)-8,len(verts))))
    mesh=bpy.data.meshes.new(name+'_Mesh')
    mesh.from_pydata(verts,[],faces); mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    asset.objects.link(obj)
    return finish(obj,name,material,weights)

torso_weights=lambda p: blend(p.z,[(0.90,'Hips'),(1.06,'Spine'),(1.23,'Chest')])
loft('Jacket_body',[(0,0,z,w,d) for z,w,d in [(.78,.38,.27),(.82,.42,.30),(.9,.43,.31),(1.00,.43,.30),(1.1,.47,.31),(1.23,.51,.32),(1.30,.45,.29),(1.34,.30,.24)]],2,torso_weights)
loft('Trouser_hips',[(0,0,z,w,d) for z,w,d in [(.70,.32,.24),(.77,.40,.27),(.82,.35,.23),(.86,.31,.21)]],3,rigid('Hips'))
box('Jacket_hem',(0,0,.80),(.43,.31,.065),4,'Hips',.014,1,weights=torso_weights)
box('Neck',(0,0,1.365),(.17,.18,.17),0,'Neck',.025,2)
box('Collar_back',(0,.08,1.335),(.34,.19,.15),2,'Chest',.035,2)
box('Collar_left',(.106,-.075,1.32),(.13,.17,.12),4,'Chest',.018,1,rotation=(0,-.15,-.13))
box('Collar_right',(-.106,-.075,1.32),(.13,.17,.12),4,'Chest',.018,1,rotation=(0,.15,.13))
box('Zipper',(0,-.161,1.065),(.022,.018,.34),4,'Spine',.005,1,weights=torso_weights)
box('Chest_badge_mount',(.145,-.171,1.204),(.115,.024,.115),3,'Chest',.015,1)
box('Cyan_wayfinder',(.145,-.19,1.211),(.062,.015,.065),5,'Chest',.009,1)
box('Utility_pocket',(-.14,-.165,.936),(.125,.045,.11),2,'Spine',.016,1,weights=torso_weights)
box('Pocket_flap',(-.14,-.196,.98),(.14,.02,.035),4,'Spine',.007,1,weights=torso_weights)
# Head is deliberately oversized, with a tapered silhouette and broad bevels.
box('Head_form',(0,-.015,1.575),(.43,.365,.405),0,'Head',.07,2)
for side in [-1,1]:
    box('Ear_'+str(side),(side*.218,-.005,1.56),(.07,.10,.125),0,'Head',.025,1)
    box('Eye_'+str(side),(side*.083,-.201,1.591),(.044,.015,.050),1,'Head',.007,1)
    box('Brow_'+str(side),(side*.084,-.205,1.642),(.070,.019,.020),1,'Head',.005,1,rotation=(0,side*.07,0))
box('Nose',(0,-.213,1.547),(.064,.065,.076),0,'Head',.019,2)
box('Mouth',(0,-.201,1.486),(.069,.012,.012),1,'Head',.003,1)
box('Hair_cap',(0,.01,1.763),(.455,.39,.18),1,'Head',.053,2)
box('Hair_back',(0,.147,1.658),(.418,.104,.25),1,'Head',.03,1)
box('Swept_fringe',(-.079,-.17,1.741),(.30,.10,.145),1,'Head',.025,1,rotation=(0,-.15,-.04))
box('Hair_sweep',(.071,-.035,1.814),(.30,.32,.094),1,'Head',.03,1,rotation=(0,-.10,0))
for side in [-1,1]:
    suffix='L' if side==1 else 'R'
    arm_weights=lambda p,s=suffix: blend(p.z,[(.81,'Forearm.'+s),(.93,'Forearm.'+s),(1.14,'UpperArm.'+s),(1.25,'UpperArm.'+s),(1.35,'Clavicle.'+s)])
    loft('Sleeve_'+suffix,[(side*x,y,z,w,d) for x,y,z,w,d in [(.532,-.025,.83,.155,.18),(.53,-.024,.875,.166,.19),(.50,-.018,.95,.18,.20),(.475,-.009,1.01,.19,.205),(.45,0,1.065,.197,.21),(.40,0,1.15,.205,.23),(.34,0,1.25,.23,.25),(.275,0,1.31,.20,.22)]],2,arm_weights)
    box('Cuff_'+suffix,(side*.534,-.025,.837),(.17,.196,.07),4,'Forearm.'+suffix,.015,1)
    box('Hand_'+suffix,(side*.568,-.034,.734),(.178,.205,.20),0,'Hand.'+suffix,.043,2,rotation=(0,side*-.14,0))
    box('Thumb_'+suffix,(side*.49,-.116,.749),(.074,.09,.115),0,'Hand.'+suffix,.024,1)
    leg_weights=lambda p,s=suffix: blend(p.z,[(.14,'Foot.'+s),(.245,'Shin.'+s),(.35,'Shin.'+s),(.60,'Thigh.'+s),(.72,'Thigh.'+s),(.86,'Hips')])
    loft('Trouser_leg_'+suffix,[(side*x,y,z,w,d) for x,y,z,w,d in [(.142,.016,.15,.17,.195),(.143,.01,.25,.18,.21),(.144,-.005,.37,.19,.22),(.145,-.025,.43,.205,.235),(.145,-.027,.48,.21,.24),(.142,-.015,.54,.215,.24),(.135,0,.65,.23,.255),(.125,0,.77,.245,.26),(.12,0,.82,.245,.25)]],3,leg_weights)
    box('Boot_'+suffix,(side*.145,-.068,.115),(.245,.385,.22),4,'Foot.'+suffix,.043,2)
    box('Boot_sole_'+suffix,(side*.145,-.073,.029),(.255,.399,.058),1,'Foot.'+suffix,.018,1)
    box('Boot_collar_'+suffix,(side*.145,.01,.235),(.202,.235,.08),4,'Shin.'+suffix,.018,1,weights=leg_weights)

# Join disconnected clothing/head forms into one reusable skinned mesh.
bpy.ops.object.select_all(action='DESELECT')
for obj in parts: obj.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
bpy.ops.object.join()
player=bpy.context.object
player.name='Player_Base'; player.data.name='Player_Base_Mesh'
scene.cursor.location=(0,0,0)
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)

arm=bpy.data.armatures.new('Player_Rig_Skeleton')
rig=bpy.data.objects.new('Player_Rig',arm); asset.objects.link(rig)
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
def bone(name,head,tail,parent=None,connect=False,deform=True):
    b=arm.edit_bones.new(name); b.head=head; b.tail=tail
    if parent: b.parent=arm.edit_bones[parent]
    b.use_connect=connect; b.use_deform=deform
    b.align_roll(Vector((0,-1,0)))
    return b
bone('Root',(0,0,0),(0,0,.18),deform=False)
bone('Hips',(0,0,.79),(0,0,.94),'Root')
bone('Spine',(0,0,.94),(0,0,1.13),'Hips',True)
bone('Chest',(0,0,1.13),(0,0,1.31),'Spine',True)
bone('Neck',(0,0,1.31),(0,0,1.43),'Chest',True)
bone('Head',(0,0,1.43),(0,0,1.77),'Neck',True)
for sign in [-1,1]:
    s='L' if sign==1 else 'R'
    shoulder=(sign*.275,0,1.285); elbow=(sign*.47,-.009,1.035); wrist=(sign*.544,-.027,.82)
    bone('Clavicle.'+s,(sign*.06,0,1.27),shoulder,'Chest')
    bone('UpperArm.'+s,shoulder,elbow,'Clavicle.'+s,True)
    bone('Forearm.'+s,elbow,wrist,'UpperArm.'+s,True)
    bone('Hand.'+s,wrist,(sign*.583,-.034,.65),'Forearm.'+s,True)
    bone('Thigh.'+s,(sign*.125,0,.80),(sign*.145,-.027,.475),'Hips')
    bone('Shin.'+s,(sign*.145,-.027,.475),(sign*.145,.01,.16),'Thigh.'+s,True)
    bone('Foot.'+s,(sign*.145,.01,.16),(sign*.145,-.22,.09),'Shin.'+s,True)
bpy.ops.object.mode_set(mode='OBJECT')
rig.show_in_front=True; arm.display_type='OCTAHEDRAL'
for pb in rig.pose.bones:
    pb.rotation_mode='XYZ'
    pb.lock_scale=(True,True,True)
    if pb.name!='Root': pb.lock_location=(True,True,True)
modifier=player.modifiers.new('Player skin','ARMATURE'); modifier.object=rig
modifier.use_deform_preserve_volume=False
player.parent=rig
player['design']='Wayfinder survivor; front is -Y, Z up, meters. Joined separate forms; no textures.'
rig['animation_notes']='Relaxed A-rest. Root motion on Root; Hips bounce, Spine/Chest breathing and recoil; clavicles support shrug and arm anticipation. FK deformation skeleton, no animation actions.'
rig['bone_axes']='Local Y follows bone; local Z faces forward (-Y world) where possible. Local X supports flexion.'
scene.render.film_transparent=True
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'
scene.render.resolution_x=1024; scene.render.resolution_y=1024
scene.render.resolution_percentage=100
scene.render.filepath=str(OUT/'player_preview.png')
player.data.calc_loop_triangles()
report={'triangles':len(player.data.loop_triangles),'vertices':len(player.data.vertices),'materials':len(player.data.materials),'bones':len(arm.bones),'height':round(player.dimensions.z,4),'bounds_z':[round(min(v.co.z for v in player.data.vertices),5),round(max(v.co.z for v in player.data.vertices),5)],'hierarchy':{b.name:b.parent.name if b.parent else None for b in arm.bones}}
(OUT/'asset_report.json').write_text(json.dumps(report,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'player_base.blend'))
result=report



