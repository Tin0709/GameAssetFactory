import bpy,sys,json,math,hashlib,shutil,time
from pathlib import Path
from mathutils import Matrix,Vector,Euler
H=Path(__file__).resolve().parent;R=H.parents[4]
sys.path.insert(0,str(H));sys.path.insert(0,str(R/'blender/animation/showcase'))
import motion as m
import gaf_animation_library as ui
m.verify()
SOURCE=H/'hybrid_jump_authoring.blend'
if SOURCE.exists():
 assert '--refine-unregistered-draft'in sys.argv
 data=json.loads((R/'blender/animation/showcase/animation_manifest.json').read_text(encoding='utf8'))
 assert not any(e['source']==SOURCE.relative_to(R).as_posix()for e in data['animations'])
 shutil.copy2(SOURCE,R/'.validation/animation_showcase/hybrid_jump_original_v002'/('draft_'+str(time.time_ns())+'.blend'))
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
with bpy.data.libraries.load(str(R/'blender/animation/showcase/Animation_Showcase.blend'),link=False)as(src,dst):dst.objects=['Showcase_Player_Rig','Showcase_Player_Mesh']
rig,mesh=dst.objects
for o in dst.objects:bpy.context.scene.collection.objects.link(o)
rig.name='HybridJump_Soft_V002_Authoring_Rig';mesh.name='HybridJump_Soft_V002_Authoring_Mesh';rig.animation_data_clear();rig.matrix_world=Matrix.Identity(4)
for a in list(bpy.data.actions):bpy.data.actions.remove(a)
rest={b.name:b.bone.matrix_local.copy()for b in rig.pose.bones};hip_rest=rest['Hips'].translation
def rotate(x=0,y=0,z=0):return Euler(tuple(math.radians(v)for v in (x,y,z)),'XYZ').to_matrix().to_4x4()
def pose(d,ground):
 world={};hip=Vector((0,0,.6753+d['hip']));body=rotate(d['lean'],0,d['yaw'])
 for bone in rig.pose.bones:
  name=bone.name;parent=bone.parent.name if bone.parent else None;relative=rest[parent].inverted()@rest[name]if parent else rest[name]
  default=world[parent]@relative if parent else rest[name].copy();pivot=default.translation.copy();rot=None
  if name=='Hips':pivot=hip.copy()
  elif name in ['Spine','Chest','Neck']:
   pivot=hip+body.to_3x3()@(rest[name].translation-hip_rest);rot=body
  elif name=='Head':
   pivot=hip+body.to_3x3()@(rest[name].translation-hip_rest);rot=rotate(d['head'],0,d['yaw']*.12)
  elif name.startswith('UpperArm.'):
   side=1 if name.endswith('L')else -1
   pivot=hip+body.to_3x3()@(rest[name].translation-hip_rest)
   pitch=d['al']if side==1 else d['ar'];angle=math.radians(pitch)
   # Fan raised arms away from the face. Fixed world-Y splay would reverse
   # direction above horizontal and pull the hands inward across the eyes.
   rot=rotate(pitch,-side*3*max(0.,math.cos(angle)),side*(-d['splay']*math.sin(angle)+d['yaw']*.18))
  elif name.startswith('Leg.'):
   side=1 if name.endswith('L')else -1
   pivot=hip+(rest[name].translation-hip_rest);rot=rotate(d['ll']if side==1 else d['lr'])
   if ground:pivot=Vector((rest[name].translation.x,0,.6753));rot=rotate()
  target=Matrix.Translation(pivot)@(rot@rest[name].to_3x3().to_4x4()if rot is not None else default.to_3x3().to_4x4())
  if name=='Root':target=rest[name].copy()
  world[name]=target;basis=relative.inverted()@(world[parent].inverted()@target if parent else target)
  bone.matrix_basis=basis;bone.scale=(1,1,1)
def record(values,f):
 for b in rig.pose.bones:
  rotation='rotation_quaternion'if b.rotation_mode=='QUATERNION'else'rotation_euler'
  for prop in ['location',rotation,'scale']:
   for i,v in enumerate(getattr(b,prop)):values.setdefault((b.path_from_id(prop),i),[]).extend((f,v))
specs=[dict(action='Jump_Landing_MD2_AS_SoftBounce_Original_v002_PENDING',duration=m.LANDING,phase='landing',loop=False,floor=0),dict(action='PREVIEW_ONLY_Jump_MD2_AS_SoftBounce_Context_Original_v002_PENDING',duration=m.DURATION,phase='context',loop=False,floor=-.04,preview_only=True)]

actions=[]
for spec in specs:
 values={};n=round(spec['duration']*m.FPS*8);phase=spec['phase']
 times=sorted(set([j/(m.FPS*8)for j in range(n+1)]+m.landmarks(phase)))
 for t in times:
  if phase=='context':d,ground,_=m.context(t)
  else:d=getattr(m,phase)(t);ground=phase=='landing'
  pose(d,ground);record(values,1+t*m.FPS)
 a=bpy.data.actions.new(spec['action']);a.use_fake_user=True;slot=a.slots.new(id_type='OBJECT',name=rig.name);bag=a.layers.new('Independent original jump pose').strips.new(type='KEYFRAME').channelbags.new(slot)
 for(path,index),coords in values.items():
  c=bag.fcurves.new(path,index=index);c.keyframe_points.add(len(coords)//2);c.keyframe_points.foreach_set('co',coords)
  for k in c.keyframe_points:k.interpolation='LINEAR'
  c.update()
 a['original_authored']=True;a['source_keyframes_copied']=False;a['status']='pending';spec['start']=1;spec['end']=round(spec['duration']*m.FPS)+(1 if phase in ['takeoff','landing']else 0);actions.append(a)
 print('AUTHORED',a.name,flush=True)
rig.animation_data_create();rig.animation_data.action=actions[-1];rig.animation_data.action_slot=actions[-1].slots[0]
scene=bpy.context.scene;scene.name='HYBRID_JUMP_SOFT_V002_AUTHORING';scene.render.fps=60;scene.render.fps_base=1;scene.frame_start=1;scene.frame_end=144;scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
(H/'source_metadata.json').write_text(json.dumps({'source':SOURCE.relative_to(R).as_posix(),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'actions':[a.name for a in actions],'specs':specs,'rig':rig.name,'mesh':mesh.name,'armature':rig.data.name,'fps':60,'fps_base':1},indent=2),encoding='utf8')
print('SAVED_ORIGINAL_JUMP',flush=True)
