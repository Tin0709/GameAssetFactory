# Pending expressive Jump V2 runtime poses

Read-only native export of the existing `Full_Jump_Expressive_v2_Test`, using its correct `OBRUN_Test_Rig` Action slot. Source and Action SHA256 values are recorded in `export_validation.json`. This directory contains pose data only; no duplicate character mesh, material, rig or preview elevation.

`jump_library.res` is one **non-looping** Animation with 369 samples at 120 Hz over the source F1–93 interval (3.0667 s). Sampling matches the existing full-arm runtime rig, with UpperArm→Arm name aliases and no rest-rig changes. Root stays identity. Small hip compression is preserved; the large review trajectory is absent. Endpoint differences in the export report are expected for this non-looping source, not a failed locomotion seam.

Rebuild from project root:

1. Run Blender 5.2 background/factory-startup with `--python game_mobile_3d/assets/characters/expressive_jump_v1/export_jump.py`. It verifies the source hash and correct slot, reads/evaluates the source and exits without saving it.
2. Run Godot headless with `--audio-driver Dummy --path game_mobile_3d --script res://assets/characters/expressive_jump_v1/build_library.gd`.
3. Run `res://tests/validate_expressive_jump.gd` at 30/60 FPS and inspect actual gameplay. Export success does not establish artistic approval or production readiness.

`ExpressiveJumpPlayer.tscn` subclasses the existing isolated locomotion actor. Physics selects preparation/ascent/descent/contact/recovery in `expressive_jump_actor.gd` / `expressive_jump_visual.gd`; it never plays the entire source at a fixed duration. Existing upper weapon masks remain above the expressive base pose.

Open `res://scenes/dev/ExpressiveLocomotionTest.tscn` and press F6. Jump V2 remains **Pending**, production unchanged. Full controls, phase mappings, original-speed review and limitations: `docs/animation/reviews/godot_jump_v1/README.md`.
