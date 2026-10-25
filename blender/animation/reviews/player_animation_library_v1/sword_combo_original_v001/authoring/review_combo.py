"""Reopen/evaluate/render the new source; never alter approved library data."""
import bpy,json,math,sys
from pathlib import Path
from mathutils import Vector,Matrix

OUT=Path(__file__).resolve().parent.parent
ROOT=OUT.parents[4]
sys.path.insert(0,str(ROOT/'blender/animation/showcase'))
import gaf_animation_library as ui
sys.path.insert(0,str(Path(__file__).resolve().parent))
from build_combo import foot_design

scene=bpy.context.scene
if scene.name!='SWORD_COMBO_ORIGINAL_REVIEW':
    scene=bpy.data.scenes['SWORD_COMBO_ORIGINAL_REVIEW'];bpy.context.window.scene=scene
rig=bpy.data.objects['SC_Player_Rig'];mesh=bpy.data.objects['SC_Player_Mesh']
sword=bpy.data.objects['Sword_Sand_Block_V1']
action=bpy.data.actions['Sword_Combo_Original_v001']
rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]


def frame_set(frame):
    scene.frame_set(int(frame),subframe=frame-int(frame))
    bpy.context.view_layer.update()


def vertex_ids(names):
    groups={g.index:g.name for g in mesh.vertex_groups}
    return [v.index for v in mesh.data.vertices if any(groups[g.group] in names and g.weight>.999 for g in v.groups)]


def validate():
    groups={g.name:len(vertex_ids({g.name})) for g in mesh.vertex_groups}
    limbs={side:vertex_ids({'UpperArm.'+side,'ForeArm.'+side}) for side in ['L','R']}
    legs={side:vertex_ids({'Leg.'+side}) for side in ['L','R']}
    headids=vertex_ids({'Head'})
    headlo=Vector(tuple(min(mesh.data.vertices[i].co[a] for i in headids) for a in range(3)))
    headhi=Vector(tuple(max(mesh.data.vertices[i].co[a] for i in headids) for a in range(3)))
    bpy.context.view_layer.update()
    sword_meshes=[o for o in scene.objects if o.type=='MESH' and o.parent==sword]
    blades=[o for o in sword_meshes if 'Blade' in o.name]
    grip_reference=None;max_grip=0.;max_grip_angle=0.;min_floor=99.;max_floor_error=0.;max_rigidity=0.;max_leg_join=0.
    head_intersections=[];positions=[];max_scale=0.;max_orientation_step=0.;prev_orientation=None
    for j in range(481):
        f=1+j/8;frame_set(f)
        deps=bpy.context.evaluated_depsgraph_get()
        evaluated=mesh.evaluated_get(deps);geo=evaluated.to_mesh()
        # Exact expected rigid arm transform, including the ForeArm helper.
        for side,ids in limbs.items():
            transform=rig.pose.bones['UpperArm.'+side].matrix@rig.data.bones['UpperArm.'+side].matrix_local.inverted()
            for i in ids:
                error=(geo.vertices[i].co-transform@mesh.data.vertices[i].co).length
                max_rigidity=max(max_rigidity,error)
        feet=foot_design(f)
        for side,ids in legs.items():
            z=min(geo.vertices[i].co.z for i in ids);min_floor=min(min_floor,z)
            max_floor_error=max(max_floor_error,abs(z-(.0006+feet[side][1])))
            b=rig.pose.bones['Leg.'+side];h=rig.pose.bones['Hips']
            socket=h.matrix@(h.bone.matrix_local.inverted()@b.bone.head_local)
            max_leg_join=max(max_leg_join,(b.head-socket).length)
        arm=rig.pose.bones['UpperArm.R']
        relative=arm.matrix.inverted()@sword.matrix_world
        if grip_reference is None:grip_reference=relative.copy()
        max_grip=max(max_grip,(relative.translation-grip_reference.translation).length)
        max_grip_angle=max(max_grip_angle,relative.to_quaternion().rotation_difference(grip_reference.to_quaternion()).angle)
        head_transform=rig.pose.bones['Head'].matrix@rig.data.bones['Head'].matrix_local.inverted()
        inv=head_transform.inverted()
        for ob in blades:
            for v in ob.data.vertices:
                p=inv@(ob.matrix_world@v.co)
                if all(headlo[a]+.002<p[a]<headhi[a]-.002 for a in range(3)):
                    head_intersections.append({'frame':f,'object':ob.name});break
        for b in rig.pose.bones:max_scale=max(max_scale,max(abs(x-1) for x in b.scale))
        q=sword.matrix_world.to_quaternion()
        if prev_orientation is not None:max_orientation_step=max(max_orientation_step,prev_orientation.rotation_difference(q).angle)
        prev_orientation=q
        positions.append({'frame':f,'grip':list(sword.matrix_world.translation),'tip':list(sword.matrix_world@Vector((0,.96292,0)))})
        evaluated.to_mesh_clear()
    # Endpoints settle to the same pose; this is a nonloop attack, not a gait clip.
    frame_set(1);start={b.name:b.matrix.copy() for b in rig.pose.bones}
    frame_set(61);endpoint=max(abs(b.matrix[i][k]-start[b.name][i][k]) for b in rig.pose.bones for i in range(4) for k in range(4))
    ui.validate_action(action,{'start':1,'end':61,'fps':30,'fps_base':1.,'rotation_modes':{b.name:b.rotation_mode for b in rig.pose.bones},'slot_identifier':action.slots[0].identifier,'action_sha256':ui.action_signature(action),'action_frame_range':list(action.frame_range)},rig)
    report={'action':action.name,'status':'pending','samples':481,'fps_checks':[30,60],'groups':groups,
      'minimum_sole_z_m':min_floor,'max_sole_height_error_m':max_floor_error,
      'max_straight_arm_rigidity_error_m':max_rigidity,'max_palm_grip_translation_error_m':max_grip,
      'max_palm_grip_rotation_error_rad':max_grip_angle,'max_leg_socket_distance_m':max_leg_join,
      'head_intersection_samples':head_intersections[:20],'max_scale_error':max_scale,
      'maximum_sword_orientation_delta_per_240fps_sample_rad':max_orientation_step,
      'endpoint_matrix_error':endpoint,'rig_rest_signature':ui.rest_signature(rig.data),
      'checks':{'ground_contact':min_floor>=-.001 and max_floor_error<.0015,
       'rigid_straight_arms':max_rigidity<2e-5,'fixed_grip':max_grip<2e-5 and max_grip_angle<.001,
       'unit_scale':max_scale<1e-6,'blade_clears_head':not head_intersections,
       'connected_leg_sockets':max_leg_join<.075,'quiet_compatible_guard_endpoints':endpoint<1e-5,
       'no_rig_constraints':all(not b.constraints for b in rig.pose.bones),'no_object_root_motion':all(abs(x)<1e-7 for x in rig.location)}}
    report['passed']=all(report['checks'].values())
    (OUT/'geometry_validation.json').write_text(json.dumps(report,indent=2)+'\n')
    (OUT/'blade_samples.json').write_text(json.dumps(positions,separators=(',',':'))+'\n')
    print('SWORD_GEOMETRY',json.dumps(report),flush=True)
    if not report['passed']:raise RuntimeError('Sword geometry checks need refinement; inspect geometry_validation.json')


