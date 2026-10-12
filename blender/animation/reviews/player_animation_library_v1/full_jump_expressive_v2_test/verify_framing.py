import bpy,json,sys,runpy,hashlib
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
O=Path(__file__).resolve().parent;R=O.parents[4];s=bpy.context.scene;r=bpy.data.objects['FJ2_Test_Rig'];m=bpy.data.objects['FJ2_Test_Mesh'];height=runpy.run_path(str(O.parent/'full_jump_expressive_test/build_test.py'))['height'];bounds={view:[1,1,0,0] for view in ['FRONT','THREE_QUARTER','SIDE']}
for view in bounds:
 cam=bpy.data.objects['Showcase_'+view];cam.data.ortho_scale=3.15;cam.location.z+=.32
for j in range(369):
 f=1+j/4;s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update();e=m.evaluated_get(bpy.context.evaluated_depsgraph_get());points=[e.matrix_world@v.co+Vector((0,0,height(f)*.72/.58)) for v in e.data.vertices]
 for view,b in bounds.items():
  q=[world_to_camera_view(s,bpy.data.objects['Showcase_'+view],p) for p in points];b[:]=[min(b[0],min(x.x for x in q)),min(b[1],min(x.y for x in q)),max(b[2],max(x.x for x in q)),max(b[3],max(x.y for x in q))]
assert all(min(b[:2])>.01 and max(b[2:])<.99 for b in bounds.values()),bounds
report={'passed':True,'source_sha256':hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest(),'samples':369,'temporary_preview_height_m':.72,'camera_ortho_scale':3.15,'bounds':bounds,'all_limbs_and_hands_within_frame':True};(O/'framing_verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
