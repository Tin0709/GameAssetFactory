# R6-P production locomotion integration

The real player now defaults to REFERENCE_LOCOMOTION, using the approved R5 C animation and turn response. Gameplay controls and speed values are preserved. Legacy remains available for review and rollback.

**ARTISTIC STATUS: AWAITING HUMAN REVIEW.**

## 1. Production files changed

The integration surface is the existing sole pose writer:

- `game_mobile_3d/scenes/characters/CuboidPlayer.tscn`: selects the new visual extension and v5 model.
- `game_mobile_3d/scripts/player_reference_locomotion_r6p.gd`: adds Reference sampling and the two development modes.
- `game_mobile_3d/scripts/player_animation_v2.gd`: adds a virtual locomotion hook and extracts the existing recoil application without changing the Legacy branch.
- `game_mobile_3d/scripts/player_ready_e3_integration.gd`: exposes the existing Run contribution through a hook so Reference can exclude the V7-specific correction.
- `game_mobile_3d/scripts/animation_weapon_debug.gd`: adds debug-build F6 switching.

Supporting additions include the v5 asset/import settings, `tools/reference_locomotion_post_import.gd`, safe Blender export/validation scripts under `blender/characters/player/cuboid`, focused tests, a tracked Legacy scene fixture, a regression runner, and review tools under `scenes/dev/production_r6p`.

Historical test fixtures now explicitly select their original animation mode and account for the already-existing WeaponCarrier. Combat fixtures wait for actual READY before measuring firing cadence; the cached targeting test advances a physics tick after moving its targets. Sprint assertions sample the active reference clip. Stop-angle limits are unchanged.

## 2. Exported and imported animations

New asset: `game_mobile_3d/assets/characters/player_cuboid_animated_v5.glb`.

| Production name | Approved source Action | Duration |
|---|---|---:|
| Walk | Walk_ReferenceStudy_V2 | 0.666667 s |
| WalkTurnLeft | Walk_TurnLeft_Reference_V3 | 0.666667 s |
| WalkTurnRight | Walk_TurnRight_Reference_V3 | 0.666667 s |
| Sprint | Sprint_ReferenceStudy_V2 | 0.541667 s |
| SprintTurnLeft | Sprint_TurnLeft_Reference_V3 | 0.541667 s |
| SprintTurnRight | Sprint_TurnRight_Reference_V3 | 0.541667 s |

Export-safe copies are in `blender/characters/player/cuboid/export/locomotion_r6p/locomotion_export_copies.blend`. The study file and Actions are unchanged. Export sampling is 192 Hz; original durations are retained.

All previous production clips remain: Idle, Run V7, DrawLongGun, HolsterLongGun, LongGunReadyIdle, LongGunReadyRun. Prior animation JSON and binary payload, mesh, rig hierarchy, rest pose, skin, materials, images and helpers are preserved exactly. WeaponCarrier remains intact. Existing weapon clips loaded by the legacy adapter remain available. The post-import script copies the old native clips exactly; focused tests verify their imported track paths, types, times and values.

Validation before Godot passed: six exact loop closures, zero scale tracks, no Root travel, no added reference objects/cameras/lights, maximum source sample position error 0.000000654 m and rotation error 0.033862 degrees. See `blender/characters/player/cuboid/export/locomotion_r6p/production_glb_validation.json`.

## 3. Locomotion runtime

One persistent normalized phase drives straight/left/right Walk and straight/left/right Sprint. Sampling uses `phase × clip duration`; there are no independent turning clocks. Normal movement selects Walk. The unchanged controller's `fast_sprinting` flag selects Sprint. Idle uses the original pose branch once movement settles.

The exact R5 C mapping is measured wrapped visual yaw delta divided by elapsed time, normalized by 1.20 rad/s, signed shaping with exponent 1.35, then exponential smoothing with a 0.10-second time constant. Turn sign is character-relative and survives crossing ±PI. The production facing response remains unchanged.

Walk/Sprint blend over 0.14 seconds while retaining normalized phase. Their cycle rates blend from 1.5 to approximately 1.846154 cycles/s. Direction, Shift, Draw, Holster and weapon events never reset the clock. Both Reference and Legacy clocks continue across F6 switching.

The existing aim transition also blends the lower stride-plane compensation. This prevents a sudden full lower-body offset when target eligibility changes on Sprint release, while preserving upper target facing.

## 4. Weapon compatibility

READY Walk retains the existing LongGunHold composition. Hips and Spine remain from locomotion, and Chest retains its locomotion delta before the existing carry bias. Arms and the hand socket retain the authored Hold contact frames. Measured world-relative positional error is at most 0.000000255 m; measured rotation error is zero in the tested READY cases.

Draw and Holster continue through their existing upper-body layers, events and socket ownership. Sprint still takes priority over threats, Holsters/stows the long gun, and blocks firing. Releasing Sprint near a threat triggers the real Draw; firing resumes after READY. Live cases cover M4 and shotgun, and existing suites cover pistol and switching. Weapon instances retain their IDs.

LongGunReady_Run_V1 remains confined to the actual Legacy Run V7 contribution. It is excluded from Reference Walk and Sprint. A dedicated LongGunReady_Walk_V1 remains a later animation-layer task; no Ready, Draw or Holster animation was authored here.

## 5. Test evidence

Focused tests were written and run before production runtime changes. RED reported the missing production mode, shared-phase sampling, new clips, and real-game Reference integration. These original failures are preserved with the final results in [evidence.json](/C:/Users/ADMIN/Desktop/GameAssetFactory/docs/validation/locomotion_r6p/evidence.json).

