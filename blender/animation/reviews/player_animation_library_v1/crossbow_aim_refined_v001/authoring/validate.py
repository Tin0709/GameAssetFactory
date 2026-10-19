import bpy,json,sys,math
from pathlib import Path
from mathutils import Matrix,Quaternion,Vector
S=Path(__file__).resolve().parent;R=next(p for p in Path(bpy.data.filepath).resolve().parents if (p/'AGENTS.md').is_file());sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
BASE='Crossbow_Aim_ActionsStuff_Source_Test_v001';N='Crossbow_Aim_ActionsStuff_Refined_Test_v001';r=bpy.data.objects[ui.RIG];m=bpy.data.objects['Showcase_Player_Mesh'];s=bpy.context.scene;a=bpy.data.actions[N];base=bpy.data.actions[BASE]
p=R/'blender/animation/reviews/player_animation_library_v1/rifle_ready_idle_actionsstyle_v004/authoring/validate_upper_body_geometry.py';ns={'__file__':str(p),'__name__':'geometry_helpers'};exec(compile(p.read_text().rsplit('\nmain()',1)[0],str(p),'exec'),ns);ids,tri,bad=ns['setup'](r,m)
def setact(a):r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s['gaf_library_last_action']=a.name
def frame(f):s.frame_set(math.floor(f),subframe=f%1);bpy.context.view_layer.update();return {b.name:b.matrix.copy() for b in r.pose.bones}
setact(base);source=[];source_sat_max={};refined_sat_max={};source_head_weapon_depth=0.;refined_head_weapon_depth=0.
headlocal=[r.data.bones['Head'].matrix_local.inverted()@m.data.vertices[i].co for i in ids['Head']];hlo=[min(v[j] for v in headlocal) for j in range(3)];hhi=[max(v[j] for v in headlocal) for j in range(3)]
def head_depth(M,pts):
 inv=M['Head'].inverted();vals=[inv@v for v in pts['Rifle_V2_Body']];return max(0.,max(min(min(v[j]-hlo[j],hhi[j]-v[j]) for j in range(3)) for v in vals))
for i in range(217):
 M=frame(1+i*.5);pts,trees=ns['geometry'](r,m,ids,tri);pairs,sats=ns['collision'](r,pts,trees);source_head_weapon_depth=max(source_head_weapon_depth,head_depth(M,pts))
 for k,v in sats.items():source_sat_max[k]=max(v,source_sat_max.get(k,-1e9))
 source.append((M,pairs,sats,ns['bidirectional_gap'](pts,trees,'Head','Rifle_V2_Body'),ns['bidirectional_gap'](pts,trees,'ForeArm.L','Rifle_V2_Body')))
setact(a);metrics={k:0. for k in ['unchanged_bone_matrix_error','head_target_error','left_target_error','shoulder_root_error','head_base_error','forearm_local_error','right_grip_relative_error','unit_scale_error','loop_error']};newcollisions=[];oldcontacts={};newcontacts={};minHead=1e9;oldHead=1e9;gaps=[];armmoves=[];outward=[];headmoves=[];poses={}
for i in range(217):
 M=frame(1+i*.5);B,oldpairs,oldsat,hgap,lgap=source[i];H=B['Head']@Matrix.Rotation(math.radians(7),4,'Z');H.translation+=B['Chest'].to_3x3().col[1].normalized()*.008+B['Chest'].to_3x3().col[0].normalized()*.012
 down=Quaternion(B['Chest'].to_3x3().col[0].normalized(),math.radians(5)).to_matrix().to_4x4();out=Quaternion(B['Chest'].to_3x3().col[1].normalized(),math.radians(2)).to_matrix().to_4x4();L=down@out@B['UpperArm.L'];L.translation=B['UpperArm.L'].translation;U=down@B['UpperArm.R'];U.translation=B['UpperArm.R'].translation;F=L@B['UpperArm.L'].inverted()@B['ForeArm.L'];FR=U@B['UpperArm.R'].inverted()@B['ForeArm.R'];W=U@B['UpperArm.R'].inverted()@B['WeaponCarrier'];metrics['head_target_error']=max(metrics['head_target_error'],ns['md'](M['Head'],H));metrics['left_target_error']=max(metrics['left_target_error'],ns['md'](M['UpperArm.L'],L),ns['md'](M['ForeArm.L'],F),ns['md'](M['UpperArm.R'],U),ns['md'](M['ForeArm.R'],FR),ns['md'](M['WeaponCarrier'],W));metrics['right_grip_relative_error']=max(metrics['right_grip_relative_error'],ns['md'](M['UpperArm.R'].inverted()@M['WeaponCarrier'],B['UpperArm.R'].inverted()@B['WeaponCarrier']))
 for n in M:
  if n not in ['Head','UpperArm.L','ForeArm.L','UpperArm.R','ForeArm.R','WeaponCarrier']:metrics['unchanged_bone_matrix_error']=max(metrics['unchanged_bone_matrix_error'],ns['md'](M[n],B[n]))
  metrics['unit_scale_error']=max(metrics['unit_scale_error'],max(abs(x-1) for x in M[n].to_scale()))
 metrics['head_base_error']=max(metrics['head_base_error'],(M['Head'].translation-H.translation).length);metrics['shoulder_root_error']=max(metrics['shoulder_root_error'],(M['UpperArm.L'].translation-B['UpperArm.L'].translation).length)
 for side in ['L','R']:metrics['forearm_local_error']=max(metrics['forearm_local_error'],ns['md'](r.pose.bones['ForeArm.'+side].matrix_basis,Matrix.Identity(4)))
 palm=Vector((0,.62,0));move=M['UpperArm.L']@palm-B['UpperArm.L']@palm;armmoves.append(move.length);outward.append((M['UpperArm.L']@palm-(down@B['UpperArm.L']@palm+(B['UpperArm.L'].translation-(down@B['UpperArm.L']).translation))).dot(B['Chest'].to_3x3().col[0].normalized()));top=Vector((0,.45,0));move=M['Head']@top-B['Head']@top;gun=B['WeaponCarrier'].translation-B['Head'].translation;gun.z=0;headmoves.append(move.dot(gun.normalized()))
 pts,trees=ns['geometry'](r,m,ids,tri);pairs,sats=ns['collision'](r,pts,trees);refined_head_weapon_depth=max(refined_head_weapon_depth,head_depth(M,pts))
 for k,v in sats.items():refined_sat_max[k]=max(v,refined_sat_max.get(k,-1e9))
 gap=ns['bidirectional_gap'](pts,trees,'ForeArm.L','Rifle_V2_Body');gaps.append([lgap,gap]);minHead=min(minHead,ns['bidirectional_gap'](pts,trees,'Head','Rifle_V2_Body'));oldHead=min(oldHead,hgap)
 for k,v in pairs.items():
  if v: newcontacts[k]=max(v,newcontacts.get(k,0))
  if oldpairs[k]:oldcontacts[k]=max(oldpairs[k],oldcontacts.get(k,0))
 if i in [0,216]:poses[i]=M
