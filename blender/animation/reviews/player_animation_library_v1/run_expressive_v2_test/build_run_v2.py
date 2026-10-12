"""Separate support-led rigid Run v2, authored on a copy of approved refined Walk."""
import bpy,sys,json,math,hashlib
from pathlib import Path
from mathutils import Vector,Matrix,Euler
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];TMP=ROOT/'.validation/run_expressive_v2_test'
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
NAME='Run_Expressive_v2_Test';P=22;FPS=30;STEP=1/16;SPEED=2.1;PERIOD=P/FPS;RATE=SPEED*PERIOD;D=.1125;L=.675;MARGIN=.0004
IDLE=json.loads((OUT.parent/'jump_default_v001/idle_baseline.json').read_text())
def smooth(t):return t*t*t*(10+t*(-15+6*t))
def hermite(t,a,b,va,vb):
 return (2*t**3-3*t*t+1)*a+(t**3-2*t*t+t)*va+(-2*t**3+3*t*t)*b+(t**3-t*t)*vb
def height(u):
 q=u%.5;keys=[(0,.656,-.45),(.075,.632,0),(.23,.648,.16),(.42,.669,.13),(.46,.675,0),(.5,.656,-.45)]
 for (ta,a,va),(tb,b,vb) in zip(keys,keys[1:]):
  if ta<=q<=tb:return hermite((q-ta)/(tb-ta),a,b,va*(tb-ta),vb*(tb-ta))
 return .656
def foot(u,side):
 q=(u+(0 if side=='L' else .5))%1;duty=.42 if side=='L' else .43;a=RATE*duty/2
 if q<=duty:y=-a+RATE*q;lift=0.
 else:
  t=(q-duty)/(1-duty);y=a+RATE*(1-duty)*t-RATE*smooth(t)+.18*math.sin(2*math.pi*t)*math.sin(math.pi*t)**2
  lift=(.150 if side=='L' else .140)*math.sin(math.pi*t)**2
 return q,duty,Vector(((.135 if side=='L' else -.135)+.006,y,0)),lift
def design(u):
 u%=1;w=2*math.pi*u
 hip=Vector((.006+.013*math.sin(w-.12),-.006+.025*math.sin(2*w-.35),height(u)))
 return {'hip':hip,'pelvis':(3.0,-4.8*math.cos(w-.06),.3-1.1*math.sin(w-.12)),
 'spine':(3.0+.65*math.cos(2*w-1.1),2.3*math.cos(w-.22),.30*math.sin(w-.3)),
 'chest':(2.4+.80*math.cos(2*w-1.3),1.2*math.cos(w-.36),.15*math.sin(w-.45)),
 'head':(3.2+.55*math.cos(2*w-1.55),.15+.35*math.sin(w-.5),.75*math.cos(w-.55))}

def sole_matrix(pb,socket,base,lift,side,release,hip_z):
 yaw=math.radians(3 if side=='L' else -5);lean=math.radians(-.15 if side=='L' else .2)
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
 # Unloaded whole leg stays attached to the existing hip overlap; ground
 # anchors stay untouched during support. Smooth gates preserve release/contact.
 if release>0:
  gate=smooth(min(1,release/.045))*smooth(min(1,(1-release)/.045))
  top.z+=max(0,hip_z-.020-top.z)*gate
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
  q,duty,base,lift=foot(u,side);pb.matrix=sole_matrix(pb,socket,base,lift,side,(q-duty)/(1-duty) if q>duty else 0,d['hip'].z)
 for name,key in [('Spine','spine'),('Chest','chest')]:
  b=r.pose.bones[name];e=Euler(tuple(math.radians(x) for x in d[key]),'XYZ')
  if b.rotation_mode=='QUATERNION':b.rotation_quaternion=e.to_quaternion()
  else:b.rotation_euler=e
 w=2*math.pi*(u%1)
 for side,lag,amplitude,rest,spread in [('L',.16,39,4,14),('R',.21,42,-2,16)]:
  phase=w+(0 if side=='L' else math.pi)-lag
  pitch=rest-amplitude*math.cos(phase)
  openness=spread+6*(.5+.5*math.cos(phase))
  b=r.pose.bones['UpperArm.'+side];b.rotation_quaternion=Euler((math.radians(pitch),0,math.radians(openness*(1 if side=='L' else -1))),'ZXY').to_quaternion()
  # Existing full arms stay straight, with restrained delayed shoulder life.
  b.location+=b.bone.matrix_local.to_3x3().inverted()@Vector((.005 if side=='L' else -.005,0,-(.010 if side=='L' else .008)+.0015*math.cos(2*phase-.3)))
 bpy.context.view_layer.update()
 b=r.pose.bones['Head'];b.matrix=Matrix.Translation(b.head)@Euler(tuple(math.radians(x) for x in d['head']),'XYZ').to_matrix().to_4x4()@b.bone.matrix_local.to_3x3().to_4x4()
 bpy.context.view_layer.update()
