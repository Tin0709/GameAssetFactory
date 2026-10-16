"""Build v003 from freshly read pack. v002 is never loaded or sampled."""
import bpy,sys,json,hashlib,math,argparse
from pathlib import Path
from mathutils import Matrix,Vector
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').is_file());A=Path(__file__).resolve().parent;O=A.parent
sys.path.insert(0,str(A));sys.path.insert(0,str(ROOT/'blender/animation/showcase'))
import gaf_animation_library as ui
from extract_source import extract
from source_sampler import Sampler,DURATION,HZ,SEED
from source_retarget import RifleRetarget
p=argparse.ArgumentParser();p.add_argument('--pack',required=True);p.add_argument('--cache',required=True);p.add_argument('--rebuild-pending',action='store_true');opt=p.parse_args(sys.argv[sys.argv.index('--')+1:])
NAME='Rifle_Ready_Idle_ActionsStyle_v003';cache=Path(opt.cache);payload=extract(opt.pack,cache)
assert hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest()=='22017e77d5a722d087c46bd839e38fbec5a30ac5a56bb4b326e86cbbbbee3fde'
source=O/'rifle_ready_idle_actionsstyle_v003.blend';manifest=json.loads((ROOT/'blender/animation/showcase/animation_manifest.json').read_text())
assert not any(e['action']==NAME and e['status']=='approved' for e in manifest['animations'])
if source.exists() and not opt.rebuild_pending:raise RuntimeError('Existing Pending candidate preserved; explicit rebuild required')
rig=bpy.data.objects[ui.RIG];mesh=bpy.data.objects['Showcase_Player_Mesh'];scene=bpy.context.scene
before={a.name:ui.action_signature(a) for a in bpy.data.actions};scene.frame_set(1);bpy.context.view_layer.update()
weapon_geometry=[]
for name in ['Rifle_V2_Body','Rifle_V2_Magazine']:
 obj=bpy.data.objects[name];obj.data.calc_loop_triangles();weapon_geometry.append(([obj.matrix_world@v.co for v in obj.data.vertices],[tuple(t.vertices) for t in obj.data.loop_triangles]))
approved={b.name:b.matrix.copy() for b in rig.pose.bones};rest={b.name:b.bone.matrix_local.copy() for b in rig.pose.bones}
rig.animation_data.action=None
for n,values in json.loads(bpy.data.texts[ui.BASELINE].as_string()).items():
 for prop,v in values.items():setattr(rig.pose.bones[n],prop,v)
bpy.context.view_layer.update()
sampler=Sampler(payload);times=sampler.times();mapper=RifleRetarget(rig,mesh,approved,sampler.value(0.),weapon_geometry)
values=[];basis_error=0.;forearm_error=0.;native_targets=[]
for t in times:
 M,raw=mapper.desired(sampler.value(t));row={}
 for bone in rig.data.bones:
  args={} if not bone.parent else {'parent_matrix':M[bone.parent.name],'parent_matrix_local':rest[bone.parent.name]}
  b=bone.convert_local_to_pose(M[bone.name],rest[bone.name],invert=True,**args)
  if bone.name.startswith('ForeArm.'):
   forearm_error=max(forearm_error,max(abs(b[i][j]-float(i==j)) for i in range(4) for j in range(4)));b=Matrix.Identity(4)
  pos,q,scale=b.decompose();assert max(abs(s-1) for s in scale)<1e-5
  rebuilt=Matrix.Translation(pos)@q.to_matrix().to_4x4();basis_error=max(basis_error,max(abs(b[i][j]-rebuilt[i][j]) for i in range(4) for j in range(4)))
  row[bone.name]=(pos.copy(),q.copy(),Vector((1,1,1)))
 values.append(row)
assert forearm_error<1e-5 and basis_error<1e-5
act=bpy.data.actions.new(NAME);slot=act.slots.new(id_type='OBJECT',name='RUN_Test_Rig');bag=act.layers.new('Pack crossbow graph | literal240Hz PRS | rifle constraints').strips.new(type='KEYFRAME').channelbag(slot,ensure=True)
# Keep the existing registered slot identifier, rather than depending on new naming.
assert slot.identifier=='OBRUN_Test_Rig'
for bone in rig.pose.bones:
 prop='rotation_quaternion' if bone.rotation_mode=='QUATERNION' else 'rotation_euler';previous=None;data={'location':[],prop:[],'scale':[]}
 for row in values:
  pos,q,scale=row[bone.name]
  if prop=='rotation_quaternion':
   q=q.copy()
   if previous is not None and q.dot(previous)<0:q.negate()
   rot=q;previous=q.copy()
  else:rot=q.to_euler(bone.rotation_mode,previous) if previous is not None else q.to_euler(bone.rotation_mode);previous=rot.copy()
  data['location'].append(list(pos));data[prop].append(list(rot));data['scale'].append(list(scale))
 for prop,array in data.items():
  for axis in range(len(array[0])):
   fc=bag.fcurves.new(bone.path_from_id(prop),index=axis);fc.keyframe_points.add(len(times));fc.keyframe_points.foreach_set('co',[x for t,v in zip(times,array) for x in [1+t*30,v[axis]]])
   for k in fc.keyframe_points:k.interpolation='LINEAR'
   fc.modifiers.new('CYCLES');fc.update()
