"""Live, additive Jump + Jump Land study; never reload or rebuild the library."""
import bpy
import hashlib
import importlib.util
import json
import math
from pathlib import Path
from mathutils import Euler, Matrix, Vector

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[4]
TMP = ROOT / '.validation' / 'jump_dungeons_gif_v004'
LIBRARY = OUT.parent / 'player_animation_library_v1.blend'
SCENE = 'JGIF4_JUMP_LAND_REVIEW'
ACTION = 'Jump_DungeonsII_Combined_v004'
END, TAKE, CONTACT, HEIGHT = 36, 6, 23, .62


def curves(action):
    return [c for layer in action.layers for strip in layer.strips
            for bag in strip.channelbags for c in bag.fcurves]


def signature(action):
    values = [(c.data_path, c.array_index,
               [(tuple(k.co), tuple(k.handle_left), tuple(k.handle_right), k.interpolation,
                 k.handle_left_type, k.handle_right_type) for k in c.keyframe_points],
               [(m.type, m.mode_before, m.mode_after) if m.type == 'CYCLES' else (m.type,)
                for m in c.modifiers]) for c in curves(action)]
    return hashlib.sha256(repr(values).encode()).hexdigest()


def original_data():
    helper = ROOT / 'blender/environment/studies/dungeons_ground_style_v2/flower_preservation.py'
    spec = importlib.util.spec_from_file_location('jgif4_preservation', helper)
    p = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(p)
    snapshot = p.snapshot()
    # Object dimensions and pose values are dependency-graph outputs. Protect the
    # actual authored mesh/rest/material/action data instead of cached bounds.
    snapshot.pop('objects')
    snapshot.pop('scenes')
    snapshot['actions'] = {a.name: signature(a) for a in bpy.data.actions}
    snapshot['armatures'] = {a.name: p.digest([(b.name, b.parent.name if b.parent else None,
        [list(r) for r in b.matrix_local], b.use_deform) for b in a.bones]) for a in bpy.data.armatures}
    snapshot['weights'] = {m.name: p.digest([[(w.group, w.weight) for w in v.groups] for v in m.vertices])
                           for m in bpy.data.meshes}
    snapshot['texts'] = {t.name: p.digest(t.as_string()) for t in bpy.data.texts}
    snapshot['timing'] = {s.name: [s.render.fps, s.render.fps_base, s.frame_start, s.frame_end]
                          for s in bpy.data.scenes}
    return snapshot


def compare_originals(before):
    after = original_data()
    return [(group, name) for group, data in before.items() for name, value in data.items()
            if after[group].get(name) != value]


def point_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()


def pose_keys():
    # Authored adaptation of the two GIF silhouettes to the existing rigid legs.
    # lean, twist, head, right/left leg, right pitch/spread, left pitch/spread, elbows
    return {
        1: (0,0,0, 0,0, 0,0,0,0, 0,0),
        2: (0,0,0, 0,0, 0,0,0,0, 0,0),
        4: (16,-2,-9, 28,28, -24,-12,-20,12, 10,8),
        6: (10,-1,-7, 14,14, -10,-16,-8,17, 10,9),
        8: (24,-3,-12, 28,12, -24,-20,-16,22, 8,8),
        10:(14,1,-7, 36,-10, 15,-25,-12,26, 10,8),
        13:(7,4,-4, 45,-22, 68,-34,16,31, 8,10),
        16:(6,5,-4, 46,-24, 76,-36,28,33, 8,10),
        18:(7,3,-4, 42,-19, 72,-34,25,32, 8,10),
        20:(11,1,-5, 32,-4, 44,-27,15,26, 12,10),
        22:(16,0,-6, 19,10, 10,-14,2,17, 10,8),
        23:(18,-1,-6, 18,18, -5,-10,-6,12, 10,8),
        25:(24,-1,-9, 31,31, -14,-12,-13,13, 14,12),
        28:(12,0,-7, 13,13, -9,-8,-7,9, 9,7),
        30:(4,0,-3, 3,3, -3,-4,-2,5, 4,3),
        32:(0,0,0, 0,0, 0,0,0,0, 0,0),
        35:(0,0,0, 0,0, 0,0,0,0, 0,0),
        36:(0,0,0, 0,0, 0,0,0,0, 0,0),
    }


