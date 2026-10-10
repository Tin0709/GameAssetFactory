"""Saved-file contact, rigidity, continuity and source-preservation checks."""
import bpy,json,sys,runpy
from pathlib import Path
from itertools import combinations
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4]
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
V=runpy.run_path(str(OUT/'review_scene.py'));s=bpy.context.scene;r=bpy.data.objects['JL_Test_Rig'];m=bpy.data.objects['JL_Test_Mesh'];a=bpy.data.actions['Jump_Landing_Test'];data=json.loads((OUT/'manifest.json').read_text())
groups={g.name:[v.index for v in m.data.vertices if any(w.group==g.index and w.weight>.99 for w in v.groups)] for g in m.vertex_groups};groups={n:ids for n,ids in groups.items() if ids}
soles={side:[i for i in groups['Leg.'+side] if abs(m.data.vertices[i].co.z)<1e-6] for side in ['L','R']}
adjacent={frozenset(x) for x in [('Head','Chest'),('Chest','UpperArm.L'),('Chest','UpperArm.R'),('UpperArm.L','ForeArm.L'),('UpperArm.R','ForeArm.R'),('Chest','Leg.L'),('Chest','Leg.R')]}
distances=[(i,j,(m.data.vertices[i].co-m.data.vertices[j].co).length) for ids in groups.values() for i,j in combinations(ids,2)]
def vertices():
    e=m.evaluated_get(bpy.context.evaluated_depsgraph_get());return [e.matrix_world@v.co for v in e.data.vertices]
def separation(n,k,v):
    axes=[r.pose.bones[x].matrix.to_3x3().col[i].normalized() for x in [n,k] for i in range(3)];axes+=[x.cross(y).normalized() for x in axes[:3] for y in axes[3:6] if x.cross(y).length>1e-6]
    aa,bb=[[v[i] for i in groups[x]] for x in [n,k]]
    return max(max(min(p.dot(ax) for p in aa)-max(p.dot(ax) for p in bb),min(p.dot(ax) for p in bb)-max(p.dot(ax) for p in aa)) for ax in axes)
N=43*16+1
report={'samples':N,'max_rigid_error_m':0,'nonadjacent_overlaps':{},'camera_bounds':{},'frames':[],'minimum_floor_clearance_m':1,'max_support_height_error_m':0,'max_contact_corner_xy_error_m':0,'max_leg_local_translation_m':0}
heights=[]
for j in range(N):
    f=1+j/16;r.location=(0,0,0);V['bind'](s,r,a.name,f);v=vertices();heights.append(r.pose.bones['Hips'].head.z)
    report['minimum_floor_clearance_m']=min(report['minimum_floor_clearance_m'],min(p.z for p in v))
    report['max_rigid_error_m']=max(report['max_rigid_error_m'],max(abs((v[i]-v[k]).length-d) for i,k,d in distances))
    for side,ids in soles.items():
        report['max_leg_local_translation_m']=max(report['max_leg_local_translation_m'],r.pose.bones['Leg.'+side].location.length)
        if f>=data['contact_frames'][side]:
            z=min(v[i].z for i in ids);report['max_support_height_error_m']=max(report['max_support_height_error_m'],abs(z-.0004))
            for i in ids:
                if v[i].z<z+1e-6:
                    base=Vector(data['foot_bases'][side]);rest=Vector((base.x+m.data.vertices[i].co.x-(.1125 if side=='L' else -.1125),base.y+m.data.vertices[i].co.y,0))
                    report['max_contact_corner_xy_error_m']=max(report['max_contact_corner_xy_error_m'],(v[i].xy-rest.xy).length)
    if j%2==0:
        for n,k in combinations(groups,2):
            if frozenset([n,k]) in adjacent:continue
            depth=separation(n,k,v)
            if depth<-.00001 and depth<report['nonadjacent_overlaps'].get(n+'/'+k,{}).get('depth_m',0):report['nonadjacent_overlaps'][n+'/'+k]={'frame':f,'depth_m':depth}
        for view in ['FRONT','THREE_QUARTER','SIDE']:
            q=[world_to_camera_view(s,bpy.data.objects['Showcase_'+view],p) for p in v];b=report['camera_bounds'].setdefault(view,[1,1,0,0]);b[:]=[min(b[0],min(x.x for x in q)),min(b[1],min(x.y for x in q)),max(b[2],max(x.x for x in q)),max(b[3],max(x.y for x in q))]
    if j%16==0:report['frames'].append({'frame':f,'vertices':[list(p) for p in v],'hip':list(r.pose.bones['Hips'].head),'soles':{side:min(v[i].z for i in ids) for side,ids in soles.items()}})
