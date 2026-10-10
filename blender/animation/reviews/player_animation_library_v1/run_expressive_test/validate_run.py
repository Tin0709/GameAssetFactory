import bpy,json,math,runpy,hashlib
from pathlib import Path
from itertools import combinations
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[4];TMP=ROOT/'.validation/run_expressive_test'

def run(preservation=False):
    h=runpy.run_path(str(OUT/'build_run.py'));s=bpy.data.scenes['RUN_EXPRESSIVE_REVIEW'];bpy.context.window.scene=s
    r=bpy.data.objects['RUN_Test_Rig'];m=bpy.data.objects['RUN_Test_Mesh'];P=h['P']
    groups={g.name:[v.index for v in m.data.vertices if any(w.group==g.index and w.weight>.99 for w in v.groups)] for g in m.vertex_groups}
    groups={k:v for k,v in groups.items() if v}
    adjacent={frozenset(x) for x in [('Head','Chest'),('Chest','UpperArm.L'),('Chest','UpperArm.R'),('UpperArm.L','ForeArm.L'),('UpperArm.R','ForeArm.R'),('Chest','Leg.L'),('Chest','Leg.R')]}
    pairs=[x for x in combinations(groups,2) if frozenset(x) not in adjacent]
    def pts(f,obj=m):
        s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update()
        e=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
        return [e.matrix_world@v.co for v in e.data.vertices]
    def sep(a,b,v):
        axes=[(r.matrix_world@r.pose.bones[n].matrix).to_3x3().col[i].normalized() for n in [a,b] for i in range(3)]
        axes += [x.cross(y).normalized() for x in axes[:3] for y in axes[3:6] if x.cross(y).length>1e-6]
        aa,bb=[[v[j] for j in groups[n]] for n in [a,b]]
        return max(max(min(p.dot(ax) for p in aa)-max(p.dot(ax) for p in bb),min(p.dot(ax) for p in bb)-max(p.dot(ax) for p in aa)) for ax in axes)
    base=[m.matrix_world@v.co for v in m.data.vertices]
    distances=[(a,b,(base[a]-base[b]).length) for ids in groups.values() for a,b in combinations(ids,2)]
    soles={side:[i for i in groups['Leg.'+side] if abs(m.data.vertices[i].co.z)<1e-6] for side in ['L','R']}
    edges={}
    for side,ids in soles.items():
        for label,fn in [('heel',max),('toe',min)]:
            y=fn(m.data.vertices[i].co.y for i in ids)
            edges[side,label]=[i for i in ids if abs(m.data.vertices[i].co.y-y)<1e-6]
    report={'samples':P*32+1,'max_rigid_distance_error_m':0,'min_floor_z_m':100,'max_contact_height_error_m':0,'contacts':{},'camera_bounds':{},'overlaps':{},'max_leg_retraction_m':0,'airborne_samples':0,'max_airborne_clearance_m':0}
    samples=[]
    for k in range(P*32+1):
        f=1+k/32;u=(f-1)/P;v=pts(f)
        report['max_rigid_distance_error_m']=max(report['max_rigid_distance_error_m'],max(abs((v[a]-v[b]).length-d) for a,b,d in distances))
        floor=min(x.z for x in v);report['min_floor_z_m']=min(report['min_floor_z_m'],floor)
        support=False
        for side,offset in [('R',0),('L',.5)]:
            q=(u+offset)%1
            report['max_leg_retraction_m']=max(report['max_leg_retraction_m'],r.pose.bones['Leg.'+side].location.length)
            if q<=h['DUTY'] and q>1e-5 and abs(q-h['DUTY']/2)>.002:
                support=True;edge='heel' if q<h['DUTY']/2 else 'toe'
                cp=sum((v[i] for i in edges[side,edge]),Vector())/len(edges[side,edge])
                world=cp+Vector((0,-h['SPEED']*(f-1)/30,0))
                key=f'{side}/{math.floor(u+offset)}/{edge}'
                report['contacts'].setdefault(key,[]).append([f,*world])
                report['max_contact_height_error_m']=max(report['max_contact_height_error_m'],abs(cp.z))
        if all((u+offset)%1>h['DUTY'] for offset in [0,.5]):
            report['airborne_samples']+=1;report['max_airborne_clearance_m']=max(report['max_airborne_clearance_m'],floor)
        if k%4==0:
            for a,b in pairs:
                d=sep(a,b,v)
                if d<-.00001:
                    label=a+'/'+b
                    if d<report['overlaps'].get(label,{}).get('depth_m',0):report['overlaps'][label]={'frame':f,'depth_m':d}
            for view in ['FRONT','THREE_QUARTER','SIDE']:
                q=[world_to_camera_view(s,bpy.data.objects['RUN_'+view],x) for x in v]
                b=report['camera_bounds'].setdefault(view,[1,1,0,0]);b[:]=[min(b[0],min(x.x for x in q)),min(b[1],min(x.y for x in q)),max(b[2],max(x.x for x in q)),max(b[3],max(x.y for x in q))]
        if k%32==0:samples.append({'frame':f,'sole_min_z':floor,'hips_z':r.pose.bones['Hips'].head.z,'head_world_euler_deg':[math.degrees(x) for x in r.pose.bones['Head'].matrix.to_euler()]})
    contact_report={}
    for key,values in report['contacts'].items():
        contact_report[key]={'samples':len(values),'world_y_span_m':max(v[2] for v in values)-min(v[2] for v in values),'x_span_m':max(v[1] for v in values)-min(v[1] for v in values)}
    report['contacts']=contact_report
    report['max_contact_world_y_drift_m']=max(v['world_y_span_m'] for v in contact_report.values())
    start,end=pts(1),pts(P+1)
    report['loop_vertex_error_m']=max((a-b).length for a,b in zip(start,end))
    report['repeat_error_m']=max((a-b).length for a,b in zip(pts(4.37),pts(4.37+P)))
    eps=.001;pre,post=pts(P+1-eps),pts(1+eps)
    report['wrap_velocity_difference_m_per_frame']=max(((a-b)/eps-(c-d)/eps).length for a,b,c,d in zip(end,pre,post,start))
    report['frame_samples']=samples
    report['source_hash_unchanged']=all(hashlib.sha256(Path(path).read_bytes()).hexdigest()==value for path,value in source_hashes().items())
    if preservation:
        before=json.loads((TMP/'original_data.json').read_text());report['changed_originals']=h['H']['compare_originals'](before)
        report['old_actions']=len(before['actions']);report['actions_now']=len(bpy.data.actions)
        report['same_mesh']=m.data==bpy.data.objects['EAM_Player_Mesh'].data
        report['same_rest']=all(b.matrix_local==bpy.data.objects['EAM_Player_Rig'].data.bones[b.name].matrix_local for b in r.data.bones)
    s.frame_set(8);s.camera=bpy.data.objects['RUN_THREE_QUARTER']
    (OUT/'validation.json').write_text(json.dumps(report,indent=2))
    return {k:v for k,v in report.items() if k not in ['frame_samples','contacts']}

def source_hashes():
    j=json.loads((TMP/'backup_manifest.json').read_text())
    return {j['source']:j['sha256']}
