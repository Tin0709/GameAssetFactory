"""Render changed poses; reuse only verified identical poses and presentation."""
import bpy,json,hashlib,sys,shutil
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];OLD=ROOT/'.validation/idle_expressive_test_v3/before_short_center_revision/study';SIGNATURE=OLD.parent/'presentation_signature.json'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def presentation(s):
 return {'render':{p:getattr(s.render,p) for p in ['engine','resolution_x','resolution_y','resolution_percentage','film_transparent']},'cycles':{p:getattr(s.cycles,p) for p in ['samples','use_denoising','use_adaptive_sampling','adaptive_threshold','seed','use_animated_seed']},'view':{p:getattr(s.view_settings,p) for p in ['view_transform','look','exposure','gamma']},'cameras':{n:{'matrix':[list(x) for x in bpy.data.objects[n].matrix_world],'data':{p:getattr(bpy.data.objects[n].data,p) for p in ['type','lens','ortho_scale','shift_x','shift_y','clip_start','clip_end']}} for n in ['Showcase_FRONT','Showcase_THREE_QUARTER','Showcase_SIDE']},'lights':{o.name:{'matrix':[list(x) for x in o.matrix_world],'type':o.data.type,'energy':o.data.energy,'color':list(o.data.color)} for o in bpy.data.objects if o.type=='LIGHT'}}
s=bpy.context.scene
if 'capture' in sys.argv:
 assert sha(Path(bpy.data.filepath))==json.loads((OLD/'validation.json').read_text())['sampled_source_sha256'];SIGNATURE.write_text(json.dumps(presentation(s),indent=2));print('PRIOR PRESENTATION CAPTURED',flush=True);raise SystemExit
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
assert presentation(s)==json.loads(SIGNATURE.read_text())
r=bpy.data.objects['IEV3_Test_Rig'];m=bpy.data.objects['IEV3_Test_Mesh'];a=bpy.data.actions['Idle_Expressive_Test_v3'];r.animation_data.action=a;r.animation_data.action_slot=a.slots[0]
prior=json.loads((OLD/'validation.json').read_text());oldstamp=json.loads((OLD/'checkpoint_provenance.json').read_text());assert prior['passed'] and oldstamp['complete'] and sha(OLD/'idle_expressive_v3_review.blend')==prior['sampled_source_sha256']==oldstamp['source_sha256']
previous={int(f['frame']):[Vector(v) for v in f['vertices']] for f in prior['frames']};same=[]
for f in range(1,241):
 s.frame_set(f);e=m.evaluated_get(bpy.context.evaluated_depsgraph_get());verts=[e.matrix_world@v.co for v in e.data.vertices]
 if max((x-y).length for x,y in zip(verts,previous[f]))<1e-9:same.append(f)
folder=OUT/'checkpoint_frames';folder.mkdir();motion=folder/'three_quarter';motion.mkdir();s.render.use_persistent_data=True
stamp={'source_sha256':sha(Path(bpy.data.filepath)),'action_sha256':ui.action_signature(a),'fps':30,'range':[1,240],'presentation':'Original cameras/lights/materials. Unchanged frames reused only after exact saved-pose and presentation checks; changed poses freshly rendered.','prior_source_sha256':prior['sampled_source_sha256'],'reused_frames':same,'maximum_reused_pose_error_m':1e-9,'presentation_signature_identical':True}
for view in ['FRONT','THREE_QUARTER','SIDE']:
 s.camera=bpy.data.objects['Showcase_'+view]
 for f in [1,61]:
  p=folder/f'{view.lower()}_{f:04d}.png';old=OLD/'checkpoint_frames'/p.name
  if f in same:
   assert sha(old)==oldstamp['frames']['checkpoint_frames/'+p.name];shutil.copy2(old,p)
  else:s.frame_set(f);s.render.filepath=str(p);bpy.ops.render.render(write_still=True)
stamp.update({'frames':{p.relative_to(OUT).as_posix():sha(p) for p in folder.glob('*.png')},'stills_complete':True,'complete':False});(OUT/'checkpoint_provenance.json').write_text(json.dumps(stamp,indent=2))
s.camera=bpy.data.objects['Showcase_THREE_QUARTER'];print('VERIFIED IDENTICAL FRAMES TO REUSE',len(same),flush=True)
for f in range(1,241):
 p=motion/f'{f:04d}.png'
 if f in same:
  old=OLD/'checkpoint_frames/three_quarter'/p.name;assert sha(old)==oldstamp['frames']['checkpoint_frames/three_quarter/'+p.name];shutil.copy2(old,p)
 else:s.frame_set(f);s.render.filepath=str(p);bpy.ops.render.render(write_still=True)
assert sha(Path(bpy.data.filepath))==stamp['source_sha256']
stamp.update({'frames':{p.relative_to(OUT).as_posix():sha(p) for p in folder.rglob('*.png')},'complete':True});assert len(stamp['frames'])==246
(OUT/'checkpoint_provenance.json').write_text(json.dumps(stamp,indent=2));print('TIMING REFINEMENT RENDER COMPLETE',flush=True)
