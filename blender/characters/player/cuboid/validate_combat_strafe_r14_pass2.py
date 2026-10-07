"""Dense evaluated FK, speed, contact, loop and preservation checks."""
import bpy, sys, math, json, hashlib
from pathlib import Path
from mathutils import Vector
BASE=Path(__file__).resolve().parent;sys.path.insert(0,str(BASE))
from turning_r2_common import curves,digest,geometry,bone_signature
OUT=BASE/'combat_strafe_r14_pass2_review';d=json.loads((OUT/'design.json').read_text());before=json.loads((OUT/'preservation_before.json').read_text())
geo=geometry();preservation={'actions':all(digest(bpy.data.actions[n])==h for n,h in before['actions'].items()),'mesh_and_weights':all(geo[n]==h for n,h in before['geometry'].items()),'rigs':all(json.dumps(bone_signature(bpy.data.objects[n]),sort_keys=True)==json.dumps(sig,sort_keys=True) for n,sig in before['rigs'].items()),'V1_file':hashlib.sha256((BASE/'player_combat_strafe_r14_v1_study.blend').read_bytes()).hexdigest()==before['source_sha256']}
def heading(p):
    v=p.matrix.to_3x3()@Vector((0,0,1));return math.atan2(v.x,-v.y)
def wrap(x):return (x+math.pi)%(2*math.pi)-math.pi
def sample(data,end):
    s=bpy.data.scenes[data['scene']];bpy.context.window.scene=s;r=bpy.data.objects[data['rig']];m=bpy.data.objects[data['mesh']]
    points={n:[v.co.copy() for v in m.data.vertices if v.co.z<.0001 and any(g.group==m.vertex_groups[n].index and g.weight>.999 for g in v.groups)] for n in ['Leg.R','Leg.L']}
    rows=[]
    for i in range(end*8+1):
        f=1+i/8;s.frame_set(int(f),subframe=f%1);ev=r.evaluated_get(bpy.context.evaluated_depsgraph_get());feet={}
        for n,ps in points.items():
            mat=ev.matrix_world@ev.pose.bones[n].matrix@r.data.bones[n].matrix_local.inverted();vs=[mat@v for v in ps];cen=sum(vs,Vector())/4
            angle=ev.pose.bones[n].matrix.to_quaternion().rotation_difference(r.data.bones[n].matrix_local.to_quaternion()).angle
            feet[n]={'center':list(cen),'corners':[list(v) for v in vs],'zmin':min(v.z for v in vs),'FK_offset_m':ev.pose.bones[n].location.length,'angle_deg':math.degrees(min(angle,2*math.pi-angle))}
        rows.append({'frame':f,'time_s':(f-1)/48,'feet':feet,'hips_z':ev.pose.bones['Hips'].head.z,'twist_deg':math.degrees(wrap(heading(ev.pose.bones['Chest'])-heading(ev.pose.bones['Hips']))),'chest_yaw_deg':math.degrees(heading(ev.pose.bones['Chest'])),'stage':list(bpy.data.objects[data['stage']].location)})
    s.frame_set(1);return rows

