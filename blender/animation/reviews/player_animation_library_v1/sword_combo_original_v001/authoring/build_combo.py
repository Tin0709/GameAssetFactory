"""Original three-hit choreography; reuse exact GAF rig and existing sword.

Run in a read-only-loaded Animation_Showcase; write ONLY the new source study.
No imported MD2/A&S motion tracks. Coordinates: this measured viewer faces -Y.
"""
import bpy, json, math, sys
from pathlib import Path
from mathutils import Vector, Matrix, Euler, Quaternion

OUT=Path(__file__).resolve().parent.parent
ROOT=OUT.parents[4]
sys.path.insert(0,str(ROOT/'blender/animation/showcase'))
import gaf_animation_library as ui

ACTION='Sword_Combo_Original_v001'
SOURCE=OUT/'sword_combo_original_v001.blend'
START=1;END=61;FPS=30;L=.675;D=.1125;MARGIN=.0006


def channel(frame, keys):
    """Shape-preserving cubic Hermite: pass through contacts without stop keys."""
    x=[float(p[0]) for p in keys];y=[float(p[1]) for p in keys]
    if frame<=x[0]:return y[0]
    if frame>=x[-1]:return y[-1]
    delta=[(y[i+1]-y[i])/(x[i+1]-x[i]) for i in range(len(x)-1)]
    slopes=[0.0]*len(x)
    for i in range(1,len(x)-1):
        if delta[i-1]*delta[i]>0:
            h0=x[i]-x[i-1];h1=x[i+1]-x[i]
            w0=2*h1+h0;w1=h1+2*h0
            slopes[i]=(w0+w1)/(w0/delta[i-1]+w1/delta[i])
    i=next(i for i in range(len(x)-1) if frame<x[i+1])
    h=x[i+1]-x[i];t=(frame-x[i])/h
    return (2*t**3-3*t*t+1)*y[i]+(t**3-2*t*t+t)*h*slopes[i]+(-2*t**3+3*t*t)*y[i+1]+(t**3-t*t)*h*slopes[i+1]


# Each pose is hand-authored, in character right/forward/up coordinates.
# Blade directions are projected perpendicular to the straight arm; the palm
# and sword subsequently have one fixed rigid relative transform.
RIGHT=[
 (1,(.20,.46,-.87),(-.16,.66,.73)),
 (3,(.20,.46,-.87),(-.16,.66,.73)),
 (6.5,(.84,.32,.04),(.08,.42,.90)),
 (7.5,(.84,.32,.04),(.08,.42,.90)),
 (10,(-.10,.92,-.38),(-.76,.55,-.36)),
 (13,(-.23,.92,-.26),(-.94,.20,-.20)),
 (17,(-.19,.94,-.20),(-.86,.08,.51)),
 (21,(-.14,.91,-.25),(-.86,.12,.50)),
 (25,(.40,.84,-.31),(.86,.28,-.10)),
 (29,(.72,.58,-.17),(.69,-.05,.72)),
 (34,(.85,.35,.14),(-.05,.24,.97)),
 (37,(.60,.30,.74),(-.20,.10,.98)),
 (40,(.60,.30,.74),(-.20,.10,.98)),
 (43,(-.04,.90,-.44),(-.43,.54,-.72)),
 (46,(-.12,.83,-.55),(-.68,.56,-.49)),
 (50,(.04,.78,-.62),(-.53,.70,.44)),
 (56,(.20,.46,-.87),(-.16,.66,.73)),
 (59,(.20,.46,-.87),(-.16,.66,.73)),
 (61,(.20,.46,-.87),(-.16,.66,.73)),
]

LEFT=[(1,(-.23,.08,-.97)),(3,(-.23,.08,-.97)),(7,(-.42,-.23,-.88)),
 (11,(-.34,.32,-.88)),(15,(-.30,.38,-.87)),(21,(-.48,.18,-.86)),
 (26,(-.34,-.30,-.88)),(30,(-.28,-.36,-.89)),(37,(-.43,-.20,-.88)),
 (43,(-.48,.25,-.84)),(47,(-.36,.40,-.84)),(54,(-.23,.08,-.97)),(61,(-.23,.08,-.97))]