def build():
 destination=OUT/'run_expressive_v2_review.blend';assert not destination.exists() and NAME not in bpy.data.actions
 baseline=json.loads((TMP/'baseline.json').read_text())
 assert hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest()==baseline['approved_walk_source_sha256']
 s=bpy.context.scene;r=bpy.data.objects['WEX_Test_Rig'];m=bpy.data.objects['WEX_Test_Mesh']
 original={a.name:ui.action_signature(a) for a in bpy.data.actions};assert len(original)==12
 r.name='RN2_Test_Rig';r.data.name='RN2_Test_RestRig';m.name='RN2_Test_Mesh';s.name='RUN_EXPRESSIVE_V2_REVIEW'
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
 for f,label in [(1,'LEFT RECEIVING CONTACT'),(3,'LEFT LOAD'),(6,'LEFT SUPPORT / RECOVERY'),(10,'LEFT RELEASE'),(11,'BRIEF FLIGHT'),(12,'RIGHT RECEIVING CONTACT'),(14,'RIGHT LOAD'),(17,'RIGHT SUPPORT / RECOVERY'),(21,'RIGHT RELEASE'),(22,'BRIEF FLIGHT'),(23,'CLOSING KEY / EXCLUDED')]:s.timeline_markers.new(label,frame=f)
 s.camera=bpy.data.objects['Showcase_THREE_QUARTER'];s.frame_set(1)
 s['purpose']='Pending expressive Run v2 / approved Walk progression / no gameplay integration'
 s['diagnostic_travel_speed_m_s']=SPEED
 data={'action':NAME,'status':'pending','playback_frames':[1,P],'closing_key':P+1,'fps':FPS,'period_s':PERIOD,'seamless_loop':True,'nominal_speed_m_s':SPEED,'support_duty':{'L':.42,'R':.43},'contact_frames':{'L':1,'R':12},'flight_intervals_frames':[[10.24,12],[21.46,23]],'original_actions':original,'rig_changes':[],'approved_walk_source_sha256':baseline['approved_walk_source_sha256'],'motion_ownership':'Root/object identity. Controller owns forward -Y travel; lowest sole support moves backward +Y at2.1m/s. Run gait loading/flight height is local pose motion, not jump physics.','stance':'Same0.27m track spacing as approved Walk,3deg toe-out, mild unequal whole-leg lean. Straight full arms; no knees/ankles invented.','layering':'Full-body absolute baked Action. Future weapon layer must coordinate Chest/shoulders without replacing support hips/legs.','transition_contract':'Normalized phase0 is LEFT receiving contact;0.5 RIGHT receiving. Align WalkF1/19 to RunF1/12; match support phase, adapt speed/contact and compare velocity, not only pose. Idle requires support-aware replant; no generic contact-safe crossfade claim.'}
 (OUT/'manifest.json').write_text(json.dumps(data,indent=2));bpy.ops.wm.save_as_mainfile(filepath=str(destination))
 print('BUILT RUN V2 / PRESERVED TWELVE ACTIONS',flush=True)
if __name__=='__main__':build()
