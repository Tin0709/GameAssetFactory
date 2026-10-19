import bpy,json,sys,math,hashlib
from pathlib import Path
from mathutils import Matrix,Vector
S=Path(__file__).resolve().parent;R=next(p for p in Path(bpy.data.filepath).resolve().parents if (p/'AGENTS.md').is_file());sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
N='Rifle_Aim_Hold_ActionsStyle_v001';r=bpy.data.objects[ui.RIG];s=bpy.context.scene;old=json.loads((S/'baseline_entry.json').read_text());a0=bpy.data.actions[N];assert old['status']=='pending' and ui.action_signature(a0)==old['action_sha256'];before={a.name:ui.action_signature(a) for a in bpy.data.actions if a.name!=N};P=json.loads((S/'parameters.json').read_text());T={n:Matrix(v) for n,v in json.loads((S/'static_pose.json').read_text()).items()};rest={b.name:b.matrix_local.copy() for b in r.data.bones}
ST={'foot_center_spacing_m':.32,'fore_aft_stagger_m':.14,'right_foot':'forward','left_foot':'back','outward_leg_tilt_deg':3.,'leg_forward_back_tilt_deg':4.5,'toe_out_each_deg':5.,'stance_blade_deg':6.914611782648605,'floor_m':0.,'stance_center_x_m':-.01,'feet_policy':'fixed rigid world-space legs throughout loop; lowest sole corners seated on floor'}
mesh=bpy.data.objects['Showcase_Player_Mesh'];groups={g.index:g.name for g in mesh.vertex_groups};foot_targets={}
for side,sgn in [('L',1),('R',-1)]:
 n='Leg.'+side;verts=[rest[n].inverted()@v.co for v in mesh.data.vertices if groups[v.groups[0].group]==n];my=max(v.y for v in verts);bottom=[v for v in verts if abs(v.y-my)<1e-5];bc=sum(bottom,Vector())/len(bottom);rz=Matrix.Rotation(math.radians(ST['stance_blade_deg']),4,'Z');q=rz@Matrix.Rotation(math.radians(sgn*5),4,'Z')@Matrix.Rotation(math.radians(-sgn*3),4,'Y')@Matrix.Rotation(math.radians(sgn*4.5),4,'X')@rest[n].to_3x3().to_4x4();center=rz@Vector((sgn*.16,sgn*.07,0));center.x-=.01;rotbc=q.to_3x3()@bc;q.translation=Vector((center.x-rotbc.x,center.y-rotbc.y,0));q.translation.z=-min((q@v).z for v in verts);T[n]=q;foot_targets[n]={'sole_center':list(q@bc),'world_matrix':[list(row) for row in q]}
P['stance']=ST;(S/'parameters.json').write_text(json.dumps(P,indent=2));(S/'stance_targets.json').write_text(json.dumps(foot_targets,indent=2));(S/'static_pose.json').write_text(json.dumps({n:[list(row) for row in m] for n,m in T.items()},indent=2))
r.animation_data.action=a0;r.animation_data.action_slot=a0.slots[0];s['gaf_library_last_action']=N;s.frame_set(1);M0={b.name:b.matrix.copy() for b in r.pose.bones};times=[i/240 for i in range(865)];values={n:[] for n in ['UpperArm.L','UpperArm.R','WeaponCarrier','Leg.L','Leg.R']};baseline_samples=[]
for j,t in enumerate(times):
 f=1+30*t;s.frame_set(math.floor(f),subframe=f%1);bpy.context.view_layer.update();M={b.name:b.matrix.copy() for b in r.pose.bones};D=M['UpperArm.R']@M0['UpperArm.R'].inverted();
 if j%4==0:baseline_samples.append({n:[list(row) for row in m] for n,m in M.items()})
 new={n:D@T[n] for n in ['UpperArm.L','UpperArm.R','WeaponCarrier']};new.update({n:T[n] for n in ['Leg.L','Leg.R']})
 for n in new:
  b=r.data.bones[n];L=b.convert_local_to_pose(new[n],rest[n],invert=True,parent_matrix=M[b.parent.name],parent_matrix_local=rest[b.parent.name]);loc,q,sc=L.decompose();assert max(abs(v-1) for v in sc)<1e-5;values[n].append((loc,q))
