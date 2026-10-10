"""A quiet supported Idle; no rig changes, world travel or old Action edits."""
import bpy,json,sys,math
from pathlib import Path
from mathutils import Vector,Matrix,Euler
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];TMP=ROOT/'.validation/idle_expressive_test'
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
P=144;CLOSE=P+1;FPS=30;STEP=.125
CANDIDATE='candidate' in sys.argv
SOURCE='idle_expressive_lookaround_candidate.blend' if CANDIDATE else 'idle_expressive_review.blend'
MANIFEST='lookaround_manifest.json' if CANDIDATE else 'manifest.json'
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
    # One purposeful head-led observation, not an alternating head-shake cycle.
    C=lambda k:channel(f,k)
    head=C([(1,0,0),(22,0,0),(37,1,0),(62,1,0),(72,.96,-.006),(101,0,0),(145,0,0)])
    follow=C([(1,0,0),(27,0,0),(46,1,0),(69,1,0),(109,0,0),(145,0,0)])
    hip_follow=C([(1,0,0),(31,0,0),(52,1,0),(75,1,0),(116,0,0),(145,0,0)])
    arm_r=C([(1,0,0),(32,0,0),(54,1,0),(77,.94,-.008),(120,0,0),(145,0,0)])
    arm_l=C([(1,0,0),(35,0,0),(59,1,0),(80,.9,-.012),(124,0,0),(145,0,0)])
    arm_clear=C([(1,0,0),(24,0,0),(39,1,0),(70,1,0),(111,0,0),(145,0,0)])
    breath=C([(1,.15,0),(18,.15,0),(48,1,0),(68,.85,-.01),(102,0,0),(123,0,0),(145,.15,0)])
    return {'hip':Vector((-.003+.013*hip_follow,-.001+.0015*hip_follow,.6715+.0013*breath-.0006*hip_follow)),
      'pelvis':(1.1+.15*breath,1.2*hip_follow,.1-.35*hip_follow),
      'spine':1.3+.25*breath,'spine_yaw':1.6*follow,'chest':1+.55*breath,'chest_yaw':4.2*follow,
      'arm_r':-5.8+2.8*arm_r,'arm_l':5.2-2.4*arm_l-8*arm_clear,
      'spread_r':13.5+1.5*arm_r,'spread_l':12.0+.9*arm_l,
      'shoulder_r':.0002+.0008*arm_r-.0175*head,'shoulder_l':.0001+.0005*arm_l-.014*head,
      'head_pitch':1.5-1.8*head,'head_yaw':-.3+27*head,'head_roll':-.5*head}

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
    for name,angles in [('Spine',(d['spine'],d['spine_yaw'],d['hip'].x*13+.5*d['spine_yaw']/1.6)),('Chest',(d['chest'],d['chest_yaw'],d['hip'].x*16+d['chest_yaw']/4.2)),('UpperArm.R',(d['arm_r'],0,-d['spread_r'])),('UpperArm.L',(d['arm_l'],0,d['spread_l']))]:
        b=r.pose.bones[name];e=Euler(tuple(math.radians(x) for x in angles),'ZXY' if 'UpperArm' in name else 'XYZ')
        if b.rotation_mode=='QUATERNION':b.rotation_quaternion=e.to_quaternion()
        else:b.rotation_euler=e
    for side in ['L','R']:
        b=r.pose.bones['UpperArm.'+side];b.location+=b.bone.matrix_local.to_3x3().inverted()@Vector((0,0,d['shoulder_'+side.lower()]))
    bpy.context.view_layer.update()
    b=r.pose.bones['Head'];b.matrix=Matrix.Translation(b.head)@Euler((math.radians(d['head_pitch']),math.radians(d['head_roll']),math.radians(d['head_yaw'])),'XYZ').to_matrix().to_4x4()@b.bone.matrix_local.to_3x3().to_4x4()
    bpy.context.view_layer.update()

def build():
    assert (TMP/'live_before_idle.blend').exists() and 'Idle_Expressive_Test' not in bpy.data.actions
    assert not (OUT/SOURCE).exists()
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
    for f,label in [(1,'RELAXED REST'),(22,'HEAD LEADS ATTENTION'),(37,'CURIOUS GLANCE'),(52,'HIPS / SHOULDERS FOLLOW'),(62,'OBSERVING PAUSE'),(72,'HEAD RETURNS FIRST'),(109,'TORSO SETTLES'),(124,'ARMS SETTLE / REST'),(145,'CLOSING KEY ONLY / EXCLUDED')]:s.timeline_markers.new(label,frame=f)
    s.camera=bpy.data.objects['Showcase_THREE_QUARTER'];bpy.data.objects['Showcase_FixedFloor'].location.z=0;r.location=(0,0,0);s.frame_set(1)
    s['purpose']='Pending Expressive Idle / seamless 144-frame loop / closing key145 / fully planted boots / no runtime integration'
    baseline=json.loads((OUT/'old_idle_baseline.json').read_text())
    data={'action':a.name,'status':'pending','playback_frames':[1,P],'closing_key':CLOSE,'fps':FPS,'period_s':P/FPS,'seamless_loop':True,'in_place':True,'original_actions':original,'rig_changes':[],'fixed_foot_matrices':{side:[list(x) for x in mat] for side,mat in FEET.items()},'support':'Both full soles fixed throughout at 0.4 mm review margin; no replant or rocking','old_idle':{k:baseline[k] for k in ['source','source_sha256','action','slot','range','source_fps','period_s']},'scope':'User-requested purposeful LookAround in same pending supported unarmed Idle. No Walk, Full Jump changes, Godot edits or approval.'}
    (OUT/MANIFEST).write_text(json.dumps(data,indent=2),encoding='utf8');bpy.ops.wm.save_as_mainfile(filepath=str(OUT/SOURCE));print('BUILT NEW IDLE LOOP',flush=True)

if __name__=='__main__':build()
