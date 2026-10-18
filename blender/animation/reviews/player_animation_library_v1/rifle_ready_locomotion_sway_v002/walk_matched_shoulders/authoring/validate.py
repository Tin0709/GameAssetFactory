"""Independent evaluated mesh/rig/weapon and original-action preservation audit."""
import bpy,sys,json,math,itertools,hashlib
from pathlib import Path
from mathutils import Vector
R=next((p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').exists()),Path('/Users/tin/Desktop/Game Dev/GameAssetFactory'));O=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
G=R/'blender/animation/reviews/player_animation_library_v1/rifle_ready_idle_actionsstyle_v004/authoring/validate_upper_body_geometry.py';ns={'__file__':str(G),'__name__':'geometry_helpers'};exec(compile(G.read_text().rsplit('\nmain()',1)[0],str(G),'exec'),ns)
r=bpy.data.objects[ui.RIG];m=bpy.data.objects['Showcase_Player_Mesh'];s=bpy.context.scene;ids,tri,bad=ns['setup'](r,m);assert not bad
base=bpy.data.actions['Rifle_Ready_Idle_ActionsStyle_v004'];assert ui.action_signature(base)=='88b1ce9fe830f3377a58b8bf1cf04f1f602372f287b559aae8ee28e576d8409b'
r.animation_data.action=base;r.animation_data.action_slot=base.slots[0];s['gaf_library_last_action']=base.name;ns['frame'](1);B=ns['pose_snapshot'](r);palm=Vector((0,r.data.bones['ForeArm.L'].length*.78,0));anchor=B['WeaponCarrier'].inverted()@(B['ForeArm.L']@palm);rightrel={n:B['WeaponCarrier'].inverted()@B[n] for n in ['UpperArm.R','ForeArm.R']};rest={b.name:b.matrix_local.copy() for b in r.data.bones}
reports=[]
for e in [json.loads((O/'entry.json').read_text())]:
 a=bpy.data.actions[e['action']];ui.validate_action(a,e,r);r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s['gaf_library_last_action']=a.name
 metrics={'right_grip_matrix_error':0.,'straight_arm_cross_error':0.,'forearm_articulation_rad':0.,'head_anchor_error_m':0.,'sole_penetration_m':0.,'support_palm_delta_m':0.};max_sat={};badpairs={};poses={};scales={n:[10.,0.] for n in ['Leg.L','Leg.R']}
 closing=e['endpoint_sample_frame'];samples=[1+j/2 for j in range(round((closing-1)*2)+1)]
 for j,f in enumerate(samples):
  ns['frame'](f);M=ns['pose_snapshot'](r);pts,trees=ns['geometry'](r,m,ids,tri);pairs,sats=ns['collision'](r,pts,trees)
  for n,rel in rightrel.items():metrics['right_grip_matrix_error']=max(metrics['right_grip_matrix_error'],ns['md'](M['WeaponCarrier'].inverted()@M[n],rel))
  for side in ['L','R']:
   u=r.pose.bones['UpperArm.'+side];f0=r.pose.bones['ForeArm.'+side];metrics['straight_arm_cross_error']=max(metrics['straight_arm_cross_error'],(u.tail-u.head).normalized().cross((f0.tail-f0.head).normalized()).length);metrics['forearm_articulation_rad']=max(metrics['forearm_articulation_rad'],f0.matrix_basis.to_quaternion().angle)
  top=M['Chest']@rest['Chest'].inverted()@Vector((0,0,1.35));metrics['head_anchor_error_m']=max(metrics['head_anchor_error_m'],(M['Head'].translation-top).length);metrics['support_palm_delta_m']=max(metrics['support_palm_delta_m'],(M['WeaponCarrier'].inverted()@(M['ForeArm.L']@palm)-anchor).length)
  for n in scales:
   v=r.pose.bones[n].scale.y;scales[n][0]=min(scales[n][0],v);scales[n][1]=max(scales[n][1],v);metrics['sole_penetration_m']=max(metrics['sole_penetration_m'],max(0,-min(x.z for x in pts[n])))
  for k,v in sats.items():max_sat[k]=max(max_sat.get(k,-100),v)
  for k,v in pairs.items():
   key=frozenset(k.split('|'))
   if key not in ns['ADJACENT']|ns['CONTACT'] and ((v and (k not in sats or sats[k]>1e-5)) or sats.get(k,-1)>1e-5):badpairs.setdefault(k,{'frame':f,'triangle_pairs':v,'sat_margin_m':sats.get(k)})
  if f in [1,closing]:poses[f]=M
  if j%1800==0:print(a.name,'geometry',j,'/',len(samples),flush=True)
 seam=max(ns['md'](poses[1][n],poses[closing][n]) for n in poses[1]);fail=[]
 for k,lim in [('right_grip_matrix_error',1e-4),('straight_arm_cross_error',1e-5),('forearm_articulation_rad',1e-5),('head_anchor_error_m',1e-5),('sole_penetration_m',.0001),('support_palm_delta_m',.004)]:
  if metrics[k]>lim:fail.append(k)
 if seam>1e-4:fail.append('loop seam')
 # Neighboring blocks keep the same explicitly bounded seating envelopes.
 if max_sat.get('Chest|UpperArm.R',0)>.055:fail.append('right shoulder seating')
 if max_sat.get('Head|Chest',0)>.030:fail.append('neck seating')
 if max_sat.get('Chest|UpperArm.L',0)>.020:fail.append('left shoulder seating')
 # Second-order derivatives at the native bake interval, retaining the small
 # linear-key spacing artefact as a separately reported first-order measure.
 dt=1./240.;pose={}
 for ff in [1,1.125,1.25,closing-.25,closing-.125,closing]:
  ns['frame'](ff);pose[ff]=ns['pose_snapshot'](r)
 vm=0.;wm=0.;raw=0.;upper_vm=0.;upper_wm=0.
 def rv(q):
  if q.w<0:q.negate()
  v=Vector((q.x,q.y,q.z));length=v.length;return v*(2*math.atan2(length,q.w)/length) if length>1e-12 else Vector()
 for n in pose[1]:
  p0,p1,p2=[pose[f][n].translation for f in [1,1.125,1.25]]
  pe,pm1,pm2=[pose[f][n].translation for f in [closing,closing-.125,closing-.25]]
  vm=max(vm,((-3*p0+4*p1-p2)/(2*dt)-(3*pe-4*pm1+pm2)/(2*dt)).length)
  qs=[pose[f][n].to_quaternion() for f in [1,1.125,1.25,closing,closing-.125,closing-.25]]
  w0=(4*rv(qs[1]@qs[0].inverted())-rv(qs[2]@qs[0].inverted()))/(2*dt)
  we=(4*rv(qs[3]@qs[4].inverted())-rv(qs[3]@qs[5].inverted()))/(2*dt)
  wm=max(wm,(w0-we).length)
  if n not in ['Leg.L','Leg.R']:upper_vm=max(upper_vm,((-3*p0+4*p1-p2)/(2*dt)-(3*pe-4*pm1+pm2)/(2*dt)).length);upper_wm=max(upper_wm,(w0-we).length)
  raw=max(raw,(rv(qs[1]@qs[0].inverted())/dt-rv(qs[3]@qs[4].inverted())/dt).length)
 # The approved legs have an existing strict subframe derivative diagnostic;
 # assert that their complete wrap poses are identical rather than pretending
 # the upper-body refinement fixes or introduces that baseline characteristic.
 base=bpy.data.actions[e['refinement_base']];r.animation_data.action=base;r.animation_data.action_slot=base.slots[0];s['gaf_library_last_action']=base.name
 inherited_leg_pose_error=0.
 for ff in pose:
  ns['frame'](ff);bm=ns['pose_snapshot'](r)
  for leg in ['Leg.L','Leg.R']:inherited_leg_pose_error=max(inherited_leg_pose_error,ns['md'](pose[ff][leg],bm[leg]))
 if inherited_leg_pose_error>1e-6:fail.append('approved leg wrap changed')
 if upper_vm>.006:fail.append('new upper-body loop translation velocity')
 if upper_wm>.05:fail.append('new upper-body loop angular velocity')
 if badpairs:fail.append('nonadjacent/rifle collisions')
 rep={'action':a.name,'passed':not fail,'failures':fail,'samples':len(samples),'metrics':metrics,'loop_matrix_error':seam,'leg_scale_ranges':scales,'max_cuboid_margin_m':max_sat,'unwanted_collisions':badpairs,'second_order_loop_velocity_m_s':vm,'second_order_loop_angular_rad_s':wm,'raw_first_order_angular_rad_s':raw,'upperbody_loop_velocity_m_s':upper_vm,'upperbody_loop_angular_rad_s':upper_wm,'inherited_leg_wrap_pose_error':inherited_leg_pose_error};reports.append(rep);print(json.dumps(rep),flush=True)
(O/'geometry_validation.json').write_text(json.dumps({'passed':all(x['passed'] for x in reports),'reports':reports,'limitations':['Source leg length pulses are retained; straight cuboid legs are not fixed-length.','Adjacent rigid block joint seating is measured separately, not treated as nonadjacent collision.','Foot-floor adapters preserve source angles and horizontal paths; no gameplay foot-lock certification.','Strict full-rig subframe derivative diagnostics include inherited approved leg corner/linear-bake behavior. Those leg wrap poses are checked against the approved baseline exactly; new upper-body motion is checked separately against0.006m/s and0.05rad/s.']},indent=2))

assert all(x["passed"] for x in reports),"Geometry validation failed; inspect geometry_validation.json"