def vec_channel(frame, keys, index=1):
    return Vector(tuple(channel(frame,[(p[0],p[index][axis]) for p in keys]) for axis in range(3)))


def world_vector(v):
    return Vector((-v[0],-v[1],v[2]))


def arm_frame(direction,blade):
    down=direction.normalized()
    front=(blade-down*blade.dot(down)).normalized()
    side=front.cross(down).normalized()
    return Matrix((side,-front,-down)).transposed(),front


def quat_log(q):
    q=q.normalized()
    if q.w<0:q.negate()
    v=Vector((q.x,q.y,q.z));n=v.length
    return v*(math.atan2(n,q.w)/n) if n>1e-10 else Vector((0,0,0))


def quat_exp(v):
    n=v.length
    return Quaternion((math.cos(n),*(v*(math.sin(n)/n)))) if n>1e-10 else Quaternion((1,0,0,0))


_right_quats=None


def right_rotation(frame):
    """Time-aware spherical Bezier, avoiding near-parallel vector projections."""
    global _right_quats
    if _right_quats is None:
        qs=[]
        for f,direction,blade in RIGHT:
            q=arm_frame(world_vector(direction),world_vector(blade))[0].to_quaternion()
            if qs and qs[-1][1].dot(q)<0:q.negate()
            qs.append((f,q))
        velocities=[]
        for i,(f,q) in enumerate(qs):
            if i==0 or i==len(qs)-1:v=Vector((0,0,0))
            else:
                hp=f-qs[i-1][0];hn=qs[i+1][0]-f
                before=-quat_log(q.inverted()@qs[i-1][1])/hp
                after=quat_log(q.inverted()@qs[i+1][1])/hn
                v=(hn*before+hp*after)/(hp+hn)
                if before.length<1e-6 or after.length<1e-6:v=Vector((0,0,0))
                if v.length>.25:v*=.25/v.length
            velocities.append(v)
        _right_quats=(qs,velocities)
    qs,velocities=_right_quats
    if frame<=qs[0][0]:return qs[0][1].to_matrix()
    if frame>=qs[-1][0]:return qs[-1][1].to_matrix()
    i=next(i for i in range(len(qs)-1) if frame<qs[i+1][0])
    f,q=qs[i];g,r=qs[i+1];h=g-f;t=(frame-f)/h
    a=q@quat_exp(velocities[i]*h/3);b=r@quat_exp(-velocities[i+1]*h/3)
    qa=q.slerp(a,t);qb=a.slerp(b,t);qc=b.slerp(r,t)
    return qa.slerp(qb,t).slerp(qb.slerp(qc,t),t).to_matrix()


def rotation(pitch=0,yaw=0,roll=0):
    return (Matrix.Rotation(math.radians(yaw),3,'Z') @
            Matrix.Rotation(math.radians(roll),3,'Y') @
            Matrix.Rotation(math.radians(pitch),3,'X'))


def set_orientation(pb,rot):
    m=(rot@pb.bone.matrix_local.to_3x3()).to_4x4()
    m.translation=pb.head.copy();pb.matrix=m
    bpy.context.view_layer.update()


def sole_matrix(pb,socket,base,clearance,toe):
    """Existing rigid-sole recipe, with a fixed, explicit toe-out orientation."""
    yaw=Matrix.Rotation(math.radians(toe),3,'Z')
    direction=(socket-base).normalized()
    for _ in range(12):
        rot=Vector((0,0,1)).rotation_difference(direction).to_matrix()@yaw
        corner=min((Vector((x,y,0)) for x in [-D,D] for y in [-D,D]),key=lambda c:(rot@c).z)
        reference=yaw@corner
        sole=base+reference-rot@corner
        sole.z=MARGIN+clearance-(rot@corner).z
        direction=(socket-sole).normalized()
    rot=Vector((0,0,1)).rotation_difference(direction).to_matrix()@yaw
    m=(rot@pb.bone.matrix_local.to_3x3()).to_4x4()
    m.translation=sole+direction*L
    return m