def poses():
    folder=OUT/'review';folder.mkdir(exist_ok=True)
    for view,frames in [('THREE_QUARTER',[1,6,10,13,21,25,29,37,43,46,59]),('FRONT',[10,25,43]),('SIDE',[10,25,43])]:
        scene.camera=bpy.data.objects['SC_'+view]
        for f in frames:
            frame_set(f);scene.render.image_settings.file_format='PNG';scene.render.filepath=str(folder/f'{view.lower()}_{f:03d}.png')
            bpy.ops.render.render(write_still=True,scene=scene.name)
    print('SWORD_POSES_RENDERED',flush=True)


def videos():
    folder=OUT/'review';folder.mkdir(exist_ok=True)
    scene.render.image_settings.file_format='FFMPEG'
    scene.render.ffmpeg.format='MPEG4';scene.render.ffmpeg.codec='H264'
    scene.render.ffmpeg.constant_rate_factor='HIGH';scene.render.ffmpeg.ffmpeg_preset='GOOD'
    scene.frame_start=1;scene.frame_end=61;scene.render.fps=30
    for view in ['THREE_QUARTER','FRONT','SIDE']:
        scene.camera=bpy.data.objects['SC_'+view];scene.render.filepath=str(folder/f'sword_combo_{view.lower()}_30fps_1x.mp4')
        bpy.ops.render.render(animation=True,scene=scene.name)
    print('SWORD_VIDEOS_RENDERED_1X',flush=True)


mode=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'validate'
{'validate':validate,'poses':poses,'videos':videos}[mode]()
