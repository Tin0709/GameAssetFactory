# R4-G — isolated Godot locomotion turning lab

**ARTISTIC STATUS: AWAITING HUMAN REVIEW**

The lab is ready for manual movement and A/B review. Turning adds a restrained body bank; sliding at the requested default speeds remains a prominent limitation. Technical validation does not approve the motion. No production integration was performed.

## Asset and scene

- Export: `game_mobile_3d/assets/test/player_cuboid_locomotion_v2_test.glb` (296,024 bytes).
- Playable scene: `game_mobile_3d/scenes/dev/LocomotionTurningLab.tscn`.
- Source: `blender/characters/player/cuboid/player_locomotion_turning_v2_study.blend`.
- Export-safe Action copies: `blender/characters/player/cuboid/export/locomotion_r4g/locomotion_export_copies.blend`.

| Imported clip | Source Action | Duration |
|---|---|---:|
| Walk | Walk_ReferenceStudy_V2 | 0.666667 s |
| WalkTurnLeft | Walk_TurnLeft_Reference_V2 | 0.666667 s |
| WalkTurnRight | Walk_TurnRight_Reference_V2 | 0.666667 s |
| Sprint | Sprint_ReferenceStudy_V2 | 0.541667 s |
| SprintTurnLeft | Sprint_TurnLeft_Reference_V2 | 0.541667 s |
| SprintTurnRight | Sprint_TurnRight_Reference_V2 | 0.541667 s |

The GLB contains one mesh, one skin, the original rig hierarchy, and exactly these six animations. WeaponCarrier remains as an unanimated structural bone in the unchanged rig. There are no weapon objects, development Actions, Mixamo data, lights, cameras, references, scale channels, or accumulated Root travel. All six pose endpoints close exactly. Export uses 192 Hz sampling to preserve the existing curves; this increases sampling density without changing duration or cadence. Godot's optimizer is disabled for this asset only.

## Manual controls

| Key | Action |
|---|---|
| WASD | World-space movement; diagonals normalized |
| Shift | Sprint |
| Tab | A straight clips / B turning blend |
| F1 | Hide/show debug |
| C | Primary gameplay view / closer view, same fixed camera axes |
| R | Recenter position and heading; gait phase is retained |
| Space | Optional automated path / manual |
| F2 | Automated sequence / CW circle / CCW circle |
| F3 | Automated Walk / Sprint |
| [ / ] | Circle radius, 0.5 m increments; default 6 m |

WASD immediately takes over from automated movement. Circle mode is useful for sustained curvature that an eight-direction keyboard can only approximate. The automated sequence is straight → left → straight → right → S-curve → CW → CCW → straight recovery. It is available in either gait. Start with the primary view, compare Tab A/B, then inspect the closer view if needed. The scene starts in manual B mode.

## Controller, facing, and phase

The scene has its own CharacterBody3D, collider, imported visual, flat ground, fixed-axis elevated camera, lighting, and HUD. It does not instantiate CuboidPlayer or any gameplay/weapon/enemy systems. Camera translation follows the actor; camera orientation never follows heading. There is no camera orbit used to manufacture turning.

Actor inspector settings expose Walk **4.25 m/s**, Sprint **6.25 m/s**, facing response **12/s**, maximum yaw rate **6 rad/s**, full turn-pose rate **3 rad/s**, turn filter time constant **0.10 s**, and gait blend **0.14 s**. Speed follows the short gait blend. Animation cadence stays **1.0**; production cadence 1.60 is untouched.

Facing approaches movement heading exponentially, with a yaw-rate cap and wrapped angle differences. Controls set velocity immediately; facing eases toward that direction. This leaves some heading lag during abrupt changes, intentionally visible for review. World heading belongs to the visual parent, never to an animated Root channel.

The imported character faces local +Z; local left is +X. Positive world-Y yaw therefore means local left. Turn amount is `clamp(-actual_yaw_delta / dt / 3, -1, 1)`, filtered exponentially with the exposed 0.10-second time constant. **Negative selects Left; positive selects Right.** It depends on actual parent rotation, not A/D keys or camera directions. CW stays positive/right and CCW stays negative/left across every world heading and the ±PI boundary.

The imported AnimationPlayer is a stopped, inactive clip library. The local sampler is the sole pose writer. All six clips sample **one normalized phase × that clip's duration**. Left/straight/right absolute local positions interpolate linearly and rotations use quaternion slerp; full poses are never added together. The resulting Walk and Sprint poses use the 0.14-second gait weight. The clock advances at the blended reciprocal cycle duration, preserving normalized phase through Shift changes, turn changes, and A/B switches. No independent animation clocks, playback restarts, contact-frame resets, or foot matching are involved.

