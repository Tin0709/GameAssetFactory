import bpy,json,sys,math,hashlib
from pathlib import Path
from mathutils import Matrix,Quaternion
S=Path(__file__).resolve().parent;R=next(p for p in Path(bpy.data.filepath).resolve().parents if (p/'AGENTS.md').is_file());sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
BASE='Crossbow_Aim_ActionsStuff_Source_Test_v001';N='Crossbow_Aim_ActionsStuff_Refined_Test_v001';r=bpy.data.objects[ui.RIG];s=bpy.context.scene;old=json.loads((S/'baseline_entry.json').read_text());a0=bpy.data.actions[BASE];assert ui.action_signature(a0)==old['action_sha256'];assert N not in bpy.data.actions;before={a.name:ui.action_signature(a) for a in bpy.data.actions};r.animation_data.action=a0;r.animation_data.action_slot=a0.slots[0];s['gaf_library_last_action']=BASE
P={'head_lean_toward_rifle_deg':7.,'head_seating_lift_m':.008,'head_seating_lateral_m':.012,'arms_downward_deg':5.,'left_whole_arm_outward_deg':2.,'head_pivot':'neck-base roll with8mm up/12mm lateral collar seating','left_pivot':'unchanged upper-arm shoulder root','all_other_bones_and_source_clocks':'unchanged'};times=[i/240 for i in range(865)];values={n:[] for n in ['Head','UpperArm.L','UpperArm.R','WeaponCarrier']};baseline=[];maxloc=0.
for j,t in enumerate(times):
 f=1+30*t;s.frame_set(math.floor(f),subframe=f%1);bpy.context.view_layer.update();M={b.name:b.matrix.copy() for b in r.pose.bones}
 if j%4==0:baseline.append({n:[list(row) for row in m] for n,m in M.items()})
 H=M['Head']@Matrix.Rotation(math.radians(P['head_lean_toward_rifle_deg']),4,'Z');H.translation+=M['Chest'].to_3x3().col[1].normalized()*P['head_seating_lift_m']+M['Chest'].to_3x3().col[0].normalized()*P['head_seating_lateral_m']
 down=Quaternion(M['Chest'].to_3x3().col[0].normalized(),math.radians(P['arms_downward_deg'])).to_matrix().to_4x4();outward=Quaternion(M['Chest'].to_3x3().col[1].normalized(),math.radians(P['left_whole_arm_outward_deg'])).to_matrix().to_4x4();L=down@outward@M['UpperArm.L'];L.translation=M['UpperArm.L'].translation;U=down@M['UpperArm.R'];U.translation=M['UpperArm.R'].translation;W=U@M['UpperArm.R'].inverted()@M['WeaponCarrier']
 for n,new in [('Head',H),('UpperArm.L',L),('UpperArm.R',U),('WeaponCarrier',W)]:
  b=r.data.bones[n];q=b.convert_local_to_pose(new,b.matrix_local,invert=True,parent_matrix=M[b.parent.name],parent_matrix_local=b.parent.matrix_local);loc,rot,scale=q.decompose()
  if n not in ['Head','WeaponCarrier']:maxloc=max(maxloc,(loc-r.pose.bones[n].location).length)
  assert max(abs(v-1) for v in scale)<1e-5;values[n].append((loc,rot))
assert maxloc<1e-5;(S/'baseline_world_samples.json').write_text(json.dumps(baseline));act=a0.copy();act.name=N;act.use_fake_user=True;curves0=[fc for l in a0.layers for st in l.strips for b in st.channelbags for fc in b.fcurves];curves=[fc for l in act.layers for st in l.strips for b in st.channelbags for fc in b.fcurves];paths=set();count=0
for n,rows in values.items():
 qs=[row[1] for row in rows]
 for i in range(1,len(qs)):
  if qs[i-1].dot(qs[i])<0:qs[i].negate()
 props=[('rotation_quaternion',qs)]
 if n in ['Head','WeaponCarrier']:props.append(('location',[row[0] for row in rows]))
 for prop,arr in props:
  path=r.pose.bones[n].path_from_id(prop);paths.add(path)
  for fc in [fc for fc in curves if fc.data_path==path]:fc.keyframe_points.foreach_set('co',[v for t,row in zip(times,arr) for v in [1+t*30,row[fc.array_index]]]);fc.update();count+=1
assert count==22
def fcd(fc):return [(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type) for k in fc.keyframe_points]
assert all(fcd(a)==fcd(b) for a,b in zip(curves0,curves) if a.data_path not in paths);assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in before.items());act['research_only']=True;act['production_eligible']=False;act['adaptation']='7deg head lean with8mm collar seating; both arms5deg down, left2deg outward; rifle follows right grip. Original crossbow source preserved.';r.animation_data.action=act;r.animation_data.action_slot=act.slots[0];s['gaf_library_last_action']=N;s.frame_set(85);s.frame_start=1;s.frame_end=108;s.render.fps=30;s.render.fps_base=1.;ui.show_preview_prop(s,{'preview_prop':'rifle_stylized_v2'});out=S/'crossbow_aim_refined_v001.blend';bpy.ops.wm.save_as_mainfile(filepath=str(out),compress=True,check_existing=False)
e=dict(old);e.update(action=N,source='blender/animation/reviews/player_animation_library_v1/crossbow_aim_refined_v001/crossbow_aim_refined_v001.blend',source_sha256=hashlib.sha256(out.read_bytes()).hexdigest(),action_sha256=ui.action_signature(act),status='pending',approval_note='Preferred Crossbow source base, with user-requested stronger head lean toward rifle, both arms lowered slightly and left arm away slightly. Arsenal composite set aside. Pending review.',visual_base=BASE,visual_base_action_sha256=old['action_sha256'],rig_adaptations=P,literal_unmodified_source_pose=False);ui.validate_action(act,e,r);(S/'entry.json').write_text(json.dumps(e,indent=2));(S/'parameters.json').write_text(json.dumps(P,indent=2));(S/'source_actions_before.json').write_text(json.dumps(before,indent=2));(S/'curve_preservation.json').write_text(json.dumps({'passed':True,'edited_transform_curves':22,'unchanged_curves_exact':len(curves)-8,'all_body_legs_forearm_scales_and_shoulder_roots_exact':True,'source_actions_preserved':len(before),'local_translation_solve_error':maxloc},indent=2));print('BUILT',N,e['action_sha256'],flush=True)
