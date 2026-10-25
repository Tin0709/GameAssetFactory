"""Original Pending Sword combat family, exact preserved Showcase13 rest rig.
Attack slices come ONLY from the project's original Sword_Combo_Original_v001.
All additional motion and timing are authored here. World travel is physics-owned.
"""
import bpy,sys,json,math,hashlib
from pathlib import Path
from mathutils import Matrix,Vector,Quaternion
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').exists())
OUT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(R/'blender/animation/showcase'))
import gaf_animation_library as ui
sys.path.insert(0,str(R/'blender/animation/reviews/player_animation_library_v1/sword_combo_original_v001/authoring'))
from build_combo import channel,arm_frame,set_orientation
SOURCE=R/'blender/animation/reviews/player_animation_library_v1/sword_combo_original_v001/sword_combo_original_v001.blend'
SOURCE_HASH=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
MF=json.loads((R/'blender/animation/showcase/animation_manifest.json').read_text())
old=next(e for e in MF['animations'] if e['action']=='Sword_Combo_Original_v001')
assert SOURCE_HASH==old['source_sha256']
scene=bpy.data.scenes['SWORD_COMBO_ORIGINAL_REVIEW'];bpy.context.window.scene=scene
rig=bpy.data.objects['SC_Player_Rig'];mesh=bpy.data.objects['SC_Player_Mesh'];original=bpy.data.actions[old['action']]
assert ui.action_signature(original)==old['action_sha256']
assert ui.rest_signature(rig.data)==MF['rig_sha256']
def bind(a):rig.animation_data.action=a;rig.animation_data.action_slot=a.slots[0] if len(a.slots) else None

def frame(f):scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
def snapshot():return {b.name:b.matrix_basis.copy() for b in rig.pose.bones}
def source_pose(f):
 bind(original);frame(f);return snapshot()
base=source_pose(1);C=rig.pose.bones['UpperArm.R'].matrix.inverted()@rig.pose.bones['WeaponCarrier'].matrix

def restore(p):
 for b in rig.pose.bones:b.matrix_basis=p[b.name];b.scale=(1,1,1)
 bpy.context.view_layer.update()
def local_rotate(name,axis,angle):
 b=rig.pose.bones[name];m=b.matrix_basis.copy();rot=Matrix.Rotation(math.radians(angle),4,axis);m=m@rot;b.matrix_basis=m;b.scale=(1,1,1);bpy.context.view_layer.update()
def arms(direction,blade,left):
 ar,_=arm_frame(Vector(direction),Vector(blade));set_orientation(rig.pose.bones['UpperArm.R'],ar)
 al,_=arm_frame(Vector(left),Vector((0,-1,0)));set_orientation(rig.pose.bones['UpperArm.L'],al)
def fixed_grip():
 for name in ['ForeArm.L','ForeArm.R','Neck']:rig.pose.bones[name].matrix_basis=Matrix.Identity(4)
 bpy.context.view_layer.update();rig.pose.bones['WeaponCarrier'].matrix=rig.pose.bones['UpperArm.R'].matrix@C
 bpy.context.view_layer.update()
def guard(t):
 restore(base);a=math.sin(2*math.pi*t/.8)**2
 local_rotate('Chest','X',2.5+.3*a);local_rotate('Head','X',-1.5-.1*a)
 arms((-.25,-.76,-.60),(.75,-.38,.55),(.20,-.50,-.84));fixed_grip()
