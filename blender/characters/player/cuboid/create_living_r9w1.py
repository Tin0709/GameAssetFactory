"""R9-W1: isolated baked FK motion probes on the unchanged R8 articulated rig."""
import bpy,sys,math,json,hashlib,subprocess
import numpy as np
from pathlib import Path
from mathutils import Matrix,Vector,Euler
BASE=Path(__file__).resolve().parent;ROOT=BASE.parents[3];OUT=BASE/'living_r9w1_review';OUT.mkdir(exist_ok=True)
sys.path.insert(0,str(BASE))
from turning_r2_common import digest,curves,geometry,bone_signature,assign,camera
SOURCE=BASE/'player_longgun_arm_rig_v2_study.blend';TARGET=BASE/'player_longgun_living_r9w1_study.blend'
assert Path(bpy.data.filepath)==SOURCE
if not (OUT/'preservation.json').exists():
 names=set(subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode().split('\0'))
 names.update(str(p.relative_to(ROOT)) for p in BASE.glob('*r8a1*') if p.is_file())
 names.update(str(p.relative_to(ROOT)) for p in (BASE/'arm_r8a1_review').rglob('*') if p.is_file())
 names.update([str(SOURCE.relative_to(ROOT)),'references/animation/weapon_hold_living_reference/minecraft_crossbow_hold_turning.mp4'])
 protected={'files':{n:hashlib.sha256((ROOT/n).read_bytes()).hexdigest() for n in names if n and (ROOT/n).is_file()},'actions':{a.name:digest(a) for a in bpy.data.actions},'geometry':geometry(),'rigs':{o.name:bone_signature(o) for o in bpy.data.objects if o.type=='ARMATURE'}}
 (OUT/'preservation.json').write_text(json.dumps(protected,indent=2))
else:protected=json.loads((OUT/'preservation.json').read_text())
with bpy.data.libraries.load(str(BASE/'player_locomotion_straight_v2_study.blend'),link=False) as (src,dst):dst.actions=['Walk_ReferenceStudy_V2']
walk=bpy.data.actions['Walk_ReferenceStudy_V2'];walk.use_fake_user=True
original=bpy.data.scenes['R8A1_AUTHORING'];source_rig=bpy.data.objects['R8A1_RigV2_Author']
source_objects=[o for o in original.objects if o.type not in {'CAMERA','LIGHT'}]

def clone(label,s):
 mp={}
 for old in source_objects:
  ob=old.copy();ob.name='R9W1_'+label+'_'+old.name;ob.animation_data_clear()
  if old.type in {'ARMATURE','MESH'}:ob.data=old.data.copy()
  s.collection.objects.link(ob);mp[old]=ob;ob.hide_render=False;ob.hide_viewport=False
 for old,ob in mp.items():
  if old.parent in mp:ob.parent=mp[old.parent]
  for md in ob.modifiers:
   if md.type=='ARMATURE' and md.object in mp:md.object=mp[md.object]
  for c in ob.constraints:
   if hasattr(c,'target') and c.target in mp:c.target=mp[c.target]
 return mp[source_rig],mp

def scene(name):
 s=bpy.data.scenes.new(name);s.world=original.world;s.render.engine='BLENDER_EEVEE';s.render.resolution_x=960;s.render.resolution_y=640;s.render.resolution_percentage=100;s.render.fps=24;s.frame_start=1
 s.render.image_settings.file_format='PNG';s.view_settings.view_transform='Standard';s.view_settings.look='None'
 s.render.film_transparent=False
 for ob in original.objects:
  if ob.type=='LIGHT':s.collection.objects.link(ob)
 return s

s=scene('R9W1_AUTHORING');bpy.context.window.scene=s;r,mp=clone('Author',s);r.name='R9W1_Author_Rig'
mesh=mp[bpy.data.objects['R8A1_RigV2_Mesh']];mesh.name='R9W1_Author_Mesh'
weapon=next(o for o in mp.values() if o.type=='MESH' and 'M4A1_Blocky_Base' in o.name)
assign(r,bpy.data.actions['LongGunHold_RigV2_Study_V1']);s.frame_set(1);bpy.context.view_layer.update()
base={p.name:p.matrix_basis.copy() for p in r.pose.bones};chest0=r.pose.bones['Chest'].matrix.copy()
gun0=weapon.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world.copy()
socket=r.pose.bones['WeaponCarrier'].matrix.inverted()@gun0
gun0.translation.z-=.02  # Give the steering head corner clearance above the rear sight/stock.
gun_in_chest=chest0.inverted()@gun0
pole_local={side:chest0.inverted()@Vector(p) for side,p in [('R',(-.6,.15,.70)),('L',(.45,-.05,.70))]}
# Read established locomotion numerically, without modifying a source rig or Action.
wc=curves(walk)
def walk_basis(n,f):
 loc=Vector((0,0,0));rot=Euler((0,0,0),'XYZ')
 for c in wc:
  if c.data_path==f'pose.bones["{n}"].location':loc[c.array_index]=c.evaluate(f)
  elif c.data_path==f'pose.bones["{n}"].rotation_euler':rot[c.array_index]=c.evaluate(f)
 return Matrix.LocRotScale(loc,rot.to_quaternion(),Vector((1,1,1)))

