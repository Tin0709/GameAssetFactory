import importlib,locomotion_sway_r12_common
importlib.reload(locomotion_sway_r12_common)
from locomotion_sway_r12_common import *
d=json.loads((R12OUT/'design.json').read_text());assert not d.get('pistol_size30_lower')
before={a.name:digest(a) for a in bpy.data.actions};checks={}
for key,v in list(d['scenes'].items())+[('Hold',d['idle'])]:
    actor=v['actors']['Pistol'];sc=bpy.data.scenes[v['scene']];bpy.context.window.scene=sc;rig=bpy.data.objects[actor['rig']]
    sc.frame_set(v['frame_start']);bpy.context.view_layer.update();main=next(bpy.data.objects[n] for n in actor['weapons'] if '_Base' in n);root=main.parent;old_scale=root.scale.copy()
    chest=(rig.matrix_world@rig.pose.bones['Chest'].matrix).inverted();point=Vector((0,.10,.117))
    old_slide=chest@main.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world@point
    old=bpy.data.actions[actor['upper']];new=old.copy();new.name=old.name+'_Pistol30Low';new.use_fake_user=True
    pb=rig.pose.bones['WeaponCarrier'];rest=pb.parent.bone.matrix_local.inverted()@pb.bone.matrix_local;delta=rest.to_3x3().inverted()@Vector((0,-PISTOL_CARRIER_DROP,0))
    for fc in curves(new):
        if '"WeaponCarrier"' in fc.data_path and fc.data_path.endswith('location'):
            for k in fc.keyframe_points:
                k.co.y+=delta[fc.array_index];k.handle_left.y+=delta[fc.array_index];k.handle_right.y+=delta[fc.array_index]
            fc.update()
    def non_carrier(a):return [(fc.data_path,fc.array_index,[tuple(k.co) for k in fc.keyframe_points]) for fc in curves(a) if '"WeaponCarrier"' not in fc.data_path]
    assert non_carrier(old)==non_carrier(new)
    root.scale=old_scale*PISTOL_EXTRA_SCALE;assign(rig,new);actor['upper']=new.name;sc.frame_set(v['frame_start']);bpy.context.view_layer.update()
    new_slide=chest@main.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world@point
    slide_drop=old_slide.y-new_slide.y;assert abs(slide_drop-.02)<1e-4
    checks[key]={'scale_ratio_xyz':[root.scale[i]/old_scale[i] for i in range(3)],'slide_height_drop_m':slide_drop,'approved_arm_body_curves_identical':True}
assert all(digest(bpy.data.actions[n])==h for n,h in before.items())
d['pistol_size30_lower']={'multiplier':1.30,'slide_height_lower_m':.02,'carrier_drop_m':PISTOL_CARRIER_DROP,'checks':checks,'primary_hand':'RIGHT only'}
(R12OUT/'design.json').write_text(json.dumps(d,indent=2));result=d['pistol_size30_lower']
