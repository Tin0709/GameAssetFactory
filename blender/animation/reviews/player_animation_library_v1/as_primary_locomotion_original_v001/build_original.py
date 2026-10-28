import bpy,sys,json,math,hashlib,shutil,time
from pathlib import Path
from mathutils import Matrix,Vector,Euler
H=Path(__file__).resolve().parent;R=H.parents[4]
sys.path.insert(0,str(H));sys.path.insert(0,str(R/'blender/animation/showcase'))
import motion as m
import gaf_animation_library as ui
m.verify()
SOURCE=H/'as_primary_locomotion_authoring.blend'
if SOURCE.exists():
 assert '--refine-unregistered-draft'in sys.argv,'Create a new revision; do not overwrite authoring source'
 registry=json.loads((R/'blender/animation/showcase/animation_manifest.json').read_text(encoding='utf8'))
 assert not any(e['source']==SOURCE.relative_to(R).as_posix()for e in registry['animations']),'Registered source must remain immutable'
 shutil.copy2(SOURCE,R/'.validation/animation_showcase/as_primary_locomotion_original_v001'/('unregistered_draft_'+str(time.time_ns())+'.blend'))
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
with bpy.data.libraries.load(str(R/'blender/animation/showcase/Animation_Showcase.blend'),link=False)as(src,dst):dst.objects=['Showcase_Player_Rig','Showcase_Player_Mesh']
rig,mesh=dst.objects
for o in dst.objects:bpy.context.scene.collection.objects.link(o)
rig.name='ASPrimary_Original_Authoring_Rig';mesh.name='ASPrimary_Original_Authoring_Mesh'
rig.animation_data_clear();rig.matrix_world=Matrix.Identity(4)
for a in list(bpy.data.actions):bpy.data.actions.remove(a)
rests={b.name:b.bone.matrix_local.copy()for b in rig.pose.bones}
points={}
for name in ['Leg.L','Leg.R']:
 idx=mesh.vertex_groups[name].index
 points[name]=[v.co-rests[name].translation for v in mesh.data.vertices if any(g.group==idx and g.weight>.999 for g in v.groups)]
 assert len(points[name])==8
def rotate(x=0,y=0,z=0):return Euler((x,y,z),'XYZ').to_matrix().to_4x4()
def pose(p,s,contacts=None):
 wave=2*math.pi*p;world={}
 for bone in rig.pose.bones:
  name=bone.name;parent=bone.parent.name if bone.parent else None;rest=rests[name]
  relative=rests[parent].inverted()@rest if parent else rest
  default=world[parent]@relative if parent else rest.copy();pivot=default.translation.copy();rot=None
  if name=='Hips':pivot.z=m.hip_height(p,s)
  elif name in ['Spine','Chest']:
   rot=rotate(math.radians(4 if name=='Spine'else 7),math.radians(s['torso']*.22)*math.sin(wave+.32),math.radians(s['torso'])*math.sin(wave-.38))
  elif name=='Head':
   rot=rotate(math.radians(s['head'])*math.sin(2*wave-.57),math.radians(s['head']*.65)*math.sin(wave+.35),math.radians(s['head']*.4)*math.sin(wave-.3))
  elif name.startswith('UpperArm.'):
   side=1 if name.endswith('L')else -1
   # Original periodic spacing: fast exchanges and brief held extremes.
   shaped=math.tanh(1.35*math.sin(wave+.21))/math.tanh(1.35)
   pitch=side*math.radians(s['arm'])*(shaped+.055*math.sin(2*wave-.35))
   rot=rotate(pitch,-side*math.radians(3.5),side*math.radians(2.2)*math.sin(wave+.5))
  elif name in points:
   phase=p if name.endswith('L')else(p+.5)%1
   theta,plant,corner=m.leg(phase,s)
   if contacts is not None and name in contacts:theta=contacts[name]
   rot=rotate(theta);pivot.x=rest.translation.x;pivot.y=0.
   minimum=min((rot.to_3x3()@v).z for v in points[name])
   support=-minimum+.0003
   swing=((phase-s['duty']/2)%1)/(1-s['duty'])
   clearance=(.025 if s['kind']=='Walk'else .04)*math.sin(math.pi*swing)**2
   # A swing is never clamped onto the floor. Lift the rigid whole leg at
   # its hidden hip junction; no scale, bending, or false planted scrape.
   pivot.z=support if plant else max(world['Hips'].translation.z,support+clearance)
  target=Matrix.Translation(pivot)@(rot@rest.to_3x3().to_4x4()if rot is not None else default.to_3x3().to_4x4())
  if name=='Root':target=rest.copy()
  world[name]=target;basis=relative.inverted()@(world[parent].inverted()@target if parent else target)
  bone.matrix_basis=basis;bone.scale=(1,1,1)
 return world
def record(values,frame):
 for bone in rig.pose.bones:
  rotation='rotation_euler'if bone.rotation_mode!='QUATERNION'else'rotation_quaternion'
  for prop in ['location',rotation,'scale']:
   for axis,value in enumerate(getattr(bone,prop)):values.setdefault((bone.path_from_id(prop),axis),[]).extend((frame,value))
