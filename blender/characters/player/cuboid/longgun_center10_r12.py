import importlib,locomotion_sway_r12_common
importlib.reload(locomotion_sway_r12_common)
from locomotion_sway_r12_common import *

d=json.loads((R12OUT/'design.json').read_text());assert not d.get('longgun_center_extra10')
before={a.name:digest(a) for a in bpy.data.actions};checks={}
for key,v in list(d['scenes'].items())+[('Hold',d['idle'])]:
    sc=bpy.data.scenes[v['scene']];bpy.context.window.scene=sc
    for kind in ['Rifle','Shotgun']:
        actor=v['actors'][kind];rig=bpy.data.objects[actor['rig']]
        sc.frame_set(v['frame_start']);bpy.context.view_layer.update()
        main=next(bpy.data.objects[n] for n in actor['weapons'] if '_Base' in n)
        chest=(rig.matrix_world@rig.pose.bones['Chest'].matrix).inverted()
        old_pos=chest@main.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world.translation
        old=bpy.data.actions[actor['upper']];new=old.copy();new.name=old.name+'_Center10';new.use_fake_user=True
        pb=rig.pose.bones['WeaponCarrier'];rest=pb.parent.bone.matrix_local.inverted()@pb.bone.matrix_local
        delta=rest.to_3x3().inverted()@Vector((.0015,0,0))
        for fc in curves(new):
            if '"WeaponCarrier"' in fc.data_path and fc.data_path.endswith('location'):
                for k in fc.keyframe_points:
                    k.co.y+=delta[fc.array_index];k.handle_left.y+=delta[fc.array_index];k.handle_right.y+=delta[fc.array_index]
                fc.update()
        def non_carrier(a):return [(fc.data_path,fc.array_index,[tuple(k.co) for k in fc.keyframe_points]) for fc in curves(a) if '"WeaponCarrier"' not in fc.data_path]
        assert non_carrier(old)==non_carrier(new)
        assign(rig,new);actor['upper']=new.name;sc.frame_set(v['frame_start']);bpy.context.view_layer.update()
        new_pos=chest@main.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world.translation
        move=new_pos-old_pos
        assert abs(move.x-.0015)<1e-5 and abs(move.y)<1e-5 and abs(move.z)<1e-5
        checks[key+'_'+kind]={'chest_space_shift_m':list(move),'arm_body_curves_unchanged':True}
assert all(digest(bpy.data.actions[n])==h for n,h in before.items())
d['longgun_center_extra10']={'previous_inward_m':.015,'new_inward_m':.0165,'additional_inward_m':.0015,'forward_change_m':0,'height_change_m':0,'checks':checks}
d['long_gun_horizontal_only']={'inward_m':.0165,'forward_m':0,'up_m':0}
(R12OUT/'design.json').write_text(json.dumps(d,indent=2));result=d['longgun_center_extra10']
