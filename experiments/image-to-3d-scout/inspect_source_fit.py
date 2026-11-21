import bpy
from mathutils import Vector
from collections import Counter
s=bpy.context.scene
for m in s.timeline_markers:
 c=m.camera
 print("CAM",m.name,m.frame,list(c.location),list(c.rotation_euler),c.data.type,c.data.lens,c.data.ortho_scale)
rig=next(o for o in s.objects if o.type=="ARMATURE")
print("TYPE",rig.data.pose_position)
for x in rig.animation_data.drivers:
 print("DRIVER",x.data_path,x.array_index,x.driver.expression)
for frame in (1,2):
 s.frame_set(frame)
 for p in rig.pose.bones:
  print("BONE",frame,p.name,p.rotation_mode,[round(v,4) for v in p.rotation_euler],[round(v,4) for v in p.location])
for o in s.objects:
 if o.type!="MESH":continue
 if o.data.shape_keys:
  k=o.data.shape_keys
  print("KEY",o.name,[p.name for p in k.key_blocks])
  for c in (k.animation_data.drivers if k.animation_data else []):
   print("DRIVER",c.data_path,c.driver.expression)

