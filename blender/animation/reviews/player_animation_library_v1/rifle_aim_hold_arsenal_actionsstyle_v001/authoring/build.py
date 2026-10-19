import bpy,json,sys,math,hashlib
from pathlib import Path
from mathutils import Matrix
S=Path(__file__).resolve().parent;R=next(p for p in Path(bpy.data.filepath).resolve().parents if (p/'AGENTS.md').is_file());sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
BASE='Rifle_Aim_Hold_ActionsStyle_v001';N='Rifle_Aim_Hold_Arsenal_ActionsStyle_v001';r=bpy.data.objects[ui.RIG];s=bpy.context.scene;old=json.loads((S/'baseline_entry.json').read_text());a0=bpy.data.actions[BASE];assert ui.action_signature(a0)==old['action_sha256'];assert N not in bpy.data.actions
before={a.name:ui.action_signature(a) for a in bpy.data.actions};P=json.loads((S/'parameters.json').read_text());T={n:Matrix(v) for n,v in json.loads((S/'static_pose.json').read_text()).items()};rest={b.name:b.matrix_local.copy() for b in r.data.bones}
r.animation_data.action=a0;r.animation_data.action_slot=a0.slots[0];s['gaf_library_last_action']=BASE;s.frame_set(1);M0={b.name:b.matrix.copy() for b in r.pose.bones};times=[i/240 for i in range(865)];values={n:[] for n in ['UpperArm.L','UpperArm.R','WeaponCarrier','Head']};baseline_samples=[]
for j,t in enumerate(times):
 f=1+30*t;s.frame_set(math.floor(f),subframe=f%1);bpy.context.view_layer.update();M={b.name:b.matrix.copy() for b in r.pose.bones};D=M['UpperArm.R']@M0['UpperArm.R'].inverted();DH=M['Head']@M0['Head'].inverted()
 if j%4==0:baseline_samples.append({n:[list(row) for row in m] for n,m in M.items()})
 for n in values:
  new=(DH if n=='Head' else D)@T[n];b=r.data.bones[n];L=b.convert_local_to_pose(new,rest[n],invert=True,parent_matrix=M[b.parent.name],parent_matrix_local=rest[b.parent.name]);loc,q,sc=L.decompose();assert max(abs(v-1) for v in sc)<1e-5;values[n].append((loc,q))
(S/'baseline_world_samples.json').write_text(json.dumps(baseline_samples));act=a0.copy();act.name=N;act.use_fake_user=True;paths={r.pose.bones[n].path_from_id(p) for n in values for p in ['location','rotation_quaternion']};curves0=[fc for l in a0.layers for st in l.strips for b in st.channelbags for fc in b.fcurves];curves=[fc for l in act.layers for st in l.strips for b in st.channelbags for fc in b.fcurves];changed=0
for n,rows in values.items():
 prev=None;qs=[]
 for loc,q in rows:
  q=q.copy()
  if prev is not None and prev.dot(q)<0:q.negate()
  qs.append(q);prev=q
 for prop,arr in [('location',[v[0] for v in rows]),('rotation_quaternion',qs)]:
  path=r.pose.bones[n].path_from_id(prop)
  for fc in [fc for fc in curves if fc.data_path==path]:
   assert len(fc.keyframe_points)==len(times);fc.keyframe_points.foreach_set('co',[a for t,row in zip(times,arr) for a in [1+t*30,row[fc.array_index]]]);fc.update();changed+=1
assert changed==28
def fcd(fc):return [(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type) for k in fc.keyframe_points]
assert all(fcd(a)==fcd(b) for a,b in zip(curves0,curves) if a.data_path not in paths)
act['research_only']=True;act['production_eligible']=False;act['adaptation']='Arsenal two-hand pose under declared vanilla mainhand holding profile; original A&S idle clocks, native rifle/head/shoulder contact adapters.';r.animation_data.action=act;r.animation_data.action_slot=act.slots[0];s['gaf_library_last_action']=N;s.frame_set(85);s.frame_start=1;s.frame_end=108;s.render.fps=30;s.render.fps_base=1.;ui.show_preview_prop(s,{'preview_prop':'rifle_stylized_v2'});assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in before.items());out=S/'rifle_aim_hold_arsenal_actionsstyle_v001.blend';bpy.ops.wm.save_as_mainfile(filepath=str(out),compress=True,check_existing=False)
e={k:v for k,v in old.items() if k not in ['rig_adaptations','previous_pending_source','user_reference','visual_base','visual_base_action_sha256','source_profile','approval_note','source_controllers','source_animations']};e.update(action=N,source='blender/animation/reviews/player_animation_library_v1/rifle_aim_hold_arsenal_actionsstyle_v001/rifle_aim_hold_arsenal_actionsstyle_v001.blend',source_sha256=hashlib.sha256(out.read_bytes()).hexdigest(),action_sha256=ui.action_signature(act),status='pending',approval_note='New Arsenal two-hand hold + Actions & Stuff idle composite. Pending artistic review; previous Aim remains unchanged.',visual_base=BASE,visual_base_action_sha256=old['action_sha256'],source_animations=['animation.arsenal.2_hands.third_person','animation.player.move.arms','animation.player.holding','animation.arsenal.awm.third_person_hold','animation.oreville_ans.rrvlnm','animation.oreville_ans.dubgwy','animation.oreville_ans.jawwtn','animation.oreville_ans.asxvzc'],source_controllers=['controller.animation.player.third_person','controller.animation.oreville_ans.njvelc','controller.animation.oreville_ans.knoyhk'],source_profile='Arsenal neutral two-hand mainhand, vanilla holding-right1/left0, target pitch/yaw0; A&S neutral charged-hold rhythm replaces vanilla bob.',arsenal_source_sha256=json.loads((S/'source_reference.json').read_text())['arsenal_archive_sha256'],rig_adaptations=P,review_scope='3.6s stationary aiming hold, two continuous original-speed review cycles; no invented Ready transition.',source_derived_composite=True)
ui.validate_action(act,e,r);(S/'entry.json').write_text(json.dumps(e,indent=2));(S/'source_actions_before.json').write_text(json.dumps(before,indent=2));(S/'curve_preservation.json').write_text(json.dumps({'passed':True,'edited_curves':changed,'untouched_curves_exact':len(curves)-changed,'all_existing_actions_exact':len(before),'body_hips_legs_forearm_scales_exact':True,'same_original_idle_clocks_s':[.9,1.8,3.6]},indent=2));print('BUILT',N,e['action_sha256'],flush=True)
