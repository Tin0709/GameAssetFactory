"""Fit owned turn cameras; stage A/B on the actual camera's horizontal axis."""
from onearm_r9w4_common import *
design=json.loads((OUT/'design.json').read_text());metrics={}
for cat in PREFIX:
    row=design['reviews'][cat+'_Turn'];s=bpy.data.scenes[row['scene']];bpy.context.window.scene=s;cam=s.camera
    bpy.context.view_layer.update();right=cam.matrix_world.to_quaternion()@Vector((1,0,0))
    # Initial staging used the template camera's cached basis. Constant world
    # offsets on the final camera axis make both copies project at equal height
    # and allow a tighter full-body view. Path curves and actor speeds stay exact.
    for label,sign in [('A',-1),('B',1)]:
        rig=bpy.data.objects[row['actors'][label]['rig']];stage=rig.parent.parent;assert stage.name=='R9W4_'+cat+'_'+label+'_Stage';stage.location=right*(sign*3.1)
    for ob in s.objects:
        if ob.type=='FONT' and ob.data.body[:1] in ['A','B']:
            ob.location=right*(-3.1 if ob.data.body.startswith('A') else 3.1)+Vector((0,0,3.1))
    bpy.context.view_layer.update()
    inv_rot=cam.matrix_world.to_quaternion().inverted().to_matrix();lower=np.full(2,np.inf);upper=np.full(2,-np.inf)
    meshes=[o for o in s.objects if o.type=='MESH']
    for f in range(1,s.frame_end+1):
        s.frame_set(f);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
        for ob in meshes:
            ev=ob.evaluated_get(dg);m=ev.to_mesh()
            points=np.array([tuple(inv_rot@(ev.matrix_world@v.co))[:2] for v in m.vertices]);ev.to_mesh_clear()
            if len(points):lower=np.minimum(lower,points.min(0));upper=np.maximum(upper,points.max(0))
    aspect=s.render.resolution_x/s.render.resolution_y;span=upper-lower;centre=(upper+lower)/2
    cam.data.ortho_scale=float(max(span[0],span[1]*aspect)*1.12)
    current=inv_rot@cam.location;current.x=float(centre[0]);current.y=float(centre[1]);cam.location=inv_rot.inverted()@current
    # Orthographic frame union test: a 12% margin encloses every rendered frame.
    half=np.array([cam.data.ortho_scale/2,cam.data.ortho_scale/aspect/2]);normalized=(span/2)/half
    assert max(normalized)<.9,(cat,normalized)
    a=bpy.data.objects[row['actors']['A']['rig']];b=bpy.data.objects[row['actors']['B']['rig']];path_error=0
    for f in range(1,s.frame_end+1):
        s.frame_set(f);bpy.context.view_layer.update()
        for rig in [a,b]:
            stage=rig.parent.parent;expected=stage.matrix_world@rig.parent.matrix_basis@rig.matrix_basis;path_error=max(path_error,max(abs(expected[i][j]-rig.matrix_world[i][j]) for i in range(4) for j in range(4)))
        delta=inv_rot@(b.matrix_world.translation-a.matrix_world.translation);assert abs(delta.y)<1e-5 and abs(delta.z)<1e-5,(cat,f,delta)
    assert path_error<1e-5,path_error
    metrics[cat]={'ortho_scale':cam.data.ortho_scale,'projected_union_min':lower.tolist(),'projected_union_max':upper.tolist(),'frame_half_extent_occupancy':normalized.tolist(),'frames':s.frame_end,'camera_horizontal_staging':True,'source_path_transform_error':path_error}
(OUT/'camera_validation.json').write_text(json.dumps({'passed':True,'turns':metrics},indent=2));result=metrics
