"""Separate asymmetric-support Idle study; original ten Actions untouched."""
import bpy,json,sys,math
from pathlib import Path
from mathutils import Vector,Matrix,Euler
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4]
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
P=240;CLOSE=P+1;FPS=30;STEP=.125;NAME='Idle_Expressive_Test_v3'
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

def attention_window(f,start,arrive,observe,settled):
    # User requests 2X gesture speed; preserve the eight-second loop and quiet rests.
    anchor=25 if start<125 else 125
    offset=-30.25 if start>=125 else 0
    # Center head-neutral interval:60.5 ->30.25frames; retain turn durations and breathing.
    return window(f,*[anchor+(x-anchor)*.5+offset for x in (start,arrive,observe,settled)])

def inherited_design(f):
    # Separate interests, unequal pauses; center rest interrupts any scanning rhythm.
    left=attention_window(f,25,49,75,104);right=attention_window(f,125,146,164,194)
    body_l=attention_window(f,32,58,81,112);body_r=attention_window(f,131,154,171,205)
    hip_l=attention_window(f,38,65,84,117);hip_r=attention_window(f,137,161,175,211)
    arm_l=attention_window(f,40,67,87,120);arm_r=attention_window(f,43,71,89,123)
    arm2_l=attention_window(f,140,166,178,218);arm2_r=attention_window(f,137,163,176,214)
    clear_l=attention_window(f,27,50,77,107);clear_r=attention_window(f,126,148,166,198)
    # Two quiet breaths, independent of attention timing; no hip bob or inflation.
    breath=.5-.5*math.cos(2*math.pi*(f-1)/120)
    shoulder_b=.5-.5*math.cos(2*math.pi*(f-6)/120)
    head_b=.5-.5*math.cos(2*math.pi*(f-10)/120)
    return {'hip':Vector((-.002+.011*hip_l-.010*hip_r,-.001+.001*hip_l-.0005*hip_r,.6716)),
      'pelvis':(1.1+.4*breath,1.0*hip_l-.9*hip_r,.1-.28*hip_l+.24*hip_r),
      'spine':1.25+.92*breath,'spine_yaw':2.4*body_l-2.1*body_r,
      'chest':.8+1.68*breath,'chest_yaw':7*body_l-6.2*body_r,'chest_lift':.0072*breath,
      'arm_r':-5.8+5*arm_r-4*arm2_r+16*clear_r,
      'arm_l':5.2-4.4*arm_l+4*arm2_l-16*clear_l,
      'spread_r':11.8+2.6*arm_r+1.4*arm2_r,'spread_l':10.8+1.6*arm_l+2.4*arm2_l,
      'shoulder_r':.0028*shoulder_b-.035*left-.028*right-.012*arm2_r,
      'shoulder_l':.0024*shoulder_b-.028*left-.035*right,
      'head_pitch':1.4-1.8*left+2.5*right+.72*head_b,
      'head_yaw':-.3+52*left-46*right,'head_roll':-1.3*left+1.1*right}

def design(f):
    d=inherited_design(f)
    # Maintain the same quiet performance on a single, persistent support bias.
    # Positive X (Leg.L) supports; final requested review adds slight left-forward/right-back and 15deg toe-out.
    d['hip'].x=.028+.45*(d['hip'].x+.002)
    d['hip'].y=-.006+.5*(d['hip'].y+.001)
    d['hip'].z+=.024*(.5-.5*math.cos(2*math.pi*(f-1)/120))
    d['pelvis']=(d['pelvis'][0],d['pelvis'][1]+.4,d['pelvis'][2]+.55)
    d['spread_l']+=.6
    d['spread_r']+=.5
    d['arm_l']-=.7
    d['head_roll']+=.35
    return d


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
    angles=[('Spine',(d['spine'],d['spine_yaw'],-.40+.5*d['spine_yaw']/1.6)),('Chest',(d['chest'],d['chest_yaw'],-.25+d['chest_yaw']/4.2)),('UpperArm.R',(d['arm_r'],0,-d['spread_r'])),('UpperArm.L',(d['arm_l'],0,d['spread_l']))]
    for name,xyz in angles:
        b=r.pose.bones[name];e=Euler(tuple(math.radians(x) for x in xyz),'ZXY' if 'UpperArm' in name else 'XYZ')
        if b.rotation_mode=='QUATERNION':b.rotation_quaternion=e.to_quaternion()
        else:b.rotation_euler=e
    # Convert a tiny vertical chest offset into its parent pose coordinates.
    b=r.pose.bones['Chest'];bpy.context.view_layer.update()
    mat=b.matrix.copy();mat.translation.z+=d['chest_lift'];b.matrix=mat
    for side in ['L','R']:
        # Small resting clearance keeps the stronger breath from touching the head on return.
        b=r.pose.bones['UpperArm.'+side];b.location+=b.bone.matrix_local.to_3x3().inverted()@Vector((-.0045 if side=='R' else 0,0,d['shoulder_'+side.lower()]))
    bpy.context.view_layer.update()
    b=r.pose.bones['Head'];b.matrix=Matrix.Translation(b.head)@Euler((math.radians(d['head_pitch']),math.radians(d['head_roll']),math.radians(d['head_yaw'])),'XYZ').to_matrix().to_4x4()@b.bone.matrix_local.to_3x3().to_4x4()
    bpy.context.view_layer.update()

