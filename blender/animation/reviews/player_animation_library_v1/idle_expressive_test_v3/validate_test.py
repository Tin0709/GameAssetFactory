"""Saved Idle contact/shape/loop/old baseline/appearance preservation checks."""
import bpy,json,sys,hashlib,ast,math
from pathlib import Path
from itertools import combinations
from mathutils import Vector,Matrix
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];TMP=ROOT/'.validation/idle_expressive_test_v3'
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
s=bpy.context.scene;r=bpy.data.objects['IEV3_Test_Rig'];m=bpy.data.objects['IEV3_Test_Mesh'];a=bpy.data.actions['Idle_Expressive_Test_v3'];candidate='candidate' in sys.argv;data=json.loads((OUT/('lookaround_manifest.json' if candidate else 'manifest.json')).read_text());P=data['playback_frames'][1];CLOSE=data['closing_key']
groups={g.name:[v.index for v in m.data.vertices if any(w.group==g.index and w.weight>.99 for w in v.groups)] for g in m.vertex_groups};groups={n:ids for n,ids in groups.items() if ids}
soles={side:[i for i in groups['Leg.'+side] if abs(m.data.vertices[i].co.z)<1e-6] for side in ['L','R']}
adjacent={frozenset(x) for x in [('Head','Chest'),('Chest','UpperArm.L'),('Chest','UpperArm.R'),('UpperArm.L','ForeArm.L'),('UpperArm.R','ForeArm.R'),('Chest','Leg.L'),('Chest','Leg.R')]}
distances=[(i,j,(m.data.vertices[i].co-m.data.vertices[j].co).length) for ids in groups.values() for i,j in combinations(ids,2)]
def sample(f):
    s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update();e=m.evaluated_get(bpy.context.evaluated_depsgraph_get());return [e.matrix_world@v.co for v in e.data.vertices]
def separation(n,k,v):
    axes=[r.pose.bones[x].matrix.to_3x3().col[i].normalized() for x in [n,k] for i in range(3)];axes+=[x.cross(y).normalized() for x in axes[:3] for y in axes[3:6] if x.cross(y).length>1e-6]
    aa,bb=[[v[i] for i in groups[x]] for x in [n,k]]
    return max(max(min(p.dot(ax) for p in aa)-max(p.dot(ax) for p in bb),min(p.dot(ax) for p in bb)-max(p.dot(ax) for p in aa)) for ax in axes)
initial=sample(1);report={'sampled_source_sha256':hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest(),'sampled_action_sha256':ui.action_signature(a),'samples':P*16+1,'max_rigid_error_m':0,'max_full_sole_drift_m':0,'max_full_sole_height_error_m':0,'minimum_floor_clearance_m':1,'nonadjacent_overlaps':{},'camera_bounds':{},'frames':[]};hips=[];head=[];leglocations=[]
for j in range(report['samples']):
    f=1+j/16;v=sample(f);hips.append(list(r.pose.bones['Hips'].head));head.append(list(r.pose.bones['Head'].head));leglocations.extend(r.pose.bones['Leg.'+side].location.length for side in soles)
    report['max_rigid_error_m']=max(report['max_rigid_error_m'],max(abs((v[i]-v[k]).length-d) for i,k,d in distances));report['minimum_floor_clearance_m']=min(report['minimum_floor_clearance_m'],min(p.z for p in v))
    for ids in soles.values():
        report['max_full_sole_drift_m']=max(report['max_full_sole_drift_m'],max((v[i]-initial[i]).length for i in ids));report['max_full_sole_height_error_m']=max(report['max_full_sole_height_error_m'],max(abs(v[i].z-initial[i].z) for i in ids))
    if j%2==0:
        for n,k in combinations(groups,2):
            if frozenset([n,k]) in adjacent:continue
            depth=separation(n,k,v)
            if depth<-.00001 and depth<report['nonadjacent_overlaps'].get(n+'/'+k,{}).get('depth_m',0):report['nonadjacent_overlaps'][n+'/'+k]={'frame':f,'depth_m':depth}
        for view in ['FRONT','THREE_QUARTER','SIDE']:
            q=[world_to_camera_view(s,bpy.data.objects['Showcase_'+view],p) for p in v];b=report['camera_bounds'].setdefault(view,[1,1,0,0]);b[:]=[min(b[0],min(x.x for x in q)),min(b[1],min(x.y for x in q)),max(b[2],max(x.x for x in q)),max(b[3],max(x.y for x in q))]
    if j%16==0:report['frames'].append({'frame':f,'vertices':[list(p) for p in v]})
