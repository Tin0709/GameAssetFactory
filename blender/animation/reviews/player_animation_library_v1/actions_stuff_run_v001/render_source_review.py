"""Source-authentic fixed-clock review; original reference remains at native30FPS."""
import bpy,json,sys,hashlib
from pathlib import Path
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
import source_motion
from retarget_source import Retarget
state=json.loads((HERE/'preservation_before.json').read_text());manifest=json.loads((HERE/'manifest.json').read_text());validation=json.loads((HERE/'source_validation.json').read_text());assert validation['passed']
assert hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest()==manifest['source_sha256']
sys.path.insert(0,str(Path(state['project'])/'blender/animation/showcase'));import gaf_animation_library as ui
scene=bpy.context.scene;rig=bpy.data.objects[manifest['source_rig']];name=manifest['action'];source=bpy.data.actions[name];approved=bpy.data.actions['Run_Snappy_Test_v001']
neutral=json.loads(bpy.data.texts['GAF_Neutral_Pose.json'].as_string())
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=6;scene.cycles.use_denoising=True;scene.render.use_persistent_data=True
scene.render.resolution_x=scene.render.resolution_y=512;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
proof={'source_file_sha256':manifest['source_sha256'],'source_action_sha256':manifest['action_sha256'],
 'reference_frames_zero_based':[30,97],'primary_frames':68,'fps':30,'source_clock_cycles_s':1.6,
 'reference_zero_family_alignment':'ReferenceF40 ↔ source t2.5/F76; provisional silhouette alignment, not measured contact',
 'previous_run_alignment':'ReferenceF40 ↔ previous Run right receiving phase0.5',
 'all_cameras_same_between_models':True,'source_constant_floor':manifest['preview_floor_z_m'],
 'approved_constant_floor':0,'diagnostic_forward_rate_cycles_s':30/17,'diagnostic_is_not_canonical_source_clock':True}
def bind(action):
 rig.animation_data_create();rig.animation_data.action=None
 for b in rig.pose.bones:
  for k,v in neutral[b.name].items():setattr(b,k,v)
 rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
def render(label,view,frames):
 scene.camera=bpy.data.objects['Showcase_'+view.upper()];folder=HERE/'renders'/label/view;folder.mkdir(parents=True,exist_ok=True)
 for number,f in frames:
  path=folder/f'{number:03d}.png'
  if path.exists():continue
  scene.frame_set(int(f),subframe=f%1);scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
bind(source);bpy.data.objects['ASR_FixedFloor'].location.z=manifest['preview_floor_z_m']
# Full six-second3/4 take. Primary comparison sourcewindow uses F66–133.
render('source_full','THREE_QUARTER'.lower(),[(i,i)for i in range(1,181)])
for view in ['front','side']:
 render('source',view,[(i+1,66+i)for i in range(68)])
bind(approved);bpy.data.objects['ASR_FixedFloor'].location.z=0
for view in ['front','three_quarter','side']:
 # Both integer and half-frame sampling are rendered. Repeating exact17-frame
 # approvedmotion is valid; its different clock is explicitly preserved.
 render('approved',view,[(i+1,1+((i-10+8.5)%17))for i in range(17)])
# Diagnostic only: same source channels, observed video stride clock; bob stays
# at original lifetime. No new Action, no source curve or file edits.
rig.animation_data_clear()
for b in rig.pose.bones:
 for k,v in neutral[b.name].items():setattr(b,k,v)
bpy.context.view_layer.update();mapper=Retarget(rig)
source_motion.RATE=30/17;source_motion.PROFILE['phase_origin']=-(30/17)*2.5
bpy.data.objects['ASR_FixedFloor'].location.z=manifest['preview_floor_z_m'];scene.camera=bpy.data.objects['Showcase_FRONT']
folder=HERE/'renders/video_cadence_diagnostic/front';folder.mkdir(parents=True,exist_ok=True)
for i in range(68):
 path=folder/f'{i+1:03d}.png'
 if path.exists():continue
 d=mapper.desired((65+i)/30)
 for b in rig.data.bones:
  kw={}if not b.parent else{'parent_matrix':d[b.parent.name],'parent_matrix_local':b.parent.matrix_local}
  rig.pose.bones[b.name].matrix_basis=b.convert_local_to_pose(d[b.name],b.matrix_local,invert=True,**kw)
 bpy.context.view_layer.update();scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
assert ui.action_signature(source)==manifest['action_sha256']
assert hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest()==manifest['source_sha256']
(HERE/'render_provenance.json').write_text(json.dumps(proof,indent=2));print('SOURCE_REVIEW_RENDERS_COMPLETE',flush=True)
