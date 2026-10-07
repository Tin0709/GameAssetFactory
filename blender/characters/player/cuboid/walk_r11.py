from hold_r11_common import *
design=json.loads((OUT/'design.json').read_text());walks={}
for cat in ['Pistol','Rifle','Shotgun']:
    s=studio('R11_WALK_'+cat.upper());s.render.resolution_x=850;s.render.resolution_y=800;s.frame_end=64
    r,m,ws=clone_r11('Walk_'+cat,s,cat)
    approved=bpy.data.objects[design['categories'][cat]['mesh']]
    assert [v.name for v in m.vertex_groups]==[v.name for v in approved.vertex_groups]
    m.data=approved.data.copy() # Preserve the current slim-arm study in each walking view.
    upper=bpy.data.actions[design['categories'][cat]['actions']['Move']];lower=bpy.data.actions[design['locomotion']['lower_copies']['Walk']]
    compose(r,upper,lower,4);s.camera=camera(s,'R11_Walk_'+cat+'_Camera',(3,-5,3),(0,-.25,1.1),2.65);s.frame_set(1)
    walks[cat]={'scene':s.name,'actors':{cat:{'rig':r.name,'mesh':m.name,'weapons':[w.name for w in ws],'upper':upper.name}},'frames':64,'lower':lower.name,'loop':True,'gait':'Walk'}
design['walking']=walks;(OUT/'design.json').write_text(json.dumps(design,indent=2));result={'walking_only':list(walks),'source_gait':lower.name}
