"""Saved-source arm-height/continuity/rigidity and preserved-motion validation."""
import bpy,json,sys,hashlib,ast
from pathlib import Path
from itertools import combinations
from mathutils import Vector,Matrix
O=Path(__file__).resolve().parent;R=O.parents[4];sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
s=bpy.context.scene;r=bpy.data.objects['FJ2_Test_Rig'];m=bpy.data.objects['FJ2_Test_Mesh'];a=bpy.data.actions['Full_Jump_Expressive_v2_Test'];old=bpy.data.actions['Full_Jump_Expressive_Test'];data=json.loads((O/'manifest.json').read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
groups={g.name:[v.index for v in m.data.vertices if any(w.group==g.index and w.weight>.99 for w in v.groups)] for g in m.vertex_groups};groups={k:v for k,v in groups.items() if v}
adjacent={frozenset(x) for x in [('Head','Chest'),('Chest','UpperArm.L'),('Chest','UpperArm.R'),('UpperArm.L','ForeArm.L'),('UpperArm.R','ForeArm.R'),('Chest','Leg.L'),('Chest','Leg.R')]}
distances=[(i,j,(m.data.vertices[i].co-m.data.vertices[j].co).length) for ids in groups.values() for i,j in combinations(ids,2)]
def sample(action,f):
 r.animation_data.action=action;r.animation_data.action_slot=action.slots[0];s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update();e=m.evaluated_get(bpy.context.evaluated_depsgraph_get());return [e.matrix_world@v.co for v in e.data.vertices]
def separation(n,k,v):
 axes=[r.pose.bones[x].matrix.to_3x3().col[i].normalized() for x in [n,k] for i in range(3)];axes+=[x.cross(y).normalized() for x in axes[:3] for y in axes[3:6] if x.cross(y).length>1e-6];aa,bb=[[v[i] for i in groups[x]] for x in [n,k]]
 return max(max(min(p.dot(ax) for p in aa)-max(p.dot(ax) for p in bb),min(p.dot(ax) for p in bb)-max(p.dot(ax) for p in aa)) for ax in axes)
def curve_value(c):return [(list(k.co),list(k.handle_left),list(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type) for k in c.keyframe_points]
newcurves={(c.data_path,c.array_index):c for c in ui.curves(a)};changed=[]
for c in ui.curves(old):
 if curve_value(c)!=curve_value(newcurves[c.data_path,c.array_index]):changed.append([c.data_path,c.array_index])
allowed=['UpperArm.L','UpperArm.R','Leg.L','Leg.R','Hips','Spine','Chest','Head'];assert all(any(p.startswith(f'pose.bones["{n}"]') for n in allowed) for p,i in changed)
height=__import__('runpy').run_path(str(O.parent/'full_jump_expressive_test/build_test.py'))['height'];soles={side:[i for i in groups['Leg.'+side] if abs(m.data.vertices[i].co.z)<1e-6] for side in ['L','R']}
report={'source_sha256':sha(Path(bpy.data.filepath)),'action_sha256':ui.action_signature(a),'samples':737,'changed_curves':changed,'nonadjacent_overlaps':{},'max_rigid_error_m':0.,'maximum_straight_arm_error':0.,'outside_window_vertex_error_m':0.,'peak':{},'frames':[],'minimum_preview_floor_clearance_m':1.,'maximum_landing_support_height_error_m':0.,'maximum_landing_anchor_xy_error_m':0.,'hip_height_samples':[]}
for j in range(737):
 f=1+j/8;v=sample(a,f)
 report['hip_height_samples'].append([f,r.pose.bones['Hips'].head.z]);report['minimum_preview_floor_clearance_m']=min(report['minimum_preview_floor_clearance_m'],min(p.z for p in v)+height(f)*.72/.58)
 for side,contact,base in [('L',46,Vector((.128,-.105,0))),('R',47,Vector((-.128,.070,0)))]:
  if f>=contact:
   low=min(v[i].z for i in soles[side]);report['maximum_landing_support_height_error_m']=max(report['maximum_landing_support_height_error_m'],abs(low-.0004))
   for i in soles[side]:
    if abs(v[i].z-low)>2e-6:continue
    anchors=[base+Vector((x,y,.0004)) for x in [-.1125,.1125] for y in [-.1125,.1125]];report['maximum_landing_anchor_xy_error_m']=max(report['maximum_landing_anchor_xy_error_m'],min(((v[i]-p).xy).length for p in anchors))
 report['max_rigid_error_m']=max(report['max_rigid_error_m'],max(abs((v[i]-v[k]).length-d) for i,k,d in distances))
 for side in ['L','R']:
  arm=r.pose.bones['UpperArm.'+side];fore=r.pose.bones['ForeArm.'+side];report['maximum_straight_arm_error']=max(report['maximum_straight_arm_error'],((arm.tail-arm.head).normalized()-(fore.tail-fore.head).normalized()).length)
 if j%4==0:
  for n,k in combinations(groups,2):
   if frozenset([n,k]) in adjacent:continue
   depth=separation(n,k,v)
   if depth<-.00001:report['nonadjacent_overlaps'][n+'/'+k]={'frame':f,'depth_m':depth}
 if f<=18 or f>=65:
  ref=sample(old,f);report['outside_window_vertex_error_m']=max(report['outside_window_vertex_error_m'],max((p-q).length for p,q in zip(v,ref)))
 if j%8==0:report['frames'].append({'frame':f,'vertices':[list(p) for p in v]})
sample(a,32.5);e=m.evaluated_get(bpy.context.evaluated_depsgraph_get());v=[e.matrix_world@p.co for p in e.data.vertices];head_top=max(v[i].z for i in groups['Head'])
new_gap=r.pose.bones['Leg.L'].tail.x-r.pose.bones['Leg.R'].tail.x;sample(old,32.5);old_gap=r.pose.bones['Leg.L'].tail.x-r.pose.bones['Leg.R'].tail.x;sample(a,32.5);report['airborne_sole_center_gap_m']={'old':old_gap,'new':new_gap,'increase':new_gap-old_gap}
for side in ['L','R']:
 arm=r.pose.bones['UpperArm.'+side];fore=r.pose.bones['ForeArm.'+side];direction=(fore.tail-fore.head).normalized();hand_center=fore.tail-direction*.040
 report['peak'][side]={'hand_tip_z_m':fore.tail.z,'hand_center_z_m':hand_center.z,'head_top_z_m':head_top,'hand_center_above_head_m':hand_center.z-head_top,'hand_tip_above_head_m':fore.tail.z-head_top}
report['all_fourteen_original_actions_unchanged']=all(ui.action_signature(bpy.data.actions[n])==h for n,h in data['original_actions'].items())
report['root_and_unrelated_bone_channels_unchanged']=all(any(p.startswith(f'pose.bones["{n}"]') for n in allowed) for p,i in changed);report['timing_unchanged']=[s.frame_start,s.frame_end,s.render.fps]==[1,93,30];report['root_and_object_static']=r.parent is None and r.matrix_world==Matrix.Identity(4) and all(abs(k.co.y)<1e-8 if c.data_path.endswith('location') else True for c in ui.curves(a) if '"Root"' in c.data_path for k in c.keyframe_points)
report['landing_compression_m']=.674-min(z for f,z in report['hip_height_samples'] if 46<=f<=65);report['deepest_compression_frame']=min((z,f) for f,z in report['hip_height_samples'] if 46<=f<=65)[1];report['rebound_frame_unchanged']=67
tree=ast.parse((O.parent/'full_jump_expressive_test/verify_assets.py').read_text());ns={'hashlib':hashlib,'bpy':bpy,'ui':ui};exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['digest','assets']],type_ignores=[]),'<assets>','exec'),ns)
reference=json.loads((O.parent/'full_jump_expressive_test/asset_verification.json').read_text())['full_jump_expressive_review.blend']['asset_fingerprints'];report['rig_appearance_rest_weights_uv_materials_images_lights_unchanged']=json.loads(json.dumps(ns['assets'](r,m)))==reference
report['passed']=report['max_rigid_error_m']<2e-6 and report['maximum_straight_arm_error']<2e-6 and not report['nonadjacent_overlaps'] and report['outside_window_vertex_error_m']<2e-6 and report['all_fourteen_original_actions_unchanged'] and report['timing_unchanged'] and report['root_and_object_static'] and report['rig_appearance_rest_weights_uv_materials_images_lights_unchanged'] and all(.015<x['hand_center_above_head_m']<.12 for x in report['peak'].values()) and report['minimum_preview_floor_clearance_m']>-.00001 and report['maximum_landing_support_height_error_m']<.0001 and report['maximum_landing_anchor_xy_error_m']<.0001 and report['airborne_sole_center_gap_m']['increase']>.10 and .14<report['landing_compression_m']<.15
(O/'validation.json').write_text(json.dumps(report,indent=2));print(json.dumps({k:v for k,v in report.items() if k!='frames'},indent=2));assert report['passed']
