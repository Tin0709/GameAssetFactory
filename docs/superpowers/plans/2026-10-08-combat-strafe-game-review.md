# Combat strafe game review implementation

Goal: Integrate approved R14 Pass 2 six-direction clips into the existing Godot player, preserving peaceful locomotion, R13 weapon layers, sole skeleton writer and existing clocks. Stop at artistic review.

1. Inspect approved study/export/runtime and establish failing asset/direction/continuity tests.
2. Sample six native Actions without saving source Blender files; assemble and import versioned GLB preserving R13 resources.
3. Blend lower gait in combat READY only with continuous phase, smooth heading/twist and diagonal weights. Preserve upper transitions and sprint stow.
4. Validate real gameplay for all weapons, direction reversals, clocks, facing, twist, socket ownership and errors. Capture real Grassland review evidence.
5. Report exact changes and controls; parent reviews diff and opens game.

Findings: Existing R15 has only V1 left/right, phase reset on switch. Approved Pass 2 has six Actions at 48 FPS, 16-frame period (0.333333 s), calibrated for 2.6 m/s. Grassland is actual main, currently intentionally disables gun and has no enemies or combat controls. Newest prior R15 validation passed; preservation will be checked rather than presumed broken.

Current checkout retained by explicit user task authorization. Source .blend files remain read-only.

## Final implementation / verification ledger

- Native six-direction source: `player_combat_strafe_r14_pass2_study.blend`, Left/Right V2 and four diagonal V1 Actions; 48 FPS frames 1–17, 0.333333-second period. Export sampler uses read-only source and copied rig. Source SHA and all original Action digests verified unchanged.
- Versioned R15 GLB now contains 36 clips: unchanged R13 geometry/rest/skin/materials, unchanged original 12 clip binary data, 18 native upper clips, six native lower clips. Post-import preserves established R13 imported resources and filters strafe tracks to Hips/Leg.L/Leg.R position+rotation and Spine rotation.
- Runtime composes a circular eight-direction blend from authored six, existing forward Walk, and backward Walk sampled in reverse. Target-relative angular weights interpolate smoothly; phase never resets on direction/state handoff. Existing reference, legacy locomotion, R13 idle and weapon clocks remain untouched. Authored lower blend requires target + READY + equipped + nonsprint; upper R13 draw/hold/holster/stow layers and same writer remain intact. Small Spine rotation residual preserves living upper translation; Chest counterrotation and existing C1 twist shoulder preserve aim below20 degrees.
- Actual main Grassland gains optional F7 review target/service. Default has no target and gun disabled as before. F7 uses existing combat registry and immortal stationary AnimationTestEnemy. Existing AnimationWeaponDebug exclusively owns1/2/3; actual viewport keyboard input tested. `--combat-review` starts rifle and target. Combat review remains silent.
- Test-first evidence: six asset test failed on missing approved clips; initial runtime failed all six missing clips. Green after import/runtime integration. Expanded main-scene test discovered silent audio adapter omission (fixed via silent_test=true). Updated legacy exact-pose test required continuous-blend contract: prephysics target position induces~0.83 degree actual oblique heading and1.84% diagonal contribution. Import sample parity remains strict; runtime settled sideways gait asserts>98% cardinal influence,<2mm position and<2degree angular deviation.
- Fresh headless commands: Godot4.7.2 `--headless --fixed-fps60 --path game_mobile_3d --script res://tests/NAME.gd --log-file ABSOLUTE_LOG`, APPDATA redirected to project `.godot/validation_appdata`.
- `validate_r15_six_runtime`:12,433 checks/0 failures actual Grassland including eight dirs×three weapons, phase continuity, upper facing/twist, per-frame lower pose continuity through abrupt opposite diagonals/target changes, legacy/reference/upper clocks, target loss/holster, sprint/stow/draw restore, exactly one visible weapon, keyboard adapter, F7 cleanup.
- `validate_r15_strafe`:7,806/0; `validate_r13_integration`:8,280/0; `validate_combat`:78pass; `validate_player_pose_lab`:143/0. Both Python asset validators pass.
- Numeric limits: max torso offset19.254deg; max lower per-frame displacement0.039014m and rotation18.180deg in aggressive transitions; imported position error1.490116e-8m, quaternion min dot0.9999999404.
- Rendered real Grassland via offscreen OpenGL3/NVIDIA. First capture showed blank pixels because map_process overwrote closeup camera; capture-only map_process disabled and rerun corrected. Physics, grass provider, actual player/controller/animation kept live. Final288PNG frames cover24weapon/direction cases; JSON and render log saved under`.validation/r15`. Main peaceful camera/HUD unchanged. Parent owns final visible launch.
- Review controls: WASD/multiple keys for diagonals; Shift sprint/stow; F7 add/remove target;1pistol/2rifle/3shotgun;Rcenter. Launch actual main with `-- --combat-review --silent-review`.
- Limit: forward/back use retained Walk and reversed Walk rather than adding unapproved native Actions; smooth blends between different cadence clocks can still merit human contact/foot-sliding review. Automated continuity thresholds establish bounded motion, not final artistic quality. This is the requested review stage; no final polish or source Blender edits performed.
- Concurrent grassland-lookdev files are unrelated and preserved. No commits created.

Status: integration and technical verification complete; ARTISTIC STATUS: AWAITING HUMAN REVIEW.

## Files changed for this task

- `blender/characters/player/cuboid/export_combat_strafe_r15.py`
- `docs/superpowers/plans/2026-10-08-combat-strafe-game-review.md`
- `game_mobile_3d/assets/characters/r15/source.json`
- `game_mobile_3d/assets/characters/r15/export_manifest.json`
- `game_mobile_3d/assets/characters/r15/player_r15_combat_strafe_v1.glb`
- `game_mobile_3d/scripts/player_combat_strafe_r15.gd`
- `game_mobile_3d/scripts/grassland.gd`
- `game_mobile_3d/tools/combat_strafe_r15_post_import.gd`
- `game_mobile_3d/tests/review_r15.gd`
- `game_mobile_3d/tests/validate_r15_strafe.gd`
- `game_mobile_3d/tests/verify_r15_assets.py`
- `game_mobile_3d/tests/validate_r15_six_assets.py`
- `game_mobile_3d/tests/validate_r15_six_runtime.gd`
- `game_mobile_3d/tests/validate_r15_six_runtime.gd.uid`

Final visible Grassland review launched with rifle and combat target using D3D12 Mobile; live startup log contained no errors. Game left foreground for human review.