(S/'baseline_world_samples.json').write_text(json.dumps(baseline_samples));act=a0.copy();act.use_fake_user=True;paths={r.pose.bones[n].path_from_id(p) for n in values for p in ['location',('rotation_euler' if n.startswith('Leg.') else 'rotation_quaternion')]};changed=0;curves0=[fc for l in a0.layers for st in l.strips for b in st.channelbags for fc in b.fcurves];curves=[fc for l in act.layers for st in l.strips for b in st.channelbags for fc in b.fcurves]
def fcdata(fc):return [(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type) for k in fc.keyframe_points]
for n,rows in values.items():
 prev=None;rotations=[]
 for loc,q in rows:
  q=q.copy()
  if prev is not None and prev.dot(q)<0:q.negate()
  rotations.append(q.to_euler('XYZ') if n.startswith('Leg.') else q);prev=q
 for prop,arr in [('location',[v[0] for v in rows]),(('rotation_euler' if n.startswith('Leg.') else 'rotation_quaternion'),rotations)]:
  path=r.pose.bones[n].path_from_id(prop)
  for fc in [fc for fc in curves if fc.data_path==path]:
   assert len(fc.keyframe_points)==len(times);fc.keyframe_points.foreach_set('co',[a for t,row in zip(times,arr) for a in [1+t*30,row[fc.array_index]]]);fc.update();changed+=1
assert changed==33
assert all(fcdata(a)==fcdata(b) for a,b in zip(curves0,curves) if a.data_path not in paths)
r.animation_data.action=act;r.animation_data.action_slot=act.slots[0];a0.user_remap(act);bpy.data.actions.remove(a0);act.name=N;act['adaptation']='Inward10deg cant toward right eye; right arm and rifle rotate together with exact grip/parallel axis, left support refitted; right foot forward and left foot back; head/torso unchanged';act['research_only']=True;act['production_eligible']=False
s.frame_set(85);s.frame_start=1;s.frame_end=108;s.render.fps=30;s.render.fps_base=1.;ui.show_preview_prop(s,{'preview_prop':'rifle_stylized_v2'});assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in before.items());out=S/'rifle_aim_hold_actionsstyle_v001.blend';bpy.ops.wm.save_as_mainfile(filepath=str(out),compress=True,check_existing=False)
e=dict(old);e.update(source='blender/animation/reviews/player_animation_library_v1/rifle_aim_hold_actionsstyle_v001/eye_cant_20261019/rifle_aim_hold_actionsstyle_v001.blend',source_sha256=hashlib.sha256(out.read_bytes()).hexdigest(),action_sha256=ui.action_signature(act),rig_adaptations={**old['rig_adaptations'],'eye_cant':{k:v for k,v in P.items() if k!='stance'},'aim_stance':ST},previous_pending_source={k:old[k] for k in ['source','source_sha256','action_sha256']},approval_note='Same Pending rifle Aim: user-requested inward10deg arm/rifle cant toward right eye. Right foot forward/left back in a modest planted stance; Head/body/idle clocks unchanged; exact rigid grips.2026-10-19.')
ui.validate_action(act,e,r);(S/'entry.json').write_text(json.dumps(e,indent=2));(S/'source_actions_before.json').write_text(json.dumps(before,indent=2));(S/'curve_preservation.json').write_text(json.dumps({'passed':True,'edited_curves':33,'untouched_curves_exact':len(curves)-33,'only_modified_bones':['UpperArm.L','UpperArm.R','WeaponCarrier','Leg.L','Leg.R'],'all_head_torso_hips_scales_forearm_curves_exact':True},indent=2));print('BUILT_ALIGNED_AIM',e['action_sha256'],flush=True)