# Arc-length parameterization: constant-speed figure eight, closed with a smooth tangent.
u=np.linspace(0,2*math.pi,12001);xy=np.column_stack((2.4*np.sin(u),-1.2*np.sin(2*u)))
arc=np.r_[0,np.cumsum(np.linalg.norm(np.diff(xy,axis=0),axis=1))];arc/=arc[-1]
def path(t):
 a=float(np.interp((t/12)%1,arc,u));v=Vector((2.4*math.cos(a),-2.4*math.cos(2*a),0));heading=math.atan2(v.x,-v.y)
 return Vector((2.4*math.sin(a),-1.2*math.sin(2*a),0)),heading
def steering(t):
 # Signed curvature look-ahead, saturated smoothly; support response uses earlier values.
 _,h0=path(t-.04);_,h1=path(t+.04);rate=math.atan2(math.sin(h1-h0),math.cos(h1-h0))/.08
 return math.tanh(rate/1.35)

def rot(n,deg):r.pose.bones[n].matrix_basis=base[n]@Euler(tuple(math.radians(v) for v in deg),'XYZ').to_matrix().to_4x4()
def arm(side,target,pole):
 up=r.pose.bones['UpperArm.'+side];fo=r.pose.bones['ForeArm.'+side];sh=up.head.copy();a=up.length;b=fo.length-.075
 delta=target-sh;d=delta.length;axis=delta.normalized()
 assert abs(a-b)+.001<d<a+b-.001,(side,d,a+b)
 along=(a*a-b*b+d*d)/(2*d);height=math.sqrt(a*a-along*along);v=pole-sh;v=(v-axis*v.dot(axis)).normalized();el=sh+axis*along+v*height
 for p,head,tail in [(up,sh,el),(fo,el,el+(target-el).normalized()*fo.length)]:
  y=(tail-head).normalized();x=Vector((1,0,0));x=(x-y*x.dot(y)).normalized();z=x.cross(y).normalized();m=Matrix((x,y,z)).transposed().to_4x4();m.translation=head;p.matrix=m;bpy.context.view_layer.update()
 return {'reach':d,'bend_deg':180-math.degrees((sh-el).angle(target-el)),'elbow':list(el)}

