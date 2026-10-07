"""Final sweep refinement, executed after the initial V2 catch authoring."""
for old,new in [(6.35,6.45),(7.1,7.15)]:retime('WeaponCarrier',old,new)
for f,point,weight in [(6.45,(-.31,1.13,-.41),.14),(7.15,(-.48,1.10,-.57),.32),(8.2,(-.67,1.055,-.09),.55),(9.15,(-.69,1.025,.34),.77)]:
 frame(f);p=rig.pose.bones['WeaponCarrier']
 p.matrix=visual(tr(q0.slerp(q1,weight).to_matrix(),point));bpy.context.view_layer.update();p.scale=(1,1,1)
 p.keyframe_insert('location',frame=f,group=p.name);p.keyframe_insert('rotation_quaternion',frame=f,group=p.name)
for c in curves(a):
 if c.data_path.startswith('pose.bones["WeaponCarrier"]'):
  for k in c.keyframe_points:
   if 6<k.co.x<10:k.interpolation='BEZIER';k.handle_left_type='AUTO_CLAMPED';k.handle_right_type='AUTO_CLAMPED'
  c.update()
qc={c.array_index:c for c in curves(a) if c.data_path=='pose.bones["WeaponCarrier"].rotation_quaternion'}
last=None
for i in range(len(qc[0].keyframe_points)):
 current=Quaternion([qc[j].keyframe_points[i].co.y for j in range(4)])
 if last is not None and current.dot(last)<0:
  for j in range(4):
   k=qc[j].keyframe_points[i];k.co.y=-k.co.y;k.handle_left.y=-k.handle_left.y;k.handle_right.y=-k.handle_right.y
  current.negate()
 last=current.copy()
for c in qc.values():c.update()
