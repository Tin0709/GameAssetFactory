import bpy,json,sys,math
from pathlib import Path
from mathutils import Matrix,Vector
S=Path(__file__).resolve().parent;R=next(p for p in Path(bpy.data.filepath).resolve().parents if (p/'AGENTS.md').is_file());sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
N='Rifle_Aim_Hold_Arsenal_ActionsStyle_v001';r=bpy.data.objects[ui.RIG];m=bpy.data.objects['Showcase_Player_Mesh'];s=bpy.context.scene;a=bpy.data.actions[N];r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s['gaf_library_last_action']=N
p=R/'blender/animation/reviews/player_animation_library_v1/rifle_ready_idle_actionsstyle_v004/authoring/validate_upper_body_geometry.py';ns={'__file__':str(p),'__name__':'geometry_helpers'};exec(compile(p.read_text().rsplit('\nmain()',1)[0],str(p),'exec'),ns);ids,tri,bad=ns['setup'](r,m)
# Explicit solid Minecraft hand contacts, bounded below by component geometry.
ns['CONTACT'] |= {frozenset(('ForeArm.L','Rifle_V2_Body')),frozenset(('ForeArm.R','Rifle_V2_Magazine'))}
P=json.loads((S/'parameters.json').read_text());T={n:Matrix(v) for n,v in json.loads((S/'static_pose.json').read_text()).items()};baseline=bpy.data.actions['Rifle_Aim_Hold_ActionsStyle_v001'];r.animation_data.action=baseline;r.animation_data.action_slot=baseline.slots[0];s['gaf_library_last_action']=baseline.name;source=[]
for j in range(217):
 f=1+j*.5;s.frame_set(math.floor(f),subframe=f%1);bpy.context.view_layer.update();source.append({b.name:b.matrix.copy() for b in r.pose.bones})
r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s['gaf_library_last_action']=N
metrics={k:0. for k in ['unchanged_bone_matrix_error','new_target_matrix_error','foot_vertex_drift','foot_floor_error','right_grip_error','forearm_local_error','unit_scale_error','shoulder_surface_gap','support_surface_gap','loop_error']};collisions=[];adjacent=[];minhead=1e9;headseat=[1e9,-1e9];shoulderseat=0.;poses={};foot0={};gaprange=[1e9,-1e9]
def frame(f):s.frame_set(math.floor(f),subframe=f%1);bpy.context.view_layer.update();return {b.name:b.matrix.copy() for b in r.pose.bones}
for i in range(217):
 M=frame(1+i*.5);D=source[i]['UpperArm.R']@source[0]['UpperArm.R'].inverted();DH=source[i]['Head']@source[0]['Head'].inverted();pts,trees=ns['geometry'](r,m,ids,tri);pairs,sats=ns['collision'](r,pts,trees)
 for n in M:
  changed=n in ['UpperArm.R','UpperArm.L','ForeArm.R','ForeArm.L','WeaponCarrier','Head'];expected=(DH if n=='Head' else D)@T[n] if changed else source[i][n]
  key='new_target_matrix_error' if changed else 'unchanged_bone_matrix_error';metrics[key]=max(metrics[key],ns['md'](M[n],expected));metrics['unit_scale_error']=max(metrics['unit_scale_error'],max(abs(x-1) for x in M[n].to_scale()))
 metrics['right_grip_error']=max(metrics['right_grip_error'],(M['UpperArm.R']@Vector(P['right_palm'])-M['WeaponCarrier'].translation).length)
 for side in ['L','R']:
  n='Leg.'+side
  if not i:foot0[n]=[v.copy() for v in pts[n]]
  metrics['foot_vertex_drift']=max(metrics['foot_vertex_drift'],max((v-v0).length for v,v0 in zip(pts[n],foot0[n])));metrics['foot_floor_error']=max(metrics['foot_floor_error'],abs(min(v.z for v in pts[n])));metrics['forearm_local_error']=max(metrics['forearm_local_error'],ns['md'](r.pose.bones['ForeArm.'+side].matrix_basis,Matrix.Identity(4)));metrics['shoulder_surface_gap']=max(metrics['shoulder_surface_gap'],max(0,-sats['Chest|UpperArm.'+side]));shoulderseat=max(shoulderseat,sats['Chest|UpperArm.'+side])
 gap=ns['bidirectional_gap'](pts,trees,'ForeArm.L','Rifle_V2_Body');gaprange=[min(gaprange[0],gap),max(gaprange[1],gap)];metrics['support_surface_gap']=max(metrics['support_surface_gap'],gap);minhead=min(minhead,ns['bidirectional_gap'](pts,trees,'Head','Rifle_V2_Body'));hs=next(v for k,v in sats.items() if frozenset(k.split('|'))==frozenset(('Head','Chest')));headseat=[min(headseat[0],hs),max(headseat[1],hs)]
 for k,c in pairs.items():
  key=frozenset(k.split('|'));allowed=ns['ADJACENT']|ns['CONTACT']
  if c and key not in allowed and sats.get(k,1)>1e-5:collisions.append({'frame':1+i*.5,'pair':k,'sat':sats.get(k),'triangles':c})
 for k,v in sats.items():
  key=frozenset(k.split('|'))
  if key not in ns['ADJACENT'] and key not in ns['CONTACT'] and v>1e-5 and not pairs[k]:collisions.append({'frame':1+i*.5,'pair':k,'sat':v,'contained':True})
  lim=.03 if key==frozenset(('Head','Chest')) else .055 if 'Chest' in key and any(n.startswith('UpperArm.') for n in key) else .08
  if key in ns['ADJACENT'] and v>lim:adjacent.append({'frame':1+i*.5,'pair':k,'sat':v,'limit':lim})
 if i in [0,216]:poses[i]=M
