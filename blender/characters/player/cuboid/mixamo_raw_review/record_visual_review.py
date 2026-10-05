import json
from pathlib import Path
base=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
p=base/'mixamo_raw_retarget_report.json';r=json.loads(p.read_text(encoding='utf-8'))
r['visual_review']={'views':['isometric','side'],'frames':[1,4.8,8.6,12.4,16.2],'contact_sheet':str(base/'mixamo_raw_review'/'Player_Run_Mixamo_RAW_review.png'),'notes':['First and endpoint poses visually match.','Whole rigid arms can reach near head height, following source upper-arm motion without elbow articulation.','Clipping occurs around neck/chest, shoulders and pelvis; legs overlap near the crotch.','No corrective stylization or geometry edits performed.'],'ready_for_raw_visual_review':True}
p.write_text(json.dumps(r,indent=2),encoding='utf-8')
