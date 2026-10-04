"""Player authoring recipe, executed through Blender MCP in a copy of base_scene."""
import bpy, math, json
from mathutils import Vector
from pathlib import Path

OUT = Path(r'C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/player/v2')
OUT.mkdir(parents=True, exist_ok=True)
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'player_voxel_v2.blend'))
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
        c=0.025
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

torso_weights=lambda p: blend(p.z,[(.89,'Hips'),(1.09,'Spine'),(1.29,'Chest')])
# Almost square corners; the ring loops exist for bending, not rounded silhouettes.
loft('Tunic',[(0,0,z,.48,.29) for z in [.83,.88,.94,1.01,1.08,1.15,1.23,1.30,1.365]],2,torso_weights)
loft('Hip_form',[(0,0,z,w,d) for z,w,d in [(.73,.39,.24),(.79,.43,.26),(.84,.36,.22),(.88,.31,.20)]],3,rigid('Hips'))
box('Neck',(0,0,1.386),(.20,.20,.10),0,'Neck',0)
# Broad flat collar; no sculpted lapels or projecting toy buttons.
box('Collar_left',(-.075,-.151,1.335),(.105,.018,.06),4,'Chest',0)
box('Collar_right',(.075,-.151,1.335),(.105,.018,.06),4,'Chest',0)
box('Tunic_placket',(0,-.149,1.225),(.026,.010,.23),3,'Chest',0,weights=torso_weights)
box('Wayfinder_badge',(.146,-.153,1.26),(.060,.014,.068),5,'Chest',0)
# Functional flat shoulder strap continues down into a small side satchel.
loft('Satchel_strap',[(-.15,-.15,z,.048,.022) for z in [.90,.96,1.04,1.12,1.20,1.28,1.365]],4,torso_weights)
box('Belt',(0,0,.858),(.49,.305,.058),4,'Hips',.003,1)
box('Satchel',(-.222,-.137,.884),(.17,.125,.17),4,'Hips',.004,1)
box('Satchel_flap',(-.222,-.204,.934),(.178,.014,.071),3,'Hips',0)

# A single cubic head with material-defined stepped hair. No helmet shell,
# sculpted nose, round ears, or protruding eyebrows. Grids define color borders.
verts=[]; faces=[]; colors=[]
center=Vector((0,-.008,1.63)); dims=(.46,.43,.46)
for normal,u,v in [((1,0,0),(0,1,0),(0,0,1)),((-1,0,0),(0,-1,0),(0,0,1)),((0,1,0),(-1,0,0),(0,0,1)),((0,-1,0),(1,0,0),(0,0,1)),((0,0,1),(1,0,0),(0,1,0)),((0,0,-1),(1,0,0),(0,-1,0))]:
    start=len(verts)
    for j in range(5):
        for i in range(5):
            q=Vector(normal)*.5+Vector(u)*(i/4-.5)+Vector(v)*(j/4-.5)
            verts.append(tuple(center+Vector((q.x*dims[0],q.y*dims[1],q.z*dims[2]))))
    for j in range(4):
        for i in range(4):
            a=start+j*5+i; faces.append((a,a+1,a+6,a+5))
            hair=(normal[2]==1 or (normal[1]==1 and j>=1) or (abs(normal[0])==1 and j>=2) or (normal[1]==-1 and (j==3 or (j==2 and i==0))))
            colors.append(1 if hair else 0)
head_mesh=bpy.data.meshes.new('Cubic_head_Mesh'); head_mesh.from_pydata(verts,[],faces); head_mesh.update()
head=bpy.data.objects.new('Cubic_head',head_mesh); asset.objects.link(head)
finish(head,'Cubic_head',0,rigid('Head')); head.data.materials.append(mats[1])
for poly,idx in zip(head.data.polygons,colors): poly.material_index=idx
# Flush-color rectangles, all opaque and extremely shallow.
for sign in [-1,1]:
    box('Eye_'+str(sign),(sign*.083,-.224,1.633),(.045,.003,.041),1,'Head',0)
box('Mouth',(0,-.224,1.518),(.06,.003,.013),1,'Head',0)