def step(frame,a,b,amount=.04):
    if not a<frame<b:return 0.0
    return amount*math.sin(math.pi*(frame-a)/(b-a))**2


def foot_design(frame):
    left_y=channel(frame,[(1,-.06),(4,-.06),(9,-.16),(29,-.16),(36,-.20),(51,-.20),(58,-.06),(61,-.06)])
    right_y=channel(frame,[(1,.065),(16,.065),(23,-.065),(44,-.065),(51,.065),(61,.065)])
    left_x=channel(frame,[(1,.16),(29,.16),(36,.18),(51,.18),(58,.16),(61,.16)])
    return {
        'L':(Vector((left_x,left_y,0)),step(frame,4,9,.028)+step(frame,29,36,.024)+step(frame,51,58,.028),8),
        'R':(Vector((-.16,right_y,0)),step(frame,16,23,.026)+step(frame,44,51,.032),-8),
    }


def pose(rig,neutral,frame):
    for b in rig.pose.bones:
        b.matrix_basis=Matrix.Identity(4)
        for prop,value in neutral[b.name].items():setattr(b,prop,value)
        b.scale=(1,1,1)
    bpy.context.view_layer.update()
    hip_yaw=channel(frame,[(1,-6),(3,-6),(7,-16),(11,10),(15,13),(21,15),(26,-13),(30,-16),(37,-10),(44,10),(48,8),(56,-6),(61,-6)])
    chest_yaw=channel(frame,[(1,-9),(3,-9),(7,-35),(11,28),(15,36),(21,39),(26,-35),(30,-40),(37,-24),(44,23),(48,19),(56,-9),(61,-9)])
    lean=channel(frame,[(1,3),(4,3),(7,1),(11,8),(15,5),(21,2),(26,7),(30,4),(37,-3),(43,13),(46,15),(51,6),(57,3),(61,3)])
    x=channel(frame,[(1,-.012),(7,-.028),(11,.026),(15,.020),(21,.030),(26,-.032),(30,-.020),(37,-.024),(44,.025),(48,.018),(56,-.012),(61,-.012)])
    y=channel(frame,[(1,0),(7,.018),(11,-.035),(16,-.025),(21,-.014),(27,-.050),(33,-.030),(37,.012),(44,-.065),(47,-.060),(57,0),(61,0)])
    z=channel(frame,[(1,.653),(4,.653),(7,.660),(10,.649),(11.5,.649),(15,.650),(21,.646),(25,.648),(26.5,.646),(31,.652),(37,.648),(41,.650),(44,.644),(46,.648),(50,.651),(53,.657),(57,.653),(61,.653)])
    roll=channel(frame,[(1,-1),(7,-2),(11,2),(15,1),(21,2),(26,-2),(31,-1),(37,-2),(44,2),(49,1),(56,-1),(61,-1)])
    hips=rig.pose.bones['Hips']
    m=(rotation(lean*.30,hip_yaw,roll)@hips.bone.matrix_local.to_3x3()).to_4x4();m.translation=(x,y,z);hips.matrix=m
    bpy.context.view_layer.update()
    set_orientation(rig.pose.bones['Spine'],rotation(lean*.65,chest_yaw*.58,roll*.45))
    set_orientation(rig.pose.bones['Chest'],rotation(lean,chest_yaw,roll*.28))
    # Technical Neck/ForeArm helpers retain identity local transforms.
    rig.pose.bones['Neck'].matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
    head_yaw=channel(frame,[(1,0),(7,-5),(11,5),(20,7),(26,-6),(36,-4),(44,5),(53,0),(61,0)])
    set_orientation(rig.pose.bones['Head'],rotation(lean*.2,head_yaw,roll*.15))
    # A single rigid rotation drives the full right arm and its sword grip.
    arm_rot=right_rotation(frame)
    right_dir=arm_rot@Vector((0,0,-1));blade=arm_rot@Vector((0,-1,0))
    right=rig.pose.bones['UpperArm.R'];set_orientation(right,arm_rot)
    for side in ['L','R']:rig.pose.bones['ForeArm.'+side].matrix_basis=Matrix.Identity(4)
    left_dir=world_vector(vec_channel(frame,LEFT)).normalized()
    left_rot,_=arm_frame(left_dir,Vector((0,-1,0)))
    set_orientation(rig.pose.bones['UpperArm.L'],left_rot)
    bpy.context.view_layer.update()
    palm=right.head+right_dir*.622
    # X=blade face normal, Y=blade length, Z=the hand/arm's downward axis.
    side=blade.cross(right_dir).normalized()
    sword_rotation=Matrix((side,blade,right_dir)).transposed()
    weapon=rig.pose.bones['WeaponCarrier']
    wm=sword_rotation.to_4x4();wm.translation=palm;weapon.matrix=wm
    bpy.context.view_layer.update()
    feet=foot_design(frame)
    for side in ['L','R']:
        b=rig.pose.bones['Leg.'+side]
        socket=hips.matrix@(hips.bone.matrix_local.inverted()@b.bone.head_local)
        base,lift,toe=feet[side];b.matrix=sole_matrix(b,socket,base,lift,toe)
    bpy.context.view_layer.update()
    return {'palm':palm,'blade':blade,'feet':feet,'hip':(x,y,z),'chest_yaw':chest_yaw}