r.location=V['landing_offset'](1);V['bind'](s,r,'Jump_AirPose_Test',21.875);prev=vertices();V['bind'](s,r,'Jump_AirPose_Test',22);end=vertices()
V['bind'](s,r,a.name,1);start=vertices();r.location=V['landing_offset'](1.125);V['bind'](s,r,a.name,1.125);nxt=vertices()
report['boundary_position_error_m']=max((p-q).length for p,q in zip(end,start))
report['boundary_velocity_difference_m_per_s']=max(((q-p)/.125-(b-a)/.125).length*30 for p,q,a,b in zip(start,nxt,prev,end))
report['pose_only_boundary_velocity_difference_m_per_s']=max((((q-V['landing_offset'](1.125))-(p-V['landing_offset'](1)))/.125-(b-a)/.125).length*30 for p,q,a,b in zip(start,nxt,prev,end))
# Recheck the retained approved Takeoff-to-AirPose boundary on this saved duplicate.
r.location=(0,0,0);V['bind'](s,r,'Jump_Takeoff_Test',23.875);prev=vertices();V['bind'](s,r,'Jump_Takeoff_Test',24);end=vertices()
r.location=V['AP']['preview_offset'](1,V['AIR_DATA']);V['bind'](s,r,'Jump_AirPose_Test',1);start=vertices()
r.location=V['AP']['preview_offset'](1.125,V['AIR_DATA']);V['bind'](s,r,'Jump_AirPose_Test',1.125);nxt=vertices()
report['retained_takeoff_airpose_boundary_position_error_m']=max((p-q).length for p,q in zip(end,start))
report['retained_takeoff_airpose_boundary_velocity_difference_m_per_s']=max(((q-p)/.125-(b-a)/.125).length*30 for p,q,a,b in zip(start,nxt,prev,end))
# Review travel is external and must not take the soles through the stage.
report['sequence_minimum_floor_clearance_m']=1;report['sequence_camera_bounds']={}
for j in range(87*8+1):
    f=1+j/8;V['sequence'](s,r,f);v=vertices();report['sequence_minimum_floor_clearance_m']=min(report['sequence_minimum_floor_clearance_m'],min(p.z for p in v))
    for view in ['FRONT','THREE_QUARTER','SIDE']:
        q=[world_to_camera_view(s,bpy.data.objects['Showcase_'+view],p) for p in v];b=report['sequence_camera_bounds'].setdefault(view,[1,1,0,0]);b[:]=[min(b[0],min(x.x for x in q)),min(b[1],min(x.y for x in q)),max(b[2],max(x.x for x in q)),max(b[3],max(x.y for x in q))]
report['root_static']=all(max(k.co.y for k in c.keyframe_points)-min(k.co.y for k in c.keyframe_points)<1e-8 for c in ui.curves(a) if '"Root"' in c.data_path)
report['approved_actions_unchanged']=all(ui.action_signature(bpy.data.actions[n])==sig for n,sig in data['original_actions'].items())
library=json.loads((ROOT/'blender/animation/showcase/animation_manifest.json').read_text());report['rest_unchanged']=ui.rest_signature(r.data)==library['rig_sha256'];report['no_scale_tracks']=not any(c.data_path.endswith('scale') for c in ui.curves(a));report['rig_changes']=[]
report['hip_height_range_m']=[min(heights),max(heights)];report['compression_from_ready_m']=.674-min(heights);report['rebound_above_ready_m']=max(heights[16*16:])-.674
reference=json.loads((OUT.parent/'lowerbody_recovery_test/validation.json').read_text());report['reference_recovery_compression_m']=reference['hip_compression_from_ready_m'];report['reference_recovery_max_leg_translation_m']=reference['max_leg_local_translation_m']
report['passed']=report['max_rigid_error_m']<2e-6 and not report['nonadjacent_overlaps'] and report['minimum_floor_clearance_m']>-.00001 and report['max_support_height_error_m']<.0001 and report['max_contact_corner_xy_error_m']<.0001 and report['max_leg_local_translation_m']<reference['max_leg_local_translation_m'] and report['boundary_position_error_m']<2e-6 and report['pose_only_boundary_velocity_difference_m_per_s']<.035 and report['boundary_velocity_difference_m_per_s']<.09 and report['root_static'] and report['approved_actions_unchanged'] and report['rest_unchanged'] and report['no_scale_tracks'] and report['retained_takeoff_airpose_boundary_position_error_m']<2e-6 and report['retained_takeoff_airpose_boundary_velocity_difference_m_per_s']<.035 and report['sequence_minimum_floor_clearance_m']>-.00001 and all(min(b[:2])>0 and max(b[2:])<1 for b in list(report['camera_bounds'].values())+list(report['sequence_camera_bounds'].values()))
(OUT/'validation.json').write_text(json.dumps(report,indent=2));print(json.dumps({k:v for k,v in report.items() if k!='frames'}),flush=True);assert report['passed'],'Inspect validation.json'
