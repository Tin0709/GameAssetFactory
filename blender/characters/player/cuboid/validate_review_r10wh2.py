from hold_r10wh2_common import *
from bpy_extras.object_utils import world_to_camera_view
design=json.loads((OUT/'design.json').read_text());failures=[];rows={}
for job,d in design['reviews'].items():
    s=bpy.data.scenes[d['scene']];bpy.context.window.scene=s;actors=[bpy.data.objects[d['actors'][tag]['rig']] for tag in ['A','B']]
    lo_a=[(st.action.name,st.repeat,st.scale) for tr in actors[0].animation_data.nla_tracks for st in tr.strips];lo_b=[(st.action.name,st.repeat,st.scale) for tr in actors[1].animation_data.nla_tracks for st in tr.strips]
    if lo_a!=lo_b:failures.append(job+' gait strips differ')
    frames=[1,17,33,49,64] if job.endswith('_Move') else [1,14,52,104,156,208,833] if job.endswith('_Sprint') else [1,49,73,145,217,289] if job.endswith('_AimAround') else [1,25,49,73,96]
    if job.endswith('_Turn'):frames=[1,25,49,72,73,109,144,145,193,240,241,301,348,349,409,456]
    diff=0
    for f in frames:
        s.frame_set(f);bpy.context.view_layer.update()
        for n in LOWER:
            a=actors[0].pose.bones[n].matrix_basis;b=actors[1].pose.bones[n].matrix_basis;diff=max(diff,max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4)))
        for n in ['Spine','Chest','Neck','Head','WeaponCarrier']:
            a=actors[0].pose.bones[n].matrix_basis;b=actors[1].pose.bones[n].matrix_basis;diff=max(diff,max(abs(a[i][j]-b[i][j]) for i in range(4) for j in range(4)))
        if job.endswith('_Turn'):
            for r in actors:
                if r.parent.animation_data.action.name!=design['locomotion']['imported_actions']['PREVIEW_ONLY_R3_Walk_Path']:failures.append(job+' source path changed')
    if diff>1e-5:failures.append(job+' approved body/gait composition differs')
    rows[job]={'sample_frames':frames,'matched_body_and_gait_max_difference':diff,'gait_strips':lo_b}
# Every integer turning/showcase frame must fit the review camera.
camera_rows={}
scenes=[(job,d) for job,d in design['reviews'].items() if job.endswith('_Turn')]+[('Showcase_'+mode,d) for mode,d in design['showcases'].items()]
for job,d in scenes:
    s=bpy.data.scenes[d['scene']];bpy.context.window.scene=s;lo=[99,99];hi=[-99,-99]
    for f in range(1,s.frame_end+1):
        s.frame_set(f);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
        for ob in [o for o in s.objects if o.type=='MESH']:
            ev=ob.evaluated_get(dg);mesh=ev.to_mesh()
            for v in mesh.vertices:
                c=world_to_camera_view(s,s.camera,ev.matrix_world@v.co)
                for i in range(2):lo[i]=min(lo[i],c[i]);hi[i]=max(hi[i],c[i])
            ev.to_mesh_clear()
    camera_rows[job]={'min':lo,'max':hi,'frames':s.frame_end}
    if min(lo)<.025 or max(hi)>.975:failures.append(job+' review camera clips actor')
result={'passed':not failures,'failures':failures,'reviews':rows,'camera_bounds':camera_rows};(OUT/'review_validation.json').write_text(json.dumps(result,indent=2))
