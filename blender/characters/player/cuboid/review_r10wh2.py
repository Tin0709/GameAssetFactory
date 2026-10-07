from hold_r10wh2_common import *
import ast
design=json.loads((OUT/'design.json').read_text());old=json.loads((BASE/'weapon_hold_r10wh1_review/design.json').read_text());loc=design['locomotion'];reviews={}
tree=ast.parse((BASE/'review_onearm_r9w4.py').read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='compose'],type_ignores=[]),'<unchanged native gait composition>','exec'))
def light_scene(name):
    assert name not in bpy.data.scenes;s=scene(name);bpy.context.window.scene=s;s.render.resolution_x=1920;s.render.resolution_y=900;s.render.fps=24;s.eevee.taa_render_samples=16;s.sync_mode='FRAME_DROP'
    for ob in list(s.objects):
        if ob.type=='LIGHT':s.collection.objects.unlink(ob)
    for ob in bpy.data.scenes['R10WH1_REVIEW_RIFLE_HOLD'].objects:
        if ob.type=='LIGHT':s.collection.objects.link(ob)
    return s
def label(s,cam,text,x,size=.10):
    font=bpy.data.curves.new('R10WH2_Label','FONT');font.body=text;font.align_x='CENTER';font.size=size;ob=bpy.data.objects.new(font.name,font);s.collection.objects.link(ob);ob.parent=cam;ob.location=(x,cam.data.ortho_scale/(s.render.resolution_x/s.render.resolution_y)/2-.17,-10)
for cat in ['Pistol','Rifle','Shotgun']:
    d=design['categories'][cat]
    for mode in ['Hold','Move','AimAround','Turn','Sprint']:
        name='R10WH2_AB_'+cat.upper()+'_'+mode.upper();s=light_scene(name);source=bpy.data.scenes[old['reviews'][cat+'_'+mode]['scene']];cam=source.camera.copy();cam.data=source.camera.data.copy();cam.name=name+'_Camera';s.collection.objects.link(cam);s.camera=cam;right=cam.rotation_euler.to_quaternion()@Vector((1,0,0))
        turning=mode=='Turn';N=456 if turning else 832 if mode=='Sprint' else PERIOD[mode];s.frame_end=N
        lower=loc['turn_lower']['Walk'] if turning else loc['lower_copies']['Walk'] if mode=='Move' else loc['lower_copies']['Sprint'] if mode=='Sprint' else None;actors={}
        for tag,sign in [('A',-1),('B',1)]:
            r,m,ws=clone_wh2(cat+'_'+mode+'_'+tag,s,cat);upper=(d['baseline_turn'] if tag=='A' else d['turn_action']) if turning else d['baseline_actions' if tag=='A' else 'actions']['Move' if mode=='Sprint' else mode]
            compose(r,bpy.data.actions[upper],bpy.data.actions[lower] if lower else None,1 if turning else 4 if mode=='Move' else 64 if mode=='Sprint' else 1)
            offset=right*(sign*(2.8 if turning else 1.65))
            if turning:
                stage=bpy.data.objects.new(name+'_'+tag+'_Stage',None);s.collection.objects.link(stage);stage.location=offset
                path=bpy.data.objects.new(name+'_'+tag+'_Path',None);s.collection.objects.link(path);path.parent=stage;assign(path,bpy.data.actions[loc['imported_actions']['PREVIEW_ONLY_R3_Walk_Path']]);r.parent=path;r.matrix_parent_inverse=Matrix.Identity(4);r.location=(0,0,0)
            else:r.location=offset
            actors[tag]={'rig':r.name,'mesh':m.name,'weapons':[w.name for w in ws],'upper':upper}
            label(s,cam,'A  APPROVED WH1' if tag=='A' else 'B  WH2 ELBOW FOLD',sign*(2.8 if turning else 1.65),.16 if turning else .10)
        s.frame_set(1);reviews[cat+'_'+mode]={'scene':s.name,'actors':actors,'movie_frames':208 if mode=='Sprint' else N,'full_frames':N,'lower':lower,'loop':mode not in ['Turn','Sprint']}
design['reviews']=reviews;showcases={}
for mode in ['Hold','AimAround']:
    name='R10WH2_SHOWCASE_'+mode.upper();s=light_scene(name);s.render.resolution_x=2400;s.render.resolution_y=900;cam=camera(s,name+'_Camera',(-3,-5,2.6),(0,-.2,1.1),8.1);s.camera=cam;right=cam.rotation_euler.to_quaternion()@Vector((1,0,0));actors={}
    for i,cat in enumerate(['Pistol','Rifle','Shotgun']):
        r,m,ws=clone_wh2('Showcase_'+mode+'_'+cat,s,cat);compose(r,bpy.data.actions[design['categories'][cat]['actions'][mode]],None,1);r.location=right*((i-1)*2.65);actors[cat]={'rig':r.name,'mesh':m.name,'weapons':[w.name for w in ws]};label(s,cam,'PISTOL' if cat=='Pistol' else 'RIFLE / M4' if cat=='Rifle' else 'SHOTGUN',(i-1)*2.65,.13)
    s.frame_end=PERIOD[mode];s.frame_set(25 if mode=='Hold' else 1);showcases[mode]={'scene':name,'actors':actors,'movie_frames':PERIOD[mode],'loop':True}
design['showcases']=showcases;(OUT/'design.json').write_text(json.dumps(design,indent=2));result={'AB_scenes':len(reviews),'showcase_scenes':len(showcases),'checkpoint':checkpoint()}
