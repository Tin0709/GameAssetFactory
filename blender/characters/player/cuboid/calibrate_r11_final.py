import importlib,hold_r11_common
importlib.reload(hold_r11_common)
from hold_r11_common import *
design=json.loads((OUT/'design.json').read_text())
for cat,d in design['categories'].items():
    d.setdefault('baseline_scale',1.12 if cat=='Rifle' else 1.0)
    for data in [d]+[s['actors'][cat] for s in design['showcases'].values()]:
        w=next(bpy.data.objects[n] for n in data['weapons'] if '_Base' in n);w.parent.scale=STUDY_GUN_SCALE[cat]
    s=bpy.data.scenes[d['scene']];bpy.context.window.scene=s;r=bpy.data.objects[d['rig']];assign(r,None)
    for p in r.pose.bones:p.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update();w=next(bpy.data.objects[n] for n in d['weapons'] if '_Base' in n);gm=r.matrix_world.inverted()@w.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world
    socket=r.pose.bones['WeaponCarrier'].matrix.inverted()@gm;d['socket']=[list(row) for row in socket];d['study_weapon_scale']=STUDY_GUN_SCALE[cat]
    for view,pos,target,scale in [('FrontReference',(3,-5,3),(0,-.25,1.1),2.65),('UnderReference',(1.5,-3,-.15),(0,-.2,1.15),2.8),('ReverseTop',(-3,-5,25),(0,-.35,1.2),1.95)]:
        if view not in d['cameras']:d['cameras'][view]=camera(s,'R11_'+cat+'_'+view,pos,target,scale).name
for mode,d in design['showcases'].items():
    if mode=='Turn':continue
    s=bpy.data.scenes[d['scene']];cam=s.camera;cam.location=(3,-5,3);cam.rotation_euler=(Vector((0,-.25,1.1))-cam.location).to_track_quat('-Z','Y').to_euler();right=cam.rotation_euler.to_quaternion()@Vector((1,0,0))
    for i,cat in enumerate(['Pistol','Rifle','Shotgun']):bpy.data.objects[d['actors'][cat]['rig']].location=right*((i-1)*2.7)
(OUT/'design.json').write_text(json.dumps(design,indent=2))
p=BASE/'refine_r11_reference.py';ns={'__file__':str(p)};exec(compile(p.read_text(encoding='utf-8'),str(p),'exec'),ns);result={'calibrated':'raised straight separated arms; dev gun-root sizes fit the reference reach'}
