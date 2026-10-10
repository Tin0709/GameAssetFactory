"""Inspect saved takeoff geometry, contact, intersections and preservation."""
import bpy,json,sys,hashlib,math
from pathlib import Path
from itertools import combinations
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];TMP=ROOT/'.validation/jump_takeoff_test'
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
s=bpy.context.scene;r=bpy.data.objects['JT_Test_Rig'];m=bpy.data.objects['JT_Test_Mesh'];a=bpy.data.actions['Jump_Takeoff_Test']
groups={g.name:[v.index for v in m.data.vertices if any(w.group==g.index and w.weight>.99 for w in v.groups)] for g in m.vertex_groups};groups={k:v for k,v in groups.items() if v}
soles={n:[i for i in groups[n] if abs(m.data.vertices[i].co.z)<1e-6] for n in ['Leg.L','Leg.R']}
adjacent={frozenset(x) for x in [('Head','Chest'),('Chest','UpperArm.L'),('Chest','UpperArm.R'),('UpperArm.L','ForeArm.L'),('UpperArm.R','ForeArm.R'),('Chest','Leg.L'),('Chest','Leg.R')]}
distances=[(i,j,(m.data.vertices[i].co-m.data.vertices[j].co).length) for ids in groups.values() for i,j in combinations(ids,2)]
def points(f):
    s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update();e=m.evaluated_get(bpy.context.evaluated_depsgraph_get())
    return [e.matrix_world@v.co for v in e.data.vertices]
def separation(n,k,v):
    axes=[r.pose.bones[x].matrix.to_3x3().col[i].normalized() for x in [n,k] for i in range(3)]
    axes+=[x.cross(y).normalized() for x in axes[:3] for y in axes[3:6] if x.cross(y).length>1e-6]
    aa,bb=[[v[i] for i in groups[x]] for x in [n,k]]
    return max(max(min(p.dot(ax) for p in aa)-max(p.dot(ax) for p in bb),min(p.dot(ax) for p in bb)-max(p.dot(ax) for p in aa)) for ax in axes)
report={'samples':369,'max_rigid_error_m':0,'min_sole_z_m':1,'max_ground_contact_error_m':0,'nonadjacent_overlaps':{},'camera_bounds':{},'frames':[],'max_adjacent_sample_motion_m':0}
prev=None;hips=[]
for j in range(369):
    f=1+j/16;v=points(f);sole={n:min(v[i].z for i in ids) for n,ids in soles.items()}
    report['max_rigid_error_m']=max(report['max_rigid_error_m'],max(abs((v[i]-v[k]).length-d) for i,k,d in distances))
    report['min_sole_z_m']=min(report['min_sole_z_m'],min(sole.values()))
    if f<=19:report['max_ground_contact_error_m']=max(report['max_ground_contact_error_m'],max(abs(x) for x in sole.values()))
    if prev:
        step,index=max(((x-y).length,i) for i,(x,y) in enumerate(zip(v,prev)))
        if step>report['max_adjacent_sample_motion_m']:
            report['max_adjacent_sample_motion_m']=step;report['largest_motion_sample']={'frame':f,'vertex':index,'group':[n for n,ids in groups.items() if index in ids]}
    prev=v;hips.append(r.pose.bones['Hips'].head.z)
    if j%2==0:
        for n,k in combinations(groups,2):
            if frozenset([n,k]) in adjacent:continue
            depth=separation(n,k,v)
            if depth<-.00001 and depth<report['nonadjacent_overlaps'].get(n+'/'+k,{}).get('depth_m',0):report['nonadjacent_overlaps'][n+'/'+k]={'frame':f,'depth_m':depth}
        for view in ['FRONT','THREE_QUARTER','SIDE']:
            q=[world_to_camera_view(s,bpy.data.objects['Showcase_'+view],x) for x in v];bounds=report['camera_bounds'].setdefault(view,[1,1,0,0])
            bounds[:]=[min(bounds[0],min(x.x for x in q)),min(bounds[1],min(x.y for x in q)),max(bounds[2],max(x.x for x in q)),max(bounds[3],max(x.y for x in q))]
    if j%16==0:report['frames'].append({'frame':f,'hip':list(r.pose.bones['Hips'].head),'soles':sole,'vertices':[list(x) for x in v]})
manifest=json.loads((OUT/'manifest.json').read_text());library=json.loads((ROOT/'blender/animation/showcase/animation_manifest.json').read_text())
report['approved_actions_unchanged']=all(ui.action_signature(bpy.data.actions[n])==sig for n,sig in manifest['original_actions'].items())
report['rest_unchanged']=ui.rest_signature(r.data)==library['rig_sha256']
report['rig_changes']=[];report['hip_compression_m']=hips[0]-min(hips);report['early_flight_hip_rise_m']=hips[-1]-.674
report['no_scale_tracks']=not any(c.data_path.endswith('scale') for c in ui.curves(a))
report['frame_range']=list(a.frame_range);report['slot']=r.animation_data.action_slot.identifier
report['actions']=sorted(x.name for x in bpy.data.actions)
report['passed']=report['approved_actions_unchanged'] and report['rest_unchanged'] and report['no_scale_tracks'] and report['max_rigid_error_m']<2e-6 and report['min_sole_z_m']>-.0001 and report['max_ground_contact_error_m']<.001 and not report['nonadjacent_overlaps'] and all(min(b[:2])>0 and max(b[2:])<1 for b in report['camera_bounds'].values())
(OUT/'validation.json').write_text(json.dumps(report,indent=2));print(json.dumps({k:v for k,v in report.items() if k!='frames'}),flush=True)
assert report['passed'],'Inspect validation.json'
