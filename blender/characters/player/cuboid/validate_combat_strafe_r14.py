"""Measure evaluated R14 pose/contacts densely and verify protected source data."""
import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector
BASE=Path(__file__).resolve().parent;sys.path.insert(0,str(BASE))
from turning_r2_common import curves,digest,geometry,bone_signature
OUT=BASE/'combat_strafe_r14_review';design=json.loads((OUT/'design.json').read_text());before=json.loads((OUT/'preservation_before.json').read_text())
geo=geometry()
preservation={'actions':all(n in bpy.data.actions and digest(bpy.data.actions[n])==h for n,h in before['actions'].items()),'meshes_weights':all(geo.get(n)==h for n,h in before['geometry'].items()),'rigs':all(json.dumps(bone_signature(bpy.data.objects[n]),sort_keys=True)==json.dumps(sig,sort_keys=True) for n,sig in before['rigs'].items())}
report={'preservation':preservation,'sampling':'1/8 frame at 24 FPS, evaluated bone matrices and original rigid-weighted sole vertices','cases':{}}
def heading(p):
    v=p.matrix.to_3x3()@Vector((0,0,1));return math.atan2(v.x,-v.y)
def wrap(v):return (v+math.pi)%(2*math.pi)-math.pi
for case in ['B','C','D']:
    data=design['reviews'][case];s=bpy.data.scenes[data['scene']];bpy.context.window.scene=s;r=bpy.data.objects[data['rig']];mesh=bpy.data.objects[data['mesh']]
    points={n:[v.co.copy() for v in mesh.data.vertices if any(g.group==mesh.vertex_groups[n].index and g.weight>.999 for g in v.groups)] for n in ['Leg.L','Leg.R']}
    soles={n:[v for v in vs if v.z<.0001] for n,vs in points.items()}
    rows=[];end=21 if case!='D' else 269
    for i in range((end-1)*8+1):
        f=1+i/8;s.frame_set(int(f),subframe=f%1);dg=bpy.context.evaluated_depsgraph_get();ev=r.evaluated_get(dg)
        row={'frame':f,'twist_deg':math.degrees(wrap(heading(ev.pose.bones['Chest'])-heading(ev.pose.bones['Hips']))),'hips_yaw_deg':math.degrees(heading(ev.pose.bones['Hips'])),'chest_yaw_deg':math.degrees(heading(ev.pose.bones['Chest'])),'hips_z':ev.pose.bones['Hips'].head.z,'hips_x':ev.pose.bones['Hips'].head.x,'feet':{}}
        for n in points:
            mat=ev.matrix_world@ev.pose.bones[n].matrix@r.data.bones[n].matrix_local.inverted()
            vs=[mat@v for v in points[n]];foot=[mat@v for v in soles[n]];center=sum(foot,Vector())/len(foot)
            row['feet'][n]={'zmin':min(v.z for v in vs),'center':list(center),'xmin':min(v.x for v in foot),'xmax':max(v.x for v in foot),'hip_offset':r.pose.bones[n].location.length}
        rows.append(row)
    maxspeed=0;maxsupportdrift=0;flights={n:[] for n in points}
    for n in points:
        for a,b in zip(rows,rows[1:]):
            if a['feet'][n]['zmin']<.004 and b['feet'][n]['zmin']<.004:
                va=Vector(a['feet'][n]['center']);vb=Vector(b['feet'][n]['center']);maxspeed=max(maxspeed,(vb-va).length*192)
        if case!='D':
            t0,t1=(8,21) if (n=='Leg.R')==(case=='B') else (1,11)
            support=[Vector(row['feet'][n]['center']) for row in rows if t0<=row['frame']<=t1]
            maxsupportdrift=max(maxsupportdrift,max((v-support[0]).length for v in support))
        flights[n]=[row['frame'] for row in rows if row['feet'][n]['zmin']>.006]
    info={'max_twist_deg':max(abs(x['twist_deg']) for x in rows),'hips_yaw_range_deg':[min(x['hips_yaw_deg'] for x in rows),max(x['hips_yaw_deg'] for x in rows)],'chest_yaw_range_deg':[min(x['chest_yaw_deg'] for x in rows),max(x['chest_yaw_deg'] for x in rows)],'floor_min_m':min(x['feet'][n]['zmin'] for x in rows for n in points),'max_foot_clearance_m':max(x['feet'][n]['zmin'] for x in rows for n in points),'max_support_speed_mps':maxspeed,'max_support_segment_drift_m':maxsupportdrift,'max_leg_hip_offset_m':max(x['feet'][n]['hip_offset'] for x in rows for n in points),'hips_height_range_m':[min(x['hips_z'] for x in rows),max(x['hips_z'] for x in rows)],'hips_lateral_range_m':[min(x['hips_x'] for x in rows),max(x['hips_x'] for x in rows)],'sole_lateral_gap_min_m':min(x['feet']['Leg.L']['xmin']-x['feet']['Leg.R']['xmax'] for x in rows),'flight_windows':{n:[min(fs),max(fs)] if fs else [] for n,fs in flights.items()}}
    a=bpy.data.actions[data['action']];cs=curves(a)
    info['forbidden_tracks']=[c.data_path for c in cs if 'Root' in c.data_path or c.data_path.endswith('scale') or any(n in c.data_path for n in ['Arm','Weapon','Head','Chest'])]
    if case!='D':
        info['loop_value_max_error']=max(abs(c.evaluate(1)-c.evaluate(21)) for c in cs)
        info['loop_derivative_max_error']=max(abs((c.evaluate(1.001)-c.evaluate(1))/.001-(c.evaluate(21)-c.evaluate(20.999))/.001) for c in cs)
        info['simultaneous_flight_samples']=sum(all(row['feet'][n]['zmin']>.006 for n in points) for row in rows)
    report['cases'][case]=info
    (OUT/('measurements_'+case+'.json')).write_text(json.dumps(rows))
    s.frame_set(1)
report['pass']=all(preservation.values()) and all(x['max_twist_deg']<20 and x['floor_min_m']>-.002 and not x['forbidden_tracks'] for x in report['cases'].values())
(OUT/'validation.json').write_text(json.dumps(report,indent=2));result=report
