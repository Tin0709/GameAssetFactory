import bpy,sys,json,hashlib,time
from pathlib import Path
from mathutils import Vector
R=next((p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').exists()),Path('/Users/tin/Desktop/Game Dev/GameAssetFactory'));O=Path(__file__).resolve().parent.parent
TARGET=R/'blender/animation/reviews/player_animation_library_v1/rifle_ready_locomotion_sway_v002/walk_matched_shoulders'
sys.path.insert(0,str(R/'blender/animation/showcase'));sys.path.insert(0,str(O/'authoring'));import gaf_animation_library as ui
from fit import apply,SETTINGS,target
N='Rifle_Ready_Run_ActionsStyle_v002';s=bpy.context.scene;r=bpy.data.objects[ui.RIG];a=bpy.data.actions[N]
before=json.loads((O/'previous_action_hashes.json').read_text());assert ui.action_signature(a)==before[N]
base_entry=json.loads((O/'previous_entry.json').read_text())
assert ui.action_signature(bpy.data.actions[SETTINGS['walking_reference']])==SETTINGS['walking_action_sha256']
assert hashlib.sha256((R/base_entry['source']).read_bytes()).hexdigest()==base_entry['source_sha256']
changed={n:['location','rotation_quaternion'] for n in ['UpperArm.R','UpperArm.L','WeaponCarrier']}
old_curves={(c.data_path,c.array_index):[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type) for k in c.keyframe_points] for c in ui.curves(a)}
frames=sorted({float(k.co.x) for c in ui.curves(a) for k in c.keyframe_points});rest={b.name:b.matrix_local.copy() for b in r.data.bones};palm=Vector((0,r.data.bones['ForeArm.L'].length*.78,0));r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s['gaf_library_last_action']=N
values={n:{p:[] for p in ps} for n,ps in changed.items()};last={};improvement={side:[10.,-10.] for side in ['L','R']};maxgrip=0.;maxsupport=0.;target_error={'L':0.,'R':0.};local_ranges={side:[] for side in ['L','R']}
for j,f in enumerate(frames):
 s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update();B={b.name:b.matrix.copy() for b in r.pose.bones};M=apply(B,palm)
 for side in ['L','R']:
  n='UpperArm.'+side;socket=(B['Chest']@rest['Chest'].inverted()@rest[n]).translation;v=(B[n].translation-socket).length-(M[n].translation-socket).length
  expected=globals()['target'](side,B['Chest'],B);target_error[side]=max(target_error[side],(M[n].translation-expected).length);local_ranges[side].append(list(B['Chest'].inverted()@M[n].translation))
  improvement[side][0]=min(improvement[side][0],v);improvement[side][1]=max(improvement[side][1],v)
 maxsupport=max(maxsupport,(M['WeaponCarrier'].inverted()@(M['ForeArm.L']@palm)-B['WeaponCarrier'].inverted()@(B['ForeArm.L']@palm)).length)
 for n,props in changed.items():
  bone=r.data.bones[n];local=bone.convert_local_to_pose(M[n],rest[n],invert=True,parent_matrix=M[bone.parent.name],parent_matrix_local=rest[bone.parent.name]);pos,q,scale=local.decompose()
  if n in last and q.dot(last[n])<0:q.negate()
  last[n]=q.copy()
  for p in props:values[n][p].append(list(pos if p=='location' else q))
 if j%6000==0:print('SAMPLE',j,'/',len(frames),flush=True)
for c in ui.curves(a):
 match=next(((n,p) for n,ps in changed.items() for p in ps if c.data_path==r.pose.bones[n].path_from_id(p)),None)
 if match:
  n,p=match;ys=[v[c.array_index] for v in values[n][p]];c.keyframe_points.clear();c.keyframe_points.add(len(frames));c.keyframe_points.foreach_set('co',[z for f,y in zip(frames,ys) for z in (f,y)])
  for k in c.keyframe_points:k.interpolation='LINEAR'
  c.update()
untouched=0
for c in ui.curves(a):
 if any(c.data_path==r.pose.bones[n].path_from_id(p) for n,ps in changed.items() for p in ps):continue
 assert old_curves[c.data_path,c.array_index]==[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type) for k in c.keyframe_points];untouched+=1
assert set(before)=={a.name for a in bpy.data.actions}
for n,h in before.items():
 if n!=N:assert ui.action_signature(bpy.data.actions[n])==h,n
entry=dict(base_entry)
entry.update(source=(TARGET/'run_walk_matched_shoulders.blend').relative_to(R).as_posix(),action_sha256=ui.action_signature(a),shoulder_attachment=SETTINGS,
 refinement_note='2026-10-18 same Pending Run v002: use actual Walk v0012 Chest-local shoulder means/envelope for BOTH shoulders. Preserve source Run body/core/legs/head and Chest-led sway. Native carry calibration5deg up/5deg yaw/10deg right-arm axial rotation retains rigid right grip. Closest fixed-palm left support lies within2mm of the Walk socket target. Incoming relative shoulder float retains its clocks at15percent amplitude to match the Walking envelope; torso bounce is unchanged. Not a literal new source controller. Previous pending revision remains intact.',
 previous_pending_source=entry['source'],previous_pending_action_sha256=before[N])
entry.pop('source_sha256',None);ui.validate_action(a,entry,r)
s.frame_start=1;s.frame_end=2700;s.render.fps=30;s.render.fps_base=1.;s.frame_set(1);s.camera=bpy.data.objects['Showcase_THREE_QUARTER'];ui.show_preview_prop(s,{'preview_prop':'rifle_stylized_v2'})
bpy.ops.wm.save_as_mainfile(filepath=str(O/'run_walk_matched_shoulders.blend'),compress=True,check_existing=False)
entry['source_sha256']=hashlib.sha256((O/'run_walk_matched_shoulders.blend').read_bytes()).hexdigest();(O/'entry.json').write_text(json.dumps(entry,indent=2)+'\n')
report={'passed':True,'same_pending_action':N,'other_actions_exact':len(before)-1,'untouched_curves_exact':untouched,'samples':len(frames),'changed_properties':changed,'shoulder_socket_distance_improvement_m':improvement,'left_support_palm_relative_error_m':maxsupport,'settings':SETTINGS,'walking_socket_target_max_error_m':target_error,'new_chest_local_shoulder_ranges':{side:{'min':[min(v[k] for v in vals) for k in range(3)],'max':[max(v[k] for v in vals) for k in range(3)]} for side,vals in local_ranges.items()}};(O/'build_validation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report),flush=True)
