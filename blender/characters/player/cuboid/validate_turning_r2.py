import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from turning_r2_common import *
protected=json.loads((OUT/'preservation_before.json').read_text());check_preserved(protected)
s=bpy.data.scenes['R2_Turn_Authoring'];bpy.context.window.scene=s;r=bpy.data.objects['R2_Author_Rig'];mesh=bpy.data.objects['R2_Author_Mesh'];pts=mesh_points(mesh)
def box(n):
    lo=pts[n].min(0)+.015;hi=pts[n].max(0)-.015
    if n.startswith('Leg'):hi[2]-=.07
    m=np.array(r.pose.bones[n].matrix@r.data.bones[n].matrix_local.inverted())
    return m[:3,:3]@((lo+hi)/2)+m[:3,3],m[:3,:3],(hi-lo)/2
def overlap(a,b):
    ca,ra,ea=box(a);cb,rb,eb=box(b)
    for ax in [*ra.T,*rb.T]+[np.cross(x,y) for x in ra.T for y in rb.T]:
        if np.linalg.norm(ax)<1e-7:continue
        if abs((cb-ca)@ax)>=np.abs(ra.T@ax)@ea+np.abs(rb.T@ax)@eb:return False
    return True
pairs=[('Arm.L','Chest'),('Arm.R','Chest'),('Arm.L','Head'),('Arm.R','Head'),('Leg.L','Leg.R'),('Leg.L','Chest'),('Leg.R','Chest'),('Head','Chest')]
report={'preserved_actions':len(protected['actions']),'preserved_geometry_weights_all_existing_rigs':True,'original_blend_hashes_unchanged':True,'pose_checks':{},'loop_checks':{}}
for gait,period in PERIOD.items():
    base=bpy.data.actions[gait+'_ReferenceStudy_V1']
    for direction in ['Left','Right']:
        a=bpy.data.actions[gait+'_Turn'+direction+'_Reference_V1'];slopes=[]
        for c in curves(a):
            k,j=c.keyframe_points[0],c.keyframe_points[-1];slopes.append(abs((k.handle_right.y-k.co.y)/(k.handle_right.x-k.co.x)-(j.co.y-j.handle_left.y)/(j.co.x-j.handle_left.x)))
        loop={'endpoint_error':max(abs(c.evaluate(1)-c.evaluate(period+1)) for c in curves(a)),'seam_slope_error':max(slopes),'duration':period/24,'scale_tracks':sum(c.data_path.endswith('scale') for c in curves(a)),'weapon_tracks':sum('WeaponCarrier' in c.data_path for c in curves(a))}
        assert loop['endpoint_error']<1e-6 and loop['seam_slope_error']<1e-5 and not loop['scale_tracks'] and not loop['weapon_tracks']
        report['loop_checks'][a.name]=loop
        for w in [.25,.5,.75,1.]:
            bottoms=[];hits=[];head_z=[];rooterror=0.;shouldererror=0.;head_delta=[]
            for i in range(period*8+1):
                f=1+i/8;pa=sample(r,s,base,f);pb=sample(r,s,a,f);ps=mix(pa,pb,w);apply(r,ps)
                bottoms.append(floor_min(r,pts));head_z.append(r.pose.bones['Head'].matrix.translation.z)
                for aa,bb in pairs:
                    if overlap(aa,bb):hits.append({'f':f,'pair':[aa,bb]})
                rooterror=max(rooterror,max(abs(r.pose.bones['Root'].matrix_basis[x][y]-(1 if x==y else 0)) for x in range(4) for y in range(4)))
                for n in ['Arm.L','Arm.R']:shouldererror=max(shouldererror,(ps[n][0]-pa[n][0]).length)
                # Local head change is measured relative to matching base, not source footage.
                head_delta.append(math.degrees(pa['Head'][1].to_quaternion().rotation_difference(ps['Head'][1].to_quaternion()).angle))
            entry={'samples':len(bottoms),'min_leg_bottom_m':min(bottoms),'head_bob_m':max(head_z)-min(head_z),'root_basis_error':rooterror,'additional_shoulder_translation_m':shouldererror,'head_local_delta_max_deg':max(head_delta),'inset_body_hits':hits}
            report['pose_checks'][gait+'_'+direction+'_w'+str(w)]=entry
            assert min(bottoms)>-.001,(gait,direction,w,min(bottoms))
            assert rooterror<1e-6 and shouldererror<1e-6
            # Write diagnostic before asserting clipping, so failure evidence is retained.
            (OUT/'validation.json').write_text(json.dumps(report,indent=2))
            assert not hits,(gait,direction,w,hits[:4])
    # Direct L/R midpoint is a supplemental crossfade stress check.
    left=bpy.data.actions[gait+'_TurnLeft_Reference_V1'];right=bpy.data.actions[gait+'_TurnRight_Reference_V1'];low=1
    for i in range(period*4+1):
        f=1+i/4;pa=sample(r,s,left,f);pb=sample(r,s,right,f);apply(r,mix(pa,pb,.5));low=min(low,floor_min(r,pts));assert not any(overlap(a,b) for a,b in pairs)
    report['pose_checks'][gait+'_LeftRightMidpoint']={'min_leg_bottom_m':low};assert low>-.001
(OUT/'validation.json').write_text(json.dumps(report,indent=2))
print('R2_VALIDATED '+json.dumps({'preserved_actions':report['preserved_actions'],'cases':len(report['pose_checks']),'minimum_floor':min(v['min_leg_bottom_m'] for v in report['pose_checks'].values()),'max_slope_error':max(v['seam_slope_error'] for v in report['loop_checks'].values())}),flush=True)
