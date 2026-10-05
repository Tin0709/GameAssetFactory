"""Blender background export; source blends are never saved or modified on disk."""
import bpy, json, hashlib, struct, shutil
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'game_mobile_3d/assets/characters'
records = []
for kind in ('Player', 'Zombie'):
    source = ROOT / f'blender/animation_v2/{kind.lower()}_animation_v2.blend'
    sha = hashlib.sha256(source.read_bytes()).hexdigest()
    bpy.ops.wm.open_mainfile(filepath=str(source))
    rig = bpy.data.objects[kind + '_Cuboid_Rig']
    mesh = bpy.data.objects[kind + '_Cuboid_Base']
    # Reconstruct absolute recoil from its Euler-delta authoring representation.
    # Godot then subtracts the imported reference translation and composes
    # inverse(reference quaternion) * recoil quaternion, never Euler deltas.
    for action in bpy.data.actions:
        if not action.name.endswith('_Recoil'): continue
        reference = bpy.data.actions[action['reference_pose']]
        curves = reference.layers[0].strips[0].channelbags[0].fcurves
        base = {(c.data_path, c.array_index): c.evaluate(1) for c in curves}
        # Unkeyed chest/head in held pose use authored Idle at time zero.
        idle = bpy.data.actions['Player_Idle']
        for c in idle.layers[0].strips[0].channelbags[0].fcurves:
            base.setdefault((c.data_path, c.array_index), c.evaluate(1))
        for c in action.layers[0].strips[0].channelbags[0].fcurves:
            offset = base.get((c.data_path, c.array_index), 0.0)
            for key in c.keyframe_points: key.co.y += offset
    rig.animation_data.action = None
    for bone in rig.pose.bones:
        bone.location = (0,0,0); bone.rotation_euler = (0,0,0); bone.scale = (1,1,1)
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True); mesh.select_set(True); bpy.context.view_layer.objects.active = rig
    path = OUT / f'{kind.lower()}_animation_v2.glb'
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
        export_animations=True, export_animation_mode='ACTIONS', export_frame_range=False,
        export_force_sampling=True, export_anim_slide_to_zero=True, export_def_bones=False,
        export_rest_position_armature=True, export_reset_pose_bones=True,
        export_anim_single_armature=True, export_cameras=False, export_lights=False,
        export_morph=False)
    raw = path.read_bytes(); size = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20+size])
    names = [a['name'] for a in doc['animations']]
    assert len(names) == (15 if kind == 'Player' else 2), names
    assert not any(n.startswith('REVIEW') for n in names)
    binary_start = 20 + size + 8
    primitive = doc['meshes'][0]['primitives'][0]
    accessor = doc['accessors'][primitive['attributes']['WEIGHTS_0']]
    view = doc['bufferViews'][accessor['bufferView']]
    assert accessor['componentType'] == 5126
    for vertex in range(accessor['count']):
        offset = binary_start + view.get('byteOffset', 0) + accessor.get('byteOffset', 0) + vertex * view.get('byteStride', 16)
        weights = struct.unpack_from('<4f', raw, offset)
        assert sum(w > 0.00001 for w in weights) == 1 and abs(sum(weights)-1) < 0.00001
    assert hashlib.sha256(source.read_bytes()).hexdigest() == sha
    records.append(dict(source=str(source.relative_to(ROOT)), sha256=sha, actions=names,
        joints=len(doc['skins'][0]['joints']), rigid_single_bone_vertices=accessor['count'], bytes=len(raw), recoil='absolute reference poses; runtime quaternion difference'))
weapon_out = OUT.parent / 'weapons'
weapon_out.mkdir(exist_ok=True)
weapons = []
for source, name in [('pistol/blocky_pistol_v4.glb', 'pistol_v4.glb'), ('m4a1_blocky/m4a1_blocky_v4.glb', 'm4a1_v4.glb'), ('shotgun/blocky_shotgun_v4.glb', 'shotgun_v4.glb')]:
    source = ROOT / 'blender/weapons' / source
    shutil.copyfile(source, weapon_out / name)
    weapons.append(dict(source=str(source.relative_to(ROOT)), runtime=name, sha256=hashlib.sha256(source.read_bytes()).hexdigest()))
(OUT/'animation_v2_manifest.json').write_text(json.dumps(dict(characters=records, weapons=weapons), indent=2))
