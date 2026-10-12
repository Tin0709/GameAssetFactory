"""Source-bound full review with consistent extra headroom and temporary height."""
import bpy,json,sys,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
O=Path(__file__).resolve().parent;R=O.parents[4];B=O.parent/'full_jump_expressive_test/higher_preview_v002';sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();source=O/'full_jump_expressive_v2_review.blend';v=json.loads((O/'validation.json').read_text());assert v['passed'] and sha(source)==v['source_sha256']
# Read the already-reviewed presentation cameras and actual baked elevation;
# neither original preview nor new in-place source is saved by this script.
bpy.ops.wm.open_mainfile(filepath=str(B/'full_jump_higher_preview_v002.blend'));s=bpy.context.scene
cameras={view:{'matrix':bpy.data.objects['Showcase_'+view].matrix_world.copy(),'ortho':bpy.data.objects['Showcase_'+view].data.ortho_scale} for view in ['FRONT','THREE_QUARTER','SIDE']};heights={}
for f in range(1,94):s.frame_set(f);heights[f]=bpy.data.objects['Review_Only_Jump_Travel'].location.z
# Use the preserved presentation stage; import only the compatible pose Action.
r=bpy.data.objects['FJ_Test_Rig']
with bpy.data.libraries.load(str(source),link=False) as (src,dst):dst.actions=['Full_Jump_Expressive_v2_Test']
a=dst.actions[0];assert ui.action_signature(a)==v['action_sha256'];r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s.render.use_persistent_data=True
# Higher hands need a little more presentation headroom than the old low-arm
# preview. This camera-only8.6% widening applies consistently to every frame.
for view in cameras:
 cam=bpy.data.objects['Showcase_'+view];cam.data.ortho_scale=3.15;cam.location.z+=.10
proof={'source_sha256':v['source_sha256'],'action_sha256':v['action_sha256'],'original_preview_sha256':sha(B/'full_jump_higher_preview_v002.blend'),'preview_height_m':max(heights.values()),'fps':30,'frames':{},'rendered_frames':[],'reused_unchanged_frames':[],'matching_camera_pixel_checks':{},'temporary_elevation_only':True,'camera_ortho_scale':3.15,'camera_note':'All frames freshly rendered, consistent extra headroom for raised hands; original cameras/files unchanged.'}
def render(view,f,p):
 s.camera=bpy.data.objects['Showcase_'+view];s.frame_set(f);bpy.context.view_layer.update();s.render.filepath=str(p);bpy.ops.render.render(write_still=True)
for view in ['THREE_QUARTER','FRONT','SIDE']:
 dest=O/'frames'/view.lower();dest.mkdir(parents=True,exist_ok=True)
 for f in ([33,51] if 'keys' in sys.argv else range(1,94)):
  p=dest/f'{f:03d}.png'
  render(view,f,p);proof['rendered_frames'].append(p.relative_to(O).as_posix())
  proof['frames'][p.relative_to(O).as_posix()]=sha(p)
assert sha(source)==v['source_sha256'] and len(proof['frames'])==(6 if 'keys' in sys.argv else 279)
(O/('key_render_provenance.json' if 'keys' in sys.argv else 'render_provenance.json')).write_text(json.dumps(proof,indent=2));print('SOURCE-BOUND REVIEW COMPLETE / SAME TIMING AND0.72M REVIEW ARC')