def animate_pose(rig, idle):
    action = bpy.data.actions.new(ACTION)
    action.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = action
    for frame, values in pose_keys().items():
        lean, twist, head, right, left, rp, rs, lp, ls, re, le = values
        rotations = {'Spine':(lean*.35,0,0), 'Chest':(lean*.65,twist,0),
            'Head':(head,-twist*.4,0), 'Leg.R':(right,0,0), 'Leg.L':(left,0,0),
            'UpperArm.R':(rp,0,rs), 'UpperArm.L':(lp,0,ls),
            'ForeArm.R':(re,0,0), 'ForeArm.L':(le,0,0)}
        for name, angles in rotations.items():
            bone = rig.pose.bones[name]
            bone.location = idle[name]['location']
            if name.startswith('UpperArm') and 2 <= frame <= 32:
                bone.location.x += -.008 if name.endswith('.L') else .008
            rotation = Euler(tuple(math.radians(x) for x in angles),
                             'ZXY' if name.startswith('UpperArm') else 'XYZ')
            if bone.rotation_mode == 'QUATERNION':
                bone.rotation_quaternion = rotation.to_quaternion()
                prop = 'rotation_quaternion'
            else:
                bone.rotation_euler = rotation
                prop = 'rotation_euler'
            bone.keyframe_insert(prop, frame=frame, group=name)
            if name.startswith('UpperArm'):
                bone.keyframe_insert('location', frame=frame, group=name)
    for curve in curves(action):
        curve.extrapolation = 'CONSTANT'
        for key in curve.keyframe_points:
            key.interpolation = 'BEZIER'
            key.handle_left_type = key.handle_right_type = 'AUTO_CLAMPED'
    return action


def animate_carrier(scene, mesh, carrier):
    right = mesh.vertex_groups['Leg.R'].index
    soles = [v.index for v in mesh.data.vertices if abs(v.co.z) < 1e-5]
    right_sole = [v.index for v in mesh.data.vertices if abs(v.co.z) < 1e-5 and
                  any(w.group == right and w.weight > .99 for w in v.groups)]
    samples = []
    density = 64
    for n in range((END-1)*density+1):
        f = 1+n/density
        scene.frame_set(int(f), subframe=f%1)
        bpy.context.view_layer.update()
        evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
        points = [evaluated.matrix_world @ v.co for v in evaluated.data.vertices]
        samples.append((f, -min(points[i].z for i in soles)+.0003,
                        -sum(points[i].y for i in right_sole)/len(right_sole)))
    launch = samples[(TAKE-1)*density]
    contact = samples[(CONTACT-1)*density]
    travel = bpy.data.actions.new('PREVIEW_ONLY_' + ACTION + '_Travel')
    travel.use_fake_user = True
    carrier.animation_data_create()
    carrier.animation_data.action = travel
    for f, support, support_y in samples:
        if TAKE < f < CONTACT:
            u = (f-TAKE)/(CONTACT-TAKE)
            z = (1-u)*launch[1] + u*contact[1] + 4*HEIGHT*u*(1-u)
            # Only support alignment, not a locomotion speed or game trajectory.
            smooth = u*u*(3-2*u)
            y = (1-smooth)*launch[2] + smooth*contact[2]
        else:
            z, y = support, support_y
        carrier.location = (0,y,z)
        carrier.keyframe_insert('location', index=1, frame=f, group='PREVIEW ONLY / SUPPORT')
        carrier.keyframe_insert('location', index=2, frame=f, group='PREVIEW ONLY / ARC + SUPPORT')
    for curve in curves(travel):
        for key in curve.keyframe_points:
            key.interpolation = 'LINEAR'
    return {'density': density, 'margin_m': .0003, 'launch_z':launch[1], 'contact_z':contact[1]}


