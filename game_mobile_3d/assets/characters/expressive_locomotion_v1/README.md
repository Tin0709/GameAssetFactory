# Approved expressive locomotion export

Used only by `res://scenes/dev/ExpressiveLocomotionTest.tscn` (F6). Production scenes and controllers are unchanged. See [gameplay review and controls](../../../../docs/animation/reviews/godot_locomotion_v1/README.md).

`approved_library.res` contains three separate looping clips: approved `Idle_Expressive_Test_v3` (8 s), `Walk_Expressive_Test` (1.2 s) and `Run_Expressive_v3_Test` (2/3 s). The default lab evaluates movement at 1.5× travel/cadence while keeping Idle at normal speed; the exported clips themselves are not retimed.

## Export contract

`export_approved.py` reads the existing Showcase manifest and saved authoring files, verifies source hashes, binds the exact `OBRUN_Test_Rig` Action slot, and samples at 120 Hz including the closing pose. It never saves a Blender file. Position and quaternion tracks are retained independently; root/world travel and scale deformation are absent. Bone aliases `UpperArm.L/R` → `Arm.L/R` preserve the current runtime convention. Coordinate conversion occurs once. Rest-transform error is below 6e-8; maximum reconstructed vertex error below 0.000001 m. Source hashes, durations and exact closing-pose errors are in `export_validation.json`.

`build_library.gd` writes the compressed native AnimationLibrary (342,928 bytes). The test reuses the unchanged `jump_gif_v004/player_r15_jump_gif_v004.glb` model rather than exporting another mesh or rig. Existing legacy clips in that model remain present; total shipping character memory has not been optimized or certified by this experiment.

The tiny `approved_atlas_64.png` is an exact copy of the model's packed atlas, imported losslessly with nearest filtering and no mipmaps. Instance-local material overrides avoid a lossy VRAM-compression artifact in the existing model import. Production model materials, texture bytes and import settings remain unchanged. `validate_model.py` and `geometry_material_validation.json` verify identical geometry/UV/packed texture data. `audit_material.gd` is an optional diagnostic, not a runtime dependency.

## Rebuild only when explicitly needed

From the project root, run Blender 5.2 in background with `--factory-startup --python game_mobile_3d/assets/characters/expressive_locomotion_v1/export_approved.py`, then Godot with `--headless --audio-driver Dummy --path game_mobile_3d --script res://assets/characters/expressive_locomotion_v1/build_library.gd`. Use the installed executable paths. `approved_samples.json` is the intermediate audit/build input.

Run `res://tests/validate_expressive_locomotion.gd` with `--headless --audio-driver Dummy --fixed-fps 30`, then 60. The test writes `res://.validation/expressive_locomotion_v1/runtime_validation.json`. Optional user arguments `-- --expressive-pace-1` or `-- --expressive-pace-2` test comparison speeds. Keep audio normal for interactive user launches.

Do not promote this export to production based on headless checks alone. Actual gameplay review, sharp-turn support, full weapon-state transitions, terrain and measured 30 FPS target-phone performance remain required. No Jump clip is selected by this test.
