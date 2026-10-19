import bpy,json,sys,hashlib,math
from pathlib import Path
from mathutils import Matrix,Vector
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').is_file());S=Path(__file__).resolve().parent.parent;sys.path.insert(0,str(S));sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
from motion import RifleFit
N='Rifle_Aim_Hold_ActionsStyle_v001';BASE='Crossbow_Aim_ActionsStuff_Source_Test_v001';r=bpy.data.objects[ui.RIG];s=bpy.context.scene;a0=bpy.data.actions[BASE];mf=json.loads((R/'blender/animation/showcase/animation_manifest.json').read_text());be=next(e for e in mf['animations'] if e['action']==BASE);old=next(e for e in mf['animations'] if e['action']==N);assert old['status']=='pending';
if (S/'rifle_aim_hold_actionsstyle_v001.blend').exists():raise RuntimeError('Preserve existing result. Rebuild in a backed-up working copy with an explicit output path.')
assert ui.action_signature(a0)==be['action_sha256'];assert N not in bpy.data.actions
before={a.name:ui.action_signature(a) for a in bpy.data.actions};r.animation_data.action=a0;r.animation_data.action_slot=a0.slots[0];s['gaf_library_last_action']=BASE;s.frame_set(1);bpy.context.view_layer.update();B={b.name:b.matrix.copy() for b in r.pose.bones};rest={b.name:b.matrix_local.copy() for b in r.data.bones};P=json.loads((S/'parameters.json').read_text());fit=RifleFit(r,B,P);times=[i/240 for i in range(865)];values=[];targets=[];forearm=0.;scaleerror=0.
for t in times:
 f=1+t*30;s.frame_set(math.floor(f),subframe=f%1);bpy.context.view_layer.update();source={b.name:b.matrix.copy() for b in r.pose.bones};M=fit.value(source);row={}
 for b in r.data.bones:
  kw={} if not b.parent else {'parent_matrix':M[b.parent.name],'parent_matrix_local':rest[b.parent.name]};L=b.convert_local_to_pose(M[b.name],rest[b.name],invert=True,**kw);p,q,sc=L.decompose();scaleerror=max(scaleerror,max(abs(x-1) for x in sc))
  if b.name.startswith('ForeArm.'):forearm=max(forearm,max(abs(L[i][j]-float(i==j)) for i in range(4) for j in range(4)))
  row[b.name]=(p.copy(),q.copy(),Vector((1,1,1)))
 values.append(row);targets.append(M)
assert max(forearm,scaleerror)<1e-5
act=bpy.data.actions.new(N);slot=act.slots.new(id_type='OBJECT',name='RUN_Test_Rig');bag=act.layers.new('Source charged hold rhythm | reference rifle grip adapter').strips.new(type='KEYFRAME').channelbag(slot,ensure=True)
for b in r.pose.bones:
 prop='rotation_quaternion' if b.rotation_mode=='QUATERNION' else 'rotation_euler';data={'location':[],'scale':[],prop:[]};prev=None
 for row in values:
  p,q,sc=row[b.name];q=q.copy()
  if prop=='rotation_quaternion':
   if prev is not None and q.dot(prev)<0:q.negate()
   rot=q
  else:rot=q.to_euler(b.rotation_mode,prev) if prev is not None else q.to_euler(b.rotation_mode)
  prev=rot.copy()
  for k,v in [('location',p),('scale',sc),(prop,rot)]:data[k].append(list(v))
 for prop,arr in data.items():
  for axis in range(len(arr[0])):
   fc=bag.fcurves.new(b.path_from_id(prop),index=axis);fc.keyframe_points.add(len(times));fc.keyframe_points.foreach_set('co',[x for t,v in zip(times,arr) for x in [1+t*30,v[axis]]])
   for k in fc.keyframe_points:k.interpolation='LINEAR'
   fc.modifiers.new('CYCLES');fc.update()
act.use_fake_user=True;act['research_only']=True;act['production_eligible']=False;act['visual_base']=BASE;act['source_pack_sha256']=be['source_pack_sha256'];act['adaptation']='reference-image rifle placement and rigid two-hand contact fitting; source body/legs/lifetime retained'
r.animation_data.action=act;r.animation_data.action_slot=slot;s['gaf_library_last_action']=N;s.frame_start=1;s.frame_end=108;s.render.fps=30;s.render.fps_base=1.;s.frame_set(1);ui.show_preview_prop(s,{'preview_prop':'rifle_stylized_v2'});s.camera=bpy.data.objects['Showcase_THREE_QUARTER']
assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in before.items())
out=S/'rifle_aim_hold_actionsstyle_v001.blend';bpy.ops.wm.save_as_mainfile(filepath=str(out),compress=True,check_existing=False)
e=dict(be);e.update(action=N,source='blender/animation/reviews/player_animation_library_v1/rifle_aim_hold_actionsstyle_v001/source_pose_rifle_fit_20261019/rifle_aim_hold_actionsstyle_v001.blend',source_sha256=hashlib.sha256(out.read_bytes()).hexdigest(),action_sha256=ui.action_signature(act),action_frame_range=list(act.frame_range),start=1,end=108,status='pending',approval_note='Same Pending rifle Aim refined from accepted literal crossbow pose and user rifle-reference images2026-10-19. Blender-only review.',visual_base=BASE,visual_base_action_sha256=be['action_sha256'],rig_adaptations=P,previous_pending_source={k:old[k] for k in ['source','source_sha256','action_sha256']},source_derived_reconstruction=True,original_custom_animation=False,contains_source_derived_base_pose=True,review_scope='Source-clock rifle aiming HOLD only; previous Ready→Aim→Hold→Ready source/timeline preserved in previous_pending_source.');ui.validate_action(act,e,r);(S/'entry.json').write_text(json.dumps(e,indent=2));(S/'source_actions_before.json').write_text(json.dumps(before,indent=2));(S/'fit_stats.json').write_text(json.dumps(fit.stats,indent=2));print('FIT_STATS',fit.stats,flush=True)
# Review stills; presentation-only render settings are never saved into the source.
s.render.engine='BLENDER_EEVEE';s.render.resolution_x=640;s.render.resolution_y=640;s.render.resolution_percentage=100;s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG'
if hasattr(s.eevee,'taa_render_samples'):s.eevee.taa_render_samples=32
mirror=Matrix.Diagonal(Vector((-1.,1.,1.,1.)));op=bpy.data.objects['Showcase_THREE_QUARTER'].copy();op.data=op.data.copy();op.name='Showcase_THREE_QUARTER_OPPOSITE';s.collection.objects.link(op);op.matrix_world=mirror@op.matrix_world@mirror
for view in ['FRONT','THREE_QUARTER','SIDE','THREE_QUARTER_OPPOSITE']:
 c=bpy.data.objects['Showcase_'+view];c.data=c.data.copy();c.data.ortho_scale*=1.18;s.camera=c;s.render.filepath=str(S/('pose_'+view.lower()+'.png'));bpy.ops.render.render(write_still=True)
