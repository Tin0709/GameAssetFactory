"""Original contact-driven rigid walk, authored on a copy of approved Idle v3."""
import bpy,sys,json,math,hashlib
from pathlib import Path
from mathutils import Vector,Matrix,Euler
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];TMP=ROOT/'.validation/walk_expressive_test'
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
NAME='Walk_Expressive_Test';P=36;FPS=30;STEP=1/16;SPEED=.9;PERIOD=P/FPS;RATE=SPEED*PERIOD;D=.1125;L=.675;MARGIN=.0004
IDLE=json.loads((OUT.parent/'jump_default_v001/idle_baseline.json').read_text())
def smooth(t):return t*t*t*(10+t*(-15+6*t))
def foot(u,side):
 q=(u+(0 if side=='L' else .5))%1;duty=.60 if side=='L' else .62;a=RATE*duty/2
 if q<=duty:y=-a+RATE*q;lift=0.
 else:
  t=(q-duty)/(1-duty);y=a+RATE*(1-duty)*t-RATE*smooth(t)
  lift=(.072 if side=='L' else .066)*math.sin(math.pi*t)**2
 return q,duty,Vector(((.18 if side=='L' else -.18)+.006,y,0)),lift
def design(u):
 u%=1;w=2*math.pi*u
 # Receiving dips follow contact; longer support and no flight distinguish walk from Run.
 hip=Vector((.006+.038*math.sin(w-.12),-.006,.652+.011*math.cos(2*w-.9)))
 # Let the rigid torso inherit the pelvis instead of cancelling its gait sway.
 # Local Y turns around world vertical; local Z supplies the lateral balance.
 # Delayed, partial upper-body opposition keeps the support rhythm readable.
 return {'hip':hip,'pelvis':(1.5,-3.6*math.cos(w-.08),.4-2.6*math.sin(w-.12)),
 'spine':(1.8+.4*math.cos(2*w-1.1),1.4*math.cos(w-.25),.65*math.sin(w-.3)),
 'chest':(1.3+.55*math.cos(2*w-1.3),.6*math.cos(w-.35),.25*math.sin(w-.45)),
 'head':(1.4+.38*math.cos(2*w-1.55),.2+.3*math.sin(w-.5),.65*math.cos(w-.55))}
def sole_matrix(pb,socket,base,lift,side):
 yaw=math.radians(5 if side=='L' else -5);lean=math.radians(-2 if side=='L' else 3.5)
 yaw_matrix=Matrix.Rotation(yaw,3,'Z')
 def calc(pitch):
  rot=yaw_matrix@Matrix.Rotation(lean,3,'Y')@Matrix.Rotation(pitch,3,'X')
  corner=Vector((-D if rot[2][0]>0 else D,-D if rot[2][1]>0 else D,0))
  sole=base+yaw_matrix@corner-rot@corner;sole.z=MARGIN+lift-(rot@corner).z
  top=sole+rot@Vector((0,0,L))
  return rot,top
 low,high=-math.radians(55),math.radians(55)
 for _ in range(35):
  mid=(low+high)/2;rot,top=calc(mid)
  if top.y>socket.y:low=mid
  else:high=mid
 pitch=(low+high)/2
 # Ease the entire rigid leg through flat: a gentle receiving/pass passage,
 # not a cusp where the lowest sole edge switches and Bezier baking lifts it.
 pitch*=1-math.exp(-(pitch/math.radians(6))**2)
 rot,top=calc(pitch)
 mat=(rot@pb.bone.matrix_local.to_3x3()).to_4x4();mat.translation=top
 return mat
def pose(r,u):
 r.animation_data.action=None
 for b in r.pose.bones:
  for key,value in IDLE[b.name].items():setattr(b,key,value)
 d=design(u);h=r.pose.bones['Hips'];h.rotation_euler=Euler(tuple(math.radians(x) for x in d['pelvis']),'XYZ')
 h.location=h.bone.matrix_local.to_3x3().inverted()@(d['hip']-h.bone.head_local)
 bpy.context.view_layer.update()
 for side in ['L','R']:
  pb=r.pose.bones['Leg.'+side];socket=h.matrix@(h.bone.matrix_local.inverted()@pb.bone.head_local)
  q,duty,base,lift=foot(u,side);pb.matrix=sole_matrix(pb,socket,base,lift,side)
 for name,key in [('Spine','spine'),('Chest','chest')]:
  b=r.pose.bones[name];e=Euler(tuple(math.radians(x) for x in d[key]),'XYZ')
  if b.rotation_mode=='QUATERNION':b.rotation_quaternion=e.to_quaternion()
  else:b.rotation_euler=e
 w=2*math.pi*(u%1)
 for side,lag,amplitude,rest,spread in [('L',.20,20,3,12),('R',.27,22,-3,13)]:
  phase=w+(0 if side=='L' else math.pi)-lag
  pitch=rest-amplitude*math.cos(phase)
  openness=spread+2*(.5+.5*math.cos(phase))
  b=r.pose.bones['UpperArm.'+side];b.rotation_quaternion=Euler((math.radians(pitch),0,math.radians(openness*(1 if side=='L' else -1))),'ZXY').to_quaternion()
  # Existing full arms stay straight, with restrained delayed shoulder life.
  b.location+=b.bone.matrix_local.to_3x3().inverted()@Vector((.005 if side=='L' else -.005,0,-(.010 if side=='L' else .008)+.0015*math.cos(2*phase-.3)))
 bpy.context.view_layer.update()
 b=r.pose.bones['Head'];b.matrix=Matrix.Translation(b.head)@Euler(tuple(math.radians(x) for x in d['head']),'XYZ').to_matrix().to_4x4()@b.bone.matrix_local.to_3x3().to_4x4()
 bpy.context.view_layer.update()
