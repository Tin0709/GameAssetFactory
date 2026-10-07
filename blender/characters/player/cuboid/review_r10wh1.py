from hold_r10wh1_common import *
import ast
design=json.loads((OUT/'design.json').read_text());old=json.loads((BASE/'living_r9w4_review/design.json').read_text());loc=old['locomotion'];reviews={}
tree=ast.parse((BASE/'review_onearm_r9w4.py').read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='compose'],type_ignores=[]),'<existing native gait composition>','exec'))
for cat in ['Rifle','Shotgun','Pistol']:
    data=design['categories'][cat]
    for mode in ['Hold','Move','AimAround','Turn','Sprint']:
        name='R10WH1_REVIEW_'+cat.upper()+'_'+mode.upper();assert name not in bpy.data.scenes;s=scene(name);bpy.context.window.scene=s;s.render.resolution_x=1920;s.render.resolution_y=900;s.render.fps=24;s.eevee.taa_render_samples=16;s.sync_mode='FRAME_DROP'
        for ob in list(s.objects):
            if ob.type=='LIGHT':s.collection.objects.unlink(ob)
        for ob in bpy.data.scenes['R9W4_REVIEW_RIFLE_HOLD'].objects:
            if ob.type=='LIGHT':s.collection.objects.link(ob)
        turning=mode=='Turn';s.camera=camera(s,name+'_Camera',(0,10,5.5) if turning else (-3,-5,2.6),(0,0,.9) if turning else (0,-.2,1.1),12.0 if turning else 6.3)
        right=s.camera.rotation_euler.to_quaternion()@Vector((1,0,0));actors={}
        N=456 if turning else 832 if mode=='Sprint' else PERIOD[mode];s.frame_end=N
        lower_name=loc['turn_lower']['Walk'] if turning else loc['lower_copies']['Walk'] if mode=='Move' else loc['lower_copies']['Sprint'] if mode=='Sprint' else None
        for label,sign in [('A',-1),('B',1)]:
            r,m,ws=clone_r10(cat+'_'+mode+'_'+label,s,cat);upper_name=(data['baseline_turn'] if label=='A' else data['turn_action']) if turning else data['baseline_actions' if label=='A' else 'actions']['Move' if mode=='Sprint' else mode]
            compose(r,bpy.data.actions[upper_name],bpy.data.actions[lower_name] if lower_name else None,1 if turning else 4 if mode=='Move' else 64 if mode=='Sprint' else 1)
            offset=right*(sign*(2.8 if turning else 1.65))
            if turning:
                stage=bpy.data.objects.new('R10WH1_'+cat+'_'+label+'_Stage',None);s.collection.objects.link(stage);stage.location=offset
                path=bpy.data.objects.new('R10WH1_'+cat+'_'+label+'_Path',None);s.collection.objects.link(path);path.parent=stage;assign(path,bpy.data.actions[loc['imported_actions']['PREVIEW_ONLY_R3_Walk_Path']]);r.parent=path;r.matrix_parent_inverse=Matrix.Identity(4);r.location=(0,0,0)
            else:r.location=offset
            actors[label]={'rig':r.name,'mesh':m.name,'weapons':[w.name for w in ws],'upper':upper_name}
        if turning:
            inv=s.camera.rotation_euler.to_quaternion().inverted().to_matrix();lo=np.full(2,np.inf);hi=np.full(2,-np.inf)
            for f in range(1,N+1):
                s.frame_set(f);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
                for ob in [o for o in s.objects if o.type=='MESH']:
                    ev=ob.evaluated_get(dg);mesh=ev.to_mesh();pts=np.array([tuple(inv@(ev.matrix_world@v.co))[:2] for v in mesh.vertices]);ev.to_mesh_clear();lo=np.minimum(lo,pts.min(0));hi=np.maximum(hi,pts.max(0))
            aspect=1920/900;span=hi-lo;s.camera.data.ortho_scale=float(max(span[0],span[1]*aspect)*1.12);p=inv@s.camera.location;p.x=float((hi[0]+lo[0])/2);p.y=float((hi[1]+lo[1])/2);s.camera.location=inv.inverted()@p
        for label,sign in [('A',-1),('B',1)]:
            font=bpy.data.curves.new('R10WH1_Label','FONT');font.body='A  CURRENT R9-W4' if label=='A' else 'B  RIGHT PRIMARY / LEFT LIGHT SUPPORT';font.align_x='CENTER';font.size=.10 if not turning else .16;ob=bpy.data.objects.new(font.name,font);s.collection.objects.link(ob);ob.parent=s.camera;ob.location=(sign*(2.8 if turning else 1.65),s.camera.data.ortho_scale/(1920/900)/2-.17,-10);ob.rotation_euler=(0,0,0)
        s.frame_set(1);reviews[cat+'_'+mode]={'scene':s.name,'actors':actors,'frames':[1,N],'movie_frames':208 if mode=='Sprint' else N,'loop':mode not in ['Turn','Sprint'],'lower':lower_name,'camera_fit':'full trajectory / 12% margin' if turning else 'matched front 3/4','camera_scale':s.camera.data.ortho_scale}
design['reviews']=reviews;design['locomotion']=loc;(OUT/'design.json').write_text(json.dumps(design,indent=2));result={'reviews':len(reviews),'checkpoint':checkpoint()}
