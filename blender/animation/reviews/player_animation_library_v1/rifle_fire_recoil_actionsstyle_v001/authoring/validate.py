"""Evaluated geometry, grip, loop and repeated-shot checks; never edits sources."""
import bpy,json,sys,math,argparse,hashlib
from pathlib import Path
from mathutils import Matrix,Vector
p=argparse.ArgumentParser();p.add_argument('--repo');opt=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []);S=Path(__file__).resolve().parent;O=S.parent;R=Path(opt.repo) if opt.repo else next(p for p in S.parents if (p/'AGENTS.md').is_file());sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
P=R/'blender/animation/reviews/player_animation_library_v1/rifle_ready_idle_actionsstyle_v004/authoring/validate_upper_body_geometry.py';g={'__file__':str(P),'__name__':'geometry_helpers'};exec(compile(P.read_text().rsplit('\nmain()',1)[0],str(P),'exec'),g)
E=json.loads((S/'baseline_entry.json').read_text());N='Rifle_Fire_Recoil_ActionsStyle_v001';r,m,a=g['open_scene'](R/E['source'],E['action']);g['frame'](85);B=g['pose_snapshot'](r);base_top=g['topology'](r,m);ids,tri,bad=g['setup'](r,m);bp,bt=g['geometry'](r,m,ids,tri);pairs0,sats0=g['collision'](r,bp,bt);C=B['UpperArm.R'].inverted()@B['WeaponCarrier'];anchor=B['WeaponCarrier'].inverted()@(B['ForeArm.L']@Vector((0,r.data.bones['ForeArm.L'].length*.78,0)));base_local_head=r.pose.bones['Head'].matrix_basis.copy();floor={n:min(v.z for v in bp[n]) for n in ['Leg.L','Leg.R']};headlocal=[B['Head'].inverted()@v for v in bp['Head']];hlo=[min(v[j] for v in headlocal) for j in range(3)];hhi=[max(v[j] for v in headlocal) for j in range(3)]
sourceactions={a.name:ui.action_signature(a) for a in bpy.data.actions}
r,m,a=g['open_scene'](O/'rifle_fire_recoil_actionsstyle_v001.blend',N);assert g['topology'](r,m)==base_top;assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in sourceactions.items());ids,tri,bad=g['setup'](r,m);assert not bad
metrics={k:0. for k in ['entry_pose_error','exit_pose_error','right_grip_relative_error','forearm_articulation_error','unit_scale_error','foot_vertex_drift_m','left_support_anchor_drift_m','right_shoulder_offset_m','left_shoulder_offset_m','head_local_roll_change_rad','muzzle_pitch_up_deg','weapon_back_m','endpoint_velocity_m_s']};fails=[];contacts={};satmax={};headgap=1e9;leftgap=1e9;maxheaddepth=0.;firstlast={};fwd=B['WeaponCarrier'].to_3x3().col[1].normalized();pitch0=math.atan2(fwd.z,Vector((fwd.x,fwd.y,0)).length)
for i in range(81):
 f=1+i/16;g['frame'](f);M=g['pose_snapshot'](r);pts,trees=g['geometry'](r,m,ids,tri);pairs,sats=g['collision'](r,pts,trees)
 if i in [0,80]:firstlast[i]=M
 if i==0:metrics['entry_pose_error']=max(g['md'](M[n],B[n]) for n in M)
 if i in [64,80]:metrics['exit_pose_error']=max(metrics['exit_pose_error'],max(g['md'](M[n],B[n]) for n in M))
 metrics['right_grip_relative_error']=max(metrics['right_grip_relative_error'],g['md'](M['UpperArm.R'].inverted()@M['WeaponCarrier'],C))
 for side in ['L','R']:metrics['forearm_articulation_error']=max(metrics['forearm_articulation_error'],g['md'](r.pose.bones['ForeArm.'+side].matrix_basis,Matrix.Identity(4)))
 for n in M:metrics['unit_scale_error']=max(metrics['unit_scale_error'],max(abs(x-1) for x in M[n].to_scale()))
 for n in ['Leg.L','Leg.R']:metrics['foot_vertex_drift_m']=max(metrics['foot_vertex_drift_m'],max((x-y).length for x,y in zip(pts[n],bp[n])))
 palm=Vector((0,r.data.bones['ForeArm.L'].length*.78,0));metrics['left_support_anchor_drift_m']=max(metrics['left_support_anchor_drift_m'],(M['WeaponCarrier'].inverted()@(M['ForeArm.L']@palm)-anchor).length)
 for side,key in [('R','right_shoulder_offset_m'),('L','left_shoulder_offset_m')]:metrics[key]=max(metrics[key],((B['Chest']@M['Chest'].inverted()@M['UpperArm.'+side]).translation-B['UpperArm.'+side].translation).length)
 dhead=base_local_head.inverted()@r.pose.bones['Head'].matrix_basis;metrics['head_local_roll_change_rad']=max(metrics['head_local_roll_change_rad'],abs(dhead.to_euler().z))
 forward=M['WeaponCarrier'].to_3x3().col[1].normalized();metrics['muzzle_pitch_up_deg']=max(metrics['muzzle_pitch_up_deg'],math.degrees(math.atan2(forward.z,Vector((forward.x,forward.y,0)).length)-pitch0));metrics['weapon_back_m']=max(metrics['weapon_back_m'],(M['WeaponCarrier'].translation-B['WeaponCarrier'].translation).dot(-fwd))
 headgap=min(headgap,g['bidirectional_gap'](pts,trees,'Head','Rifle_V2_Body'));leftgap=min(leftgap,g['bidirectional_gap'](pts,trees,'ForeArm.L','Rifle_V2_Body'))
 inv=M['Head'].inverted();vs=[inv@v for v in pts['Rifle_V2_Body']];maxheaddepth=max(maxheaddepth,max(0.,max(min(min(v[j]-hlo[j],hhi[j]-v[j]) for j in range(3)) for v in vs)))
 for k,n in pairs.items():
  contacts[k]=max(contacts.get(k,0),n)
  key=frozenset(k.split('|'));allowed=g['ADJACENT']|g['CONTACT']|{frozenset(('ForeArm.L','Rifle_V2_Body'))}
  if n and not pairs0[k] and key not in allowed and sats.get(k,1)>1e-5:fails.append('new_nonadjacent_contact:'+k)
 for k,n in sats.items():
  satmax[k]=max(satmax.get(k,-1e9),n)
  if n>max(0,sats0[k])+.003 and frozenset(k.split('|')) not in g['ADJACENT']:fails.append('deepened_body_contact:'+k)
