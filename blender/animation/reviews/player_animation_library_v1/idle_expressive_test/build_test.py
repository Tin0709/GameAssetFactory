"""A quiet supported Idle; no rig changes, world travel or old Action edits."""
import bpy,json,sys,math
from pathlib import Path
from mathutils import Vector,Matrix,Euler
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];TMP=ROOT/'.validation/idle_expressive_test'
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
P=96;CLOSE=P+1;FPS=30;STEP=.125
IDLE=json.loads((OUT.parent/'jump_default_v001/idle_baseline.json').read_text())
FEET={}

def channel(f,keys):
    f=1+(f-1)%P
    for (fa,a,da),(fb,b,db) in zip(keys,keys[1:]):
        if fa<=f<=fb:
            t=(f-fa)/(fb-fa);h=fb-fa
            return (2*t**3-3*t*t+1)*a+(t**3-2*t*t+t)*h*da+(-2*t**3+3*t*t)*b+(t**3-t*t)*h*db
    raise ValueError(f)

def design(f):
    C=lambda k:channel(f,k)
    x=C([(1,-.004,-.00025),(12,-.006,0),(20,-.006,0),(48,.009,0),(58,.009,0),(79,.003,-.00035),(97,-.004,-.00025)])
    z=C([(1,.6718,-.00004),(15,.6709,0),(25,.6714,.00008),(35,.673,0),(53,.6705,0),(62,.6705,0),(80,.6724,0),(97,.6718,-.00004)])
    breath=C([(1,.08,.008),(13,.18,.013),(29,1,0),(40,.88,-.022),(65,0,0),(78,0,0),(97,.08,.008)])
    return {'hip':Vector((x,C([(1,-.001,0),(24,-.002,0),(48,.001,0),(65,.001,0),(84,-.001,0),(97,-.001,0)]),z)),
      'pelvis':(1.15+.18*breath,-x*24,-x*30),
      'spine':1.5+.32*breath,'chest':1+.65*breath,
      'arm_r':C([(1,-6,-.012),(20,-6.3,0),(36,-3.5,0),(57,-4.2,-.05),(74,-7.3,0),(86,-6.2,.035),(97,-6,-.012)]),
      'arm_l':C([(1,5.4,-.018),(15,5.2,0),(30,6.6,0),(44,7.4,0),(65,4.7,0),(82,5.8,0),(97,5.4,-.018)]),
      'spread_r':13.5+.6*C([(1,.15,.002),(24,0,0),(43,1,0),(62,.8,-.012),(83,.1,0),(97,.15,.002)]),
      'spread_l':11.8+.5*C([(1,.4,.006),(18,.55,0),(36,1,0),(61,0,0),(80,.1,.016),(97,.4,.006)]),
      'shoulder_r':.00065*C([(1,.15,.003),(17,.15,0),(35,1,0),(62,0,0),(80,.05,0),(97,.15,.003)]),
      'shoulder_l':.0008*C([(1,.1,.002),(10,.1,0),(29,1,0),(58,0,0),(78,0,0),(97,.1,.002)]),
      'head_pitch':C([(1,1.7,.006),(20,1.8,0),(41,2.05,0),(61,1.55,0),(79,1.6,0),(97,1.7,.006)]),
      'head_yaw':C([(1,-.35,.012),(24,.1,.018),(45,.7,0),(58,.7,0),(82,-.4,0),(97,-.35,.012)])}

def reset(r):
    r.animation_data.action=None
    for b in r.pose.bones:
        for k,v in IDLE[b.name].items():setattr(b,k,v)

def pose(r,f):
    reset(r);d=design(f);hip=r.pose.bones['Hips']
    hip.rotation_euler=Euler(tuple(math.radians(a) for a in d['pelvis']),'XYZ')
    hip.location=hip.bone.matrix_local.to_3x3().inverted()@(d['hip']-hip.bone.head_local)
    bpy.context.view_layer.update()
    # Idle needs no replant or boot rocking. Compensate existing leg pose channels
    # to retain exactly fixed rigid boots while the hips transfer a little load.
    for side in ['L','R']:r.pose.bones['Leg.'+side].matrix=FEET[side]
    for name,angles in [('Spine',(d['spine'],d['hip'].x*12,d['hip'].x*13)),('Chest',(d['chest'],-d['hip'].x*18,d['hip'].x*16)),('UpperArm.R',(d['arm_r'],0,-d['spread_r'])),('UpperArm.L',(d['arm_l'],0,d['spread_l']))]:
        b=r.pose.bones[name];e=Euler(tuple(math.radians(x) for x in angles),'ZXY' if 'UpperArm' in name else 'XYZ')
        if b.rotation_mode=='QUATERNION':b.rotation_quaternion=e.to_quaternion()
        else:b.rotation_euler=e
    for side in ['L','R']:
        b=r.pose.bones['UpperArm.'+side];b.location+=b.bone.matrix_local.to_3x3().inverted()@Vector((0,0,d['shoulder_'+side.lower()]))
    bpy.context.view_layer.update()
    b=r.pose.bones['Head'];b.matrix=Matrix.Translation(b.head)@Euler((math.radians(d['head_pitch']),0,math.radians(d['head_yaw'])),'XYZ').to_matrix().to_4x4()@b.bone.matrix_local.to_3x3().to_4x4()
    bpy.context.view_layer.update()

