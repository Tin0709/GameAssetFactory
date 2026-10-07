from hold_r10wh1_common import *
design={'primary_arm':'R','support_arm':'L','eye_local':list(EYE),'categories':{}}
for category in ['Rifle','Shotgun','Pistol']:
    s=scene('R10WH1_PROBE_'+category.upper());bpy.context.window.scene=s;r,m,ws=clone_r10('Probe_'+category,s,category)
    source=json.loads((BASE/'living_r9w4_review/design.json').read_text())['categories'][category];sample(r,s,bpy.data.actions['LongGunReady_LivingRef_V2'],1);base={n:r.pose.bones[n].matrix_basis.copy() for n in UPPER};socket=Matrix(source['socket'])
    body_pose(r,base,0,0,0,0);metrics=pose_hold(r,ws,socket,category)
    cameras={}
    for view,position,target in [('Front',(0,-5,1.35),(0,-.2,1.1)),('FrontThreeQuarter',(-3,-5,2.6),(0,-.2,1.1)),('Side',(-5,-.2,1.8),(0,-.2,1.1)),('Rear',(3,5,2.8),(0,-.2,1.1))]:cameras[view]=camera(s,'R10WH1_'+category+'_'+view,position,target,2.65).name
    s.render.resolution_x=800;s.render.resolution_y=700;s.render.resolution_percentage=100;s.eevee.taa_render_samples=16
    for view in ['Front','FrontThreeQuarter','Side']:
        s.camera=bpy.data.objects[cameras[view]];s.render.filepath=str(OUT/(category+'_initial_'+view+'.png'));bpy.ops.render.render(write_still=True)
    boxes=boxes_for(r,m,.005);metrics['head']=triangle_box(r,ws,'Head',boxes['Head']);metrics['chest']=triangle_box(r,ws,'Chest',boxes['Chest'])
    design['categories'][category]={'scene':s.name,'rig':r.name,'mesh':m.name,'weapons':[w.name for w in ws],'socket':[list(row) for row in socket],'base':{n:[list(row) for row in mat] for n,mat in base.items()},'cameras':cameras,'initial_metrics':metrics,'baseline_actions':source['actions'],'baseline_turn':source['turn_response_action']}
(OUT/'design.json').write_text(json.dumps(design,indent=2));result={c:v['initial_metrics'] for c,v in design['categories'].items()}
