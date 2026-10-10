"""Original grounded loading/recovery study. Run build() only on backed-up source."""
import bpy, json, math, runpy
from pathlib import Path
from mathutils import Vector, Matrix, Euler

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[4]
TMP=ROOT/'.validation/lowerbody_recovery_test'
H=runpy.run_path(str(OUT.parent/'jump_dungeons_gif_v004/build_jump.py'))
R=runpy.run_path(str(OUT.parent/'run_expressive_test/build_run.py'))
END=48; FPS=30; L=.675; D=.1125; MARGIN=.0004

def smooth(t):
    t=max(0,min(1,t)); return t*t*(3-2*t)

def channel(f,keys):
    for (fa,a),(fb,b) in zip(keys,keys[1:]):
        if fa<=f<=fb:return a+(b-a)*smooth((f-fa)/(fb-fa))
    return keys[0][1] if f<keys[0][0] else keys[-1][1]

def design(f):
    # Deliberate support shift -> small receiving step -> absorption -> slower return.
    x=channel(f,[(1,0),(7,.048),(11,.038),(15,-.037),(18,-.040),(26,-.018),(37,0),(48,0)])
    y=channel(f,[(1,0),(7,.025),(11,.012),(16,-.045),(19,-.052),(30,-.030),(40,0),(48,0)])
    z=channel(f,[(1,.674),(7,.646),(11,.658),(16,.556),(18,.548),(27,.643),(33,.685),(40,.674),(48,.674)])
    pitch=channel(f,[(1,2),(7,4),(11,2),(16,7),(19,7.5),(28,2),(34,1),(42,2),(48,2)])
    roll=channel(f,[(1,0),(7,-2),(11,-1),(16,2),(19,2),(29,.4),(40,0),(48,0)])
    twist=channel(f,[(1,0),(8,-1.4),(12,-.6),(18,1.4),(29,.5),(40,0),(48,0)])
    spine=channel(f,[(1,2),(8,4),(12,3),(18,8),(21,9),(29,3),(35,0),(44,2),(48,2)])
    chest=channel(f,[(1,2),(9,3),(13,2),(19,6),(22,6.5),(31,2),(37,1),(45,2),(48,2)])
    # Existing 32 mm shoulder inset remains in the idle baseline.
    ap=channel(f,[(1,-9),(8,-18),(12,-21),(17,9),(20,20),(28,2),(35,-13),(44,-9),(48,-9)])
    al=channel(f,[(1,10),(9,15),(13,12),(18,-10),(22,-15),(30,3),(37,12),(45,10),(48,10)])
    spread=channel(f,[(1,20),(8,20),(12,20),(18,24),(22,25),(32,20),(44,20),(48,20)])
    # L remains on the floor. R unloads, makes a small forward replant, then receives load.
    step=channel(f,[(1,0),(7,0),(12,1),(48,1)])
    lift=.028*math.sin(math.pi*max(0,min(1,(f-7)/6)))**2 if 7<f<13 else 0
    return {'hip':Vector((x,y,z)),'pelvis':(pitch,twist,roll),'spine':spine,'chest':chest,
            'arms':{'R':(ap,0,-spread),'L':(al,0,spread-2)},
            'feet':{'L':(Vector((.1145,.065,0)),0),'R':(Vector((-.1145,-.055-.075*step,0)),lift)}}

def leg_matrix(pb,hip,base,clearance):
    """Aim a rigid block toward its hip; anchor the low sole corner during roll.
    The chosen ground corner is base + (+/-D,+/-D,0). At a sign change the
    whole sole/edge is down, allowing the support corner to change naturally.
    """
    direction=(hip-Vector((base.x,base.y,0))).normalized()
    for _ in range(12):
        rot=Vector((0,0,1)).rotation_difference(direction).to_matrix()
        corner=Vector((-D if rot[2][0]>0 else D,-D if rot[2][1]>0 else D,0))
        sole=base+corner-rot@corner;sole.z=MARGIN+clearance-(rot@corner).z
        direction=(hip-sole).normalized()
    rot=Vector((0,0,1)).rotation_difference(direction).to_matrix()
    head=sole+direction*L
    matrix=(rot@pb.bone.matrix_local.to_3x3()).to_4x4();matrix.translation=head
    return matrix

def set_pose(r,idle,f):
    d=design(f)
    for b in r.pose.bones:
        for k,v in idle[b.name].items():setattr(b,k,v)
    hip=r.pose.bones['Hips']
    rot=Euler(tuple(math.radians(a) for a in d['pelvis']),'XYZ').to_matrix()
    # Pelvis Euler axes are the established bone-local axes.
    hip.rotation_euler=rot.to_euler()
    hip.location=hip.bone.matrix_local.to_3x3().inverted()@(d['hip']-hip.bone.head_local)
    bpy.context.view_layer.update()
    for side in ['L','R']:
        b=r.pose.bones['Leg.'+side]
        socket=hip.matrix@(hip.bone.matrix_local.inverted()@b.bone.head_local)
        # 2 mm outward per side is a pose clearance offset, never a rest-rig edit.
        socket.x += .002*(1 if side=='L' else -1)
        base,lift=d['feet'][side]
        b.matrix=leg_matrix(b,socket,base,lift)
    for name,angles in [('Spine',(d['spine'],-d['pelvis'][1]*.4,-d['pelvis'][2]*.55)),
                        ('Chest',(d['chest'],-d['pelvis'][1]*.5,0))]+[('UpperArm.'+s,a) for s,a in d['arms'].items()]:
        b=r.pose.bones[name];e=Euler(tuple(math.radians(a) for a in angles),'ZXY' if 'UpperArm' in name else 'XYZ')
        if b.rotation_mode=='QUATERNION':b.rotation_quaternion=e.to_quaternion()
        else:b.rotation_euler=e
    # Calm gaze, with a small delayed nod during the receiving/compression event.
    bpy.context.view_layer.update()
    head=r.pose.bones['Head'];p=head.parent
    nod=channel(f,[(1,-2),(13,-2),(21,0),(25,-1),(36,-2),(48,-2)])
    head.matrix=(Matrix.Translation(head.head) @ Euler((math.radians(4+nod),0,0)).to_matrix().to_4x4()
                 @ head.bone.matrix_local.to_3x3().to_4x4())
    bpy.context.view_layer.update()

