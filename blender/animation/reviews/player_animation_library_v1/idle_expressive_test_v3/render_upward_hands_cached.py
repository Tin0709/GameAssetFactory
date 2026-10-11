"""Reuse only byte-verified frames with identical evaluated pose and presentation."""
import bpy,json,hashlib,shutil,runpy
from pathlib import Path
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];OLD=ROOT/'.validation/idle_expressive_test_v3/before_upward_hands_revision/study'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def environment():
 s=bpy.context.scene
 def nodes(tree):
  result=[]
  if tree:
   for n in tree.nodes:
    defaults=[]
    for x in n.inputs:
     if hasattr(x,'default_value'):
      v=x.default_value;defaults.append((x.name,list(v) if hasattr(v,'__len__') and not isinstance(v,str) else v))
    result.append((n.name,n.type,defaults))
  return result
 objects=[]
 for o in bpy.data.objects:
  if o.type=='ARMATURE' or o.name=='IEV3_Test_Mesh':continue
  assert o.animation_data is None
  data={'name':o.name,'type':o.type,'matrix':[list(x) for x in o.matrix_world],'hide_render':o.hide_render}
  if o.type=='CAMERA':data.update({'camera':[o.data.type,o.data.lens,o.data.ortho_scale,o.data.shift_x,o.data.shift_y,o.data.clip_start,o.data.clip_end,o.data.dof.use_dof,o.data.dof.focus_distance]})
  if o.type=='LIGHT':data.update({'light':[o.data.type,o.data.energy,list(o.data.color),getattr(o.data,'size',None)]})
  if o.type=='MESH':data.update({'vertices':[list(v.co) for v in o.data.vertices],'polygons':[list(p.vertices) for p in o.data.polygons],'materials':[(m.name,nodes(m.node_tree)) for m in o.data.materials]})
  objects.append(data)
 return {'objects':objects,'world':nodes(s.world.node_tree),'render':[s.render.engine,s.render.resolution_x,s.render.resolution_y,s.render.resolution_percentage,s.render.film_transparent,s.render.image_settings.file_format,s.cycles.samples,s.cycles.use_denoising,s.cycles.seed,s.cycles.use_animated_seed],'color':[s.view_settings.view_transform,s.view_settings.look,s.view_settings.exposure,s.view_settings.gamma]}
source=Path(bpy.data.filepath);new_env=environment();bpy.ops.wm.open_mainfile(filepath=str(OLD/'idle_expressive_v3_review.blend'));old_env=environment();assert new_env==old_env,'Render environment differs; do not reuse'
bpy.ops.wm.open_mainfile(filepath=str(source))
v=json.loads((OUT/'validation.json').read_text());old=json.loads((OLD/'validation.json').read_text());stamp=json.loads((OLD/'checkpoint_provenance.json').read_text())
assert v['passed'] and old['passed'] and stamp['complete'] and sha(source)==v['sampled_source_sha256'] and sha(OLD/'idle_expressive_v3_review.blend')==stamp['source_sha256']==old['sampled_source_sha256']
assert v['appearance_rest_weights_uv_materials_images_lights_unchanged'] and old['appearance_rest_weights_uv_materials_images_lights_unchanged']
folder=OUT/'checkpoint_frames';motion=folder/'three_quarter';motion.mkdir(exist_ok=True);reused={}
for current,prior in zip(v['frames'][:240],old['frames'][:240]):
 assert current['frame']==prior['frame'];f=int(current['frame'])
 error=max(abs(a-b) for p,q in zip(current['vertices'],prior['vertices']) for a,b in zip(p,q))
 if error>1e-6:continue
 oldfile=OLD/'checkpoint_frames/three_quarter'/f'{f:04d}.png';assert sha(oldfile)==stamp['frames'][oldfile.relative_to(OLD).as_posix()]
 shutil.copy2(oldfile,motion/oldfile.name);reused[str(f)]={'geometry_error_m':error,'image_sha256':sha(oldfile)}
report={'source_sha256':v['sampled_source_sha256'],'previous_source_sha256':old['sampled_source_sha256'],'presentation_identical':True,'appearance_identical':True,'reused_frames':reused,'reused_count':len(reused),'rerendered_count':240-len(reused),'note':'Only evaluated-pose-identical frames reuse prior native pixels. Changed hand-motion frames render anew.'}
(OUT/'unchanged_frame_reuse.json').write_text(json.dumps(report,indent=2));print('VERIFIED NATIVE FRAME REUSE',len(reused),flush=True)
runpy.run_path(str(OUT/'render_checkpoint.py'),run_name='__main__')