A samples the straight clips while continuing exactly the same phase, filter, velocity, and facing logic. B enables the turn weight. Releasing movement freezes the existing phase and lets turn intent recover toward zero; the scene has no Idle/start/stop/pivot/strafing Actions. A stationary frozen gait pose is a lab limitation, not a production idle proposal.

## Review observations

These are provisional observations from actual movement captures and pose sheets, not human approval. Twelve three-second A/B sequences were sampled at normal 24 fps: straight, mild CW/CCW bends, tight CW/CCW circles, and turn → straight → opposite turn, for each gait. Capture advances five real 120 Hz physics ticks per displayed sample. Travel-speed assertions verified the displayed 4.25/6.25 m/s; the GIF timing totals exactly three seconds. The GIFs enlarge a crop of the primary camera; full-camera sheets are also supplied.

At a **12 m** radius, Walk turn weight is about **0.118** and Sprint about **0.174**. The body response is subtle from the gameplay camera. Walk retains its smaller buoyant motion; Sprint retains its more committed arm/leg swing. The turning layer is easiest to see as torso/hips participation rather than a large independent head tilt. The cross-body arm style and compact recovery shape remain present. This is a modest visual difference from A, especially during gentle curves.

At **2.5 m** radius, Walk holds about **0.567** and Sprint **0.833**. Sign is stable in both directions, gait cycles continue, and the bank does not visibly flip or grow without bound. Sprint's bank is more readable, but its ground contact remains unconvincing at the default speed. CW/CCW bank direction is consistent; contact appearance is not perfectly symmetric. No obvious new head/neck separation or gross body/leg penetration was seen in the sampled gameplay views. Those views do not establish collision-free geometry at every phase.

Turn entry eases in; circle-to-straight recovery eases to neutral. The filtered opposite-turn transition crosses zero smoothly rather than resetting the stride. In the recovery capture, held ±0.9 rad/s curves approach ±0.30 weight, with the middle straight interval recovering toward zero. The script tests also exercise reversal and arbitrary Shift phases. From the fixed camera, bank makes the body follow the curve more clearly than the path/facing-only pose, but sliding still gives a rotating/skating impression. Human review must decide whether the improvement is sufficient.

**Tight Sprint is a stress case, not a recommended supported radius.** At 2.5 m, the authored lean remains bounded while soles move substantially over the floor. Smaller radii are available for observation, but were not used to tune the motion. Curvature above 3 rad/s saturates the turn-pose weight; above the 6 rad/s facing cap, the body cannot keep up with commanded heading. The current contact/silhouette already limits convincing movement at 2.5 m; no minimum artistically acceptable radius is certified.

### Sliding, separated from turning

Sliding is visible in straight A and B before any turn response. The same authored cadence must accompany 2.83 m of travel per Walk cycle and 3.39 m per Sprint cycle at these defaults. The present rigid-leg strokes do not make that travel look planted. This points to a speed/cadence/stride mismatch independently of the turn layer; no speed, cadence, or animation was changed to conceal it.

The following is a **sole-motion proxy**, not a foot-lock test: mean horizontal velocity of the original bottom-face center during adjacent samples whose lowest sole corner is within 4 cm of the floor. The sample set changes when banking raises a foot, and it can include rolling/swing boundaries. These numbers support the presence of substantial floor-relative motion; they do not rank artistic quality or prove that turning fixes contact.

| Gait / path | A left / right sole m/s | B left / right sole m/s |
|---|---:|---:|
| Walk straight | 4.64 / 4.10 | 4.64 / 4.10 |
| Walk mild CW | 4.66 / 4.08 | 4.67 / 4.08 |
| Walk mild CCW | 4.62 / 4.13 | 4.62 / 4.13 |
| Walk tight CW | 4.81 / 4.06 | 4.24 / 4.10 |
| Walk tight CCW | 4.59 / 4.29 | 4.63 / 4.17 |
| Sprint straight | 2.92 / 6.27 | 2.92 / 6.27 |
| Sprint mild CW | 2.91 / 6.32 | 2.92 / 6.20 |
| Sprint mild CCW | 2.98 / 6.26 | 2.98 / 6.27 |
| Sprint tight CW | 3.21 / 6.71 | 3.50 / 4.69 |
| Sprint tight CCW | 3.54 / 6.47 | 3.57 / 2.95 |

Walk: straight sliding dominates; mild turns barely change it. Tight B slightly reduces some sampled drift but still slides strongly. Inside/outside differences are modest in CW; in CCW the inside left leg shows more motion than the outside right. There is no consistent contact improvement sufficient to call Walk planted.