def build():
    assert not bpy.app.background
    assert Path(bpy.data.filepath).resolve() == LIBRARY.resolve()
    assert bpy.context.mode == 'OBJECT'
    assert not bpy.context.screen.is_animation_playing
    assert SCENE not in bpy.data.scenes and ACTION not in bpy.data.actions
    TMP.mkdir(parents=True, exist_ok=True)
    backup = TMP / 'live_before_jump_gif_v004.blend'
    assert not backup.exists(), 'Preserve an existing backup.'
    baseline = original_data()
    (TMP/'original_data.json').write_text(json.dumps(baseline, indent=2))
    bpy.app.driver_namespace['jgif4_original_data'] = baseline
    bpy.ops.wm.save_as_mainfile(filepath=str(backup), copy=True)
    assert Path(bpy.data.filepath).resolve() == LIBRARY.resolve()
    assert not compare_originals(baseline)
    template = bpy.data.scenes['JUMP_DEFAULT_V001_REVIEW']
    scene = bpy.data.scenes.new(SCENE)
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'GPU'
    scene.cycles.samples = 16
    scene.cycles.use_denoising = True
    scene.render.use_persistent_data = True
    scene.render.resolution_x = scene.render.resolution_y = 640
    scene.render.resolution_percentage = 100
    scene.render.fps = 30
    scene.render.fps_base = 1
    scene.frame_start, scene.frame_end = 1, END
    scene.render.image_settings.file_format = 'PNG'
    scene.render.use_motion_blur = False
    scene.world = template.world
    for name in ['view_transform','look','exposure','gamma']:
        setattr(scene.view_settings, name, getattr(template.view_settings,name))
    actor = bpy.data.collections.new('JGIF4_Actor')
    scene.collection.children.link(actor)
    carrier = bpy.data.objects.new('JGIF4_PREVIEW_ONLY_Carrier',None)
    actor.objects.link(carrier)
    carrier['purpose'] = 'Preview arc and sole support only; never export as pose/Root motion.'
    source = bpy.data.objects['JD1_Player_Rig']
    body = bpy.data.objects['JD1_Player_Mesh']
    rig = source.copy()
    rig.data = source.data.copy()
    rig.name = 'JGIF4_Player_Rig'
    rig.data.name = 'JGIF4_Player_RestRig'
    rig.animation_data_clear()
    rig.parent = carrier
    rig.matrix_parent_inverse = Matrix.Identity(4)
    actor.objects.link(rig)
    mesh = body.copy()
    mesh.name = 'JGIF4_Player_Mesh'
    mesh.parent = rig
    actor.objects.link(mesh)
    for modifier in mesh.modifiers:
        if modifier.type == 'ARMATURE':
            modifier.object = rig
    idle = json.loads((OUT.parent/'jump_default_v001/idle_baseline.json').read_text())
    for bone in rig.pose.bones:
        b = idle[bone.name]
        bone.location = b['location']
        bone.scale = b['scale']
        bone.rotation_mode = b['rotation_mode']
        bone.rotation_euler = b['rotation_euler']
        bone.rotation_quaternion = b['rotation_quaternion']
    for obj in [rig,mesh]:
        obj.hide_viewport = obj.hide_render = False
    for suffix in ['FixedFloor','Key','Fill','Rim']:
        obj = bpy.data.objects['JD1_'+suffix].copy()
        obj.name = 'JGIF4_'+suffix
        scene.collection.objects.link(obj)
    cameras = {}
    for direction, location in [('THREE_QUARTER',(3,-6,5.1)),('SIDE',(6,0,2.6)),
                                 ('FRONT',(0,-7,2.7)),('BACK',(0,7,2.7))]:
        data = bpy.data.cameras.new('JGIF4_'+direction)
        data.type = 'ORTHO'
        data.ortho_scale = 3.7
        camera = bpy.data.objects.new(data.name,data)
        scene.collection.objects.link(camera)
        camera.location = location
        point_at(camera,(0,-.08,1.16))
        cameras[direction] = camera.name
    scene.camera = bpy.data.objects[cameras['THREE_QUARTER']]
    scene['review_cameras'] = json.dumps(cameras)
    scene['jump_rig'], scene['jump_carrier'] = rig.name, carrier.name
    scene['jump_status'] = 'GIF Jump + Jump Land / Blender only / awaiting artistic review'
    bpy.context.window.scene = scene
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    action = animate_pose(rig,idle)
    support = animate_carrier(scene,mesh,carrier)
    markers = {1:'READY',4:'ANTICIPATE',6:'LAST SUPPORT / PUSH',8:'GIF JUMP ENTRY',
               14:'APEX / ASYMMETRIC SILHOUETTE',20:'BLEND INTO LAND',23:'FIRST CONTACT',
               25:'ABSORB / JUMP LAND',28:'RECOVER',32:'IDLE',36:'END / IDLE'}
    for frame,label in markers.items():
        scene.timeline_markers.new(label,frame=frame)
    library = bpy.data.scenes['PLAYER_ANIMATION_LIBRARY_V1']
    old_catalog = json.loads(library['review_catalog'])
    entry = {'id':'jump_dungeons_gif_v004','label':'Jump + Land / Dungeons GIF V004',
             'group':'Jump (study only)','scene':scene.name,'review_rig':rig.name,
             'review_carrier':carrier.name,'action':action.name,'start':1,'end':END,'fps':30,
             'duration_seconds':(END-1)/30,'review_note':'Combined Jump + Jump Land GIF study',
             'phase_note':'F6 push / F23 contact / F25 absorb',
             'carrier_note':'Pose separate from preview arc/support',
             'status':'Blender-only / awaiting user review'}
    assert not any(e['id']==entry['id'] for e in old_catalog)
    library['review_catalog'] = json.dumps(old_catalog+[entry])
    library['review_selected'] = entry['id']
    library.player_review_group = 'Jump (study only)'
    for window in bpy.context.window_manager.windows:
        if window.scene == scene:
            for area in window.screen.areas:
                if area.type == 'VIEW_3D':
                    space = area.spaces.active
                    space.use_local_camera = False
                    space.camera = scene.camera
                    space.region_3d.view_perspective = 'CAMERA'
                    space.region_3d.view_camera_zoom = 15
                    space.show_region_ui = True
                    space.overlay.show_overlays = False
                    space.shading.type = 'MATERIAL'
    scene.frame_set(14)
    changes = compare_originals(baseline)
    assert not changes,changes
    manifest = {'scene':scene.name,'rig':rig.name,'mesh':mesh.name,'carrier':carrier.name,
                'pose_action':action.name,'slot':rig.animation_data.action_slot.identifier,
                'travel_action':carrier.animation_data.action.name,'cameras':cameras,'markers':markers,
                'take':TAKE,'contact':CONTACT,'end':END,'height_m':HEIGHT,'fps':30,'support':support,
                'old_actions':len(baseline['actions']),'old_catalog':old_catalog,'entry':entry,
                'backup':str(backup),'status':'Blender only / awaiting user review / no runtime changes'}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
    return {k:manifest[k] for k in ['scene','pose_action','old_actions','take','contact','end','backup']}
