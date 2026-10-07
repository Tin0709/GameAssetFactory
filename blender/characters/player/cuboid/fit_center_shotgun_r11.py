"""Move long guns inward slightly; enlarge shotgun 30% without face penetration."""
import importlib,hold_r11_common
importlib.reload(hold_r11_common)
from hold_r11_common import *

design=json.loads((OUT/'design.json').read_text())
assert 'center_shotgun_fit' not in design
(OUT/'center_shotgun_before.json').write_text(json.dumps(design,indent=2))
preserved={a.name:digest(a) for a in bpy.data.actions}
for cat in ['Rifle','Shotgun']:
    c=design['categories'][cat];rig=bpy.data.objects[c['rig']]
    pb=rig.pose.bones['WeaponCarrier']
    rest=pb.parent.bone.matrix_local.inverted()@pb.bone.matrix_local
    change=rest.to_3x3().inverted()@Vector((.015,0,.115 if cat=='Shotgun' else 0))
    for mode,old_name in list(c['actions'].items()):
        old=bpy.data.actions[old_name];new=old.copy()
        new.name=old_name+'_CenterFitR11';new.use_fake_user=True
        for fc in curves(new):
            if '"WeaponCarrier"' in fc.data_path and fc.data_path.endswith('location'):
                delta=change[fc.array_index]
                for k in fc.keyframe_points:
                    k.co.y+=delta;k.handle_left.y+=delta;k.handle_right.y+=delta
                fc.update()
        c['actions'][mode]=new.name
    actors=[c,design['walking'][cat]['actors'][cat]]+[v['actors'][cat] for v in design['showcases'].values()]
    for actor in actors:
        base=next(bpy.data.objects[n] for n in actor['weapons'] if '_Base' in n)
        base.parent.scale=STUDY_GUN_SCALE[cat]
    for mode,v in design['showcases'].items():
        actor=v['actors'][cat];name=c['actions']['Move' if mode=='Turn' else mode]
        assign(bpy.data.objects[actor['rig']],bpy.data.actions[name]);actor['upper']=name
    actor=design['walking'][cat]['actors'][cat]
    assign(bpy.data.objects[actor['rig']],bpy.data.actions[c['actions']['Move']]);actor['upper']=c['actions']['Move']
    sc=bpy.data.scenes[c['scene']];bpy.context.window.scene=sc
    sample(rig,sc,bpy.data.actions[c['actions']['Hold']],25)
    base=next(bpy.data.objects[n] for n in c['weapons'] if '_Base' in n)
    gm=rig.matrix_world.inverted()@base.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world
    c['socket']=list(map(list,rig.pose.bones['WeaponCarrier'].matrix.inverted()@gm))
    c['study_weapon_scale']=list(STUDY_GUN_SCALE[cat]);c['gun_offset_character_right_m']=GUN_RIGHT[cat]
    c['gun_offset_forward_up_m']=list(GUN_OFFSET[cat]);design['walk_sway']['actions'][cat]=c['actions']['Move']
assert all(digest(bpy.data.actions[name])==value for name,value in preserved.items())
design['center_shotgun_fit']={'inward_change_m':.015,'shotgun_size_multiplier':1.30,'shotgun_forward_clearance_adjustment_m':.115,'production_migration':False}
(OUT/'design.json').write_text(json.dumps(design,indent=2))
(OUT/'center_shotgun_source_action_hashes.json').write_text(json.dumps(preserved,indent=2))
result=design['center_shotgun_fit']
