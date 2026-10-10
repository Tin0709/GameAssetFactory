"""Separate supported two-sided Idle study; original nine Actions untouched."""
import bpy,json,sys,math
from pathlib import Path
from mathutils import Vector,Matrix,Euler
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4]
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
P=240;CLOSE=P+1;FPS=30;STEP=.125;NAME='Idle_Expressive_Test_v2'
IDLE=json.loads((OUT.parent/'jump_default_v001/idle_baseline.json').read_text());FEET={}

def channel(f,keys):
    f=1+(f-1)%P
    for (fa,a,da),(fb,b,db) in zip(keys,keys[1:]):
        if fa<=f<=fb:
            t=(f-fa)/(fb-fa);h=fb-fa
            return (2*t**3-3*t*t+1)*a+(t**3-2*t*t+t)*h*da+(-2*t**3+3*t*t)*b+(t**3-t*t)*h*db
    raise ValueError(f)

def window(f,start,arrive,observe,settled):
    return channel(f,[(1,0,0),(start,0,0),(arrive,1,0),(observe,1,0),(settled,0,0),(CLOSE,0,0)])

def design(f):
    # Separate interests, unequal pauses; center rest interrupts any scanning rhythm.
    left=window(f,25,49,75,104);right=window(f,125,146,164,194)
    body_l=window(f,32,58,81,112);body_r=window(f,131,154,171,205)
    hip_l=window(f,38,65,84,117);hip_r=window(f,137,161,175,211)
    arm_l=window(f,40,67,87,120);arm_r=window(f,43,71,89,123)
    arm2_l=window(f,140,166,178,218);arm2_r=window(f,137,163,176,214)
    clear_l=window(f,27,50,77,107);clear_r=window(f,126,148,166,198)
    # Two quiet breaths, independent of attention timing; no hip bob or inflation.
    breath=.5-.5*math.cos(2*math.pi*(f-1)/120)
    shoulder_b=.5-.5*math.cos(2*math.pi*(f-6)/120)
    head_b=.5-.5*math.cos(2*math.pi*(f-10)/120)
    return {'hip':Vector((-.002+.011*hip_l-.010*hip_r,-.001+.001*hip_l-.0005*hip_r,.6716)),
      'pelvis':(1.1+.1*breath,1.0*hip_l-.9*hip_r,.1-.28*hip_l+.24*hip_r),
      'spine':1.25+.23*breath,'spine_yaw':1.2*body_l-1.05*body_r,
      'chest':.8+.42*breath,'chest_yaw':3.5*body_l-3.1*body_r,'chest_lift':.0018*breath,
      'arm_r':-5.8+2.5*arm_r-2.0*arm2_r+8*clear_r,
      'arm_l':5.2-2.2*arm_l+2.0*arm2_l-8*clear_l,
      'spread_r':11.8+1.3*arm_r+.7*arm2_r,'spread_l':10.8+.8*arm_l+1.2*arm2_l,
      'shoulder_r':.0007*shoulder_b-.0175*left-.014*right-.006*arm2_r,
      'shoulder_l':.0006*shoulder_b-.014*left-.0175*right,
      'head_pitch':1.4-.9*left+1.25*right+.18*head_b,
      'head_yaw':-.3+26*left-23*right,'head_roll':-.65*left+.55*right}

def reset(r):
    r.animation_data.action=None
    for b in r.pose.bones:
        for k,v in IDLE[b.name].items():setattr(b,k,v)

def pose(r,f):
    reset(r);d=design(f);hip=r.pose.bones['Hips']
    hip.rotation_euler=Euler(tuple(math.radians(a) for a in d['pelvis']),'XYZ')
    hip.location=hip.bone.matrix_local.to_3x3().inverted()@(d['hip']-hip.bone.head_local)
    bpy.context.view_layer.update()
    for side in ['L','R']:r.pose.bones['Leg.'+side].matrix=FEET[side]
    angles=[('Spine',(d['spine'],d['spine_yaw'],d['hip'].x*13+.5*d['spine_yaw']/1.6)),('Chest',(d['chest'],d['chest_yaw'],d['hip'].x*16+d['chest_yaw']/4.2)),('UpperArm.R',(d['arm_r'],0,-d['spread_r'])),('UpperArm.L',(d['arm_l'],0,d['spread_l']))]
    for name,xyz in angles:
        b=r.pose.bones[name];e=Euler(tuple(math.radians(x) for x in xyz),'ZXY' if 'UpperArm' in name else 'XYZ')
        if b.rotation_mode=='QUATERNION':b.rotation_quaternion=e.to_quaternion()
        else:b.rotation_euler=e
    # Convert a tiny vertical chest offset into its parent pose coordinates.
    b=r.pose.bones['Chest'];bpy.context.view_layer.update()
    mat=b.matrix.copy();mat.translation.z+=d['chest_lift'];b.matrix=mat
    for side in ['L','R']:
        b=r.pose.bones['UpperArm.'+side];b.location+=b.bone.matrix_local.to_3x3().inverted()@Vector((0,0,d['shoulder_'+side.lower()]))
    bpy.context.view_layer.update()
    b=r.pose.bones['Head'];b.matrix=Matrix.Translation(b.head)@Euler((math.radians(d['head_pitch']),math.radians(d['head_roll']),math.radians(d['head_yaw'])),'XYZ').to_matrix().to_4x4()@b.bone.matrix_local.to_3x3().to_4x4()
    bpy.context.view_layer.update()

