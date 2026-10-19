import bpy,json,sys,math
from pathlib import Path
from mathutils import Matrix,Vector
R=next(p for p in Path(bpy.data.filepath).resolve().parents if (p/'AGENTS.md').is_file());S=Path(__file__).resolve().parent;sys.path.insert(0,str(S));sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui

r=bpy.data.objects[ui.RIG];m=bpy.data.objects['Showcase_Player_Mesh'];s=bpy.context.scene;N='Rifle_Aim_Hold_ActionsStyle_v001';BASE='Crossbow_Aim_ActionsStuff_Source_Test_v001';P=json.loads((S/'parameters.json').read_text());a=bpy.data.actions[N];src=bpy.data.actions[BASE]
path=R/'blender/animation/reviews/player_animation_library_v1/rifle_ready_idle_actionsstyle_v004/authoring/validate_upper_body_geometry.py';ns={'__file__':str(path),'__name__':'geometry_helpers'};exec(compile(path.read_text().rsplit('\nmain()',1)[0],str(path),'exec'),ns);ids,tri,bad=ns['setup'](r,m)
def setact(act):r.animation_data.action=act;r.animation_data.action_slot=act.slots[0];s['gaf_library_last_action']=act.name
def frame(f):s.frame_set(math.floor(f),subframe=f%1);bpy.context.view_layer.update();return {b.name:b.matrix.copy() for b in r.pose.bones}
if (S/'baseline_world_samples.json').exists():
 source=[{n:Matrix(v) for n,v in row.items()} for row in json.loads((S/'baseline_world_samples.json').read_text())]
else:
 oldentry=json.loads((S/'baseline_entry.json').read_text())
 with bpy.data.libraries.load(str(R/oldentry['source']),link=False) as (ls,ld):ld.actions=[N]
 baseline=ld.actions[0];assert ui.action_signature(baseline)==oldentry['action_sha256'];setact(baseline);source=[frame(1+i*.5) for i in range(217)];setact(a);bpy.data.actions.remove(baseline)
