"""R1: original rigid full-body locomotion study, isolated from weapon/Godot work."""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Matrix, Vector, Quaternion
BASE=Path(__file__).resolve().parent
OUT=BASE/'reference_study_r1_review';OUT.mkdir(exist_ok=True)
DEV=BASE/'player_locomotion_reference_study.blend'
assert Path(bpy.data.filepath)==DEV
src=(BASE/'create_ready_e1.py').read_text()
exec(src[src.index('def curves('):src.index('def sample(')])
source_rig=bpy.data.objects['Player_Cuboid_Rig'];rig=source_rig
mesh=bpy.data.objects['Player_Cuboid_Base']
assert all(n not in bpy.data.actions for n in ['Walk_ReferenceStudy_V1','Sprint_ReferenceStudy_V1'])
protected={'actions':{a.name:digest(a) for a in bpy.data.actions},'geometry':geometry(),'bones':bones(),
 'weapon_dev_sha256':hashlib.sha256((BASE/'player_cuboid_weapon_animation_dev.blend').read_bytes()).hexdigest()}
(OUT/'preservation_before.json').write_text(json.dumps(protected,indent=2))

def copy_character(s,label,x=0):
    rr=source_rig.copy();rr.data=source_rig.data.copy();rr.name='R1_'+label+'_Rig';rr.animation_data_clear()
    s.collection.objects.link(rr);rr.location.x=x
    for p in rr.pose.bones:p.matrix_basis=Matrix.Identity(4)
    mm=mesh.copy();mm.name='R1_'+label+'_Mesh';s.collection.objects.link(mm);mm.parent=rr
    mm.matrix_parent_inverse=mesh.matrix_parent_inverse.copy()
    for mod in mm.modifiers:
        if mod.type=='ARMATURE':mod.object=rr
    rr.hide_render=False;mm.hide_render=False;rr.hide_viewport=False;mm.hide_viewport=False
    return rr,mm

scene=bpy.data.scenes.new('R1_Authoring');scene.use_fake_user=True
bpy.context.window.scene=scene
rig,displaymesh=copy_character(scene,'Study')
rig.animation_data_create()
points={}
for n in ['Head','Chest','Arm.L','Arm.R','Leg.L','Leg.R']:
    gi=mesh.vertex_groups[n].index
    points[n]=[v.co.copy() for v in mesh.data.vertices if any(g.group==gi and g.weight>.999 for g in v.groups)]
def world_points(n):
    m=rig.pose.bones[n].matrix@rig.data.bones[n].matrix_local.inverted()
    return [m@v for v in points[n]]

def pose(t,sprint):
    rig.animation_data.action=None
    for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
    a=2*math.pi*t;c=math.cos(a);sn=math.sin(a)
    def rot(n,x=0,y=0,z=0):rig.pose.bones[n].rotation_euler=tuple(map(math.radians,(x,y,z)))
    # Actual rest axes: axial bones +Y is up; limb +Y is down, local +X swings forward.
    rot('Hips',2.0 if sprint else 1.0,(3.0 if sprint else 2.0)*c,(2.8 if sprint else 1.8)*sn)
    rig.pose.bones['Hips'].location.x=(.013 if sprint else .010)*sn
    rot('Spine',(5.5 if sprint else 2.2)+(1.4 if sprint else .7)*math.cos(2*a),-(3.4 if sprint else 2.2)*c,-1.3*sn)
    rot('Chest',1.8 if sprint else .8,-(3.2 if sprint else 1.8)*c,-.7*sn)
    for side,shift,sign in [('R',0,-1),('L',math.pi,1)]:
        p=a+shift;v=math.cos(p)
        leg=(44 if sprint else 30)*v-(5 if sprint else 3)*math.sin(2*p)-(14 if sprint else 10)
        rot('Leg.'+side,leg,0,sign*.8)
        # Small local rigid recovery lift. No bending, stretch or changed rest geometry.
        lift=(.038 if sprint else .018)*max(0,math.sin(p))**2
        rig.pose.bones['Leg.'+side].location.y=-lift
        arm=(13 if sprint else 7)-(51 if sprint else 34)*v
        forward=max(0,(arm-12)/(52 if sprint else 29))
        rot('Arm.'+side,arm,sign*(4 if sprint else 2)*forward,sign*(2-(16 if sprint else 10)*forward**2))
    bpy.context.view_layer.update()
    # Calm orientation, inherited positional bob: no head location keys or world lock.
    chestq=rig.pose.bones['Chest'].matrix.to_quaternion()
    restq=rig.data.bones['Chest'].matrix_local.to_quaternion()
    delta=chestq@restq.inverted()
    for n,amount in [('Neck',.45),('Head',.20)]:
        p=rig.pose.bones[n];m=(Quaternion().slerp(delta,amount)@rig.data.bones[n].matrix_local.to_quaternion()).to_matrix().to_4x4()
        m.translation=p.matrix.translation;p.matrix=m;bpy.context.view_layer.update()
    low=min(v.z for n in ['Leg.L','Leg.R'] for v in world_points(n))
    # Whole-body clearance preserves linked vertical motion. A small flight arc on Sprint.
    clearance=.006+(.060 if sprint else .034)*math.sin(a)**4
    rig.pose.bones['Hips'].location.y=clearance-low
    bpy.context.view_layer.update()
    return {p.name:(p.location.copy(),p.rotation_euler.copy()) for p in rig.pose.bones}

