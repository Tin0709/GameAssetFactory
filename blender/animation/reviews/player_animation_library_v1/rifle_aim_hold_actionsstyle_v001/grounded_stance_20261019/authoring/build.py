import bpy,json,sys,math,hashlib
from pathlib import Path
from mathutils import Matrix,Vector
S=Path(__file__).resolve().parent;R=next(p for p in Path(bpy.data.filepath).resolve().parents if (p/'AGENTS.md').is_file());sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
N='Rifle_Aim_Hold_ActionsStyle_v001';r=bpy.data.objects[ui.RIG];s=bpy.context.scene;old=json.loads((S/'baseline_entry.json').read_text());a0=bpy.data.actions[N];assert old['status']=='pending' and ui.action_signature(a0)==old['action_sha256'];before={a.name:ui.action_signature(a) for a in bpy.data.actions if a.name!=N}
P={'foot_center_spacing_m':.32,'fore_aft_stagger_m':.10,'outward_leg_tilt_deg':3.,'leg_forward_back_tilt_deg':2.5,'toe_out_each_deg':5.,'stance_blade_deg':6.914611782648605,'floor_m':0.,'stance_center_x_m':-.01,'feet_policy':'constant world-space rigid leg matrices; lowest sole corners on floor; unchanged hips breathing above planted feet','upper_body':'all non-leg curves exact copies of preceding arm-axis aligned Pending'};(S/'parameters.json').write_text(json.dumps(P,indent=2))
rest={b.name:b.matrix_local.copy() for b in r.data.bones};mesh=bpy.data.objects['Showcase_Player_Mesh'];groups={g.index:g.name for g in mesh.vertex_groups};T={};foot_rest={}
for side,sgn in [('L',1),('R',-1)]:
 n='Leg.'+side;verts=[rest[n].inverted()@v.co for v in mesh.data.vertices if groups[v.groups[0].group]==n];my=max(v.y for v in verts);bottom=[v for v in verts if abs(v.y-my)<1e-5];bc=sum(bottom,Vector())/len(bottom)
 rz=Matrix.Rotation(math.radians(P['stance_blade_deg']),4,'Z');q=rz@Matrix.Rotation(math.radians(sgn*P['toe_out_each_deg']),4,'Z')@Matrix.Rotation(math.radians(-sgn*P['outward_leg_tilt_deg']),4,'Y')@Matrix.Rotation(math.radians(-sgn*P['leg_forward_back_tilt_deg']),4,'X')@rest[n].to_3x3().to_4x4()
 center=rz@Vector((sgn*.16,-sgn*.05,0));center.x+=P['stance_center_x_m'];rotbc=q.to_3x3()@bc;q.translation=Vector((center.x-rotbc.x,center.y-rotbc.y,0));q.translation.z=-min((q@v).z for v in verts);T[n]=q;foot_rest[n]={'sole_center':list(q@bc),'lowest_z':min((q@v).z for v in verts),'world_matrix':[list(row) for row in q]}
(S/'stance_targets.json').write_text(json.dumps(foot_rest,indent=2));r.animation_data.action=a0;r.animation_data.action_slot=a0.slots[0];s['gaf_library_last_action']=N;times=[i/240 for i in range(865)];values={n:[] for n in T};samples=[]
for j,t in enumerate(times):
 f=1+30*t;s.frame_set(math.floor(f),subframe=f%1);bpy.context.view_layer.update();M={b.name:b.matrix.copy() for b in r.pose.bones}
 if j%4==0:samples.append({n:[list(row) for row in m] for n,m in M.items()})
 for n,target in T.items():
  b=r.data.bones[n];L=b.convert_local_to_pose(target,rest[n],invert=True,parent_matrix=M[b.parent.name],parent_matrix_local=rest[b.parent.name]);loc,q,sc=L.decompose();assert max(abs(v-1) for v in sc)<1e-5;values[n].append((loc,q.to_euler('XYZ')))
(S/'baseline_world_samples.json').write_text(json.dumps(samples));act=a0.copy();act.use_fake_user=True;paths={r.pose.bones[n].path_from_id(p) for n in values for p in ['location','rotation_euler']};curves0=[fc for l in a0.layers for st in l.strips for b in st.channelbags for fc in b.fcurves];curves=[fc for l in act.layers for st in l.strips for b in st.channelbags for fc in b.fcurves]
def fcdata(fc):return [(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type) for k in fc.keyframe_points]
changed=0
for n,rows in values.items():
 for prop,arr in [('location',[v[0] for v in rows]),('rotation_euler',[v[1] for v in rows])]:
  path=r.pose.bones[n].path_from_id(prop)
  for fc in [fc for fc in curves if fc.data_path==path]:
   assert len(fc.keyframe_points)==len(times);fc.keyframe_points.foreach_set('co',[a for t,row in zip(times,arr) for a in [1+t*30,row[fc.array_index]]]);fc.update();changed+=1
assert changed==12;assert all(fcdata(a)==fcdata(b) for a,b in zip(curves0,curves) if a.data_path not in paths)
r.animation_data.action=act;r.animation_data.action_slot=act.slots[0];a0.user_remap(act);bpy.data.actions.remove(a0);act.name=N;act['adaptation']='Modest planted aiming stance only: 0.32m sole centers, 0.10m stagger,3deg outward rigid legs,5deg toe-out per side. All non-leg curves unchanged.';act['research_only']=True;act['production_eligible']=False;s.frame_set(85);s.frame_start=1;s.frame_end=108;s.render.fps=30;s.render.fps_base=1.;ui.show_preview_prop(s,{'preview_prop':'rifle_stylized_v2'});assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in before.items());out=S/'rifle_aim_hold_actionsstyle_v001.blend';bpy.ops.wm.save_as_mainfile(filepath=str(out),compress=True,check_existing=False)
e=dict(old);e.update(source='blender/animation/reviews/player_animation_library_v1/rifle_aim_hold_actionsstyle_v001/grounded_stance_20261019/rifle_aim_hold_actionsstyle_v001.blend',source_sha256=hashlib.sha256(out.read_bytes()).hexdigest(),action_sha256=ui.action_signature(act),rig_adaptations={**old['rig_adaptations'],'aim_stance':P},previous_pending_source={k:old[k] for k in ['source','source_sha256','action_sha256']},approval_note='Same Pending rifle Aim: user-requested modest planted stance; only rigid leg location/rotation changes. All upper-body, grip, head and original idle clocks preserved.2026-10-19.')
ui.validate_action(act,e,r);(S/'entry.json').write_text(json.dumps(e,indent=2));(S/'source_actions_before.json').write_text(json.dumps(before,indent=2));(S/'curve_preservation.json').write_text(json.dumps({'passed':True,'edited_curves':12,'untouched_curves_exact':len(curves)-12,'only_modified_bones':['Leg.L','Leg.R'],'all_upper_body_hips_grip_head_clocks_scales_exact':True},indent=2));print('BUILT_GROUNDED_AIM',e['action_sha256'],flush=True)