for sign in [-1,1]:
    s='L' if sign==1 else 'R'
    aw=lambda p,s=s:blend(p.z,[(.84,'Forearm.'+s),(.91,'Forearm.'+s),(1.19,'UpperArm.'+s),(1.29,'UpperArm.'+s),(1.41,'Clavicle.'+s)])
    # Straight A-rest arm: small outward clearance, no round shoulder caps.
    rows=[(sign*(.347+(1.34-z)*.17),0,z,.205,.255) for z in [.845,.89,.95,1.01,1.06,1.12,1.20,1.28,1.35]]
    loft('Sleeve_'+s,rows,2,aw)
    box('Cuff_'+s,(sign*.43,0,.865),(.210,.260,.045),3,'Forearm.'+s,.002,1)
    box('Hand_'+s,(sign*.445,-.002,.763),(.197,.243,.167),0,'Hand.'+s,.003,1)
    lw=lambda p,s=s:blend(p.z,[(.14,'Foot.'+s),(.27,'Shin.'+s),(.32,'Shin.'+s),(.62,'Thigh.'+s),(.76,'Thigh.'+s),(.90,'Hips')])
    loft('Leg_'+s,[(sign*.125,0,z,.218,.255) for z in [.17,.24,.32,.39,.45,.49,.55,.62,.71,.80,.84]],3,lw)
    box('Boot_'+s,(sign*.125,-.044,.14),(.23,.34,.25),4,'Foot.'+s,.005,1)
    box('Sole_'+s,(sign*.125,-.044,.028),(.238,.35,.056),1,'Foot.'+s,.003,1)
    loft('Boot_shaft_'+s,[(sign*.125,0,z,.226,.265) for z in [.18,.24,.29,.32]],4,lw)

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
    shoulder=(sign*.347,0,1.32); elbow=(sign*.393,0,1.05); wrist=(sign*.433,0,.845)
    bone('Clavicle.'+s,(sign*.06,0,1.27),shoulder,'Chest')
    bone('UpperArm.'+s,shoulder,elbow,'Clavicle.'+s,True)
    bone('Forearm.'+s,elbow,wrist,'UpperArm.'+s,True)
    bone('Hand.'+s,wrist,(sign*.455,0,.68),'Forearm.'+s,True)
    bone('Thigh.'+s,(sign*.125,0,.80),(sign*.125,0,.48),'Hips')
    bone('Shin.'+s,(sign*.125,0,.48),(sign*.125,0,.16),'Thigh.'+s,True)
    bone('Foot.'+s,(sign*.125,0,.16),(sign*.125,-.20,.09),'Shin.'+s,True)
bpy.ops.object.mode_set(mode='OBJECT')
rig.show_in_front=True; arm.display_type='OCTAHEDRAL'
for pb in rig.pose.bones:
    pb.rotation_mode='XYZ'
    pb.lock_scale=(True,True,True)
    if pb.name!='Root': pb.lock_location=(True,True,True)
modifier=player.modifiers.new('Player skin','ARMATURE'); modifier.object=rig
modifier.use_deform_preserve_volume=False
player.parent=rig
player['design']='Voxel Wayfinder v2; cubic proportions, planar face, straight limbs. Front -Y, Z up, meters.'
rig['animation_notes']='Relaxed A-rest. Root motion on Root; Hips bounce, Spine/Chest breathing and recoil; clavicles support shrug and arm anticipation. FK deformation skeleton, no animation actions.'
rig['bone_axes']='Local Y follows bone; local Z faces forward (-Y world) where possible. Local X supports flexion.'
scene.render.film_transparent=True
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'
scene.render.resolution_x=1024; scene.render.resolution_y=1024
scene.render.resolution_percentage=100
scene.render.filepath=str(OUT/'player_voxel_v2_preview.png')
player.data.calc_loop_triangles()
report={'triangles':len(player.data.loop_triangles),'vertices':len(player.data.vertices),'materials':len(player.data.materials),'bones':len(arm.bones),'height':round(player.dimensions.z,4),'bounds_z':[round(min(v.co.z for v in player.data.vertices),5),round(max(v.co.z for v in player.data.vertices),5)],'hierarchy':{b.name:b.parent.name if b.parent else None for b in arm.bones}}
(OUT/'asset_report.json').write_text(json.dumps(report,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'player_voxel_v2.blend'))
result=report