def animate():
    r=bpy.data.objects['LB_Test_Rig'];a=bpy.data.actions['LowerBody_Recovery_Test']
    idle=json.loads((OUT.parent/'jump_default_v001/idle_baseline.json').read_text())
    for layer in list(a.layers):a.layers.remove(layer)
    previous={}
    # Bake existing bone rotations/translations; no runtime constraints or rig edits.
    for j in range((END-1)*8+1):
        f=1+j/8
        set_pose(r,idle,f)
        for b in r.pose.bones:
            prop='rotation_quaternion' if b.rotation_mode=='QUATERNION' else 'rotation_euler'
            if prop=='rotation_quaternion':
                q=b.rotation_quaternion
                if b.name in previous and q.dot(previous[b.name])<0:q.negate()
                previous[b.name]=q.copy()
            b.keyframe_insert(prop,frame=f,group=b.name)
            b.keyframe_insert('location',frame=f,group=b.name)
    for c in H['curves'](a):
        for k in c.keyframe_points:k.interpolation='LINEAR'
    return {'action':a.name,'frames':[1,END],'fps':FPS,'rig_changes':[]}

def build():
    assert bpy.context.mode=='OBJECT' and 'LowerBody_Recovery_Test' not in bpy.data.actions
    assert (TMP/'live_before_test.blend').exists()
    template=bpy.data.scenes['RUN_EXPRESSIVE_REVIEW']
    s=bpy.data.scenes.new('LOWERBODY_RECOVERY_REVIEW');s.world=template.world
    s.render.engine='CYCLES';s.cycles.device='GPU';s.cycles.samples=16;s.cycles.use_denoising=True
    s.render.resolution_x=s.render.resolution_y=640;s.render.resolution_percentage=100
    s.render.fps=FPS;s.frame_start=1;s.frame_end=END;s.render.image_settings.file_format='PNG';s.render.use_motion_blur=False
    for k in ['view_transform','look','exposure','gamma']:setattr(s.view_settings,k,getattr(template.view_settings,k))
    r,m=R['make_actor'](s,bpy.data.objects['RUN_Test_Rig'],bpy.data.objects['RUN_Test_Mesh'],'LB_Test')
    for suffix in ['FixedFloor','Key','Fill','Rim','FRONT','THREE_QUARTER','SIDE']:
        o=bpy.data.objects['RUN_'+suffix].copy();o.name='LB_'+suffix;s.collection.objects.link(o)
    s.camera=bpy.data.objects['LB_THREE_QUARTER'];bpy.context.window.scene=s
    a=bpy.data.actions.new('LowerBody_Recovery_Test');a.use_fake_user=True
    r.animation_data_create();r.animation_data.action=a
    result=animate()
    for f,label in [(1,'MOVING-READY'),(7,'LEFT LOAD / ANTICIPATION'),(10,'RIGHT FOOT REPLANT'),(13,'RIGHT CONTACT'),(18,'MAXIMUM ABSORPTION'),(22,'TORSO FOLLOW-THROUGH'),(33,'RECOVERY / SMALL OVERSHOOT'),(42,'SETTLED / READY')]:s.timeline_markers.new(label,frame=f)
    s['purpose']='Grounded lower-body quality study / no jump / Blender-only / pending review'
    s.frame_set(18)
    for o in bpy.context.selected_objects:o.select_set(False)
    r.select_set(True);bpy.context.view_layer.objects.active=r
    result.update({'scene':s.name,'source':json.loads((TMP/'backup_manifest.json').read_text()),'status':'Arm and run exploratory steps explicitly approved; lower-body test pending review','support':'L planted throughout; R unloaded/replanted F7-13; both feet supported during absorption/recovery','root_motion':False})
    (OUT/'manifest.json').write_text(json.dumps(result,indent=2))
    return result

def render(view,frames):
    s=bpy.data.scenes['LOWERBODY_RECOVERY_REVIEW'];bpy.context.window.scene=s;s.camera=bpy.data.objects['LB_'+view]
    p=OUT/'frames'/view.lower();p.mkdir(parents=True,exist_ok=True)
    for f in frames:
        s.frame_set(f);s.render.filepath=str(p/f'{f:03d}.png')
        bpy.ops.render.render(write_still=True,scene=s.name)
    return {'view':view,'frames':list(frames)}