report={'preservation':preservation,'sampling':'1/8 of a 48 FPS frame = 384 Hz; evaluated bones and original sole corners','cases':{},'transitions':[]}
for direction,data in d['reviews'].items():
    rows=sample(data,32);a=bpy.data.actions[data['action']];lead=a['leading_leg'];segments=[]
    for n in ['Leg.R','Leg.L']:
        # Analytical contact windows exclude near-ground swing samples.
        window=[]
        for row in rows:
            u=(((row['frame']-1)/16)-(0 if n==lead else .5))%1
            contact=.58+1/128<=u<=1-1/128
            if contact:window.append(row)
            elif window:segments.append((n,window));window=[]
        if window:segments.append((n,window))
    metrics=[]
    for n,segment in segments:
        if len(segment)<8:continue
        centers=[Vector(row['feet'][n]['center']) for row in segment];p0=centers[0]
        # Follow the same physical sole corners, avoiding corner-switch jumps.
        corner_drift=max(max((Vector(row['feet'][n]['corners'][j])-Vector(segment[0]['feet'][n]['corners'][j])).xy.length for row in segment) for j in range(4))
        first,last=segment[0],segment[-1];dt=last['time_s']-first['time_s'];worlddelta=Vector(last['feet'][n]['center'])-Vector(first['feet'][n]['center']);stage_delta=Vector(last['stage'])-Vector(first['stage'])
        implied=(stage_delta-worlddelta).xy.length/dt
        metrics.append({'foot':n,'plant_start_frame':first['frame'],'plant_end_frame':last['frame'],'centroid_xy_drift_m':max((v-p0).xy.length for v in centers),'x_drift_m':max(abs(v.x-p0.x) for v in centers),'y_drift_m':max(abs(v.y-p0.y) for v in centers),'sole_corner_xy_drift_m':corner_drift,'implied_stride_velocity_mps':implied})
    info={'action':a.name,'duration_seconds':16/48,'leading_leg':lead,'trailing_delay_seconds':8/48,'support_segments':metrics,'centroid_xy_slip_mm':max(x['centroid_xy_drift_m'] for x in metrics)*1000,'sole_corner_xy_slip_mm':max(x['sole_corner_xy_drift_m'] for x in metrics)*1000,'x_slip_mm':max(x['x_drift_m'] for x in metrics)*1000,'y_slip_mm':max(x['y_drift_m'] for x in metrics)*1000,'implied_stride_velocity_mps':[min(x['implied_stride_velocity_mps'] for x in metrics),max(x['implied_stride_velocity_mps'] for x in metrics)],'max_twist_deg':max(abs(row['twist_deg']) for row in rows),'max_chest_heading_deg':max(abs(row['chest_yaw_deg']) for row in rows),'floor_min_m':min(row['feet'][n]['zmin'] for row in rows for n in ['Leg.R','Leg.L']),'max_flight_clearance_m':max(row['feet'][n]['zmin'] for row in rows for n in ['Leg.R','Leg.L']),'max_FK_offset_m':max(row['feet'][n]['FK_offset_m'] for row in rows for n in ['Leg.R','Leg.L']),'max_leg_angle_deg':max(row['feet'][n]['angle_deg'] for row in rows for n in ['Leg.R','Leg.L']),'hips_bounce_mm':(max(row['hips_z'] for row in rows)-min(row['hips_z'] for row in rows))*1000,'loop_value_max_error':max(abs(c.evaluate(1)-c.evaluate(17)) for c in curves(a)),'loop_derivative_max_error':max(abs((c.evaluate(1.001)-c.evaluate(1))/.001-(c.evaluate(17)-c.evaluate(16.999))/.001) for c in curves(a)),'forbidden_tracks':[c.data_path for c in curves(a) if any(n in c.data_path for n in ['Root','Arm','Chest','Head','Weapon']) or c.data_path.endswith('scale')]}
    report['cases'][direction]=info;(OUT/('measurements_'+direction+'.json')).write_text(json.dumps(rows))
    print('MEASURED',direction,'slip mm',info['centroid_xy_slip_mm'],'corner mm',info['sole_corner_xy_slip_mm'],'FK',info['max_FK_offset_m'],flush=True)
for data in d['transitions']:
    rows=sample(data,bpy.data.scenes[data['scene']].frame_end);steps=[];contacts=[];plant_segments=[]
    for n in ['Leg.R','Leg.L']:
        for left,right in zip(rows,rows[1:]):
            delta=(Vector(right['feet'][n]['center'])-Vector(left['feet'][n]['center'])).length;steps.append(delta)
            if left['feet'][n]['zmin']<.004 and right['feet'][n]['zmin']<.004:contacts.append(delta*384)
    info={'scene':data['scene'],'sequence':data['sequence'],'max_twist_deg':max(abs(row['twist_deg']) for row in rows),'floor_min_m':min(row['feet'][n]['zmin'] for row in rows for n in ['Leg.R','Leg.L']),'max_world_foot_delta_per_384hz_sample_m':max(steps),'max_near_ground_foot_speed_mps':max(contacts,default=0),'note':'Smooth shared-phase pose blends. Contact locking is not guaranteed during vector changes; existing forward/back Walk endpoints are comparison baselines.'}
    # Record finite contact excursions, not just centroid velocity. Keep this
    # separate from six-action straight travel; native Walk remains a baseline.
    for n in ['Leg.R','Leg.L']:
        window=[]
        for row in rows:
            if row['feet'][n]['zmin']<.004:window.append(row)
            elif window:
                if len(window)>2:plant_segments.append(max((Vector(x['feet'][n]['center'])-Vector(window[0]['feet'][n]['center'])).xy.length for x in window))
                window=[]
        if len(window)>2:plant_segments.append(max((Vector(x['feet'][n]['center'])-Vector(window[0]['feet'][n]['center'])).xy.length for x in window))
    info['max_near_ground_centroid_excursion_m']=max(plant_segments,default=0)
    info['handoff_phases']=data['handoff_phases']
    report['transitions'].append(info)
    print('TRANSITION',data['scene'],info['max_twist_deg'],info['floor_min_m'],flush=True)
report['new_Combat_Strafe_Actions']=[a.name for a in bpy.data.actions if a.name.startswith('Combat_Strafe') and a.name not in before['actions']]
report['pass']=all(preservation.values()) and len(report['new_Combat_Strafe_Actions'])==6 and all(c['max_twist_deg']<=20 and c['floor_min_m']>-.002 and c['centroid_xy_slip_mm']<2 and c['sole_corner_xy_slip_mm']<40 and c['loop_value_max_error']<1e-5 and c['loop_derivative_max_error']<.001 and not c['forbidden_tracks'] for c in report['cases'].values()) and all(c['max_twist_deg']<=20 and c['floor_min_m']>-.002 and c['max_world_foot_delta_per_384hz_sample_m']<.05 for c in report['transitions'])
(OUT/'validation.json').write_text(json.dumps(report,indent=2));print('PASS',report['pass'],flush=True)
assert report['pass'],report