actions={}
for gait,period in [('Walk',16),('Sprint',13)]:
    poses=[pose(i/64,gait=='Sprint') for i in range(64)];poses.append(poses[0])
    action=bpy.data.actions.new(gait+'_ReferenceStudy_V1');action.use_fake_user=True;rig.animation_data.action=action
    for i,ps in enumerate(poses):
        f=1+period*i/64
        for n in ['Root','Hips','Spine','Chest','Neck','Head','Arm.L','Arm.R','Leg.L','Leg.R']:
            p=rig.pose.bones[n];p.location,p.rotation_euler=ps[n]
            p.keyframe_insert('rotation_euler',frame=f,group=n)
            if n in ['Root','Hips','Leg.L','Leg.R']:p.keyframe_insert('location',frame=f,group=n)
    step=period/64
    for curve in curves(action):
        ks=curve.keyframe_points;ys=[k.co.y for k in ks]
        for i,k in enumerate(ks):
            j=i%64;slope=(ys[(j+1)%64]-ys[(j-1)%64])/(2*step)
            k.interpolation='BEZIER';k.handle_left_type=k.handle_right_type='FREE'
            k.handle_left=(k.co.x-step/3,k.co.y-slope*step/3);k.handle_right=(k.co.x+step/3,k.co.y+slope*step/3)
        curve.modifiers.new('CYCLES');curve.update()
    action['fps']=24;action['cycle_frames']=period;action['cycle_seconds']=period/24
    action['playback']='1..%d unique samples; terminal endpoint %d retained; 1.0x speed'%(period,period+1)
    action['source']='Original R1 study of separate 093200 rear and 093249 front recordings. Chosen angles are artistic values, not recovered source geometry.'
    action['rig_contract']='Full body in place, original rigid hierarchy; no scale tracks, no WeaponCarrier tracks; unarmed study only.'
    actions[gait]=action

# Independent side-by-side playback: 208 is the common multiple of 16 and 13.
preview=bpy.data.scenes.new('R1_Walk_Sprint_Comparison');preview.use_fake_user=True
preview.render.engine='BLENDER_EEVEE';preview.render.fps=24;preview.render.fps_base=1
preview.render.resolution_x=1000;preview.render.resolution_y=650;preview.render.resolution_percentage=100
preview.frame_start=1;preview.frame_end=208;preview.sync_mode='FRAME_DROP'
preview.world=bpy.data.worlds.new('R1_World');preview.world.use_nodes=True
preview.world.node_tree.nodes['Background'].inputs[0].default_value=(.18,.22,.27,1)
preview.world.node_tree.nodes['Background'].inputs[1].default_value=.6
for gait,x in [('Walk',-.9),('Sprint',.9)]:
    rr,mm=copy_character(preview,gait,x);rr.animation_data_create();rr.animation_data.action=actions[gait]
    rr.animation_data.action_slot=actions[gait].slots[0]
    data=bpy.data.curves.new('R1_'+gait+'_Label','FONT');data.body=gait+'  /  '+('0.667 s' if gait=='Walk' else '0.542 s');data.align_x='CENTER';data.size=.12
    o=bpy.data.objects.new(data.name,data);preview.collection.objects.link(o);o.location=(x,0,2.05);o.rotation_euler=(math.pi/2,0,0)
