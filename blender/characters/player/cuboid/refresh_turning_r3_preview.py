import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from turning_r2_common import *
OUT=BASE/'turning_study_r3_review';DEV=BASE/'player_locomotion_turning_v2_study.blend'
src=(BASE/'build_turning_r2_preview.py').read_text();exec(src[src.index('CASES='):src.index("metadata={'fps'")].replace('ReferenceStudy_V1','ReferenceStudy_V2').replace('_Reference_V1','_Reference_V2'))
meta=json.loads((OUT/'preview_metadata.json').read_text());s=bpy.data.scenes['R3_Turn_Authoring'];bpy.context.window.scene=s;r=bpy.data.objects['R2_R3_Author_Rig']
for gait in PERIOD:
 rows=meta['gaits'][gait]['rows'];a=bpy.data.actions['PREVIEW_ONLY_R3_'+gait+'_BlendedReel']
 for k in range((len(rows)-1)*4+1):
  f=1+k/4;i=int(k/4);u=k/4-i;row=rows[i];w=row['signed_weight']
  if u and i+1<len(rows) and rows[i+1]['case']==row['case']:w=rate(row['case'],row['case_time']+u/24)/MAX_RATE
  key_pose(r,a,f,fullpose(gait,(f-1)/24,w))
 for c in curves(a):
  for k in c.keyframe_points:k.interpolation='LINEAR'
check_preserved(json.loads((OUT/'preservation_before.json').read_text()));bpy.context.window.scene=bpy.data.scenes['R3_Review_AB'];bpy.context.scene.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=str(DEV),check_existing=False)
result={'preview_updated':True}
