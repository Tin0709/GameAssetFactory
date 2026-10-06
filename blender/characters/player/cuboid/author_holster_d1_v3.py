import bpy,json,math
from mathutils import Matrix,Vector,Quaternion,Euler
from pathlib import Path
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
DEV=BASE/'player_cuboid_weapon_animation_dev.blend'
assert Path(bpy.data.filepath)==DEV
rig=bpy.data.objects['Player_Cuboid_Rig'];scene=bpy.context.scene
source=bpy.data.actions['Holster_LongGun_V2']
def curves(a):return [c for l in a.layers for st in l.strips for bag in st.channelbags for c in bag.fcurves]
existing=bpy.data.actions.get('Holster_LongGun_V3_Final')
assert not existing,'Final action already exists; do not overwrite it.'
old_frames=[1,2.8,3.7,4.6,5.5,8.2,10.5,11.5,13.3,14.8,16.3,18]
rig.animation_data.action=source
cache={}
for f in old_frames:
 scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
 cache[f]=rig.pose.bones['WeaponCarrier'].matrix.copy()
# Duplicate actual V2; preserve V1/V2 datablocks and F-curves.
action=source.copy();action.name='Holster_LongGun_V3_Final';action.use_fake_user=True
action['pass']='D1 Pass 3 final character acting and production polish'
rig.animation_data.action=action
def retime(bone,old,new):
 for c in curves(action):
  if c.data_path.startswith('pose.bones["'+bone+'"]'):
   for k in c.keyframe_points:
    if abs(k.co.x-old)<.001:
     delta=new-old;k.co.x+=delta;k.handle_left.x+=delta;k.handle_right.x+=delta
   c.update()
def adjust(bone,f,delta):
 scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
 p=rig.pose.bones[bone];p.rotation_euler=[p.rotation_euler[i]+math.radians(delta[i]) for i in range(3)]
 p.keyframe_insert('rotation_euler',frame=f,group=bone)
for bone,old,new in [('Chest',14.4,14.55),('Chest',16.4,16.65),('Arm.R',10.6,10.35),('Arm.R',15.5,15.7),('Arm.R',17.4,17.55),('Arm.L',5.3,5.4),('Arm.L',6.2,6.4),('Arm.L',17.1,17.0),('Spine',11.8,12.0),('Neck',10.9,11.15),('Head',12.1,12.35),('WeaponCarrier',10.5,10.7),('WeaponCarrier',11.5,11.6),('WeaponCarrier',16.3,16.15)]:
 retime(bone,old,new)
adjust('Chest',2.2,(-.28,0,0))
adjust('Chest',14.55,(.08,-.15,.03))
adjust('Arm.L',3.35,(-.55,.15,.35))
adjust('Arm.L',4.7,(-.55,.15,.35))
adjust('Neck',3.4,(-.10,.08,0))
adjust('Neck',11.15,(-.08,.15,-.03))
adjust('Head',12.35,(-.03,.1,0))
# Bounded refinements to apparent grip/shoulder relationship.
right_deltas={2.6:(-.2,0,-.2),3.1:(-1,-.3,-1),4.9:(-2.5,-1,-2),7.7:(-1.5,1,2),10.35:(-.4,2,-.6),12.9:(1.5,1,1.5),14.3:(.6,.3,.6)}
for f,delta in right_deltas.items():adjust('Arm.R',f,delta)
# Keep the original endpoint and approved arc; apply small spatial corrections.
offsets={1:(0,0,0),2.8:(.022,-.012,.008),3.7:(.032,-.016,.008),4.6:(.030,-.025,.010),5.5:(.025,-.030,0),8.2:(0,-.018,.008),10.5:(0,-.018,.008),11.5:(-.006,-.020,-.008),13.3:(-.020,.018,0),14.8:(0,0,0),16.3:(0,0,0),18:(0,0,0)}
new_frames={10.5:10.7,11.5:11.6,16.3:16.15}
stowed=cache[18];previous=None
for old in old_frames:
 f=new_frames.get(old,old);scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
 world=cache[old].copy();world.translation+=Vector(offsets[old])
 if old==14.8:
  q=stowed.to_quaternion().slerp(world.to_quaternion(),.65)
  p=stowed.translation.lerp(world.translation,.65)
  world=q.to_matrix().to_4x4();world.translation=p
 p=rig.pose.bones['WeaponCarrier'];p.matrix=world;bpy.context.view_layer.update();p.scale=(1,1,1)
 q=p.rotation_quaternion.copy()
 if previous is not None and q.dot(previous)<0:q.negate();p.rotation_quaternion=q
 previous=q.copy()
 p.keyframe_insert('location',frame=f,group='WeaponCarrier');p.keyframe_insert('rotation_quaternion',frame=f,group='WeaponCarrier')
for c in curves(action):
 for k in c.keyframe_points:k.interpolation='BEZIER';k.handle_left_type='AUTO_CLAMPED';k.handle_right_type='AUTO_CLAMPED'
 c.update()
# Final subframe adjustments after clearance/velocity review.
for bone,old,new in [('Arm.R',12.9,12.65),('Arm.R',14.3,14.05),('WeaponCarrier',10.7,10.55),('WeaponCarrier',11.6,11.65)]:
 retime(bone,old,new)
events=[(1,'HOLSTER_BEGIN'),(5,'SUPPORT_HAND_RELEASE'),(15,'WEAPON_BACK_CONTACT'),(16,'HOLSTER_RELEASE'),(18,'HOLSTER_DONE')]
for m in list(action.pose_markers):action.pose_markers.remove(m)
for f,n in events:action.pose_markers.new(n).frame=f
for m in list(scene.timeline_markers):
 if m.name in dict((n,f) for f,n in events):scene.timeline_markers.remove(m)
for f,n in events:scene.timeline_markers.new(n,frame=f)
action['event_subframes_json']=json.dumps({'HOLSTER_BEGIN':1,'SUPPORT_HAND_RELEASE':5.4,'WEAPON_BACK_CONTACT':14.8,'HOLSTER_RELEASE':15.7,'HOLSTER_DONE':18})
action['authoring_fps']=24;action['duration_seconds']=17/24
action['comparison_source']='Holster_LongGun_V2'
scene.frame_set(1)
result={'created':action.name,'frame_range':list(action.frame_range),'offsets_m':offsets,'right_arm_corrections_deg':right_deltas,'saved':False}