def custom(kind,t,duration):
 restore(base);u=t/duration
 if kind=='Ready':
  breath=math.sin(2*math.pi*u)**2
  local_rotate('Chest','X',.45*breath);local_rotate('Head','X',-.18*breath)
 elif kind=='Guard':guard(t)
 elif kind=='Parry':
  guard(0);e=channel(t,[(0,0),(.065,1),(.11,.8),(.20,.22),(.32,0)])
  local_rotate('Chest','Z',-8*e);local_rotate('Chest','X',-3*e);local_rotate('Head','Z',4*e)
  direction=Vector((-.25,-.76,-.60)).lerp(Vector((-.50,-.76,-.42)),e)
  blade=Vector((.75,-.38,.55)).lerp(Vector((.45,-.20,.87)),e)
  arms(direction,blade,(.20,-.50,-.84))
 elif kind=='Hurt':
  e=channel(t,[(0,0),(.055,1),(.10,.92),(.22,.25),(.40,0)])
  local_rotate('Chest','X',-12*e);local_rotate('Spine','X',-3*e);local_rotate('Chest','Z',7*e);local_rotate('Head','X',7*e)
  local_rotate('UpperArm.L','X',-10*e);local_rotate('UpperArm.R','X',-13*e)
 elif kind=='Roll':
  tuck=channel(t,[(0,0),(.09,.8),(.16,1),(.49,1),(.59,.6),(.72,0)])
  # Full straight segments fold at existing shoulder/hip pivots only.
  local_rotate('Hips','X',18*tuck);local_rotate('Chest','X',25*tuck);local_rotate('Head','X',-12*tuck)
  local_rotate('Leg.L','X',-52*tuck);local_rotate('Leg.R','X',-43*tuck)
  # Keep blade close to the roll axis, extending sideways rather than into floor.
  ar0=rig.pose.bones['UpperArm.R'].matrix.to_quaternion();al0=rig.pose.bones['UpperArm.L'].matrix.to_quaternion()
  ar,_=arm_frame(Vector((-.26,-.40,-.88)),Vector((-1,0,0)))
  al,_=arm_frame(Vector((.32,-.70,-.64)),Vector((0,-1,0)))
  qr=ar0.slerp(ar.to_quaternion(),tuck);ql=al0.slerp(al.to_quaternion(),tuck)
  for name,q in [('UpperArm.R',qr),('UpperArm.L',ql)]:
   b=rig.pose.bones[name];m=q.to_matrix().to_4x4();m.translation=b.head;b.matrix=m;bpy.context.view_layer.update()
  fixed_grip()
  theta=channel(t,[(0,0),(.055,0),(.12,.12),(.25,2.25),(.39,4.65),(.56,6.10),(.64,2*math.pi),(.72,2*math.pi)])
  pivot=Vector((0,0,.78));rot=Matrix.Rotation(theta,4,'X')
  root=rig.pose.bones['Root'];root.matrix=Matrix.Translation(pivot)@rot@Matrix.Translation(-pivot)@root.matrix
  # Preserve the unwrapped Euler path: no shortest-arc endpoint collapse.
  root.rotation_euler.x=theta
  bpy.context.view_layer.update()
  deps=bpy.context.evaluated_depsgraph_get();ev=mesh.evaluated_get(deps);geo=ev.to_mesh();lowest=min(v.co.z for v in geo.vertices);ev.to_mesh_clear()
  root.location.y+=.0006-lowest;bpy.context.view_layer.update()
 fixed_grip()
 return snapshot()
CLIPS={'Ready':(.8,True,None),'Attack1':(.6,False,(1,19)),'Attack2':(.5,False,(19,34)),'Attack3':(.9,False,(34,61)),'Guard':(.8,True,None),'Parry':(.32,False,None),'Roll':(.72,False,None),'Hurt':(.4,False,None)}
# Capture source before any new Action is created; never mutate source curves.
poses={}
for kind,(duration,loop,source_range) in CLIPS.items():
 times=[min(j/240,duration) for j in range(math.ceil(duration*240)+1)]
 poses[kind]=[(t,source_pose(source_range[0]+t*30) if source_range else custom(kind,t,duration)) for t in times]
 assert abs(times[-1]-duration)<1e-7
