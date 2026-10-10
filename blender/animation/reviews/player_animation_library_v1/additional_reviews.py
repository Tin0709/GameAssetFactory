"""Layer existing weapon-ready poses over the authored strafe family; no new keys."""
import bpy

def add_armed_strafes(sc, catalog, actors, clone_actor, entry, assign):
    catalog[:] = [e for e in catalog if e['group'] != 'Combat Strafe']
    reference = bpy.data.objects['R14_P2_Right_Rig']
    for kind in ['Pistol', 'Rifle', 'Shotgun']:
        key = 'Combat_' + kind
        if key not in actors:
            rig, col = clone_actor('R12_Hold_' + kind + '_Rig', key)
            ready = rig.animation_data.action
            track = rig.animation_data.nla_tracks.new()
            track.name = 'REVIEW / existing ' + kind + ' ready'
            strip = track.strips.new(ready.name, 1, ready)
            if ready.slots:
                strip.action_slot = ready.slots[0]
            strip.action_frame_start = 1
            strip.action_frame_end = 97
            strip.scale = 2
            strip.repeat = 100
            strip.blend_type = 'REPLACE'
            strip.influence = 1
            strip.extrapolation = 'HOLD'
            for bone in rig.pose.bones:
                bone.rotation_mode = reference.pose.bones[bone.name].rotation_mode
            assign(rig, bpy.data.actions['Combat_StrafeRight_V2'])
            actors[key]['ready_action'] = ready.name
        for direction in ['Left', 'Right', 'ForwardLeft', 'ForwardRight', 'BackwardLeft', 'BackwardRight']:
            name = 'Combat_Strafe' + direction + ('_V2' if direction in ['Left', 'Right'] else '_V1')
            entry('Strafe ' + direction + ' / ' + kind, 'Combat Strafe', key, 1, 17, 48,
                  action=name, status='Existing authored lower body + existing weapon-ready upper body; Blender composition')
            catalog[-1]['weapon'] = kind

def add_jump_slices(catalog):
    # Original authored world travel and poses; only playback ranges change.
    for label, start, end in [('Jump up / lead A', 17, 37), ('Jump down / lead A', 74, 92),
                              ('Jump up / opposite lead', 121, 141), ('Jump down / opposite lead', 178, 196)]:
        catalog.append({'label': label, 'group': 'Jump (study only)', 'scene': 'BLOCK_JUMP_V2_REVIEW',
                        'start': start, 'end': end, 'fps': 24, 'duration_seconds': (end-start)/24,
                        'status': 'Original block journey slice with world travel; Blender only'})
    for i, e in enumerate(catalog):
        e['id'] = str(i)
