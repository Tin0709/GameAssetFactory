import bpy,json,sys,math
from pathlib import Path
from mathutils import Matrix,Vector
R=next(p for p in Path(bpy.data.filepath).resolve().parents if (p/'AGENTS.md').is_file());S=Path(__file__).resolve().parent;sys.path.insert(0,str(S));sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
from motion import RifleFit,HOLD,CORE
r=bpy.data.objects[ui.RIG];m=bpy.data.objects['Showcase_Player_Mesh'];s=bpy.context.scene;N='Rifle_Aim_Hold_ActionsStyle_v001';BASE='Crossbow_Aim_ActionsStuff_Source_Test_v001';P=json.loads((S/'parameters.json').read_text());a=bpy.data.actions[N];src=bpy.data.actions[BASE]
path=R/'blender/animation/reviews/player_animation_library_v1/rifle_ready_idle_actionsstyle_v004/authoring/validate_upper_body_geometry.py';ns={'__file__':str(path),'__name__':'geometry_helpers'};exec(compile(path.read_text().rsplit('\nmain()',1)[0],str(path),'exec'),ns);ids,tri,bad=ns['setup'](r,m)
def setact(act):r.animation_data.action=act;r.animation_data.action_slot=act.slots[0];s['gaf_library_last_action']=act.name
def frame(f):s.frame_set(math.floor(f),subframe=f%1);bpy.context.view_layer.update();return {b.name:b.matrix.copy() for b in r.pose.bones}
setact(src);B=frame(1);fit=RifleFit(r,B,P);source=[frame(1+i*.5) for i in range(217)];setact(a);metrics={k:0. for k in ['source_core_matrix_error','requested_pose_error','right_grip_error','left_palm_error','forearm_local_error','straight_arm_error','unit_scale_error','shoulder_surface_gap','support_surface_gap','loop_error']};minhead=1e9;collisions=[];adjacent=[];poses={};handmin=1e9;handmax=-1e9;headseat=0.;headseatmin=1e9;shoulderseat=0.
for i in range(217):
 f=1+i*.5;M=frame(f);target=fit.value(source[i]);pts,trees=ns['geometry'](r,m,ids,tri);pairs,sats=ns['collision'](r,pts,trees)
 for n in M:
  metrics['requested_pose_error']=max(metrics['requested_pose_error'],ns['md'](M[n],target[n]))
  if n in CORE:metrics['source_core_matrix_error']=max(metrics['source_core_matrix_error'],ns['md'](M[n],source[i][n]))
  metrics['unit_scale_error']=max(metrics['unit_scale_error'],max(abs(x-1) for x in M[n].to_scale()))
 metrics['right_grip_error']=max(metrics['right_grip_error'],(M['UpperArm.R']@fit.gR-M['WeaponCarrier'].translation).length)
 metrics['left_palm_error']=max(metrics['left_palm_error'],(M['UpperArm.L']@fit.gL-M['WeaponCarrier']@fit.support).length)
 for side in ['R','L']:
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
limits={'source_core_matrix_error':1e-5,'requested_pose_error':1e-5,'right_grip_error':3e-5,'left_palm_error':3e-5,'forearm_local_error':1e-5,'straight_arm_error':1e-5,'unit_scale_error':1e-5,'shoulder_surface_gap':.01,'support_surface_gap':.015,'loop_error':1e-5};fail=[k for k,v in limits.items() if metrics[k]>v]
if vseam>.010 or wseam>.05:fail.append('loop_velocity_discontinuity')
if collisions:fail.append('nonadjacent_or_rifle_collision')
if adjacent:fail.append('excessive_joint_seating')
if minhead<.02:fail.append('face_clearance_below20mm')
if headseatmin<-.001:fail.append('visible_head_collar_gap')
if handmin<-.003 or handmax>.0015:fail.append('crossing_hand_contact_outside3mm_gap_1p5mm_seating')
report={'passed':not fail,'failures':fail,'sampled_poses':217,'metrics':metrics,'limits':limits,'loop_translation_velocity_difference_m_s':vseam,'loop_velocity_limits':{'translation_m_s':.010,'angular_rad_s':.05},'loop_angular_velocity_difference_rad_s':wseam,'minimum_head_rifle_surface_gap_m':minhead,'crossing_hand_contact_sat_range_m':[handmin,handmax],'head_chest_max_seating_m':headseat,'head_chest_min_seating_m':headseatmin,'shoulder_max_seating_m':shoulderseat,'collisions_count':len(collisions),'collisions':collisions[:50],'adjacent':adjacent[:15],'existing_actions_preserved':len(old),'source_study_exact':ui.action_signature(src)==old[BASE],'notes':['Native source leg/foot motion including4.83mm sole corner seating is unchanged.','240Hz linear source bake has finite one-sided chord velocities: rifle5.25mm/s in immutable crossbow,7.20mm/s after longer forward attachment.10mm/s limit bounds a0.333mm one-frame displacement at30FPS; no source timing was retimed to hide this.','Static diagonal body/head and fitted rifle/arm matrices are authored to user photo; immutable source clocks and lower body stay exact.','The two rigid hand blocks intentionally touch with at most1.5mm seating; this explicit user-requested contact is the only additional allowed pair.','There are no elbows, length changes, mesh edits or scale.']};(S/'geometry_validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2));assert report['passed'],fail