bind(original);assert ui.action_signature(original)==old['action_sha256']
scene.name='SWORD_COMBAT_ORIGINAL_V001_REVIEW';rig.name='SCC_Player_Rig';mesh.name='SCC_Player_Mesh'
scene.render.fps=30;scene.render.fps_base=1.;actions={};entries={}
for kind,(duration,loop,source_range) in CLIPS.items():
 action=bpy.data.actions.new('Sword_'+kind+'_Original_v001');action.use_fake_user=True
 rig.animation_data.action=action;previous={}
 for t,p in poses[kind]:
  restore(p)
  for b in rig.pose.bones:
   prop='rotation_quaternion' if b.rotation_mode=='QUATERNION' else 'rotation_euler'
   if prop=='rotation_quaternion':
    if b.name in previous and b.rotation_quaternion.dot(previous[b.name])<0:b.rotation_quaternion.negate()
    previous[b.name]=b.rotation_quaternion.copy()
   if kind=='Roll' and b.name=='Root':
    b.rotation_euler.x=channel(t,[(0,0),(.055,0),(.12,.12),(.25,2.25),(.39,4.65),(.56,6.10),(.64,2*math.pi),(.72,2*math.pi)])
   b.scale=(1,1,1)
   for path in ['location',prop,'scale']:b.keyframe_insert(path,frame=1+t*30,group=b.name)
 for curve in ui.curves(action):
  for k in curve.keyframe_points:k.interpolation='LINEAR'
 actions[kind]=action
 entries[kind]={'action':action.name,'duration':duration,'loop':loop,'source_frames':source_range,'action_sha256':ui.action_signature(action),'action_frame_range':list(action.frame_range),'slot_identifier':action.slots[0].identifier,'start':1,'end':int(math.floor(1+duration*30+1e-6)),'fps':30,'fps_base':1.,'rotation_modes':{b.name:b.rotation_mode for b in rig.pose.bones}}
 ui.validate_action(action,entries[kind],rig)
 print('AUTHORED',kind,action.name,len(poses[kind]),flush=True)
bind(actions['Ready']);frame(1);scene.frame_start=1;scene.frame_end=25
scene['review_status']='PENDING / original sword combat, authorized playable review'
scene['provenance']='All transforms original. Attacks are exact continuous slices of OUR original combo. No Fiery/A&S raw motion imported.'
scene['world_travel_owner']='Controller physics. Roll Root compensation centers local rotating body and resolves floor only.'
path=OUT/'sword_combat_v001.blend'
bpy.data.libraries.write(str(path),{scene,*actions.values()},fake_user=False,compress=True)
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==SOURCE_HASH
result={'schema':1,'status':'pending','original_custom_animation':True,'source_derived_reconstruction':False,'source':str(path.relative_to(R)),'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'source_rig':rig.name,'source_mesh':mesh.name,'source_armature':rig.data.name,'rig_signature':ui.rest_signature(rig.data),'original_combo_source':str(SOURCE.relative_to(R)),'original_combo_source_sha256':SOURCE_HASH,'original_combo_action_sha256':old['action_sha256'],'clips':entries,'provenance':{'P':'Independent original Ready/Guard/Parry/Roll/Hurt; Attack1/2/3 continuous slices of the project original choreography. Original timing and pose authorship.','S':'Exact existing 13bone rest rig, new Sword Sand Block GLB/markers. No raw source game tracks used.','U':'Artistic approval pending; no copied commercial game behavior claimed.'},'entry_exit':{'Ready':'Looped settled stance; zero endpoint velocities, upper body owner while locomotion owns support.','Attack1':'Original F1 Ready→F19 flowing open left finish; outgoing nonzero velocity for Attack2 or runtime recovery blend.','Attack2':'Original F19 open left→F34 right raised load; outgoing nonzero velocity for Attack3 or runtime recovery blend.','Attack3':'Original F34 right raised→F61 settled Ready; zero exit velocity.','Guard':'Held settled front diagonal guard; loop endpoints zero velocity; locomotion support retained.','Parry':'Guard→quick original receive→Guard; zero entry/exit velocity, controller owns successful contact.','Roll':'Ready→full forward turn→Ready, unwrapped0→2π, original local ground compensation; physics owns travel/collision.','Hurt':'Ready→asymmetric recoil→Ready; zero endpoints, controller owns interrupt and knockback.'},'contact_seconds':{'Attack1':.30,'Attack2':.20,'Attack3':.30},'world_travel_owner':'physics','roll_unwrapped_root_x_rad':[0,2*math.pi]}
(OUT/'design.json').write_text(json.dumps(result,indent=2)+'\n')
print('SWORD_COMBAT_SAVED',path,flush=True)