def build():
    assert NAME not in bpy.data.actions and not (OUT/'idle_expressive_v3_review.blend').exists()
    s=bpy.context.scene;r=bpy.data.objects['IEV2_Test_Rig'];m=bpy.data.objects['IEV2_Test_Mesh']
    original={a.name:ui.action_signature(a) for a in bpy.data.actions};assert len(original)==10
    reset(r);bpy.context.view_layer.update()
    # Twenty-five millimetres extra clearance per hip prevents the yawed solid blocks intersecting.
    placements={'L':{'top':(.1575,0,.675),'yaw':15.0,'pitch':-3.75,'lean':-3.0},'R':{'top':(-.1175,0,.675),'yaw':-15.0,'pitch':3.75,'lean':8.0}}
    # Keep sideways opening primary; latest explicit user instruction adds a small opposed fore/aft angle and 15deg toe-out.
    # Character LEFT is forward, RIGHT back. No invented ankle/knee or animated foot pivot; fixed lowest corner contacts.
    for side,d in placements.items():
        b=r.pose.bones['Leg.'+side];rest=b.bone.matrix_local
        rot=Matrix.Rotation(math.radians(d['yaw']),4,'Z')@Matrix.Rotation(math.radians(d['lean']),4,'Y')@Matrix.Rotation(math.radians(d['pitch']),4,'X')
        ids=[v.index for v in m.data.vertices if any(g.group==m.vertex_groups[b.name].index and g.weight>.99 for g in v.groups)]
        transform=Matrix.Translation(Vector(d['top']))@rot@Matrix.Translation(-b.bone.head_local)
        z=min((transform@m.data.vertices[i].co).z for i in ids)
        transform.translation.z+=.0004-z
        FEET[side]=transform@rest
    r.name='IEV3_Test_Rig';m.name='IEV3_Test_Mesh';s.name='IDLE_EXPRESSIVE_V3_REVIEW'
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
    for f,label in [(1,'ASYMMETRIC SUPPORTED REST'),(25,'FIRST HEAD-LED LOOK'),(37,'OBSERVE / BODY FOLLOWS'),(65,'RETURN / REST'),(95,'SECOND INTEREST'),(106,'SHORTER LOWER LOOK'),(130,'HEAD RETURNS'),(142,'SETTLED REST'),(241,'CLOSING KEY / EXCLUDED')]:s.timeline_markers.new(label,frame=f)
    s.camera=bpy.data.objects['Showcase_THREE_QUARTER'];bpy.data.objects['Showcase_FixedFloor'].location.z=0;r.location=(0,0,0);s.frame_set(1)
    s['purpose']='Pending v3 / asymmetric support Idle / two-sided curious head / transform-only breath / no gameplay integration'
    data={'action':NAME,'status':'pending','playback_frames':[1,P],'closing_key':CLOSE,'fps':FPS,'period_s':P/FPS,'seamless_loop':True,'in_place':True,'original_actions':original,'rig_changes':[],'fixed_foot_matrices':{side:[list(x) for x in mat] for side,mat in FEET.items()},'stance_placements':placements,'support_leg':'Leg.L / character left / lateral3deg, forward3.75deg, outward yaw15deg / fixed lowest corner','relaxed_leg':'Leg.R / character right / lateral8deg, backward3.75deg, outward yaw15deg / fixed lowest corner','support_logic':'Pelvis positive-X bias28mm; unequal sideways opening remains primary; latest user asks slight character-left forward/right backward and requested15deg toe-out. Static leg matrices; no rig edits','breathing':'Latest user request:4X original amplitude (double previous2X),24mm hips +7.2mm rigid chest lift; doubled breath-only shoulder/head/torso terms. Same4second timing; fixed feet, no scale','lookaround':'2X head/arm attention amplitude with delayed torso/shoulder support; 2X gesture speed around F25/F125. Rest gaps retained; breathing timing/amplitude and planted legs unchanged','center_pause':'Latest user correction:head-neutral middle interval halved60.5->30.25frames (2.0167->1.0083s). Second attention group shifted30.25frames earlier; first look, gesture range/duration, breathing, leg matrices and8s loop unchanged. Quiet seam rest retained','face_controls':'No facial bones or shape keys; head articulation only','scope':'Current v3 stance/breath review checkpoint; preserve v2/v1 and all other studies; no Godot edits/export.'}
    (OUT/'manifest.json').write_text(json.dumps(data,indent=2),encoding='utf8')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'idle_expressive_v3_review.blend'));print('BUILT SEPARATE V3 IDLE',flush=True)
if __name__=='__main__':build()