def make_action(name,values,style):
 a=bpy.data.actions.new(name);a.use_fake_user=True;slot=a.slots.new(id_type='OBJECT',name=rig.name)
 bag=a.layers.new('Original authored pose').strips.new(type='KEYFRAME').channelbags.new(slot)
 for(path,axis),coords in values.items():
  c=bag.fcurves.new(path,index=axis);c.keyframe_points.add(len(coords)//2);c.keyframe_points.foreach_set('co',coords)
  for k in c.keyframe_points:k.interpolation='LINEAR'
  c.update()
 a['original_authored']=True;a['source_keyframes_copied']=False;a['status']='pending'
 return a
actions=[];specs=[]
for style in m.STYLES:
 values={}
 for j in range(m.END*8+1):
  frame=1+j/8;pose((j/8/m.FPS*style['hz']+m.ORIGIN)%1,style);record(values,frame)
 a=make_action(style['kind']+'_ASInspired_Original_v001_PENDING',values,style);actions.append(a)
 specs.append({'action':a.name,'start':1,'end':m.END,'loop':True,'style':style})
 print('AUTHORED',a.name,flush=True)
# One original preview-only transition take. Integrate the shared clock and
# travel continuously. Anchored rolling edges are resolved in traveled space;
# this is original offline contact construction, not a recovered runtime IK.
values={};trace=[];p=m.ORIGIN;travel=0.;last_speed=m.STYLES[0]['speed'];last_hz=m.STYLES[0]['hz'];anchors={};lastkeys={};corners={};released={};lasttheta={};lastnom={};lastdelta={}
dt=1/(m.FPS*8);duration=4.5
for j in range(int(duration/dt)+1):
 t=j*dt;w=m.weight(t);s=m.blend_style(w)
 if j:p+=(last_hz+s['hz'])*.5*dt;travel+=(last_speed+s['speed'])*.5*dt
 last_hz=s['hz'];last_speed=s['speed'];correct={};contact_info={}
 for name in points:
  ph=p if name.endswith('L')else p+.5;theta,plant,corner=m.leg(ph%1,s);nominal=theta
  key=math.floor(ph+.5)if plant else None
  if plant:
   if lastkeys.get(name)!=key:
    anchors[name]=-travel+m.L*math.sin(theta)+corner*math.cos(theta);corners[name]=corner
   corner=corners[name]
   target=anchors[name]+travel
   theta=math.asin(target/math.hypot(m.L,m.D))-math.atan2(corner,m.L)
   # Change material edge when the actual rigid sole is flat, rather than
   # changing at a nominal phase while the speed is accelerating.
   if corner>0 and theta>0:
    anchors[name]-=2*m.D;corner=-m.D;corners[name]=corner
    theta=math.asin((anchors[name]+travel)/math.hypot(m.L,m.D))-math.atan2(corner,m.L)
  else:
   if lastkeys.get(name)is not None:
    d=lasttheta[name]-lastnom[name];v=(d-lastdelta.get(name,d))/dt
    released[name]=(t,d,v)
   if name in released:
    when,d,v=released[name];age=t-when
    if age<.12:theta+=m.hermite(d,0.,v,0.,age/.12,.12)
  correct[name]=theta
  lastdelta[name]=lasttheta.get(name,theta)-lastnom.get(name,nominal)
  lasttheta[name]=theta;lastnom[name]=nominal
  lastkeys[name]=key;contact_info[name]={'plant':plant,'corner':corner,'anchor':anchors.get(name)}
 pose(p%1,s,correct);record(values,1+j/8)
 trace.append({'frame':1+j/8,'time':t,'phase':p%1,'run_weight':w,'travel_m':travel,'speed':s['speed'],'contacts':contact_info})
a=make_action('PREVIEW_ONLY_WalkRun_PhaseTransition_Original_v001_PENDING',values,{});actions.append(a)
specs.append({'action':a.name,'start':1,'end':270,'loop':False,'preview_only':True})
rig.animation_data_create();rig.animation_data.action=actions[1];rig.animation_data.action_slot=actions[1].slots[0]
scene=bpy.context.scene;scene.name='AS_PRIMARY_ORIGINAL_AUTHORING';scene.frame_start=1;scene.frame_end=m.END;scene.render.fps=m.FPS;scene.render.fps_base=1;scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
(H/'transition_trace.json').write_text(json.dumps(trace,separators=(',',':')),encoding='utf8')
(H/'source_metadata.json').write_text(json.dumps({'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'source':SOURCE.relative_to(R).as_posix(),'actions':[a.name for a in actions],'specs':specs,'rig':rig.name,'mesh':mesh.name,'armature':rig.data.name,'fps':m.FPS,'fps_base':1},indent=2),encoding='utf8')
print('SAVED_ORIGINALS',len(actions),flush=True)
