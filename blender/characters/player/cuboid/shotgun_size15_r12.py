import importlib,locomotion_sway_r12_common
importlib.reload(locomotion_sway_r12_common)
from locomotion_sway_r12_common import *
d=json.loads((R12OUT/'design.json').read_text());assert not d.get('shotgun_extra_size15')
before={a.name:digest(a) for a in bpy.data.actions}
scenes=list(d['scenes'].items())+[('Hold',d['idle'])];checks={}
for key,v in scenes:
    actor=v['actors']['Shotgun'];sc=bpy.data.scenes[v['scene']];bpy.context.window.scene=sc
    rig=bpy.data.objects[actor['rig']];sc.frame_set(v['frame_start']);bpy.context.view_layer.update()
    ws=[bpy.data.objects[n] for n in actor['weapons']];main=next(w for w in ws if '_Base' in w.name);root=main.parent
    boxes=boxes_for(rig,bpy.data.objects[actor['mesh']]);old_gap=triangle_box(rig,ws,'Head',boxes['Head'])['gap_lower_m'];old_scale=root.scale.copy()
    old=bpy.data.actions[actor['upper']];new=old.copy();new.name=old.name+'_Size15';new.use_fake_user=True
    pb=rig.pose.bones['WeaponCarrier'];rest=pb.parent.bone.matrix_local.inverted()@pb.bone.matrix_local
    delta=rest.to_3x3().inverted()@Vector((0,0,SHOTGUN_FIXED_BACK_ADVANCE))
    for fc in curves(new):
        if '"WeaponCarrier"' in fc.data_path and fc.data_path.endswith('location'):
            for k in fc.keyframe_points:
                k.co.y+=delta[fc.array_index];k.handle_left.y+=delta[fc.array_index];k.handle_right.y+=delta[fc.array_index]
            fc.update()
    def non_carrier(a):
        return [(fc.data_path,fc.array_index,[tuple(k.co) for k in fc.keyframe_points]) for fc in curves(a) if '"WeaponCarrier"' not in fc.data_path]
    assert non_carrier(new)==non_carrier(old), 'Approved arm/body motion changed'
    root.scale=old_scale*SHOTGUN_EXTRA_SCALE;assign(rig,new);actor['upper']=new.name
    sc.frame_set(v['frame_start']);bpy.context.view_layer.update();new_gap=triangle_box(rig,ws,'Head',boxes['Head'])['gap_lower_m']
    checks[key]={'scale_ratio_xyz':[root.scale[i]/old_scale[i] for i in range(3)],'old_head_gap_m':old_gap,'new_head_gap_m':new_gap,'approved_arm_body_curves_identical':True}
    assert abs(new_gap-old_gap)<1e-5 and new_gap>.025
assert all(digest(bpy.data.actions[n])==h for n,h in before.items())
d['shoulder_fit']['human_approved']=True;d['shoulder_fit']['status']='wrapped up; unchanged during shotgun resize'
d['shotgun_extra_size15']={'multiplier':SHOTGUN_EXTRA_SCALE,'pivot':'rear stock face held in place; enlargement extends forward','checks':checks,'scope':'study only'}
(R12OUT/'design.json').write_text(json.dumps(d,indent=2));result=d['shotgun_extra_size15']