metrics['loop_pose_error']=max(g['md'](firstlast[0][n],firstlast[80][n]) for n in B)
for x,y in [(1,1.125),(5.875,6)]:
 g['frame'](x);a0=g['pose_snapshot'](r);g['frame'](y);b0=g['pose_snapshot'](r);metrics['endpoint_velocity_m_s']=max(metrics['endpoint_velocity_m_s'],max((b0[n].translation-a0[n].translation).length/(.125/30) for n in B))
for k in ['entry_pose_error','exit_pose_error','right_grip_relative_error','forearm_articulation_error','unit_scale_error','foot_vertex_drift_m','loop_pose_error','endpoint_velocity_m_s']:
 if metrics[k]>1e-5:fails.append(k)
if metrics['left_support_anchor_drift_m']>.0015:fails.append('left_support_uncontrolled')
if metrics['right_shoulder_offset_m']>.018 or metrics['left_shoulder_offset_m']>.018:fails.append('shoulder_seating')
if metrics['head_local_roll_change_rad']>.0001:fails.append('approved_head_lean_changed')
if not 1.<metrics['muzzle_pitch_up_deg']<4.:fails.append('recoil_pitch')
if not .001<metrics['weapon_back_m']<.025:fails.append('recoil_back')
if maxheaddepth>.0005 or headgap<.001:fails.append('head_rifle_clearance')
# Real Blender NLA repeats the SAME absolute Action: no second Action or additive
# transform accumulation is used to generate the burst review.
r.animation_data.action=None;track=r.animation_data.nla_tracks.new();strip=track.strips.new('Same shot repeated20times',1,a);strip.action_frame_start=1;strip.action_frame_end=6;strip.repeat=20;strip.extrapolation='HOLD';repeaterror=0.
for i in range(21):
 g['frame'](1+i*5);M=g['pose_snapshot'](r);repeaterror=max(repeaterror,max(g['md'](M[n],B[n]) for n in B))
if repeaterror>1e-5:fails.append('repeat_accumulation')
report={'passed':not fails,'failures':sorted(set(fails)),'sampled_poses':81,'metrics':metrics,'preserved_embedded_actions':len(sourceactions),'head_rifle_min_gap_m':headgap,'head_weapon_vertex_depth_max_m':maxheaddepth,'left_support_min_surface_gap_m':leftgap,'baseline_foot_min_z_m':floor,'feet_exact_to_approved_base':True,'repeated_same_action_cycles':20,'repeated_boundary_pose_error':repeaterror,'baseline_body_contacts_m':sats0,'maximum_body_contacts_m':satmax,'maximum_contacts':{k:v for k,v in contacts.items() if v},'note':'Approved fixed Aim base retains its pre-existing rigid-cube/floor contacts; no new lower-body motion. Recoil is original and absolute, with a zero-offset return.'};(O/'validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2),flush=True);assert report['passed'],report['failures']