Sprint: straight contact is uneven between legs in this proxy, and both mild directions remain close to baseline. Tight B changes contact heights/sample coverage more strongly. The inside leg shows more sampled motion than the outside in both B circles (CW: right inside; CCW: left inside). Some right-leg averages drop substantially under B, especially CCW; this includes a changed near-floor sample set and is not evidence of foot locking. Tight circle contact remains visually weak. Details, sample counts, medians, and height ranges are in `foot_observations.json`.

Rigid single-piece legs remain visibly slab-like in side-facing recovery poses. The elevated primary view hides some of the missing knee articulation; the closer view exposes the rigid silhouette more clearly. The compact V2 recovery survives blending, but it cannot bend a leg. This lab does not establish that adding knees is necessary; it provides the gameplay comparison for that decision. No knees, IK, root motion, foot locking, speed warping, pivots, strafing, start/stop animations, or Turning V3 were added.

## Verification and evidence

- Export validation completed **before Godot work**: six durations, zero seam endpoint error, static Root, no scale tracks, clean topology/names. Source-world error: at most **0.000000694 m / 0.03545°**.
- Runtime validation: **5,658 checks**, zero failures. Native poses against independent Blender matrices: **0.000000716 m / 0.000977 rad** maximum error. Shared phase error below **1e-9**. A/B path/facing differences: **zero**.
- Live physical input validation: **14 checks**, zero failures, including diagonals, Shift, Tab, F1, C, optional CW/CCW paths, and immediate manual takeover.
- Rendered capture completed without script/runtime errors using the Mobile renderer and Direct3D 12. Travel measurements range approximately 4.249–4.250 m/s and 6.247–6.250 m/s; interval chord length accounts for the small circle difference.
- All **9,439 previously tracked files** match their pre-task SHA256 values. The source `.blend`, all source Actions, rig rest/hierarchy, and mesh weights are preserved. Production player, controller, camera, weapons, Ready, Draw/Holster, Run V7, and cadence are unchanged.
- Read-only independent code review found no critical or important issues. Technical results do not replace artistic review.

The headless editor logged the existing environment's safe-save warning for editor settings. Asset import nevertheless completed and native sample validation passed. Launch/capture explicitly select Direct3D 12 to avoid the host's Vulkan fallback warning. No project rendering settings were modified. The blocky shadow is visibly coarse at close zoom; lighting is lab-only.

Evidence is under `game_mobile_3d/.validation/locomotion_r4g/`: runtime/live JSON, native rendered images, `review/*_AB_24fps.gif`, phase sheets, full-camera sheets, sole observations, and the manual-window screenshot. Export/protection JSON lives beside the safe export copies. Shell logs and production hashes live in root `.validation/locomotion_r4g/`.

## Files added and reproduction

Existing tracked files modified: **none**.

- `blender/characters/player/cuboid/export_locomotion_r4g.py`: background-only safe export.
- `blender/characters/player/cuboid/validate_export_locomotion_r4g.py`: pre-import GLB assembly and source validation.
- `blender/characters/player/cuboid/assemble_locomotion_r4g_review.py`: normal-speed A/B packaging and proxy summary.
- `blender/characters/player/cuboid/export/locomotion_r4g/`: six raw intermediates, safe Action-copy `.blend`, source/sole fixtures, preservation and validation JSON.
- `game_mobile_3d/assets/test/player_cuboid_locomotion_v2_test.glb` and `.import`.
- `game_mobile_3d/scenes/dev/LocomotionTurningLab.tscn`, `locomotion_lab_actor.gd`, `locomotion_turning_lab.gd`, and generated script UIDs.
- `game_mobile_3d/tests/validate_locomotion_r4g.gd`, `validate_locomotion_r4g_live.gd`, `capture_locomotion_r4g.gd`, `open_locomotion_r4g.gd`, and generated UIDs.
- This report and `docs/superpowers/plans/2026-10-07-locomotion-turning-lab.md`.

Open the standalone scene with Godot, or launch `--path game_mobile_3d res://scenes/dev/LocomotionTurningLab.tscn`. Validation scripts run with `--headless --path game_mobile_3d --script res://tests/validate_locomotion_r4g.gd` and the equivalent live-test script. Capture uses `--rendering-method mobile --rendering-driver d3d12 --fixed-fps 120 --resolution 960x540 --script res://tests/capture_locomotion_r4g.gd`, followed by the review packager. The lab is left open in manual mode for WASD/Shift testing.
