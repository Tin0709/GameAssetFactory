from hold_r10wh2_common import *
old=json.loads((BASE/'weapon_hold_r10wh1_review/design.json').read_text());design={'categories':{},'locomotion':old['locomotion']}
for cat in ['Pistol','Rifle','Shotgun']:
    name='R10WH2_PROBE_'+cat.upper();assert name not in bpy.data.scenes
    s=scene(name);bpy.context.window.scene=s;r,m,ws=clone_wh2('Probe_'+cat,s,cat);source=old['categories'][cat];sample(r,s,bpy.data.actions[source['actions']['Hold']],25)
    cameras={view:camera(s,'R10WH2_'+cat+'_'+view,pos,target,2.65).name for view,pos,target in [('Front',(0,-5,1.35),(0,-.2,1.1)),('FrontThreeQuarter',(-3,-5,2.6),(0,-.2,1.1)),('Side',(-5,-.2,1.8),(0,-.2,1.1)),('Rear',(3,5,2.8),(0,-.2,1.1))]}
    s.render.resolution_x=800;s.render.resolution_y=700;s.render.resolution_percentage=100;s.eevee.taa_render_samples=16
    for label in ['A','B']:
        if label=='B':assign(r,None);metrics=refine_arms(r,ws,cat,.09,.09*math.sin(math.pi/2-2*math.pi*3/96))
        for view in ['Front','FrontThreeQuarter','Side']:
            s.camera=bpy.data.objects[cameras[view]];s.render.filepath=str(OUT/f'{cat}_probe_{label}_{view}.png');bpy.ops.render.render(write_still=True)
    design['categories'][cat]={'scene':s.name,'rig':r.name,'mesh':m.name,'weapons':[w.name for w in ws],'cameras':cameras,'baseline_actions':source['actions'],'baseline_turn':source['turn_action'],'probe_metrics':metrics}
(OUT/'design.json').write_text(json.dumps(design,indent=2));result={cat:row['probe_metrics'] for cat,row in design['categories'].items()}
