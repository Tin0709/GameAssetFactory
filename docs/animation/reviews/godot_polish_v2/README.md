# Locomotion polish V2 — Pending user review

Open `game_mobile_3d/scenes/dev/ExpressiveLocomotionTest.tscn` and press **F6**. Production F5/WorldMap is unchanged. WASD/arrows move, Shift runs, Space jumps, R resets. **T** cycles 1 / 1.5 / 2.25× movement; Idle stays 1×. **K** compares this polish with the preserved previous directional test. V/F/G/B retain the older turn/fall/stride/landing comparisons. E toggles the existing rifle layer; L drops from 6m. F9 retains the previous demonstration. Jump V2 is approved as a test direction only; this polish remains Pending. Stop for user review before Combat Strafe or production integration.

[Before/after at original speed](comparison_1x.mp4) · [After](after_1x.mp4) · [Before](before_1x.mp4) · [Pose samples](gameplay_poses.jpg).

The matched Mobile/D3D12 engine capture shows both 2.25× and previously accepted 1.5× movement, sharp Walk/Run turns, stops, turning jumps, weapon carry/release in three falling views and an unarmed falling gesture. Movie FPS is 30, playback is original speed, and controller/physics clocks are unmodified. `video_validation.json` records decoded length and hashes. Presentation uses the same cameras and lighting on both sides. The earlier complete review is preserved in `../godot_directional_v1/`.

## What changed

- A sharp-turn support contact can briefly shift the hips toward a reachable support configuration, before the existing single-rigid-leg solve. Signed reach demand handles both overextension and a foot too close under the hip. The world offset is bounded to 90mm total vector length, approaches at 0.9m/s and releases at 0.35m/s. A contact ID retains the support adjustment until that foot replants. This is a small diagonal weight transfer, not 90mm of vertical bouncing. Capsule translation, acceleration, yaw response, gait phase, authored support duties and the 140mm leg-correction safety bound are unchanged. No invented knee/ankle or scale deformation.
- Run's cyclic lateral hip excursion and pelvis/spine/chest yaw/roll are reduced 20% at full Run, around their cached cycle means. Forward lean, fore/aft transfer, vertical loading, close tracks, expressive arm targets and the 20% longer stride remain. Walk and Idle targets are unchanged. Extra support loading occurs only for turn-related contacts.
- Falling adds 10° of extra opening per leg instead of 5°. This doubles the additional angular opening; it does not claim exactly twice the total foot spacing. Opposing 8° solid-leg flutter and above-head straight-arm waves remain. Existing physics descent and time-to-contact fade release the gesture before impact.
- Weapon equip/release no longer inherits locomotion speed. The former 0.30/2.25-second blend compressed a large arm change into four 30FPS samples. Equip now uses its own 0.30-second clock. Release captures the displayed partial/full layer relative to the unarmed pose, follows the shortest rotation, and removes that captured offset over its own 0.30-second interval. This fixes the stale long-path offset exposed by releasing a weapon while the airborne arm base changes. The existing weapon mask, carry clips, attachment and production scripts are preserved.
- A moving, unprepared ledge-fall entry uses a fixed transition decay of 36/s instead of the accelerated Run decay of 54/s. Authored takeoff, landing and stationary entry retain their prior damping. This prevents a fast Run arm swing being collapsed into the approach pose in one sample. Physical movement still responds immediately.

## Measured validation

All 1,952 checks pass across the final matrix: 249 matched turn checks at each pace, 95 layer checks, 185 fall checks, 44 stride checks, and 77 jump checks at each pace, each repeated at 30/60 renderFPS with 60Hz physics. `checks_summary.json` and individual JSON files contain the actual results. No angular, clearance, support, gait or responsiveness guard was relaxed.

Matched 12 flat-ground turn cases per pace include Walk/Run 45°, 90° and 180° from both lead phases, observed for 36 physics ticks. The comparison is against the previously delivered refined directional solver, not the much earlier unsolved baseline.

| Pace | Render FPS | Before cumulative planted-center travel | After | Reduction | Largest after sample |
|---|---:|---:|---:|---:|---:|
|2.25×|30|0.04663m|0.000011m|>99%|<0.1mm|
|2.25×|60|0.23960m|0.11497m|52%|58mm|
|1.5×|30|1.08817m|0.69998m|36%|118mm|
|1.5×|60|2.01662m|1.38734m|31%|90mm|

Matched before/after capsule positions and gait progression remain equal. Support coverage is retained; the test does not hide sliding by adding flight, resetting strides or delaying input. Sampling and gait alignment differ between frame rates and speeds; cumulative distances must not be interpreted as a universal physical sliding rate. 90° cases were already close to planted in the faster candidate; remaining releases concentrate in hard reversals. Slower comparison pacing is available but is not inherently more stable under all pivot phases.

The original strict jump suite now passes 77/77 at both speeds and frame rates. The previously failing 30FPS weapon-recovery section drops from 60.69° to 36.48° maximum joint step. The largest step anywhere in the fast suite is 58.36° at 30FPS, 33.48° at 60FPS; the original 60° guard remains intact.

The layer suite exercises Pistol/Rifle/Shotgun at both speeds with physics-state-driven events: equip in descent, release before contact, equip in landing recovery, interrupt entry, re-equip during release and release again. First contact is latched once to verify the fall gesture has already faded. Maximum tested upper-body steps are 53.43° at 30FPS and 31.27° at 60FPS. Weapon carry intentionally owns its upper channels while equipped; the unarmed above-head wave resumes on release. This is carry/transition validation, not firing, aiming, reload or Combat Strafe certification.

## Remaining limits

Foot sliding is reduced, not eliminated. Hard reversals still exhaust bounded rigid-leg reach and release anchors, especially at 1.5×. Boot corners also rock even when the measured sole center stays anchored. Individual terrain contacts, platform edges, general slopes/stairs, full combat layering and real phone performance remain unverified. 30/60FPS checks run on desktop with fixed render sampling and 60Hz physics; they are not a phone benchmark. Review the actual motion before approval.

## Preservation and replay

Before editing, the working tree was clean and 6,833 existing files were hashed. Exact previous test scripts, tests, docs and V1 reviews are archived in `.validation/expressive_polish_v2/before/`; `baseline.json` protects original assets. `preservation_validation.json` confirms the allowed changes. All approved Blender Actions/sources, the existing Showcase/manifest, production gameplay/controllers/weapons/WorldMap, project settings and earlier reviews remain byte-identical. No new Blender Action/export was required.

The final reproducible checks are `tests/validate_expressive_polish.gd`, `validate_expressive_polish_layers.gd` and the existing fall/stride/jump suites. Run automated checks with `--headless --fixed-fps 30` or `60`, `--audio-driver Dummy`, and `--script res://tests/<suite>.gd`. Add `-- --expressive-pace-1_5` for the accepted pace comparison. `validate_expressive_jump_fast.gd` checks the default 2.25× candidate; `validate_expressive_jump.gd` checks 1.5×. Media replay uses `--expressive-polish-demo`; add `--expressive-polish-before` for the preserved prior solver and weapon timing. K exposes the same comparison interactively. Normal user playtests keep normal audio.
