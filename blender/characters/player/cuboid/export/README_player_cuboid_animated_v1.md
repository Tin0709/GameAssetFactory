# Player cuboid animated v1

Validated asset: `player_cuboid_animated_v1.glb`.
Preparation source: `../player_cuboid_game_export_v1.blend` (24 FPS).

- Mesh: Player_Cuboid_Base. Skeleton object: Player_Cuboid_Rig, 10 joints.
- Clips: Idle, 2 seconds; Run, 0.6666666865 seconds (16/24 seconds).
- Run's endpoint closes the cycle; it does not add an extra frame of hold.
- Blender forward -Y / up +Z converts to glTF model front +Z / up +Y.
- Object locations/rotations are zero; scales are one. No transforms applied.
- Existing authored curves are preserved. Only export-copy neutral constants were
  added to otherwise missing bone location/rotation channels for stable clip switching.
- Skin weights, mesh geometry, UVs, rest pose and bone hierarchy are unchanged.
- Embedded texture, one mesh, one skin, two clips. No cameras/lights/Mixamo data.
- Export sampled at 96 Hz without changing real-time speed or saved authoring FPS.
- GLB does not carry a standard loop flag. Enable looping for Idle and Run during
  Godot import; retain the recorded clip durations. No Godot project was changed.

Validation details are in `player_cuboid_animated_v1_validation.json`. Independent
glTF skinning was compared bidirectionally against Blender's evaluated vertex set
at all quarter-frame samples (193 Idle, 65 Run). Maximum error <0.0005 mm;
Root travel, accumulated Hips travel and loop pose mismatch were zero. A temporary
Blender GLB reimport also matched both initial poses within 0.0005 mm.

Reproduction scripts in the parent directory:
`prepare_game_export_v1.py` creates a new copy/export and refuses to overwrite an
existing preparation copy. `reexport_game_glb_v1.py` exports the dedicated copy
without saving its temporary 96 Hz sampling state. `validate_game_glb_v1.py`
validates without saving any Blender file.
