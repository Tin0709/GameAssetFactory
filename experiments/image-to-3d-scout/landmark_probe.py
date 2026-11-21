import bpy
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
S=1.8/518
s=bpy.context.scene
rig=s.objects["Scout Canon | Rig"]
tag="Scout Canon | "
names=["R \u00b7 Shaped quad hood with returned lining","Rear folded hood panel","R short sleeve","L short sleeve",
       "R folded shoulder yoke","L folded shoulder yoke","Long cloak with tapered supporting folds",
       "R wrapping skirt of cloak","L wrapping skirt of cloak","R hip pouch","L hip pouch","R Glove","L Glove",
       "R outsole","L outsole","R trouser","L trouser","Face","Mouth guide","Scarf wrap 1"]
for f in (1,2,3,4):
 s.frame_set(f)
 cam=s.camera
 dep=bpy.context.evaluated_depsgraph_get()
 print("VIEW",f)
 for part in names:
  ob=s.objects.get(tag+part)
  if not ob:continue
  eval=ob.evaluated_get(dep)
  mesh=eval.to_mesh()
  pts=[world_to_camera_view(s,cam,eval.matrix_world@v.co) for v in mesh.vertices]
  print(part, [tuple(round(pm([pt[i] for pt in pts])*[430,575][i],1) for i in (0,1)) for pm in (min,max)])
  eval.to_mesh_clear()
 if f in (1,2):
  for part in ("Head","UpperArm.R","UpperArm.L","Leg.R","Leg.L"):
   p=rig.pose.bones[part]
   print("AXES",part,[[round(v,3) for v in col] for col in p.bone.matrix_local.to_3x3().col])

