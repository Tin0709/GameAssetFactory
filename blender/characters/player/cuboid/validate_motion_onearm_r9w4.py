"""Independent evaluated-pose timing diagnostics for authored upper motion."""
from onearm_r9w4_common import *
design=json.loads((OUT/'design.json').read_text());rows={};failures=[]
def angular(a,b):
    angle=math.degrees(a.to_quaternion().rotation_difference(b.to_quaternion()).angle)
    return min(angle,360-angle)  # q and -q encode the same orientation.
for category,data in design['categories'].items():
    s=bpy.data.scenes[data['scene']];bpy.context.window.scene=s;r=bpy.data.objects[data['rig']]
    for mode,name in data['actions'].items():
        a=bpy.data.actions[name];N=PERIOD[mode];poses=[]
        for i in range(2*N+3):
            f=.5+i*.5;sample(r,s,a,f);poses.append({n:r.pose.bones[n].matrix_basis.copy() for n in UPPER})
        steps={n:[angular(poses[i][n],poses[i+1][n]) for i in range(len(poses)-1)] for n in UPPER}
        # Compare cyclic position derivatives on either side of the exact seam.
        seam_velocity_error=max(((poses[2][n].translation-poses[1][n].translation)-(poses[1][n].translation-poses[0][n].translation)).length for n in UPPER)
        max_step=max(max(v) for v in steps.values())
        if max_step>8:failures.append(name+' unexpected half-frame upper rotation >8 degrees')
        if seam_velocity_error>.001:failures.append(name+' loop position derivative mismatch >1mm/half-frame')
        rows[name]={'half_frame_rotation_max_deg':max_step,'loop_position_derivative_error_m_per_half_frame':seam_velocity_error,'samples':len(poses)}
    a=bpy.data.actions[data['turn_response_action']];poses=[]
    for i in range(911):
        sample(r,s,a,1+i*.5);poses.append({n:r.pose.bones[n].matrix_basis.copy() for n in UPPER})
    steps=[max(angular(poses[i][n],poses[i+1][n]) for n in UPPER) for i in range(len(poses)-1)]
    max_step=max(steps)
    if max_step>8:failures.append(a.name+' unexpected half-frame upper rotation >8 degrees')
    rows[a.name]={'half_frame_rotation_max_deg':max_step,'samples':len(poses),'loop':False}
result={'passed':not failures,'failures':failures,'actions':rows,'note':'Pose continuity diagnostics bound discontinuities; naturalness and gesture timing still require human playback.'}
(OUT/'motion_validation.json').write_text(json.dumps(result,indent=2))