def build():
    assert NAME not in bpy.data.actions and not (OUT/'idle_expressive_v2_review.blend').exists()
    s=bpy.context.scene;r=bpy.data.objects['IE_Test_Rig'];m=bpy.data.objects['IE_Test_Mesh']
    original={a.name:ui.action_signature(a) for a in bpy.data.actions};assert len(original)==9
    reset(r);bpy.context.view_layer.update()
    for side in ['L','R']:
        mat=r.pose.bones['Leg.'+side].matrix.copy();mat.translation.z+=.0004
        mat.translation.x+=.028 if side=='L' else -.028;FEET[side]=mat
    r.name='IEV2_Test_Rig';m.name='IEV2_Test_Mesh';s.name='IDLE_EXPRESSIVE_V2_REVIEW'
    if ui.SCENE_TAG in s:del s[ui.SCENE_TAG]
    a=bpy.data.actions.new(NAME);a.use_fake_user=True;previous={}
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
    for c in ui.curves(a):
        points=c.keyframe_points;vals=[k.co.y for k in points]
        for i,k in enumerate(points):
            slope=(vals[1]-vals[-2])/(2*STEP) if i in [0,len(points)-1] else (vals[i+1]-vals[i-1])/(2*STEP)
            k.interpolation='BEZIER';k.handle_left_type=k.handle_right_type='FREE'
            k.handle_left=(k.co.x-STEP/3,k.co.y-slope*STEP/3);k.handle_right=(k.co.x+STEP/3,k.co.y+slope*STEP/3)
        c.modifiers.new('CYCLES')
    assert all(ui.action_signature(bpy.data.actions[n])==sig for n,sig in original.items())
    s.frame_start=1;s.frame_end=P;s.render.fps=FPS;s.render.fps_base=1;s.timeline_markers.clear()
    for f,label in [(1,'RELAXED WIDE REST'),(25,'FIRST HEAD-LED LOOK'),(49,'OBSERVE / BODY FOLLOWS'),(76,'RETURN / REST'),(125,'SECOND INTEREST'),(146,'SHORTER LOWER LOOK'),(165,'HEAD RETURNS'),(218,'SETTLED REST'),(241,'CLOSING KEY / EXCLUDED')]:s.timeline_markers.new(label,frame=f)
    s.camera=bpy.data.objects['Showcase_THREE_QUARTER'];bpy.data.objects['Showcase_FixedFloor'].location.z=0;r.location=(0,0,0);s.frame_set(1)
    s['purpose']='Pending v2 / two-sided curious Idle / wider planted feet / transform-only breath / no gameplay integration'
    data={'action':NAME,'status':'pending','playback_frames':[1,P],'closing_key':CLOSE,'fps':FPS,'period_s':P/FPS,'seamless_loop':True,'in_place':True,'original_actions':original,'rig_changes':[],'fixed_foot_matrices':{side:[list(x) for x in mat] for side,mat in FEET.items()},'stance_each_foot_outward_m':.028,'breathing':'Independent 4-second tiny rigid chest/shoulder/head transform cycle; no pelvis bob or scaling','face_controls':'No facial bones or shape keys; head articulation only','scope':'Separate v2; preserve all current Idle and other studies, no Godot edits/export.'}
    (OUT/'manifest.json').write_text(json.dumps(data,indent=2),encoding='utf8')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'idle_expressive_v2_review.blend'));print('BUILT SEPARATE V2 IDLE',flush=True)
if __name__=='__main__':build()