sample(60);report['world_deformation_angles_deg_at_observation']={n:[math.degrees(x) for x in (r.pose.bones[n].matrix@r.data.bones[n].matrix_local.inverted()).to_euler('XYZ')] for n in ['Hips','Spine','Chest','Head']}
close=sample(CLOSE);report['loop_pose_error_m']=max((p-q).length for p,q in zip(initial,close))
prev=sample(CLOSE-.0625);nxt=sample(1.0625)
report['loop_finite_vertex_velocity_difference_m_per_s']=max(((q-p)/.0625-(p-b)/.0625).length*30 for b,p,q in zip(prev,initial,nxt))
report['loop_channel_tangent_difference']=max(abs((c.keyframe_points[0].handle_right.y-c.keyframe_points[0].co.y)/(c.keyframe_points[0].handle_right.x-c.keyframe_points[0].co.x)-(c.keyframe_points[-1].co.y-c.keyframe_points[-1].handle_left.y)/(c.keyframe_points[-1].co.x-c.keyframe_points[-1].handle_left.x)) for c in ui.curves(a))
report['cycles_modifiers_on_all_tracks']=all(len(c.modifiers)==1 and c.modifiers[0].type=='CYCLES' for c in ui.curves(a))
report['hip_xyz_range_m']=[[min(x[i] for x in hips),max(x[i] for x in hips)] for i in range(3)];report['head_xyz_range_m']=[[min(x[i] for x in head),max(x[i] for x in head)] for i in range(3)];report['maximum_leg_local_translation_m']=max(leglocations)
report['root_static']=all(max(k.co.y for k in c.keyframe_points)-min(k.co.y for k in c.keyframe_points)<1e-8 for c in ui.curves(a) if '"Root"' in c.data_path)
report['no_scale_tracks']=not any(c.data_path.endswith('scale') for c in ui.curves(a));report['original_actions_unchanged']=all(ui.action_signature(bpy.data.actions[n])==sig for n,sig in data['original_actions'].items())
assert len(bpy.data.actions)==11 and len(bpy.data.armatures)==1 and len(bpy.data.meshes)==2 and r.matrix_world==Matrix.Identity(4)
tree=ast.parse((OUT.parent/'full_jump_expressive_test/verify_assets.py').read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['digest','assets']],type_ignores=[]),'<pure asset fingerprints>','exec'))
reference=json.loads((OUT.parent/'full_jump_expressive_test/asset_verification.json').read_text())['full_jump_expressive_review.blend']['asset_fingerprints'];report['appearance_rest_weights_uv_materials_images_lights_unchanged']=json.loads(json.dumps(assets(r,m)))==reference
# Reproduce the preserved v2 Action against its exact saved original vertices.
r.animation_data.action=bpy.data.actions['Idle_Expressive_Test_v2'];r.animation_data.action_slot=r.animation_data.action.slots[0]
old=json.loads((OUT.parent/'idle_expressive_test_v2/validation.json').read_text());error=0
for item in old['frames']:
    vv=sample(item['frame']);error=max(error,max((p-Vector(q)).length for p,q in zip(vv,item['vertices'])))