Final focused results:

- 7,245 deterministic checks passed, including exact retained native clip keys and Legacy final poses with Ready, recoil and nonzero secondary springs for all weapon profiles.
- 1,761 live controller/weapon checks passed, including READY grip orientation, world-relative contact frames, Sprint priority, Draw/Holster, firing and instance ownership.
- Maximum Reference versus approved Lab C pose position error: 0.000000239 m; rotation checks passed.
- Maximum phase integration error: 0.000000000565 normalized cycles.
- All 20 relevant existing suites passed with zero script/runtime errors. These include movement, stop transitions, animation, carry, behavior, Draw/Holster and their live cases, Sprint, back carry, Ready and live Ready, selection, combat, gameplay, bounce and pose lab.

The pre-integration baseline exposed stale historical fixtures and an existing stop-transition issue. The final results above are from the integrated production player; historical clip-specific tests explicitly select Legacy. No red result remains in the final relevant suite.

Reproduce from the repository root with the Godot 4.7.2 console executable:

```powershell
godot --headless --path game_mobile_3d --script res://tests/validate_locomotion_r6p.gd --fixed-fps 60
godot --headless --path game_mobile_3d --script res://tests/validate_locomotion_r6p_live.gd --fixed-fps 60
python game_mobile_3d/tests/run_locomotion_r6p_regressions.py review
```

The runner contains this workstation's console executable path; change that constant on another workstation. It preserves existing tracked JSON reports and writes individual logs/results to the ignored local validation folder.

## 6. Manual QA

Scripted rendered gameplay QA exercised the real controller, normal production camera and normal layer/state paths. There are 18 scenarios and 1,860 paired Legacy/Reference frames at 24 FPS: Idle; straight Walk/Sprint; CW/CCW circles; S paths; reversals; straight recovery; Walk/Sprint switching; READY circles in both directions and an S path; and awareness-driven Draw, Sprint Holster/stow, release Draw and firing.

Each pair freezes the same world only while rendering its two modes. Five completed 120 Hz physics updates drive each playback frame. Recovery paths remain within the arena; steady recovery approaches zero turn without a wall collision. Armed circles reach approximately ±0.821 turn; the armed S path exercises both signs. Enemies/spawning are isolated only in the capture fixture. The playable review uses the normal production game.

[Open local A/B playback](http://127.0.0.1:8868/.validation/locomotion_r6p/review/index.html). Raw capture metrics and ordered contact sheets are under `game_mobile_3d/.validation/locomotion_r6p`. Regenerate with `scenes/dev/production_r6p/capture.gd` and `package_review.py`.

This evidence is scripted gameplay and inspection of ordered rendered frames. Human manual play and continuous artistic review remain pending.

## 7. Artistic observations

Reference makes the stowed gait visibly more asymmetric and engaged through the body. Sprint shows a stronger shoulder/cross-body arm silhouette and compact recovery leg; circle banking is clearer than Legacy. Walk adds stride/body participation that was absent from the older upright presentation. The unarmed pose tests match approved Lab C closely.

READY deliberately reduces the free-arm silhouette. The weapon pose remains coherent in sampled frames, with useful Hips/Spine/Chest response surviving the Hold layer. Draw/Holster retain their upper-body transitions over the new gait. These observations do not replace human approval of timing and naturalness.

Foot sliding remains visible. Tight reversals also retain the real controller's acceleration and speed loss. No unexpected gait restarts or additional movement-speed changes were found; sliding severity has not been calibrated quantitatively against Legacy. No IK, locking, root motion, stride warping or retiming was introduced.

## 8. Performance and regressions

Desktop headless visual-update benchmark: 4,000 samples per case, Reference mean approximately 54–56 microseconds, Legacy approximately 66–85 microseconds. This is the existing visual `_process` cost, including pose sampling/layers, not a GPU, full-game or phone measurement. The capture HUD's 120 FPS is a controlled capture rate, not mobile evidence.

The runtime retains one live skeleton and one sole pose writer. Samplers/bone indices are cached. No per-frame scene searches, IK, retargeting or duplicated character were added. Controller input, collision, movement values, camera, health, enemies, targeting, weapon switching/state mechanics, sockets, and Draw/Holster/firing code are unchanged. The v4 asset hash remains `b4c9a9b2d7b16106012be1ff23df5169eb617fadcae2fe02a211070367ef3d13`. Final capture logs contain no errors or warnings.

## 9. Rollback

In the running debug game, press **F6** to switch REFERENCE_LOCOMOTION ↔ LEGACY_LOCOMOTION. The animation debug text names the active mode. F6 is ignored in release builds.

For persistent Legacy, set `Visual.locomotion_mode = 0` in `CuboidPlayer.tscn` or use the Visual Inspector's Legacy enum value. Set it to `1` for Reference. The original runtime branch and old assets are retained.

For a full scene-level fallback, restore CuboidPlayer's visual script resource to `res://scripts/player_ready_e3_integration.gd` and model resource to `res://assets/characters/player_cuboid_animated_v4.glb`; the tracked `tests/fixtures/LegacyPlayerR6P.tscn` records that exact previous scene setup.

The real game is launched in Reference for review. Controls: WASD movement, Shift Sprint, 1/2/3 weapons, 0 unequip, R reset, F6 locomotion A/B. Normal spawning/combat are active; R starts a fresh run if needed.