def build():
    assert (TMP/'live_before_idle.blend').exists() and 'Idle_Expressive_Test' not in bpy.data.actions
    assert not (OUT/'idle_expressive_review.blend').exists()
    s=bpy.context.scene;r=bpy.data.objects['Showcase_Player_Rig'];m=bpy.data.objects['Showcase_Player_Mesh']
    original={a.name:ui.action_signature(a) for a in bpy.data.actions};reset(r);bpy.context.view_layer.update()
    for side in ['L','R']:
        mat=r.pose.bones['Leg.'+side].matrix.copy();mat.translation.z+=.0004;FEET[side]=mat
    r.name='IE_Test_Rig';m.name='IE_Test_Mesh';s.name='IDLE_EXPRESSIVE_REVIEW'
    if ui.SCENE_TAG in s:del s[ui.SCENE_TAG]
    a=bpy.data.actions.new('Idle_Expressive_Test');a.use_fake_user=True;previous={}
    for j in range(P*8+1):
        f=1+j*STEP;pose(r,f);r.animation_data.action=a
        for b in r.pose.bones:
            prop='rotation_quaternion' if b.rotation_mode=='QUATERNION' else 'rotation_euler'
            if prop=='rotation_quaternion':
                q=b.rotation_quaternion;q.normalize()
                if b.name in previous and q.dot(previous[b.name])<0:q.negate()
                previous[b.name]=q.copy()
            b.keyframe_insert(prop,frame=f,group=b.name);b.keyframe_insert('location',frame=f,group=b.name)
    r.animation_data.action=a;r.animation_data.action_slot=a.slots[0]
    # C1 periodic cubic handles, including exactly identical endpoint slopes.
    for c in ui.curves(a):
        points=c.keyframe_points;vals=[k.co.y for k in points]
        for i,k in enumerate(points):
            slope=(vals[1]-vals[-2])/(2*STEP) if i in [0,len(points)-1] else (vals[i+1]-vals[i-1])/(2*STEP)
            k.interpolation='BEZIER';k.handle_left_type=k.handle_right_type='FREE'
            k.handle_left=(k.co.x-STEP/3,k.co.y-slope*STEP/3);k.handle_right=(k.co.x+STEP/3,k.co.y+slope*STEP/3)
        c.modifiers.new('CYCLES')
    assert all(ui.action_signature(bpy.data.actions[n])==sig for n,sig in original.items())
    s.frame_start=1;s.frame_end=P;s.render.fps=FPS;s.render.fps_base=1;s.timeline_markers.clear()
    for f,label in [(1,'QUIET UNEQUAL READY'),(15,'LIGHT LEFT LOAD / QUIET'),(29,'SMALL CHEST EXPANSION'),(44,'TRAILING ARM RESPONSE'),(54,'RIGHT LOAD / QUIET'),(76,'RELAXED RETURN'),(97,'CLOSING KEY ONLY / NO EXTRA PLAYBACK FRAME')]:s.timeline_markers.new(label,frame=f)
    s.camera=bpy.data.objects['Showcase_THREE_QUARTER'];bpy.data.objects['Showcase_FixedFloor'].location.z=0;r.location=(0,0,0);s.frame_set(1)
    s['purpose']='Pending Expressive Idle / seamless 96-frame loop / closing key97 / fully planted boots / no runtime integration'
    baseline=json.loads((OUT/'old_idle_baseline.json').read_text())
    data={'action':a.name,'status':'pending','playback_frames':[1,P],'closing_key':CLOSE,'fps':FPS,'period_s':P/FPS,'seamless_loop':True,'in_place':True,'original_actions':original,'rig_changes':[],'fixed_foot_matrices':{side:[list(x) for x in mat] for side,mat in FEET.items()},'support':'Both full soles fixed throughout at 0.4 mm review margin; no replant or rocking','old_idle':{k:baseline[k] for k in ['source','source_sha256','action','slot','range','source_fps','period_s']},'scope':'Only relaxed supported unarmed Idle. No Walk, Full Jump changes, Godot edits or approval.'}
    (OUT/'manifest.json').write_text(json.dumps(data,indent=2),encoding='utf8');bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'idle_expressive_review.blend'));print('BUILT NEW IDLE LOOP',flush=True)

if __name__=='__main__':build()
