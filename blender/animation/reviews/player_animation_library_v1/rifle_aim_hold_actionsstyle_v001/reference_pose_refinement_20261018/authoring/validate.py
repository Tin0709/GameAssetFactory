import bpy,json,sys,math,itertools
from pathlib import Path
from mathutils import Matrix,Vector
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').exists());S=Path(__file__).resolve().parent.parent;sys.path.insert(0,str(Path(__file__).resolve().parent));sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
from motion import Motion,env,ease
N='Rifle_Aim_Hold_ActionsStyle_v001';r=bpy.data.objects[ui.RIG];m=bpy.data.objects['Showcase_Player_Mesh'];s=bpy.context.scene;a=bpy.data.actions[N];P=json.loads((S/'aim_parameters.json').read_text());r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s['gaf_library_last_action']=N
path=R/'blender/animation/reviews/player_animation_library_v1/rifle_ready_idle_actionsstyle_v004/authoring/validate_upper_body_geometry.py';ns={'__file__':str(path),'__name__':'geometry_helpers'};exec(compile(path.read_text().rsplit('\nmain()',1)[0],str(path),'exec'),ns);ids,tri,bad=ns['setup'](r,m)
def frame(f):s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update();return {b.name:b.matrix.copy() for b in r.pose.bones}
B=frame(1);mo=Motion(r,B);rest=mo.rest;basepts,_=ns['geometry'](r,m,ids,tri);maxes={k:0. for k in ['right_grip_error','left_palm_error','forearm_bend','straight_cross','unit_scale','foot_drift','foot_penetration','eye_line_gap_hold','shoulder_gap_hold','seam','hold_seam']};min_head_gap=1e9;max_support_gap=0.;collisions=[];adjacent=[];poses={};samples=[1+i*.5 for i in range(433)]
for j,f in enumerate(samples):
 M=frame(f);t=(f-1)/30;w=env(t);C=M['WeaponCarrier'];pts,trees=ns['geometry'](r,m,ids,tri);pairs,sats=ns['collision'](r,pts,trees)
 point=mo.gripR+Vector((0,P.get('grip_forward_m',0.)*w,0));maxes['right_grip_error']=max(maxes['right_grip_error'],(M['UpperArm.R']@point-C.translation).length)
 expected=C@(mo.anchorL+Vector((P.get('support_outward_m',0.)*w-.015*math.sin(math.pi*w)**2-P.get('transition_support_outward_m',0.)*math.sin(math.pi*w),P.get('support_back_m',0.)*ease(max(0.,(w-.2)/.8)),P.get('support_up_m',0.)*ease(min(1.,w*2))+.0007*math.sin(math.tau*t/.9))));actual=M['ForeArm.L']@mo.palmL;maxes['left_palm_error']=max(maxes['left_palm_error'],(actual-expected).length)
 for side in ['L','R']:
  u=r.pose.bones['UpperArm.'+side];q=r.pose.bones['ForeArm.'+side];maxes['straight_cross']=max(maxes['straight_cross'],(u.tail-u.head).normalized().cross((q.tail-q.head).normalized()).length);maxes['forearm_bend']=max(maxes['forearm_bend'],q.matrix_basis.to_quaternion().angle)
 for n,x in M.items():maxes['unit_scale']=max(maxes['unit_scale'],max(abs(z-1) for z in x.to_scale()))
 for n in ['Leg.L','Leg.R']:
  maxes['foot_drift']=max(maxes['foot_drift'],max((p-q).length for p,q in zip(pts[n],basepts[n])));maxes['foot_penetration']=max(maxes['foot_penetration'],max(0.,-min(p.z for p in pts[n])))
 for k,count in pairs.items():
  key=frozenset(k.split('|'))
  if count and key not in ns['ADJACENT']|ns['CONTACT'] and sats.get(k,1)>1e-5:collisions.append({'frame':f,'pair':k,'count':count,'sat':sats.get(k)})
 for k,margin in sats.items():
  key=frozenset(k.split('|'))
  if key not in ns['ADJACENT'] and margin>1e-5 and pairs[k]==0:collisions.append({'frame':f,'pair':k,'sat':margin,'contained':True})
  limit=.03 if key==frozenset(('Head','Chest')) else .055 if 'Chest' in key and ('UpperArm.L' in key or 'UpperArm.R' in key) else .08
  if key in ns['ADJACENT'] and margin>limit:adjacent.append({'frame':f,'pair':k,'margin':margin,'limit':limit})
 min_head_gap=min(min_head_gap,ns['bidirectional_gap'](pts,trees,'Head','Rifle_V2_Body'))
 if 37<=f<=145:
  eye=M['Head']@Vector((-.140625,.28125,.225));sight=C@Vector((0,0,.25));axis=C.to_3x3().col[1].normalized();maxes['eye_line_gap_hold']=max(maxes['eye_line_gap_hold'],(eye-sight).cross(axis).length)
  maxes['shoulder_gap_hold']=max(maxes['shoulder_gap_hold'],max(-sats['Chest|UpperArm.'+side] for side in ['L','R']))
  max_support_gap=max(max_support_gap,ns['bidirectional_gap'](pts,trees,'ForeArm.L','Rifle_V2_Body'))
 if f in [1.,37.,145.,217.]:poses[f]=M
 if j%120==0:print('QA',j,'collisions',len(collisions),flush=True)
md=lambda A,B:max(abs(A[i][j]-B[i][j]) for i in range(4) for j in range(4))
maxes['seam']=max(md(poses[1][n],poses[217][n]) for n in B);maxes['hold_seam']=max(md(poses[37][n],poses[145][n]) for n in B)
# Independent persisted-action preservation, not just the active pose.
old=json.loads((S/'source_actions_before.json').read_text());assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in old.items())
fail=[];limits={'right_grip_error':.00003,'left_palm_error':.00003,'forearm_bend':.0001,'straight_cross':.00001,'unit_scale':.00001,'foot_drift':.00001,'foot_penetration':.00001,'eye_line_gap_hold':.07,'shoulder_gap_hold':.008,'seam':.00001,'hold_seam':.00001}
for k,lim in limits.items():
 if maxes[k]>lim:fail.append(k)
if collisions:fail.append('Nonadjacent/rifle intersections')
if adjacent:fail.append('Excessive joint seating')
# Approved Ready surface gap reaches12.97mm; allow14mm including sub-mm life.
if max_support_gap>.014:fail.append('Support hand surface gap')
report={'passed':not fail,'failures':fail,'sampled_poses':len(samples),'metrics':maxes,'limits':limits,'minimum_head_rifle_surface_gap_m':min_head_gap,'maximum_support_hand_surface_gap_hold_m':max_support_gap,'collisions_count':len(collisions),'collisions':collisions[:90],'adjacent_excess':adjacent[:20],'existing_source_actions_preserved':len(old)};(S/'geometry_validation.json').write_text(json.dumps(report,indent=2));print('AIM_QA',json.dumps(report),flush=True);assert report['passed'],fail
