import bpy,sys,json,math,hashlib
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE));import motion as m
SOURCE=HERE/'hybrid_run_authoring.blend'
rig=bpy.data.objects['HybridRun_Authoring_Rig'];mesh=bpy.data.objects['HybridRun_Authoring_Mesh'];scene=bpy.context.scene
rests={b.name:b.bone.matrix_local.copy()for b in rig.pose.bones}
points={}
for name in ['Leg.L','Leg.R']:
 idx=mesh.vertex_groups[name].index;points[name]=[v.co-rests[name].translation for v in mesh.data.vertices if any(g.group==idx and g.weight>.999 for g in v.groups)]
actions=[bpy.data.actions['Run_Hybrid_'+v[0]+'_Original_v001']for v in m.VARIANTS]

metrics=[]
for action,variant in zip(actions,m.VARIANTS):
    rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
    hips=[];angles=[];heads=[];penetrations=[];contacts=[];scales=[];extensions=[]
    for j in range(1025):
        frame=1+32*j/1024;scene.frame_set(int(frame),subframe=frame%1)
        p=((frame-1)/32+m.ORIGIN)%1;time=(frame-1)/32/m.HZ
        hips.append(rig.pose.bones['Hips'].matrix.translation.z)
        body=rig.pose.bones['Chest'].matrix.to_3x3()@rests['Chest'].to_3x3().inverted();angles.append(math.degrees(body.to_euler('XYZ').z))
        head=rig.pose.bones['Head'].matrix.to_3x3()@rests['Head'].to_3x3().inverted();heads.append([math.degrees(v) for v in head.to_euler('XYZ')])
        for bone in rig.pose.bones:scales.append(max(abs(v-1) for v in bone.scale))
        for name in points:
            theta,height,plant,corner=m.leg(p if name.endswith('L') else (p+.5)%1)
            world=rig.pose.bones[name].matrix@rests[name].inverted()
            actual=[world@(v+rests[name].translation)for v in points[name]]
            penetrations.append(max(0,-min(v.z for v in actual)))
            extensions.append(rig.pose.bones[name].matrix.translation.z-rig.pose.bones['Hips'].matrix.translation.z)
            if plant:
                edge=[v for v in points[name] if abs(v.z+.675)<1e-5 and abs(v.y-corner)<1e-5]
                assert len(edge)==2
                pt=sum((world@(v+rests[name].translation)for v in edge),Vector())/2
                contacts.append({'bone':name,'corner':corner,'time':time,'point':[pt.x,pt.y-7*time,pt.z]})
    speeds=[]
    for name in points:
        rows=[v for v in contacts if v['bone']==name]
        for a,b in zip(rows,rows[1:]):
            if b['time']-a['time']<.001 and a['corner']==b['corner']:
                vv=(Vector(b['point'])-Vector(a['point']))/(b['time']-a['time']);speeds.append(vv.length)
                if len(speeds) in [10,30,70]:print('CONTACT_VELOCITY',tuple(vv))
    result={'action':action.name,'hip_bounce_mm':(max(hips)-min(hips))*1000,'torso_yaw_peak_to_peak_deg':max(angles)-min(angles),'head_world_relative_rest_peak_abs_deg':[max(abs(h[i])for h in heads)for i in range(3)],'rolling_contact_samples':len(speeds),'rolling_contact_speed_rms_m_s':math.sqrt(sum(v*v for v in speeds)/len(speeds)),'rolling_contact_speed_max_m_s':max(speeds),'max_floor_penetration_mm':max(penetrations)*1000,'max_scale_error':max(scales),'leg_pivot_offset_z_m':[min(extensions),max(extensions)],'gait_hz':m.HZ,'stance_fraction_original':m.DUTY,'phase_origin':m.ORIGIN,'root_world_travel_m':0}
    assert max(penetrations)<.001 and math.sqrt(sum(v*v for v in speeds)/len(speeds))<.05 and max(scales)<1e-6,result
    assert abs(result['hip_bounce_mm']-variant[1]*1000)<.1,result
    metrics.append(result);print('MEASURED',json.dumps(result),flush=True)
(HERE/'measurements.json').write_text(json.dumps({'scope':'Actually evaluated source study; rolling-edge stance schedule is original, not recovered native MD2 contacts. Virtual travel7m/s, in-place rig root. No terrain IK.','metrics':metrics},indent=2))
(HERE/'source_metadata.json').write_text(json.dumps({'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'actions':[a.name for a in actions],'rig':rig.name,'mesh':mesh.name,'armature':rig.data.name,'fps':m.FPS,'fps_base':m.FPS_BASE},indent=2))
