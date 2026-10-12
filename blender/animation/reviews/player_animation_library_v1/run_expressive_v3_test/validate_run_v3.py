"""Saved-source rigid geometry, nominal-speed support, seam and preservation audit."""
import bpy,sys,json,hashlib,math,ast,runpy
from pathlib import Path
from itertools import combinations
from mathutils import Vector,Matrix
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];TMP=ROOT/'.validation/run_expressive_v3_test'
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
B=runpy.run_path(str(OUT/'build_run_v3.py'));s=bpy.context.scene;r=bpy.data.objects['RN3_Test_Rig'];m=bpy.data.objects['RN3_Test_Mesh'];a=bpy.data.actions['Run_Expressive_v3_Test']
data=json.loads((OUT/'manifest.json').read_text());P=data['playback_frames'][1];sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
groups={g.name:[v.index for v in m.data.vertices if any(w.group==g.index and w.weight>.99 for w in v.groups)] for g in m.vertex_groups};groups={k:v for k,v in groups.items() if v}
soles={side:[i for i in groups['Leg.'+side] if abs(m.data.vertices[i].co.z)<1e-6] for side in ['L','R']}
adjacent={frozenset(x) for x in [('Head','Chest'),('Chest','UpperArm.L'),('Chest','UpperArm.R'),('UpperArm.L','ForeArm.L'),('UpperArm.R','ForeArm.R'),('Chest','Leg.L'),('Chest','Leg.R')]}
distances=[(i,j,(m.data.vertices[i].co-m.data.vertices[j].co).length) for ids in groups.values() for i,j in combinations(ids,2)]
def sample(f):
 s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update();e=m.evaluated_get(bpy.context.evaluated_depsgraph_get());return [e.matrix_world@v.co for v in e.data.vertices]
def separation(n,k,v):
 axes=[r.pose.bones[x].matrix.to_3x3().col[i].normalized() for x in [n,k] for i in range(3)];axes+=[x.cross(y).normalized() for x in axes[:3] for y in axes[3:6] if x.cross(y).length>1e-6]
 aa,bb=[[v[i] for i in groups[x]] for x in [n,k]]
 return max(max(min(p.dot(ax) for p in aa)-max(p.dot(ax) for p in bb),min(p.dot(ax) for p in bb)-max(p.dot(ax) for p in aa)) for ax in axes)
report={'source_sha256':sha(Path(bpy.data.filepath)),'action_sha256':ui.action_signature(a),'samples':P*32+1,'nominal_speed_m_s':2.31,'max_rigid_error_m':0.,'minimum_floor_clearance_m':1.,'maximum_support_drift_m':0.,'maximum_support_height_error_m':0.,'nonadjacent_overlaps':{},'maximum_waist_separation_m':{'L':-10.,'R':-10.},'camera_bounds':{},'unsupported_samples':[],'frames':[]}
anchors={};hips=[];maximum_leg_offset=0.;max_straight_arm_error=0.
for j in range(P*32+1):
 f=1+j/32;u=(f-1)/P;v=sample(f);hips.append(list(r.pose.bones['Hips'].head));travel=Vector((0,-2.31*(f-1)/30,0));grounded=0
 report['max_rigid_error_m']=max(report['max_rigid_error_m'],max(abs((v[i]-v[k]).length-d) for i,k,d in distances));report['minimum_floor_clearance_m']=min(report['minimum_floor_clearance_m'],min(p.z for p in v))
 for side in ['L','R']:
  q,duty,base,lift=B['foot'](u,side);offset=0 if side=='L' else .5
  maximum_leg_offset=max(maximum_leg_offset,r.pose.bones['Leg.'+side].location.length)
  up=r.pose.bones['UpperArm.'+side];fore=r.pose.bones['ForeArm.'+side]
  max_straight_arm_error=max(max_straight_arm_error,((up.tail-up.head).normalized()-(fore.tail-fore.head).normalized()).length)
  if q<=duty+1e-9:
   minimum=min(v[i].z for i in soles[side]);report['maximum_support_height_error_m']=max(report['maximum_support_height_error_m'],abs(minimum-.0004))
   if minimum<.00042:grounded+=1
   for i in soles[side]:
    if abs(v[i].z-.0004)>2e-6:continue
    key=(side,math.floor(u+offset+1e-9),i);world=v[i]+travel
    if key not in anchors:anchors[key]=world.copy()
    report['maximum_support_drift_m']=max(report['maximum_support_drift_m'],(world-anchors[key]).length)
 expected_flight=all(B['foot'](u,side)[0]>B['foot'](u,side)[1]+1e-9 for side in ['L','R'])
 if bool(grounded)==expected_flight:report['unsupported_samples'].append(f)
 if j%4==0:
  for side in ['L','R']:report['maximum_waist_separation_m'][side]=max(report['maximum_waist_separation_m'][side],separation('Chest','Leg.'+side,v))
  for n,k in combinations(groups,2):
   if frozenset([n,k]) in adjacent:continue
   depth=separation(n,k,v)
   if depth<-.00001 and depth<report['nonadjacent_overlaps'].get(n+'/'+k,{}).get('depth_m',0):report['nonadjacent_overlaps'][n+'/'+k]={'frame':f,'depth_m':depth}
  for view in ['FRONT','THREE_QUARTER','SIDE']:
   q=[world_to_camera_view(s,bpy.data.objects['Showcase_'+view],p) for p in v];bounds=report['camera_bounds'].setdefault(view,[1,1,0,0]);bounds[:]=[min(bounds[0],min(x.x for x in q)),min(bounds[1],min(x.y for x in q)),max(bounds[2],max(x.x for x in q)),max(bounds[3],max(x.y for x in q))]
 if j%32==0:report['frames'].append({'frame':f,'vertices':[list(p) for p in v]})
