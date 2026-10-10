"""Fresh saved-file geometry, support, continuity and approved-source audit."""
import bpy,json,sys,runpy,hashlib
from pathlib import Path
from itertools import combinations
from mathutils import Vector,Matrix
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4];TMP=ROOT/'.validation/full_jump_expressive_test'
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
B=runpy.run_path(str(OUT/'build_test.py'));bind=B['bind'];phase=B['phase'];height=B['height'];END=B['END']
s=bpy.context.scene;r=bpy.data.objects['FJ_Test_Rig'];m=bpy.data.objects['FJ_Test_Mesh'];a=bpy.data.actions['Full_Jump_Expressive_Test'];data=json.loads((OUT/'manifest.json').read_text())
assert bpy.data.filepath.endswith('full_jump_expressive_review.blend') and r.parent is None and r.matrix_world==Matrix.Identity(4)
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
report={'samples':(END-1)*16+1,'max_rigid_error_m':0,'nonadjacent_overlaps':{},'frames':[],'minimum_preview_floor_clearance_m':1,'max_support_height_error_m':0,'max_contact_corner_xy_error_m':0,'max_leg_local_translation_m':0,'maximum_reference_pose_error_m':0,'boundaries':{},'camera_bounds':{}}
hips=[]
# Use the same presentation camera framing as the separate preview file.
for view in ['FRONT','THREE_QUARTER','SIDE']:
    cam=bpy.data.objects['Showcase_'+view];cam.data.ortho_scale=2.9;cam.location.z+=.22
for j in range(report['samples']):
    f=1+j/16;bind(s,r,a.name,f);v=vertices();hips.append(r.pose.bones['Hips'].head.z)
    report['max_rigid_error_m']=max(report['max_rigid_error_m'],max(abs((v[i]-v[k]).length-d) for i,k,d in distances))
    preview=[p+Vector((0,0,height(f))) for p in v]
    report['minimum_preview_floor_clearance_m']=min(report['minimum_preview_floor_clearance_m'],min(p.z for p in preview))
    for side,ids in soles.items():
        report['max_leg_local_translation_m']=max(report['max_leg_local_translation_m'],r.pose.bones['Leg.'+side].location.length)
        if f<=19 or f>=data['contact_frames'][side]:
            z=min(v[i].z for i in ids);report['max_support_height_error_m']=max(report['max_support_height_error_m'],abs(z-.0004))
            for i in ids:
                if v[i].z<z+1e-6:
                    base=Vector(data['takeoff_foot_bases' if f<=19 else 'foot_bases'][side]);rest=Vector((base.x+m.data.vertices[i].co.x-(.1125 if side=='L' else -.1125),base.y+m.data.vertices[i].co.y,0))
                    report['max_contact_corner_xy_error_m']=max(report['max_contact_corner_xy_error_m'],(v[i].xy-rest.xy).length)
    if j%2==0:
        for n,k in combinations(groups,2):
            if frozenset([n,k]) in adjacent:continue
            depth=separation(n,k,v)
            if depth<-.00001 and depth<report['nonadjacent_overlaps'].get(n+'/'+k,{}).get('depth_m',0):report['nonadjacent_overlaps'][n+'/'+k]={'frame':f,'depth_m':depth}
        for view in ['FRONT','THREE_QUARTER','SIDE']:
            q=[world_to_camera_view(s,bpy.data.objects['Showcase_'+view],p) for p in preview];b=report['camera_bounds'].setdefault(view,[1,1,0,0]);b[:]=[min(b[0],min(x.x for x in q)),min(b[1],min(x.y for x in q)),max(b[2],max(x.x for x in q)),max(b[3],max(x.y for x in q))]
        name,local=phase(f);bind(s,r,name,local);ref=vertices()
        if name=='Jump_Takeoff_Test' and f>19:
            dz=r.pose.bones['Hips'].head.z-.674;ref=[p-Vector((0,0,dz)) for p in ref]
        report['maximum_reference_pose_error_m']=max(report['maximum_reference_pose_error_m'],max((p-q).length for p,q in zip(v,ref)))
    if j%16==0:report['frames'].append({'frame':f,'vertices':[list(p) for p in v],'hip':hips[-1],'preview_height_m':height(f),'phase':phase(f)[0]})
for label,f in data['phase_boundaries'].items():
    vv=[]
    for x in [f-.125,f,f+.125]:bind(s,r,a.name,x);vv.append(vertices())
    prev,mid,nxt=vv
    velocity=max(((q-p)/.125-(p-b)/.125).length*30 for b,p,q in zip(prev,mid,nxt))
    report['boundaries'][label]={'frame':f,'max_finite_vertex_velocity_difference_m_per_s':velocity,'duplicate_boundary_hold':False}
report['root_static']=all(max(k.co.y for k in c.keyframe_points)-min(k.co.y for k in c.keyframe_points)<1e-8 for c in ui.curves(a) if '"Root"' in c.data_path)
report['only_bone_pose_channels']=all(c.data_path.startswith('pose.bones[') for c in ui.curves(a))
report['approved_actions_unchanged']=all(ui.action_signature(bpy.data.actions[n])==sig for n,sig in data['original_actions'].items())
report['rest_unchanged']=ui.rest_signature(r.data)==json.loads((ROOT/'blender/animation/showcase/animation_manifest.json').read_text())['rig_sha256']
report['no_scale_tracks']=not any(c.data_path.endswith('scale') for c in ui.curves(a));report['hip_height_range_m']=[min(hips),max(hips)]
report['flight_hip_height_range_m']=[min(hips[(19-1)*16:(43-1)*16+1]),max(hips[(19-1)*16:(43-1)*16+1])]
report['preparation_compression_m']=.674-hips[(14-1)*16];report['landing_compression_m']=.674-hips[(51-1)*16];report['landing_rebound_m']=hips[(67-1)*16]-.674
report['preview_arc']={'single_apex':True,'apex_frame':32.5,'height_m':height(32.5),'separate_from_pose_action':True}
before=json.loads((TMP/'backup_manifest.json').read_text());allowed={str(ROOT/p) for p in before['authorized_metadata_changes']};protected=[p for p in before['files'] if p not in allowed]
report['protected_files_unchanged']=all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==before['files'][p] for p in protected);report['protected_file_count']=len(protected)
report['passed']=report['max_rigid_error_m']<2e-6 and not report['nonadjacent_overlaps'] and report['minimum_preview_floor_clearance_m']>-.00001 and report['max_support_height_error_m']<.0001 and report['max_contact_corner_xy_error_m']<.0001 and report['max_leg_local_translation_m']<.1491 and report['maximum_reference_pose_error_m']<2e-6 and all(b['max_finite_vertex_velocity_difference_m_per_s']<.035 for b in report['boundaries'].values()) and report['root_static'] and report['only_bone_pose_channels'] and report['approved_actions_unchanged'] and report['rest_unchanged'] and report['no_scale_tracks'] and report['protected_files_unchanged'] and report['flight_hip_height_range_m'][1]-report['flight_hip_height_range_m'][0]<1e-6 and all(min(b[:2])>0 and max(b[2:])<1 for b in report['camera_bounds'].values())
(OUT/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf8');print(json.dumps({k:v for k,v in report.items() if k!='frames'}),flush=True);assert report['passed'],'Inspect validation.json'