def make_scene():
    assert ACTION not in bpy.data.actions,'Never overwrite an existing Action'
    template=bpy.context.scene
    scene=bpy.data.scenes.new('SWORD_COMBO_ORIGINAL_REVIEW')
    scene.world=template.world
    scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=8
    scene.cycles.use_denoising=False
    scene.render.resolution_x=scene.render.resolution_y=640;scene.render.resolution_percentage=100
    scene.render.fps=FPS;scene.render.fps_base=1;scene.frame_start=START;scene.frame_end=END
    scene.render.image_settings.file_format='PNG';scene.render.use_motion_blur=False
    for name in ['view_transform','look','exposure','gamma']:setattr(scene.view_settings,name,getattr(template.view_settings,name))
    original=bpy.data.objects[ui.RIG];oldmesh=bpy.data.objects['Showcase_Player_Mesh']
    rig=original.copy();rig.data=original.data.copy();rig.name='SC_Player_Rig';rig.animation_data_clear();scene.collection.objects.link(rig)
    mesh=oldmesh.copy();mesh.data=oldmesh.data.copy();mesh.name='SC_Player_Mesh';mesh.parent=rig;mesh.animation_data_clear();scene.collection.objects.link(mesh)
    for modifier in mesh.modifiers:
        if modifier.type=='ARMATURE':modifier.object=rig
    for suffix in ['FixedFloor','Key','Fill','Rim','FRONT','THREE_QUARTER','SIDE']:
        old=bpy.data.objects['Showcase_'+suffix];obj=old.copy();obj.data=old.data.copy();obj.name='SC_'+suffix;scene.collection.objects.link(obj)
    scene.camera=bpy.data.objects['SC_THREE_QUARTER']
    source=ROOT/'blender/weapons/sword_sand_block_v1/Sword_Sand_Block_V1.blend'
    with bpy.data.libraries.load(str(source),link=False) as (src,dst):dst.collections=['WEAPON_EXPORT']
    prop=dst.collections[0];prop.name='SC_Sword_Preview';scene.collection.children.link(prop)
    sword=next(o for o in prop.all_objects if o.name=='Sword_Sand_Block_V1')
    sword.parent=rig;sword.parent_type='BONE';sword.parent_bone='WeaponCarrier'
    sword.matrix_parent_inverse=Matrix.Translation((0,-rig.data.bones['WeaponCarrier'].length,0));sword.matrix_basis=Matrix.Identity(4)
    for obj in prop.all_objects:
        if obj.type!='MESH':obj.hide_render=True;obj.empty_display_size=.025
    bpy.context.window.scene=scene
    for o in bpy.context.selected_objects:o.select_set(False)
    rig.select_set(True);bpy.context.view_layer.objects.active=rig
    return scene,rig,mesh,sword


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    scene,rig,mesh,sword=make_scene()
    assert ui.rest_signature(rig.data)=='cb913716b708b9f975b350f4a80a57d8244f1903ced498a6b3ce0fc5f8391b2f'
    neutral=json.loads(bpy.data.texts[ui.BASELINE].as_string())
    action=bpy.data.actions.new(ACTION);action.use_fake_user=True
    rig.animation_data_create();rig.animation_data.action=action
    prev={}
    for j in range((END-START)*8+1):
        f=START+j/8;pose(rig,neutral,f)
        for b in rig.pose.bones:
            prop='rotation_quaternion' if b.rotation_mode=='QUATERNION' else 'rotation_euler'
            if prop=='rotation_quaternion':
                if b.name in prev and b.rotation_quaternion.dot(prev[b.name])<0:b.rotation_quaternion.negate()
                prev[b.name]=b.rotation_quaternion.copy()
            b.keyframe_insert('location',frame=f,group=b.name)
            b.keyframe_insert(prop,frame=f,group=b.name)
    for curve in ui.curves(action):
        for key in curve.keyframe_points:key.interpolation='LINEAR'
    markers=[(1,'GUARD / ORIGINAL v001'),(6,'A1 / compact load'),(10,'A1 / planned contact'),(13,'A1 / follow-through'),(21,'A2 / returning load'),(25,'A2 / planned contact'),(29,'A2 / follow-through'),(37,'A3 / heavy load'),(43,'A3 / planned contact'),(46,'A3 / receive'),(53,'RECOVER'),(59,'GUARD / settled')]
    for f,label in markers:scene.timeline_markers.new(label,frame=f)
    scene['review_status']='PENDING / Original choreography / Blender only'
    scene['provenance']='P original poses/timing; A&S principles and observed MD2 footage only. No imported game animation tracks.'
    scene.frame_set(10)
    neutral_text=bpy.data.texts.new('SC_Original_Design.txt')
    neutral_text.write('Sword Combo Original v001 — PENDING\nF1–61, 30FPS. Planned contacts F10/F25/F43.\nOriginal choreography; no MD2 bone tracks or exact MD2 timing claimed.\nOne rigid right-hand grip; body in place; foot changes explicitly authored.\nBlender review only; no hitbox, damage or runtime integration.\n')
    bpy.data.libraries.write(str(SOURCE),{scene,action,neutral_text},fake_user=False,compress=True)
    design={
        'action':ACTION,'status':'pending','source':str(SOURCE.relative_to(ROOT)),
        'rig':rig.name,'mesh':mesh.name,'slot':action.slots[0].identifier,
        'frames':[START,END],'fps':FPS,'elapsed_endpoint_seconds':2.0,'nonloop':True,
        'planned_contact_frames':[10,25,43],'planned_contact_seconds':[.3,.8,1.4],
        'hit_descriptions':['right-to-left descending slash','left-to-right returning sweep','longer load / descending finisher'],
        'sword_asset':str((ROOT/'blender/weapons/sword_sand_block_v1/Sword_Sand_Block_V1.blend').relative_to(ROOT)),
        'grip_distance_from_shoulder_m':.622,'world_travel_owner':'future controller; not authored in this Action',
        'original_motion':True,'game_tracks_imported':False,'godot_modified':False,
        'provenance':{'S':'A&S controller/layer/time principles only; no source curves copied','O':'Genuine MD2 cached gameplay frame sheets G01–G03, same-body sweep/follow-through and discrete hit feedback','P':'All bone transforms, timing, footwork, arcs and receiving/recovery','U':'Real MD2 skeleton, tracks, authored keys, hit windows and blend settings unavailable'},
        'md2_publication_facts':{'damage':[14,16,22],'knockback_strength_raw':[500,500,800],'attack_speed_multiplier':[1,1,1.4],'qualification':'Previously cross-checked public data publications, not an independently authenticated local game asset. Not used as pose angles, times, physical masses or clip play rates.'},
    }
    (OUT/'design.json').write_text(json.dumps(design,indent=2)+'\n')
    print('SWORD_COMBO_SOURCE_SAVED',json.dumps({'file':str(SOURCE),'action':action.name,'slot':action.slots[0].identifier,'curves':len(ui.curves(action)),'status':'pending'}),flush=True)


if __name__=='__main__':main()