report['v2_source_vertex_error_m']=error;report['v2_original_action_sha256']=ui.action_signature(r.animation_data.action)
r.animation_data.action=a;r.animation_data.action_slot=a.slots[0]
report['observation_world_angles']={}
for phase,frame in [('first',65),('second',158)]:
    sample(frame)
    report['observation_world_angles'][phase]={n:[math.degrees(x) for x in (r.pose.bones[n].matrix@r.data.bones[n].matrix_local.inverted()).to_euler('XYZ')] for n in ['Hips','Chest','Head']}
sample(1)
sole_centers={side:sum((initial[i] for i in ids),Vector())/len(ids) for side,ids in soles.items()}
report['sole_center_separation_m']=abs(sole_centers['L'].x-sole_centers['R'].x)
report['sole_centers']={k:list(v) for k,v in sole_centers.items()}
report['sole_height_range_m']={side:[min(initial[i].z for i in ids),max(initial[i].z for i in ids)] for side,ids in soles.items()}
report['support_contact_vertex_ids']={side:[i for i in ids if initial[i].z<.00041] for side,ids in soles.items()}
report['contact_description']='Latest user review request: lateral L3/R8deg remains primary; character left slightly forward/right slightly back (opposed3.75deg pitch), both15deg toe-out; fixed lowest corner contacts, no invented joints or flattening.'
report['asymmetric_support_valid']=all(len(ids)>=1 for ids in report['support_contact_vertex_ids'].values()) and .02<report['hip_xyz_range_m'][0][0]<report['hip_xyz_range_m'][0][1]<.035 and sole_centers['L'].y<-.02 and sole_centers['R'].y>.02
report['body_breathing_rise_m']=report['hip_xyz_range_m'][2][1]-report['hip_xyz_range_m'][2][0]
report['facial_controls_absent']=m.data.shape_keys is None and not any('eye' in b.name.lower() or 'face' in b.name.lower() for b in r.pose.bones)
before=json.loads((TMP/'backup_manifest.json').read_text());allowed={str(ROOT/p) for p in before['authorized_metadata_changes']};protected=[p for p in before['files'] if p not in allowed];report['protected_files_unchanged']=all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==before['files'][p] for p in protected);report['protected_file_count']=len(protected)
report['head_led_torso_turn_readable']=20<report['observation_world_angles']['first']['Head'][2]<30 and -30<report['observation_world_angles']['second']['Head'][2]<-18 and 3<report['observation_world_angles']['first']['Chest'][2]<10 and -10<report['observation_world_angles']['second']['Chest'][2]<-2
report['sampled_source_unchanged_during_validation']=hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest()==report['sampled_source_sha256']
report['passed']=report['sampled_source_unchanged_during_validation'] and report['head_led_torso_turn_readable'] and report['max_rigid_error_m']<2e-6 and report['max_full_sole_drift_m']<1e-5 and report['max_full_sole_height_error_m']<1e-5 and report['minimum_floor_clearance_m']>0 and not report['nonadjacent_overlaps'] and report['loop_pose_error_m']<1e-6 and report['loop_finite_vertex_velocity_difference_m_per_s']<.001 and report['loop_channel_tangent_difference']<.0001 and report['cycles_modifiers_on_all_tracks'] and report['root_static'] and report['no_scale_tracks'] and report['original_actions_unchanged'] and report['appearance_rest_weights_uv_materials_images_lights_unchanged'] and report['v2_source_vertex_error_m']<2e-6 and .39<report['sole_center_separation_m']<.42 and .0239<report['body_breathing_rise_m']<.0241 and report['asymmetric_support_valid'] and report['protected_files_unchanged'] and all(min(b[:2])>0 and max(b[2:])<1 for b in report['camera_bounds'].values())
(OUT/('lookaround_validation.json' if candidate else 'validation.json')).write_text(json.dumps(report,indent=2),encoding='utf8');print(json.dumps({k:v for k,v in report.items() if k!='frames'}),flush=True);assert report['passed']