targetall={n:Matrix(row) for n,row in json.loads((S/'static_pose.json').read_text()).items()};targets={n:targetall[n] for n in ['UpperArm.R','UpperArm.L','ForeArm.R','ForeArm.L','WeaponCarrier','Leg.L','Leg.R']};gR=Vector((0,.539200127,.016389614));gL=Vector((0,.6347353700657523,0));support=Vector(P['support']);setact(a);metrics={k:0. for k in ['unchanged_bone_matrix_error','changed_hold_matrix_error','foot_vertex_drift','foot_floor_penetration','foot_floor_gap','right_grip_error','left_palm_error','forearm_local_error','straight_arm_error','unit_scale_error','barrel_arm_axis_cross_error','shoulder_surface_gap','support_surface_gap','loop_error']};minhead=1e9;collisions=[];adjacent=[];poses={};handmin=1e9;handmax=-1e9;headseat=0.;headseatmin=1e9;shoulderseat=0.;hipseatmin=1e9;hipseatmax=-1e9;foot0={};eyebefore=[];eyeafter=[]
for i in range(217):
 f=1+i*.5;M=frame(f);D=source[i]['UpperArm.R']@source[0]['UpperArm.R'].inverted();pts,trees=ns['geometry'](r,m,ids,tri);pairs,sats=ns['collision'](r,pts,trees)
 eye=M['Head']@Vector((-.140625,.28125,.225))
 for arr,C in [(eyebefore,source[i]['WeaponCarrier']),(eyeafter,M['WeaponCarrier'])]:arr.append((eye-C@Vector((0,0,.25))).cross(C.to_3x3().col[1].normalized()).length)
 for n in M:
  if n in targets:metrics['changed_hold_matrix_error']=max(metrics['changed_hold_matrix_error'],ns['md'](M[n],targets[n] if n.startswith('Leg.') else D@targets[n]))
  else:metrics['unchanged_bone_matrix_error']=max(metrics['unchanged_bone_matrix_error'],ns['md'](M[n],source[i][n]))
  metrics['unit_scale_error']=max(metrics['unit_scale_error'],max(abs(x-1) for x in M[n].to_scale()))
 metrics['barrel_arm_axis_cross_error']=max(metrics['barrel_arm_axis_cross_error'],M['UpperArm.R'].to_3x3().col[1].normalized().cross(M['WeaponCarrier'].to_3x3().col[1].normalized()).length)
 metrics['right_grip_error']=max(metrics['right_grip_error'],(M['UpperArm.R']@gR-M['WeaponCarrier'].translation).length)
 metrics['left_palm_error']=max(metrics['left_palm_error'],(M['UpperArm.L']@gL-M['WeaponCarrier']@support).length)
 for side in ['R','L']:
  n='Leg.'+side
  if not i:foot0[n]=[v.copy() for v in pts[n]]
  metrics['foot_vertex_drift']=max(metrics['foot_vertex_drift'],max((v-v0).length for v,v0 in zip(pts[n],foot0[n])))
  floorz=min(v.z for v in pts[n]);metrics['foot_floor_penetration']=max(metrics['foot_floor_penetration'],-floorz);metrics['foot_floor_gap']=max(metrics['foot_floor_gap'],floorz)
  hipkey=next(k for k in sats if frozenset(k.split('|'))==frozenset(('Chest',n)));hipseatmin=min(hipseatmin,sats[hipkey]);hipseatmax=max(hipseatmax,sats[hipkey])
  u=r.pose.bones['UpperArm.'+side];q=r.pose.bones['ForeArm.'+side];metrics['forearm_local_error']=max(metrics['forearm_local_error'],ns['md'](q.matrix_basis,Matrix.Identity(4)));metrics['straight_arm_error']=max(metrics['straight_arm_error'],(u.tail-u.head).normalized().cross((q.tail-q.head).normalized()).length)
  metrics['shoulder_surface_gap']=max(metrics['shoulder_surface_gap'],max(0.,-sats['Chest|UpperArm.'+side]))
 metrics['support_surface_gap']=max(metrics['support_surface_gap'],ns['bidirectional_gap'](pts,trees,'ForeArm.L','Rifle_V2_Body'))
 minhead=min(minhead,ns['bidirectional_gap'](pts,trees,'Head','Rifle_V2_Body'));hkey=next(k for k in sats if frozenset(k.split('|'))==frozenset(('ForeArm.L','ForeArm.R')));handmin=min(handmin,sats[hkey]);handmax=max(handmax,sats[hkey]);headseat=max(headseat,next(v for k,v in sats.items() if frozenset(k.split('|'))==frozenset(('Chest','Head'))));headseatmin=min(headseatmin,next(v for k,v in sats.items() if frozenset(k.split('|'))==frozenset(('Chest','Head'))));shoulderseat=max(shoulderseat,sats['Chest|UpperArm.R'],sats['Chest|UpperArm.L'])
 for k,count in pairs.items():
  key=frozenset(k.split('|'))
  if count and key not in ns['ADJACENT']|ns['CONTACT']|{frozenset(('ForeArm.L','ForeArm.R'))} and sats.get(k,1)>1e-5:collisions.append({'frame':f,'pair':k,'triangles':count,'sat':sats.get(k)})
 for k,margin in sats.items():
  key=frozenset(k.split('|'))
  if key not in ns['ADJACENT']|{frozenset(('ForeArm.L','ForeArm.R'))} and margin>1e-5 and not pairs[k]:collisions.append({'frame':f,'pair':k,'sat':margin,'contained':True})
  limit=.03 if key==frozenset(('Head','Chest')) else .055 if 'Chest' in key and any(n.startswith('UpperArm.') for n in key) else .08
  if key in ns['ADJACENT'] and margin>limit:adjacent.append({'frame':f,'pair':k,'margin':margin,'limit':limit})
 if i in [0,216]:poses[i]=M