definitions=[('LongGunReady_LivingRef_V1','Ready',96),('LongGunReady_Move_V1','Move',64),('LongGunAimAround_LeftRight_V1','Steering',288)]
design={'reference':'minecraft_crossbow_hold_turning.mp4','fps':24,'source_walk':walk.name,'source_walk_digest':digest(walk),'actions':{},'path':'constant arc-speed figure eight; prescribed dev trajectory, not recovered from reference','helpers':'offline two-link construction baked to FK; no persistent controls or IK','contact':'grip pinned; support follows along a bounded fore-end contact path; elbow response delayed 125ms'}
for name,mode,N in definitions:
 a=bpy.data.actions.new(name);a.use_fake_user=True;records=[];previous={};first=None
 for i in range(N+1):
  f=i+1;t=i/24;tcycle=(i%N)/24;phase=2*math.pi*i/N;moving=mode!='Ready';scan=mode=='Steering'
  assign(r,None)
  for n,m in base.items():r.pose.bones[n].matrix_basis=m
  if moving:
   for n in ['Root','Hips','Leg.L','Leg.R']:r.pose.bones[n].matrix_basis=walk_basis(n,1+(i%16))
  drive=steering(tcycle) if scan else .12*math.sin(phase)
  lag=steering(tcycle-.125) if scan else .12*math.sin(phase-.2)
  breathe=math.sin(phase*(3 if scan else 1));sway=math.sin(phase*(2 if scan else 1)+.65)
  rot('Spine',(.65*breathe,3.5*drive,.6*sway))
  rot('Chest',(1.0*breathe,10*drive,(-1.6 if scan else .5)*drive))
  rot('Neck',(.4*breathe,2.5*drive,0))
  rot('Head',(.65*breathe,4+2.5*drive,-.5*drive))
  bpy.context.view_layer.update();chest=r.pose.bones['Chest'].matrix.copy()
  # The weapon stays close to the chest; a small delayed yaw avoids whole-pose locking.
  weapon_lag=(steering(tcycle-.045)-drive)*3.5 if scan else .5*math.sin(phase-.18)
  gm=chest@gun_in_chest@Euler((math.radians(.35*breathe),0,math.radians(weapon_lag)),'XYZ').to_matrix().to_4x4()
  r.pose.bones['WeaponCarrier'].matrix=gm@socket.inverted();bpy.context.view_layer.update()
  support_y=.25+.012*lag;support_z=.02+.003*breathe
  poles={side:chest@v for side,v in pole_local.items()}
  # Move the elbow pole in chest space while keeping the actual contact on the fore-end.
  poles['L']+=chest.to_3x3()@Vector((.065*lag,.025*lag,.028*math.sin(phase-.24)))
  poles['R']+=chest.to_3x3()@Vector((.006*drive,0,0))
  arms={side:arm(side,gm@Vector(target),poles[side]) for side,target in [('R',(0,0,0)),('L',(0,support_y,support_z))]}
  localpose={p.name:p.matrix_basis.copy() for p in r.pose.bones}
  if scan:
   pos,heading=path(tcycle);root=r.pose.bones['Root'];root.matrix=Matrix.Translation(pos)@Matrix.Rotation(heading,4,'Z')@root.matrix;bpy.context.view_layer.update()
  if i==0:first={p.name:p.matrix_basis.copy() for p in r.pose.bones}
  if i==N:
   for n,m in first.items():r.pose.bones[n].matrix_basis=m
  assign(r,a)
  for pb in r.pose.bones:
   q=pb.rotation_quaternion.copy()
   if pb.name in previous and q.dot(previous[pb.name])<0:q.negate();pb.rotation_quaternion=q
   previous[pb.name]=q.copy();pb.keyframe_insert('rotation_quaternion',frame=f,group=pb.name)
   if pb.name in {'Root','Hips','Leg.L','Leg.R','WeaponCarrier'}:pb.keyframe_insert('location',frame=f,group=pb.name)
  records.append({'frame':f,'drive':drive,'support_drive':lag,'support_local':[0,support_y,support_z],'arms':arms})
 for c in curves(a):
  for k in c.keyframe_points:k.interpolation='LINEAR'
  c.modifiers.new('CYCLES')
 a['scope']='R9-W1 Blender-only study';a['cycle_frames']=N;a['source_lower_body']=walk.name if moving else 'R8 static';a['fps']=24
 if scan:
  for label,frame in [('CROSSING',1),('LEFT ARC',73),('REVERSAL',145),('RIGHT ARC',217),('LOOP',289)]:a.pose_markers.new(label).frame=frame
 design['actions'][name]={'mode':mode,'period':N,'records':records}
 # A matched control follows identical lower-body/root animation, with the R8 upper pose fixed.
 control=a.copy();control.name='PREVIEW_ONLY_R9W1_R8_'+mode;control.use_fake_user=True
 for c in list(curves(control)):
  if not any(f'pose.bones["{n}"]' in c.data_path for n in ['Root','Hips','Leg.L','Leg.R']):
   for layer in control.layers:
    for strip in layer.strips:
     for bag in strip.channelbags:
      if c in list(bag.fcurves):bag.fcurves.remove(c)
 control['scope']='Comparison only: R8 static upper body plus identical R9 lower-body/path'
 # Key fixed upper body so assignment does not inherit previously evaluated values.
 assign(r,None)
 for n,m in base.items():r.pose.bones[n].matrix_basis=m
 assign(r,control)
 for pb in r.pose.bones:
  if pb.name not in {'Root','Hips','Leg.L','Leg.R'}:
   for f in [1,N+1]:
    pb.keyframe_insert('rotation_quaternion',frame=f,group=pb.name)
    if pb.name=='WeaponCarrier':pb.keyframe_insert('location',frame=f,group=pb.name)
 print('AUTHORED',name,flush=True)