first=sample(1);last=sample(P+1);eps=.01;before=sample(P+1-eps);after=sample(1+eps)
report['loop_pose_error_m']=max((x-y).length for x,y in zip(first,last))
report['loop_finite_vertex_velocity_difference_m_s']=max(((x-y)-(z-w)).length*30/eps for x,y,z,w in zip(first,before,after,first))
report['loop_velocity_finite_step_frames']=eps
report['loop_channel_tangent_difference']=max(abs((c.keyframe_points[0].co.y-c.keyframe_points[0].handle_left.y)/(c.keyframe_points[0].co.x-c.keyframe_points[0].handle_left.x)-(c.keyframe_points[-1].handle_right.y-c.keyframe_points[-1].co.y)/(c.keyframe_points[-1].handle_right.x-c.keyframe_points[-1].co.x)) for c in ui.curves(a))
report['hip_xyz_range_m']=[[min(p[i] for p in hips),max(p[i] for p in hips)] for i in range(3)]
report['maximum_leg_local_translation_m']=maximum_leg_offset;report['maximum_straight_arm_direction_error']=max_straight_arm_error
report['original_thirteen_actions_identical']=all(ui.action_signature(bpy.data.actions[n])==h for n,h in data['original_actions'].items())
report['cycles_modifiers_on_all_tracks']=all(len(c.modifiers)==1 and c.modifiers[0].type=='CYCLES' for c in ui.curves(a));report['no_scale_tracks']=not any(c.data_path.endswith('scale') for c in ui.curves(a))
report['root_static']=all(abs(k.co.y)<1e-8 if c.data_path.endswith('location') else True for c in ui.curves(a) if '"Root"' in c.data_path for k in c.keyframe_points)
tree=ast.parse((OUT.parent/'full_jump_expressive_test/verify_assets.py').read_text());namespace={'hashlib':hashlib,'bpy':bpy,'ui':ui}
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['digest','assets']],type_ignores=[]),'<asset fingerprint>','exec'),namespace)
reference=json.loads((OUT.parent/'full_jump_expressive_test/asset_verification.json').read_text())['full_jump_expressive_review.blend']['asset_fingerprints'];report['appearance_rest_weights_uv_materials_images_lights_unchanged']=json.loads(json.dumps(namespace['assets'](r,m)))==reference
# The approved idle is evaluated again on this unchanged rig; no source or Action edits.
r.animation_data.action=bpy.data.actions['Idle_Expressive_Test_v3'];r.animation_data.action_slot=r.animation_data.action.slots[0]
idle=json.loads((OUT.parent/'idle_expressive_test_v3/validation.json').read_text());error=0.
for item in idle['frames'][::20]:error=max(error,max((p-Vector(q)).length for p,q in zip(sample(item['frame']),item['vertices'])))
report['approved_idle_geometry_error_m']=error;r.animation_data.action=a;r.animation_data.action_slot=a.slots[0]
baseline=json.loads((TMP/'baseline.json').read_text());allowed=set(baseline['allowed_metadata_changes']);protected=[p for p in baseline['files'] if p not in allowed]
report['protected_original_files']=len(protected);report['changed_protected_files']=[p for p in protected if not (ROOT/p).is_file() or sha(ROOT/p)!=baseline['files'][p]]
report['saved_source_unchanged']=sha(Path(bpy.data.filepath))==report['source_sha256']
report['passed']=report['max_rigid_error_m']<2e-6 and report['minimum_floor_clearance_m']>0 and report['maximum_support_drift_m']<5e-5 and report['maximum_support_height_error_m']<1e-5 and not report['unsupported_samples'] and not report['nonadjacent_overlaps'] and max(report['maximum_waist_separation_m'].values())<0 and report['loop_pose_error_m']<1e-6 and report['loop_finite_vertex_velocity_difference_m_s']<.02 and report['loop_channel_tangent_difference']<.001 and report['maximum_straight_arm_direction_error']<2e-6 and report['original_thirteen_actions_identical'] and report['cycles_modifiers_on_all_tracks'] and report['no_scale_tracks'] and report['root_static'] and report['appearance_rest_weights_uv_materials_images_lights_unchanged'] and report['approved_idle_geometry_error_m']<2e-6 and not report['changed_protected_files'] and report['saved_source_unchanged'] and all(min(b[:2])>0 and max(b[2:])<1 for b in report['camera_bounds'].values())
(OUT/'validation.json').write_text(json.dumps(report,indent=2));print(json.dumps({k:v for k,v in report.items() if k!='frames'},indent=2),flush=True);assert report['passed']