metrics['loop_error']=max(ns['md'](poses[0][n],poses[216][n]) for n in M);old=json.loads((S/'source_actions_before.json').read_text());assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in old.items());fail=[k for k,v in metrics.items() if v>1e-5]
# The preferred literal source already has raw rigid-cube/weapon intersections.
# Compare the entire cycle's contact envelope, rather than requiring the changed
# head pose to reproduce each source frame's contact phase.
for k,v in newcontacts.items():
 if k not in oldcontacts:newcollisions.append({'pair':k,'kind':'new_contact_pair_type'})
for k,v in refined_sat_max.items():
 key=frozenset(k.split('|'))
 if key==frozenset(('Head','Chest')):
  if v>.0305:newcollisions.append({'pair':k,'kind':'collar_seating_above30p5mm','depth':v})
 elif key not in ns['ADJACENT']|ns['CONTACT'] and v>max(1e-5,source_sat_max[k]+.001):newcollisions.append({'pair':k,'kind':'cycle_max_deeper_than_source_1mm','old':source_sat_max[k],'new':v})
if refined_head_weapon_depth>source_head_weapon_depth+.001:newcollisions.append({'pair':'Head|Rifle_V2_Body','kind':'max_weapon_vertex_depth_worse_than_source_1mm','old':source_head_weapon_depth,'new':refined_head_weapon_depth})
if newcollisions:fail.append('contact_envelope_worse_than_preferred_source')
if min(outward)<.005:fail.append('left_hand_not_moving_outward')
if min(headmoves)<.005:fail.append('head_not_leaning_toward_rifle')
report={'passed':not fail,'failures':fail,'sampled_poses':217,'metrics':metrics,'head_lean_deg':7,'arms_downward_deg':5,'head_seating_lift_m':.008,'head_seating_lateral_m':.012,'left_whole_arm_outward_deg':2,'left_palm_displacement_m':[min(armmoves),max(armmoves)],'left_palm_outward_projection_m':[min(outward),max(outward)],'head_top_toward_gun_projection_m':[min(headmoves),max(headmoves)],'head_rifle_min_gap_m':{'source':oldHead,'refined':minHead},'left_arm_weapon_surface_gap_m':{'source_range':[min(v[0] for v in gaps),max(v[0] for v in gaps)],'refined_range':[min(v[1] for v in gaps),max(v[1] for v in gaps)]},'source_sat_cycle_max_m':source_sat_max,'refined_sat_cycle_max_m':refined_sat_max,'head_weapon_vertex_depth_max_m':{'source':source_head_weapon_depth,'refined':refined_head_weapon_depth},'new_collisions':newcollisions[:25],'new_collisions_count':len(newcollisions),'source_contacts_max':oldcontacts,'refined_contacts_max':newcontacts,'source_actions_exact':len(old),'note':'Literal source contact/foot limitations are retained. Both arm shoulder roots stay fixed; rifle follows right-arm lowering exactly. Head seating8mm keeps the tilted head at the collar. No source reconstruction or gameplay asset changes.'};(S/'validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2));assert report['passed'],fail
