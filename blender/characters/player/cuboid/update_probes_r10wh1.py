from hold_r10wh1_common import *
design=json.loads((OUT/'design.json').read_text());metrics={}
for category,data in design['categories'].items():
    s=bpy.data.scenes[data['scene']];bpy.context.window.scene=s;r=bpy.data.objects[data['rig']];ws=[bpy.data.objects[n] for n in data['weapons']];bpy.context.view_layer.update()
    gun_base=next(w for w in ws if '_Base' in w.name)
    socket=r.pose.bones['WeaponCarrier'].matrix.inverted()@gun_base.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world
    data['socket']=[list(row) for row in socket];data['socket_authority']='main gun Base mesh, never Pump mesh';base={n:Matrix(x) for n,x in data['base'].items()}
    body_pose(r,base,0,0,0,0);row=pose_hold(r,ws,socket,category);boxes=boxes_for(r,bpy.data.objects[data['mesh']],.005)
    row['head']=triangle_box(r,ws,'Head',boxes['Head']);row['chest']=triangle_box(r,ws,'Chest',boxes['Chest']);data['initial_metrics']=row;metrics[category]=row
    for view in ['Front','FrontThreeQuarter','Side']:
        s.camera=bpy.data.objects[data['cameras'][view]];s.render.filepath=str(OUT/(category+'_fitted_'+view+'.png'));bpy.ops.render.render(write_still=True)
(OUT/'design.json').write_text(json.dumps(design,indent=2));result=metrics
