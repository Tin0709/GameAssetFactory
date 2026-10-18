import bpy,json,sys,hashlib,math
from pathlib import Path
from mathutils import Matrix,Vector
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').exists());S=Path(__file__).resolve().parent.parent;sys.path.insert(0,str(S));sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
from motion import Motion
N='Rifle_Aim_Hold_ActionsStyle_v001';
if any(e['action']==N and e['status']=='approved' for e in json.loads((R/'blender/animation/showcase/animation_manifest.json').read_text())['animations']):raise RuntimeError('Never overwrite an approved Aim Action')
r=bpy.data.objects[ui.RIG];mesh=bpy.data.objects['Showcase_Player_Mesh'];s=bpy.context.scene;mf=json.loads((R/'blender/animation/showcase/animation_manifest.json').read_text());e0=next(e for e in mf['animations'] if e['action']=='Rifle_Ready_Idle_ActionsStyle_v004');assert e0['status']=='approved';base=bpy.data.actions[e0['action']];assert ui.action_signature(base)==e0['action_sha256'];assert N not in bpy.data.actions
r.animation_data.action=base;r.animation_data.action_slot=base.slots[0];s['gaf_library_last_action']=base.name;s.frame_set(1);bpy.context.view_layer.update();B={b.name:b.matrix.copy() for b in r.pose.bones};mo=Motion(r,B);P=json.loads((S/'aim_parameters.json').read_text());r.animation_data.action=None;before={a.name:ui.action_signature(a) for a in bpy.data.actions}
values=[];previous={};times=[i/240 for i in range(1729)];max_basis_error=0.
for t in times:
 M=mo.value(t,P);row={}
 for b in r.data.bones:
  kw={} if not b.parent else {'parent_matrix':M[b.parent.name],'parent_matrix_local':mo.rest[b.parent.name]};L=b.convert_local_to_pose(M[b.name],mo.rest[b.name],invert=True,**kw);pos,q,sc=L.decompose();assert max(abs(x-1) for x in sc)<1e-5
  if b.name in previous and q.dot(previous[b.name])<0:q.negate()
  previous[b.name]=q.copy();row[b.name]=(pos.copy(),q.copy(),Vector((1,1,1)))
  if b.name.startswith('ForeArm'):assert max(abs(L[a][b]-float(a==b)) for a in range(4) for b in range(4))<1e-5
 values.append(row)
a=bpy.data.actions.new(N);slot=a.slots.new(id_type='OBJECT',name='RUN_Test_Rig');bag=a.layers.new('One Ready Aim Hold Ready | straight arms | rifle constraints').strips.new(type='KEYFRAME').channelbag(slot,ensure=True)
for b in r.pose.bones:
 prop='rotation_quaternion' if b.rotation_mode=='QUATERNION' else 'rotation_euler';data={'location':[],'scale':[],prop:[]};prev=None
 for row in values:
  pos,q,scale=row[b.name];rot=q if prop=='rotation_quaternion' else q.to_euler(b.rotation_mode,prev) if prev is not None else q.to_euler(b.rotation_mode);prev=rot.copy()
  for k,v in [('location',pos),('scale',scale),(prop,rot)]:data[k].append(list(v))
 for key,rows in data.items():
  for axis in range(len(rows[0])):
   c=bag.fcurves.new(b.path_from_id(key),index=axis);c.keyframe_points.add(len(times));c.keyframe_points.foreach_set('co',[x for t,row in zip(times,rows) for x in [1+t*30,row[axis]]])
   for k in c.keyframe_points:k.interpolation='LINEAR'
   c.modifiers.new('CYCLES');c.update()
a.use_fake_user=True;a['research_only']=True;a['production_eligible']=False;a['visual_base']=base.name;a['hold_start_frame']=37.;a['hold_end_frame']=145.;a['source_aim_reference']='knoyhk.gjhnog / jawwtn + asxvzc, rrvlnm then dubgwy; custom rifle adaptation'
r.animation_data.action=a;r.animation_data.action_slot=slot;s['gaf_library_last_action']=N;s.frame_start=1;s.frame_end=216;s.render.fps=30;s.render.fps_base=1.;s.frame_set(1);s.camera=bpy.data.objects['Showcase_THREE_QUARTER'];ui.show_preview_prop(s,{'preview_prop':'rifle_stylized_v2'})
assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in before.items())
out=S/'rifle_aim_hold_actionsstyle_v001.blend';bpy.ops.wm.save_as_mainfile(filepath=str(out),compress=True,check_existing=False)
e={k:v for k,v in e0.items() if k in ['source_rig','source_mesh','source_armature','slot_identifier','rotation_modes','preview_prop','preview_prop_source','preview_prop_source_sha256','source_pack_sha256']};e.update(action=N,source='blender/animation/reviews/player_animation_library_v1/rifle_aim_hold_actionsstyle_v001/rifle_aim_hold_actionsstyle_v001.blend',source_sha256=hashlib.sha256(out.read_bytes()).hexdigest(),action_sha256=ui.action_signature(a),action_frame_range=[1.,217.],start=1,end=216,fps=30,fps_base=1.,status='pending',approval_note='One new Blender Aim/Hold candidate requested2026-10-18; Pending visual review. No Godot integration.',seamless_loop=True,research_only=True,production_eligible=False,source_derived_reconstruction=False,original_custom_animation=True,contains_source_derived_base_pose=True,bake_hz=240,source_duration_s=7.2,endpoint_sample_frame=217,ready_base=base.name,phases={'Ready':[1,19],'Raise':[19,37],'Hold':[37,145],'Lower':[145,163],'Ready_return':[163,217]},hold_loop_range=[37,145],source_animations=['animation.oreville_ans.rrvlnm','animation.oreville_ans.dubgwy','animation.oreville_ans.jawwtn','animation.oreville_ans.asxvzc'],source_controllers=['controller.animation.oreville_ans.njvelc','controller.animation.oreville_ans.knoyhk'],rig_adaptations=P)
ui.validate_action(a,e,r);(S/'entry.json').write_text(json.dumps(e,indent=2));(S/'source_actions_before.json').write_text(json.dumps(before,indent=2));print('BUILT_ONE_AIM_ACTION',N,len(times),e['action_sha256'],flush=True)