metrics['loop_error']=max(ns['md'](poses[0][n],poses[216][n]) for n in M)
A=frame(1);B1=frame(1.125);Z=frame(108.875);E=frame(109);vseam=0.;wseam=0.
for n in A:
 v0,w0=ns['transform_vel'](A[n],B1[n],1/240);v1,w1=ns['transform_vel'](Z[n],E[n],1/240);vseam=max(vseam,(v0-v1).length);wseam=max(wseam,(w0-w1).length)
old=json.loads((S/'source_actions_before.json').read_text());assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in old.items())
limits={'unchanged_bone_matrix_error':1e-5,'changed_hold_matrix_error':1e-5,'foot_vertex_drift':1e-5,'foot_floor_penetration':1e-5,'foot_floor_gap':1e-5,'right_grip_error':3e-5,'left_palm_error':3e-5,'forearm_local_error':1e-5,'straight_arm_error':1e-5,'unit_scale_error':1e-5,'barrel_arm_axis_cross_error':1e-5,'shoulder_surface_gap':.01,'support_surface_gap':.015,'loop_error':1e-5};fail=[k for k,v in limits.items() if metrics[k]>v]
if vseam>.006 or wseam>.05:fail.append('loop_velocity_discontinuity')
if collisions:fail.append('nonadjacent_or_rifle_collision')
if adjacent:fail.append('excessive_joint_seating')
if minhead<.008:fail.append('face_clearance_below8mm')
if min(a-b for a,b in zip(eyebefore,eyeafter))<.02:fail.append('eye_line_not_closer_by20mm')
if headseatmin<-.001:fail.append('visible_head_collar_gap')
centers={n:Vector(row['sole_center']) for n,row in json.loads((S/'stance_targets.json').read_text()).items()};forward=(centers['Leg.R']-centers['Leg.L']).dot(poses[0]['WeaponCarrier'].to_3x3().col[1].normalized())
if forward<.12:fail.append('right_foot_not_forward')
if hipseatmin<-.003:fail.append('visible_hip_leg_gap')
if handmin<-.003 or handmax>.0015:fail.append('crossing_hand_contact_outside3mm_gap_1p5mm_seating')
report={'passed':not fail,'failures':fail,'sampled_poses':217,'metrics':metrics,'limits':limits,'loop_translation_velocity_difference_m_s':vseam,'loop_velocity_limits':{'translation_m_s':.006,'angular_rad_s':.05},'loop_angular_velocity_difference_rad_s':wseam,'minimum_head_rifle_surface_gap_m':minhead,'before_eye_sight_gap_range_m':[min(eyebefore),max(eyebefore)],'after_eye_sight_gap_range_m':[min(eyeafter),max(eyeafter)],'minimum_eye_line_improvement_m':min(a-b for a,b in zip(eyebefore,eyeafter)),'crossing_hand_contact_sat_range_m':[handmin,handmax],'head_chest_max_seating_m':headseat,'head_chest_min_seating_m':headseatmin,'shoulder_max_seating_m':shoulderseat,'hip_leg_signed_contact_range_m':[hipseatmin,hipseatmax],'right_foot_forward_projection_m':forward,'collisions_count':len(collisions),'collisions':collisions[:50],'adjacent':adjacent[:15],'existing_actions_preserved':len(old),'source_study_exact':ui.action_signature(src)==old[BASE],'notes':['User-requested10deg inward arm/rifle cant toward character right eye. Original source timing remains unchanged.','Only33 arm/carrier location/quaternion and leg location/Euler curves changed. All93 remaining curves and evaluated head/torso/hips remain exact copies of preceding grounded stance.','Right grip and barrel/arm parallelism are retained. Left rigid support is refitted with submillimeter static shoulder displacement. No elbow, scale, mesh or rig changes.','The small fitted eye-ward cant intentionally reduces earlier face clearance; explicit8mm surface clearance minimum, no head/rifle intersection. The square head and full-length block arms still prevent perfect optical ADS.','Sight/eye markers are approximate rig diagnostics; source rifle has a carry handle rather than an added optic.','Right foot is forward and left foot back,0.14m stagger/0.32m lateral sole-center spacing in the stance frame. Feet stay planted; no wider stance, knee or ankle articulation.']};(S/'geometry_validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2));assert report['passed'],fail