metrics['loop_error']=max(ns['md'](poses[0][n],poses[216][n]) for n in poses[0]);A=frame(1);B=frame(1.125);Z=frame(108.875);E=frame(109);vseam=wseam=0.
for n in A:
 v0,w0=ns['transform_vel'](A[n],B[n],1/240);v1,w1=ns['transform_vel'](Z[n],E[n],1/240);vseam=max(vseam,(v0-v1).length);wseam=max(wseam,(w0-w1).length)
# All hand/weapon transforms share D, so component contact depths are invariant.
frame(1);components=json.loads((S/'weapon_components.json').read_text());contact_depth={}
import itertools
for part,arm in [('Rifle_V2_Body','ForeArm.L'),('Rifle_V2_Magazine','ForeArm.R')]:
 depths=[];ma=r.pose.bones[arm].matrix;wc=r.pose.bones['WeaponCarrier'].matrix
 for vertices in components[part]:
  lo=[min(v[j] for v in vertices) for j in range(3)];hi=[max(v[j] for v in vertices) for j in range(3)];box=[wc@Vector(v) for v in itertools.product(*[(lo[j],hi[j]) for j in range(3)])]
  depths.append(ns['cuboid_signed_margin'](pts[arm],box,[ma.to_3x3().col[j] for j in range(3)],[wc.to_3x3().col[j] for j in range(3)]))
 contact_depth[part+'|'+arm]=max(depths)
old=json.loads((S/'source_actions_before.json').read_text());assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in old.items())
limits={'unchanged_bone_matrix_error':1e-5,'new_target_matrix_error':1e-5,'foot_vertex_drift':1e-5,'foot_floor_error':1e-5,'right_grip_error':2e-5,'forearm_local_error':1e-5,'unit_scale_error':1e-5,'shoulder_surface_gap':.01,'support_surface_gap':.012,'loop_error':1e-5};fail=[k for k,v in limits.items() if metrics[k]>v]
if max(contact_depth.values())>.008:fail.append('hand_contact_seating_above8mm')
if collisions:fail.append('nonadjacent_collision')
if adjacent:fail.append('excessive_joint_seating')
if minhead<.008:fail.append('face_clearance_below8mm')
if headseat[0]<-.002:fail.append('head_collar_gap')
if vseam>.006 or wseam>.05:fail.append('loop_velocity')
report={'passed':not fail,'failures':fail,'sampled_poses':217,'metrics':metrics,'limits':limits,'minimum_head_rifle_surface_gap_m':minhead,'support_surface_gap_range_m':gaprange,'head_chest_signed_contact_range_m':headseat,'shoulder_max_seating_m':shoulderseat,'loop_translation_velocity_difference_m_s':vseam,'loop_angular_velocity_difference_rad_s':wseam,'all_source_file_previous_actions_exact':len(old),'bounded_solid_hand_contact_max_component_obb_depth_m':contact_depth,'hand_seating_limit_m':.008,'collision_pairs':{k:sum(c['pair']==k for c in collisions) for k in sorted(set(c['pair'] for c in collisions))},'collisions_count':len(collisions),'collisions':collisions[:30],'adjacent':adjacent[:20]};(S/'geometry_validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2),flush=True);assert report['passed'],fail
