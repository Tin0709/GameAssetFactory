"""Prepare three weapon probes inside the versioned live Blender W4 copy."""
from onearm_r9w4_common import *
assert Path(bpy.data.filepath).name=='player_weapon_onearm_r9w4_study.blend'
assert not bpy.data.scenes.get('R9W4_ASSETS')
assets_scene=bpy.data.scenes.new('R9W4_ASSETS');assets={}
for category in ['Pistol','Shotgun']:
    p=ROOT/'blender/weapons'/category.lower()/('blocky_'+category.lower()+'_v4.blend')
    with bpy.data.libraries.load(str(p),link=False) as (src,dst):
        dst.objects=[n for n in src.objects if n in ['Grip_Point','Support_Hand_Point','Muzzle_Point','Shotgun_Pump','Blocky_'+category+'_Root','Blocky_'+category+'_Base']]
    assets[category]=list(dst.objects)
    for ob in assets[category]:assets_scene.collection.objects.link(ob);ob.name='R9W4_Asset_'+category+'_'+ob.name

design={'primary_arm':'L','off_arm':'R','reference':'provided_crossbow_reference.png','categories':{}}
for category in ['Rifle','Pistol','Shotgun']:
    s=scene('R9W4_PROBE_'+category.upper());bpy.context.window.scene=s
    r,m,weapons=clone_actor('Probe_'+category,s,category,assets)
    sample(r,s,bpy.data.actions['LongGunReady_LivingRef_V2'],1)
    gm=weapons[0].evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world.copy();socket=r.pose.bones['WeaponCarrier'].matrix.inverted()@gm
    # Same front / side / rear projections for each weapon and A/B render.
    cameras={}
    for view,position,target in [('Front',(-3,-5,3.4),(0,-.2,1)),('Side',(-5,-.25,1.9),(0,-.2,1)),('Rear',(3,5,3.2),(0,-.2,1))]:
        cameras[view]=camera(s,'R9W4_'+category+'_'+view,position,target,3.4).name
    s.camera=bpy.data.objects[cameras['Front']]
    boxes=boxes_for(r,m);assign(r,None)
    probe=configure_pose(r,weapons,socket,category)
    metrics={'off_terminal':triangle_box(r,weapons,'ForeArm.R',TERMINAL),'support_terminal':triangle_box(r,weapons,'ForeArm.L',TERMINAL),'off_forearm':triangle_box(r,weapons,'ForeArm.R',boxes['ForeArm.R']),'head':triangle_box(r,weapons,'Head',boxes['Head']),'chest':triangle_box(r,weapons,'Chest',boxes['Chest'])}
    design['categories'][category]={'scene':s.name,'rig':r.name,'mesh':m.name,'weapons':[w.name for w in weapons],'socket':[list(row) for row in socket],'cameras':cameras,'config':dict(CONFIG[category]),'initial_metrics':metrics}
(OUT/'design.json').write_text(json.dumps(design,indent=2))
result={'probes':{k:v['initial_metrics'] for k,v in design['categories'].items()}}
