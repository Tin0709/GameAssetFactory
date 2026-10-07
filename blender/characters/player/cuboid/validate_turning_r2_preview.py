import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from turning_r2_common import *
# Reuse the validated oriented-box diagnostic, without rerunning full-pose tests here.
p=BASE/'validate_turning_r2.py';src=p.read_text();exec(src[src.index('def box('):src.index("report={'preserved")])
meta=json.loads((OUT/'preview_metadata.json').read_text());protected=json.loads((OUT/'preservation_before.json').read_text());check_preserved(protected)
report={'preview_checks':{},'circle_sign_checks':[],'phase_entry_cases':len(json.loads((OUT/'phase_entry_tests.json').read_text()))}
src=(BASE/'build_turning_r2_preview.py').read_text();exec(src[src.index('def evaluate('):src.index("metadata={'fps'")])
for gait,period in PERIOD.items():
    sa=bpy.data.scenes['R2_'+gait+'_A'];sb=bpy.data.scenes['R2_'+gait+'_B']
    assert sa.camera.matrix_world==sb.camera.matrix_world
    assert sa.camera.data.ortho_scale==sb.camera.data.ortho_scale
    ra=bpy.data.objects['R2_'+gait+'_A_Rig'];rb=bpy.data.objects['R2_'+gait+'_B_Rig']
    assert ra.parent.animation_data.action==rb.parent.animation_data.action
    rows=meta['gaits'][gait]['rows']
    for label,sign in [('CCW circle',1),('CW circle',-1)]:
        rs=[row for row in rows if row['case']==label]
        assert all(row['signed_weight']*sign>=-1e-9 for row in rs)
        yawspan=rs[-1]['yaw']-rs[0]['yaw'];assert abs(abs(yawspan)-2*math.pi)<1e-5
        report['circle_sign_checks'].append({'gait':gait,'case':label,'yaw_degrees':math.degrees(yawspan),'same_local_sign_across_all_headings':True})
    for variant in ['A','B']:
        s=bpy.data.scenes['R2_'+gait+'_'+variant];bpy.context.window.scene=s
        r=bpy.data.objects['R2_'+gait+'_'+variant+'_Rig'];pts=mesh_points(bpy.data.objects['R2_'+gait+'_'+variant+'_Mesh'])
        lowest=1.;hits=[];rooterror=0.;valueerror=0.;foot_samples=[]
        for i in range(911):
            f=1+i/2;s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
            # Do not evaluate the interpolation across a deliberate path-clip cut.
            k=int(f)-1
            if f!=int(f) and k+1<len(rows) and rows[k]['case']!=rows[k+1]['case']:continue
            lowest=min(lowest,floor_min(r,pts))
            for a,b in pairs:
                if overlap(a,b):hits.append({'frame':f,'pair':[a,b]})
            rooterror=max(rooterror,max(abs(r.pose.bones['Root'].matrix_basis[x][y]-(1 if x==y else 0)) for x in range(4) for y in range(4)))
            if f==int(f):
                expected=fullpose(gait,rows[k]['time'],rows[k]['signed_weight'] if variant=='B' else 0)
                for n in BODY:
                    p=r.pose.bones[n];valueerror=max(valueerror,(p.location-expected[n][0]).length,max(abs(p.rotation_euler[j]-expected[n][1][j]) for j in range(3)))
            for n in ['Leg.L','Leg.R']:
                bottom=float(transformed(r,pts,n)[:,2].min())
                point=Vector(((.1125 if n=='Leg.L' else -.1125),0,0))
                world=r.matrix_world@r.pose.bones[n].matrix@r.data.bones[n].matrix_local.inverted()@point
                foot_samples.append({'f':f,'case':rows[k]['case'],'leg':n,'height':bottom,'world':world})
        speeds=[]
        for a,b in zip(foot_samples,foot_samples[2:]):
            if a['leg']==b['leg'] and a['case']==b['case'] and max(a['height'],b['height'])<.03:
                dt=(b['f']-a['f'])/24
                if dt>0:
                    d=b['world']-a['world'];speeds.append(math.hypot(d.x,d.y)/dt)
        report['preview_checks'][gait+'_'+variant]={'samples':911,'min_leg_bottom_m':lowest,'inset_body_hits':hits,'root_error':rooterror,'shared_phase_pose_error':valueerror,
          'near_ground_lower_face_center_horizontal_speed_m_s':{'count':len(speeds),'median':float(np.median(speeds)),'p95':float(np.percentile(speeds,95)),'max':max(speeds)},'foot_metric_note':'Lower face-center proxy at bottom height <3 cm; not a recovered source contact or proof of foot planting.'}
        (OUT/'preview_validation.json').write_text(json.dumps(report,indent=2))
        assert lowest>-.002 and rooterror<1e-6 and valueerror<2e-5,(gait,variant,lowest,rooterror,valueerror)
        assert not hits,(gait,variant,hits[:4])
(OUT/'preview_validation.json').write_text(json.dumps(report,indent=2))
print('R2_PREVIEW_VALIDATED '+json.dumps(report),flush=True)