def camera(s,name,pos,target,scale):
    d=bpy.data.cameras.new(name);d.type='ORTHO';d.ortho_scale=scale
    o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.location=pos;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();return o
preview.camera=camera(preview,'R1_Front_Comparison',(0,-8,2.4),(0,0,1),3.8)
for name,pos,power,size in [('Key',(-3,-4,6),750,5),('Fill',(3,1,4),500,4)]:
    d=bpy.data.lights.new('R1_'+name,'AREA');d.energy=power;d.shape='DISK';d.size=size
    o=bpy.data.objects.new(d.name,d);preview.collection.objects.link(o);o.location=pos;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
# Floor only belongs to study scenes. Existing model mesh data is untouched.
bpy.context.window.scene=preview
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.002));floor=bpy.context.object;floor.name='R1_Review_Ground'
mat=bpy.data.materials.new('R1_Ground_Material');mat.diffuse_color=(.10,.13,.16,1);floor.data.materials.append(mat)
scene.world=preview.world;scene.render.engine='BLENDER_EEVEE';scene.render.fps=24;scene.render.fps_base=1
for o in preview.objects:
    if o.type=='LIGHT' or o==floor:scene.collection.objects.link(o)
scene.render.resolution_x=322;scene.render.resolution_y=538;scene.render.resolution_percentage=100
scene.camera=camera(scene,'R1_Front_Study',(0,-8,1.15),(0,0,.9),2.5)
camera(scene,'R1_Rear_Study',(0,7,4.2),(0,0,.9),2.5)
game=preview.copy();game.name='R1_GameplayScale';game.use_fake_user=True
D=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
q=(D@Matrix.Rotation(math.radians(36.86989764584402),3,'Y')@Matrix.Rotation(math.radians(-36.31588642394517),3,'X')).to_quaternion()
c=camera(game,'R1_Gameplay',(0,0,15),(0,0,1),14.5*1280/720);c.rotation_euler=q.to_euler();c.location=Vector((0,0,1))+q@Vector((0,0,15));game.camera=c
game.render.resolution_x=1280;game.render.resolution_y=720
rig.animation_data.action=actions['Walk'];scene.frame_start=1;scene.frame_end=16
for a in bpy.data.actions:
    if a.name in protected['actions']:assert digest(a)==protected['actions'][a.name],a.name
assert all(geometry()[n]==h for n,h in protected['geometry'].items())
rig=source_rig;assert json.dumps(bones(),sort_keys=True)==json.dumps(protected['bones'],sort_keys=True)
readme=bpy.data.texts.new('R1_README');readme.write('R1 first-pass original unarmed locomotion.\nWalk_ReferenceStudy_V1: keys 1..17; play 1..16 at 24 FPS.\nSprint_ReferenceStudy_V1: keys 1..14; play 1..13 at 24 FPS.\nR1_Walk_Sprint_Comparison: both independent clocks at 1.0x; Space to play. 208 unique frames.\nR1_GameplayScale: project elevated camera, 14.5 vertical units at 1280x720.\nR1_Authoring: isolated study rig, assign either action.\nNo Godot or weapon compatibility claims. Source review used decoded frames, not observed continuous playback.\n')
bpy.context.window.scene=preview;preview.frame_set(1)
for a in bpy.context.screen.areas:
    if a.type=='VIEW_3D':
        a.spaces.active.overlay.show_overlays=False;a.spaces.active.shading.type='MATERIAL';a.spaces.active.region_3d.view_perspective='CAMERA';a.spaces.active.region_3d.view_camera_zoom=5
    if a.type=='DOPESHEET_EDITOR':a.spaces.active.mode='TIMELINE'
bpy.ops.wm.save_as_mainfile(filepath=str(DEV),check_existing=False)
result={'file':str(DEV),'actions':list(actions),'protected_actions':len(protected['actions'])}