act.use_fake_user=True;act['research_only']=True;act['production_eligible']=False;act['source_pack_sha256']='9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d'
rig.animation_data.action=act;rig.animation_data.action_slot=slot;scene.frame_start=1;scene.frame_end=324;scene.frame_set(1);scene.render.fps=30;scene.render.fps_base=1.;scene.camera=bpy.data.objects['Showcase_THREE_QUARTER'];ui.show_preview_prop(scene,{'preview_prop':'rifle_stylized_v2'});scene['gaf_library_last_action']=NAME
assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in before.items())
bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True,check_existing=False)
entry={'action':NAME,'source':source.relative_to(ROOT).as_posix(),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'source_rig':rig.name,'source_mesh':mesh.name,'source_armature':rig.data.name,'slot_identifier':slot.identifier,'action_sha256':ui.action_signature(act),'action_frame_range':list(act.frame_range),'start':1,'end':324,'fps':30,'fps_base':1.,'status':'pending','approval_note':'New literal crossbow source-graph reconstruction, Pending Blender review. Rifle grip/left support/boot contact adapters documented; no gameplay integration.','seamless_loop':True,'research_only':True,'production_eligible':False,'source_derived_reconstruction':True,'original_custom_animation':False,'source_pack_sha256':act['source_pack_sha256'],'source_animations':['animation.oreville_ans.rrvlnm','animation.oreville_ans.dubgwy','animation.oreville_ans.jcyjaa','animation.oreville_ans.cndmcx','animation.oreville_ans.boabcq'],'source_controllers':['controller.animation.oreville_ans.njvelc','controller.animation.oreville_ans.fotixv','controller.animation.oreville_ans.iplurh','controller.animation.oreville_ans.xunqct'],'rotation_modes':{b.name:b.rotation_mode for b in rig.pose.bones},'preview_prop':'rifle_stylized_v2','preview_prop_source':'blender/weapons/rifle_stylized_v2/Rifle_Stylized_V2.blend','preview_prop_source_sha256':'0d8c2d0fb05e8be82d5c2a3485eb3cd1a40acdc70c1e656ed2f4322e17bad03f','bake_hz':HZ,'random_seed':SEED,'source_profile':'ordinary player0, mainhand crossbow, uncharged, no offhand, dry standing; prior movement and12s attack-free age','source_duration_s':DURATION,'endpoint_sample_frame':325}
ui.validate_action(act,entry,rig);(O/'entry.json').write_text(json.dumps(entry,indent=2))
changes=[];last=None
for r in sampler.rows:
 state=(r['controllers']['kcexxa']['state'],r['controllers']['bjmscc']['state'])
 if state!=last:changes.append([r['time_s'],state]);last=state
report={'passed':True,'source_pack_read_this_build':str(opt.pack),'source_files':{a:sampler.runtime.payload['files'][sampler.runtime.channels.aliases[a]] for a in ['mshwsb','tcucxa','tculwn','look_at_target','xfltzh']},'duration_s':DURATION,'sample_count':len(times),'sampler_hz':HZ,'basis_error':basis_error,'forearm_error':forearm_error,'adapters_maximum':mapper.maximum,'source_controller_events':changes,'source_random_draws':sampler.runtime.random_draws,'source_loop_channel_error':max(abs(sampler.value(0)[b][c][i]-sampler.value(DURATION)[b][c][i]) for b in sampler.value(0) for c in sampler.value(0)[b] for i in range(3)),'candidate_sha256':entry['source_sha256'],'action_sha256':entry['action_sha256'],'existing_source_actions_preserved':len(before),'v002_loaded_or_sampled':False}
(O/'source_build_validation.json').write_text(json.dumps(report,indent=2));(cache/'simulation_trace.json').write_text(json.dumps(sampler.rows,separators=(',',':')));(cache/'sample_times.json').write_text(json.dumps(times));print('V003_SOURCE_BUILT',json.dumps(report),flush=True)