def build():
 destination=OUT/'walk_expressive_review.blend';assert not destination.exists() and NAME not in bpy.data.actions
 baseline=json.loads((TMP/'baseline.json').read_text())
 assert hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest()==baseline['approved_idle_source_sha256']
 s=bpy.context.scene;r=bpy.data.objects['IEV3_Test_Rig'];m=bpy.data.objects['IEV3_Test_Mesh']
 original={a.name:ui.action_signature(a) for a in bpy.data.actions};assert len(original)==11
 r.name='WEX_Test_Rig';r.data.name='WEX_Test_RestRig';m.name='WEX_Test_Mesh';s.name='WALK_EXPRESSIVE_REVIEW'
 a=bpy.data.actions.new(NAME);a.use_fake_user=True;r.animation_data_create();r.animation_data.action=a;previous={}
 for j in range(P*16+1):
  f=1+j*STEP;pose(r,(f-1)/P);r.animation_data.action=a
  for b in r.pose.bones:
   prop='rotation_quaternion' if b.rotation_mode=='QUATERNION' else 'rotation_euler'
   if prop=='rotation_quaternion':
    q=b.rotation_quaternion;q.normalize()
    if b.name in previous and q.dot(previous[b.name])<0:q.negate()
    previous[b.name]=q.copy()
   b.keyframe_insert(prop,frame=f,group=b.name);b.keyframe_insert('location',frame=f,group=b.name)
 for c in ui.curves(a):
  keys=c.keyframe_points;values=[k.co.y for k in keys];count=len(keys)-1
  for i,k in enumerate(keys):
   slope=(values[(i+1)%count]-values[(i-1)%count])/(2*STEP)
   k.interpolation='BEZIER';k.handle_left_type=k.handle_right_type='FREE'
   k.handle_left=(k.co.x-STEP/3,k.co.y-slope*STEP/3);k.handle_right=(k.co.x+STEP/3,k.co.y+slope*STEP/3)
  c.modifiers.new('CYCLES')
 r.animation_data.action=a;r.animation_data.action_slot=a.slots[0]
 assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in original.items())
 s.frame_start=1;s.frame_end=P;s.render.fps=FPS;s.render.fps_base=1;s.timeline_markers.clear()
 for f,label in [(1,'LEFT CONTACT / RIGHT SUPPORT'),(5,'RECEIVE'),(10,'LEFT SUPPORT / RIGHT PASSING'),(19,'RIGHT CONTACT / LEFT SUPPORT'),(23,'RECEIVE'),(28,'RIGHT SUPPORT / LEFT PASSING'),(37,'CLOSING KEY / EXCLUDED')]:s.timeline_markers.new(label,frame=f)
 s.camera=bpy.data.objects['Showcase_THREE_QUARTER'];s.frame_set(1)
 s['purpose']='Pending expressive walk / in-place / approved Idle v3 posture anchor / no gameplay integration'
 s['diagnostic_travel_speed_m_s']=SPEED
 data={'action':NAME,'status':'pending','playback_frames':[1,P],'closing_key':P+1,'fps':FPS,'period_s':PERIOD,'seamless_loop':True,'nominal_speed_m_s':SPEED,'support_duty':{'L':.60,'R':.62},'contact_frames':{'L':1,'R':19},'original_actions':original,'rig_changes':[],'approved_idle_source_sha256':baseline['approved_idle_source_sha256'],'motion_ownership':'Root/object identity. Controller owns forward -Y travel; stance sole anchors move backward +Y at0.9m/s. Review travel is temporary presentation only.','stance':'Approved Idle v3 upper-body posture, straight full arms and support-led balance. Dynamic walking tracks0.36m apart,5deg toe-out; idle0.40m/15deg stance must replant into these tracks at start/stop.','layering':'Full-body absolute baked Action, not additive. Future weapon masks must coordinate Chest/shoulders without replacing hips/legs.','transition_contract':'Loop begins left receiving contact while right remains in support; opposite contactF19. Preserve phase for future Walk/Run. Idle v3 fixed support cannot safely transition by generic crossfade; separately author/test start/stop or support-aware replants. No runtime readiness claim.'}
 (OUT/'manifest.json').write_text(json.dumps(data,indent=2));bpy.ops.wm.save_as_mainfile(filepath=str(destination))
 print('BUILT WALK / PRESERVED ELEVEN ACTIONS',flush=True)
if __name__=='__main__':build()
