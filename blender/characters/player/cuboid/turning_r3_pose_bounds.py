import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from turning_r2_common import *
from bpy_extras.object_utils import world_to_camera_view
OUT=BASE/'turning_study_r3_review';s=bpy.data.scenes['R3_Review_AB'];bpy.context.window.scene=s;bounds={}
for f in [13,37,61,109,181,265,289,313,337,373,397,421,445]:
 s.frame_set(f);bpy.context.view_layer.update()
 for gait in PERIOD:
  for v in ['A','B']:
   r=bpy.data.objects['R3_Review_'+gait+'_'+v+'_Rig'];pts=mesh_points(bpy.data.objects['R3_Review_'+gait+'_'+v+'_Mesh']);ps=[]
   for n in pts:
    for p in transformed(r,pts,n):
     q=world_to_camera_view(s,s.camera,r.matrix_world@Vector(p));ps.append((q.x*s.render.resolution_x,(1-q.y)*s.render.resolution_y))
   bounds[gait+'_'+v+'_'+str(f)]=[min(x for x,y in ps),min(y for x,y in ps),max(x for x,y in ps),max(y for x,y in ps)]
(OUT/'pose_bounds.json').write_text(json.dumps(bounds));print('R3_BOUNDS_DONE',flush=True)
