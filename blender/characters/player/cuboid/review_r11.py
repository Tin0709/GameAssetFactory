from hold_r11_common import *
design=json.loads((OUT/'design.json').read_text());old=json.loads((BASE/'weapon_hold_r10wh2_review/design.json').read_text());loc=design['locomotion'];shows={}
for mode in ['Hold','Move','AimAround','Sprint','Turn']:
    s=studio('R11_SHOWCASE_'+mode.upper());s.render.resolution_x=1800;s.render.resolution_y=800
    if mode=='Turn':
        src=bpy.data.scenes[old['reviews']['Rifle_Turn']['scene']].camera;cam=src.copy();cam.data=src.data.copy();cam.name='R11_Turn_Camera';s.collection.objects.link(cam)
    else:cam=camera(s,'R11_Showcase_'+mode,(-3,-5,2.6),(0,-.35,1.1),8.8)
    s.camera=cam;right=cam.rotation_euler.to_quaternion()@Vector((1,0,0));actors={};lower=loc['turn_lower']['Walk'] if mode=='Turn' else loc['lower_copies']['Sprint'] if mode=='Sprint' else loc['lower_copies']['Walk'] if mode=='Move' else None
    N=456 if mode=='Turn' else 208 if mode=='Sprint' else PERIOD[mode];s.frame_end=N
    for i,cat in enumerate(['Pistol','Rifle','Shotgun']):
        r,m,ws=clone_r11('Showcase_'+mode+'_'+cat,s,cat);a=bpy.data.actions[design['categories'][cat]['actions']['Move' if mode in ['Sprint','Turn'] else mode]]
        compose(r,a,bpy.data.actions[lower] if lower else None,1 if mode=='Turn' else 64 if mode=='Sprint' else 4 if mode=='Move' else 1)
        offset=right*((i-1)*2.7)
        if mode=='Turn':
            stage=bpy.data.objects.new('R11_'+cat+'_TurnStage',None);s.collection.objects.link(stage);stage.location=offset
            path=bpy.data.objects.new('R11_'+cat+'_TurnPath',None);s.collection.objects.link(path);path.parent=stage;assign(path,bpy.data.actions[loc['imported_actions']['PREVIEW_ONLY_R3_Walk_Path']]);r.parent=path;r.matrix_parent_inverse=Matrix.Identity(4);r.location=(0,0,0)
        else:r.location=offset
        actors[cat]={'rig':r.name,'mesh':m.name,'weapons':[w.name for w in ws],'upper':a.name};label(s,cam,cat.upper(),(i-1)*2.7)
    s.frame_set(25 if mode=='Hold' else 1);shows[mode]={'scene':s.name,'actors':actors,'frames':N,'lower':lower,'loop':mode in ['Hold','Move','AimAround']}
design['showcases']=shows
(OUT/'design.json').write_text(json.dumps(design,indent=2))
bpy.context.window.scene=bpy.data.scenes[shows['Hold']['scene']]
bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'player_weapon_hold_r11_study.blend'),check_existing=False)
result={'showcases':list(shows)}