# Explicit inspection copies cancel only Root channels; render evaluation cannot restore travel.
for source_name,target_name in [('LongGunAimAround_LeftRight_V1','PREVIEW_ONLY_R9W1_Steering_Local'),('PREVIEW_ONLY_R9W1_R8_Steering','PREVIEW_ONLY_R9W1_R8_Local')]:
 a=bpy.data.actions[source_name].copy();a.name=target_name;a.use_fake_user=True
 for layer in a.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for c in list(bag.fcurves):
     if c.data_path.startswith('pose.bones["Root"]'):bag.fcurves.remove(c)
 assign(r,None);r.pose.bones['Root'].matrix_basis=Matrix.Identity(4);assign(r,a)
 for f in [1,289]:
  r.pose.bones['Root'].keyframe_insert('location',frame=f,group='Root');r.pose.bones['Root'].keyframe_insert('rotation_quaternion',frame=f,group='Root')
 a['scope']='Inspection only: root trajectory removed; upper-body motion identical to steering Action'
for name,pos,target,scale in [('Front',(-3,-5,2.5),(0,-.2,1),3.4),('Gameplay',(-3,-5,4.4),(0,-.2,1),3.8),('Opposite',(3,-5,4.4),(0,-.2,1),3.8),('Side',(-5,-.25,1.9),(0,-.2,1),3.4),('Close',(-3,-5,2.65),(0,-.3,1.36),2.45),('Distance',(-3,-5,4.4),(0,-.2,1),12),('Path',(0,-9,10),(0,0,.6),8.4)]:camera(s,'R9W1_'+name,pos,target,scale)
s.camera=bpy.data.objects['R9W1_Front'];s.frame_end=96;assign(r,bpy.data.actions[definitions[0][0]]);s.frame_set(1)
# Three ready-to-play A/B scenes, equal camera and light offsets in separately rendered panels.
for name,mode,N in definitions+[('PREVIEW_ONLY_R9W1_Steering_Local','Local',288)]:
 cs=scene('R9W1_REVIEW_'+mode.upper());bpy.context.window.scene=cs;cs.frame_end=N
 for i,act in enumerate(['PREVIEW_ONLY_R9W1_R8_'+mode,name]):
  rr,copies=clone(mode+str(i),cs);rr.name='R9W1_'+mode+'_'+('Baseline' if i==0 else 'Living')+'_Rig';assign(rr,bpy.data.actions[act])
  q=Vector((-3,-5,3.45)).to_track_quat('Z','Y');right=q@Vector((1,0,0));offset=right*((i-.5)*(7.0 if mode=='Steering' else 2.1))
  for old,ob in copies.items():
   if old.parent is None and not ob.constraints:ob.location+=offset
  font=bpy.data.curves.new('R9W1_Label','FONT');font.body='A  R8 HOLD + SAME GAIT / PATH' if i==0 else 'B  R9 LIVING '+mode.upper();font.align_x='CENTER';font.size=.12 if mode!='Steering' else .25
  label=bpy.data.objects.new(font.name,font);cs.collection.objects.link(label);label.location=offset+Vector((0,0,2.15 if mode!='Steering' else 3.8));label.rotation_euler=q.to_euler()
  if mode=='Steering':
   curve=bpy.data.curves.new('R9W1_PathGuide','CURVE');curve.dimensions='3D';curve.bevel_depth=.013;curve.bevel_resolution=0
   spline=curve.splines.new('POLY');spline.points.add(240)
   for j,point in enumerate(spline.points):
    pos,_=path(j/20);point.co=(*(pos+offset+Vector((0,0,-.015))),1)
   ob=bpy.data.objects.new(curve.name,curve);cs.collection.objects.link(ob)
 cs.camera=camera(cs,'R9W1_Review_'+mode,Vector((0,-.2,1))+q@Vector((0,0,15)),(0,-.2,1),5.4 if mode!='Steering' else 16)
 cs.frame_set(1)
(OUT/'design.json').write_text(json.dumps(design,indent=2))
for n,h in protected['actions'].items():assert digest(bpy.data.actions[n])==h,n
geo=geometry()
for n,h in protected['geometry'].items():assert geo[n]==h,n
for n,h in protected['rigs'].items():assert json.dumps(bone_signature(bpy.data.objects[n]))==json.dumps(h),n
bpy.context.window.scene=bpy.data.scenes['R9W1_REVIEW_READY'];bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET),check_existing=False)
print('R9W1_SAVED',TARGET,flush=True)
