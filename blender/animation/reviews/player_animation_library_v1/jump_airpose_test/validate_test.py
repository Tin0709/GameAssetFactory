"""Saved-file rigidity, articulation and boundary continuity checks."""
import bpy,json,sys,hashlib,runpy,math
from pathlib import Path
from mathutils import Vector,Matrix
from itertools import combinations
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];TMP=ROOT/'.validation/jump_airpose_test'
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
V=runpy.run_path(str(OUT/'review_scene.py'))
s=bpy.context.scene;r=bpy.data.objects['AP_Test_Rig'];m=bpy.data.objects['AP_Test_Mesh'];a=bpy.data.actions['Jump_AirPose_Test'];data=json.loads((OUT/'manifest.json').read_text())
groups={g.name:[v.index for v in m.data.vertices if any(w.group==g.index and w.weight>.99 for w in v.groups)] for g in m.vertex_groups};groups={n:ids for n,ids in groups.items() if ids}
adjacent={frozenset(x) for x in [('Head','Chest'),('Chest','UpperArm.L'),('Chest','UpperArm.R'),('UpperArm.L','ForeArm.L'),('UpperArm.R','ForeArm.R'),('Chest','Leg.L'),('Chest','Leg.R')]}
distances=[(i,j,(m.data.vertices[i].co-m.data.vertices[j].co).length) for ids in groups.values() for i,j in combinations(ids,2)]
def vertices():
    e=m.evaluated_get(bpy.context.evaluated_depsgraph_get());return [e.matrix_world@v.co for v in e.data.vertices]
def separation(n,k,v):
    axes=[r.pose.bones[x].matrix.to_3x3().col[i].normalized() for x in [n,k] for i in range(3)]
    axes+=[x.cross(y).normalized() for x in axes[:3] for y in axes[3:6] if x.cross(y).length>1e-6]
    aa,bb=[[v[i] for i in groups[x]] for x in [n,k]]
    return max(max(min(p.dot(ax) for p in aa)-max(p.dot(ax) for p in bb),min(p.dot(ax) for p in bb)-max(p.dot(ax) for p in aa)) for ax in axes)
report={'samples':337,'max_rigid_error_m':0,'nonadjacent_overlaps':{},'camera_bounds':{},'frames':[]}
hips=[];min_clearance=1
for j in range(337):
    f=1+j/16;r.location=(0,0,0);V['bind'](s,r,a.name,f);v=vertices();hips.append(list(r.pose.bones['Hips'].head))
    min_clearance=min(min_clearance,min(p.z for p in v)-bpy.data.objects['Showcase_FixedFloor'].location.z)
    report['max_rigid_error_m']=max(report['max_rigid_error_m'],max(abs((v[i]-v[k]).length-d) for i,k,d in distances))
    if j%2==0:
        for n,k in combinations(groups,2):
            if frozenset([n,k]) in adjacent:continue
            depth=separation(n,k,v)
            if depth<-.00001 and depth<report['nonadjacent_overlaps'].get(n+'/'+k,{}).get('depth_m',0):report['nonadjacent_overlaps'][n+'/'+k]={'frame':f,'depth_m':depth}
        for view in ['FRONT','THREE_QUARTER','SIDE']:
            q=[world_to_camera_view(s,bpy.data.objects['Showcase_'+view],p) for p in v];bounds=report['camera_bounds'].setdefault(view,[1,1,0,0]);bounds[:]=[min(bounds[0],min(x.x for x in q)),min(bounds[1],min(x.y for x in q)),max(bounds[2],max(x.x for x in q)),max(bounds[3],max(x.y for x in q))]
    if j%16==0:report['frames'].append({'frame':f,'vertices':[list(p) for p in v]})
report['hip_position_range_m']=[max(p[i] for p in hips)-min(p[i] for p in hips) for i in range(3)]
report['minimum_review_floor_clearance_m']=min_clearance
# Boundary geometry and motion: keep all body articulation, externalize translation.
r.location=(0,0,0);V['bind'](s,r,'Jump_Takeoff_Test',23.875);prev=vertices()
V['bind'](s,r,'Jump_Takeoff_Test',24);end=vertices()
r.location=V['preview_offset'](1,data);V['bind'](s,r,a.name,1);start=vertices()
r.location=V['preview_offset'](1.125,data);V['bind'](s,r,a.name,1.125);nxt=vertices()
report['boundary_position_error_m']=max((p-q).length for p,q in zip(end,start))
report['boundary_velocity_difference_m_per_s']=max(((q-p)/.125-(b-a)/.125).length*30 for p,q,a,b in zip(start,nxt,prev,end))
report['root_and_hip_translation_constant']=all(max(k.co.y for k in c.keyframe_points)-min(k.co.y for k in c.keyframe_points)<1e-8 for c in ui.curves(a) if c.data_path.endswith('location') and any('"'+n+'"' in c.data_path for n in ['Root','Hips']))
report['approved_actions_unchanged']=all(ui.action_signature(bpy.data.actions[n])==sig for n,sig in data['original_actions'].items())
manifest=json.loads((ROOT/'blender/animation/showcase/animation_manifest.json').read_text());report['rest_unchanged']=ui.rest_signature(r.data)==manifest['rig_sha256']
report['no_scale_tracks']=not any(c.data_path.endswith('scale') for c in ui.curves(a));report['rig_changes']=[]
report['passed']=report['max_rigid_error_m']<2e-6 and not report['nonadjacent_overlaps'] and report['boundary_position_error_m']<2e-6 and report['boundary_velocity_difference_m_per_s']<.035 and report['root_and_hip_translation_constant'] and report['approved_actions_unchanged'] and report['rest_unchanged'] and report['no_scale_tracks'] and all(min(b[:2])>0 and max(b[2:])<1 for b in report['camera_bounds'].values())
(OUT/'validation.json').write_text(json.dumps(report,indent=2));print(json.dumps({k:v for k,v in report.items() if k!='frames'}),flush=True)
assert report['passed'],'Inspect validation.json'
