**Current scene update — 2026-10-12:** the same isolated F6 scene now includes physics-driven Pending Jump V2. See [the jump gameplay review](../godot_jump_v1/README.md) for Space/jump controls and latest evidence. The locomotion-only records and clips below remain preserved historical checkpoints. Walk/Run stay 1.5x and Idle 1x. Production remains unchanged.

# Expressive locomotion gameplay test — Pending

Open `game_mobile_3d/scenes/dev/ExpressiveLocomotionTest.tscn` in Godot and press **F6 (Run Current Scene)**. F5 still runs the unchanged WorldMap. This separate flat-ground scene uses the approved Idle v3, refined Walk and Run v3; it does not replace production locomotion or integrate Jump.

## Latest pace refinement

The user found the first 2× trial too fast. The default is now **1.5× movement and gait**, with **Idle at its original 1× speed**. Walk travels at 1.35 m/s with a 0.8-second cycle; Run travels at 3.465 m/s with a 0.444-second cycle. Idle stays eight seconds, including the original breathing and observation timing. Source Actions and poses are unchanged.

Travel, cadence, turning and movement settling are adjusted together. Acceleration/deceleration scale with pace squared to retain the corresponding shorter response time. Global engine time and gravity are unchanged. Press **T / Compare pace** to cycle 1× → 1.5× → 2× movement pace; Idle remains normal at every setting. The exact earlier all-2× candidate is archived under `.validation/expressive_locomotion_v1/before_moderate_pace/`, and the original candidate under `before_double_pace/`.

## Controls and review

| Control | Behavior |
|---|---|
| WASD / arrows | Walk; slider adjusts input strength |
| Shift / RUN | Run |
| R / Reset | Return to test origin |
| 1 / 2 / 3 | Front / three-quarter / side camera |
| T / Compare pace | Original / moderate / fast travel and gait |
| F9 / Demo | Scripted three-view review sequence |
| E / Rifle layer | Optional existing upper-body carry/socket smoke test |

Onscreen directional buttons support touch review. This is a test control scheme, not an integrated production mobile HUD.

Latest video: [1.5× gameplay, recorded at original speed](gameplay_pace1_5x_1x.mp4). It contains three-quarter, side and front views, starts, stops, Walk↔Run and a diagonal direction change. The 547-frame recording is 18.233 seconds at 30 FPS, rendered by actual Godot Mobile/D3D12. Engine `time_scale` is 1; playback was not retimed. Earlier [1×](gameplay_1x.mp4) and [all-2×](gameplay_pace2x_1x.mp4) recordings remain available. The latter predates restoration of normal Idle speed.

## What the integration does

The existing full-arm runtime model and R15 pose-writer architecture are reused. Only three approved Actions are sampled into the additional native library. There is no competing AnimationTree pose writer. Existing upper-body masks remain above the expressive lower-body pose.

Walk and Run share normalized phase: **0 = LEFT receiving, 0.5 = RIGHT receiving**. Actual capsule speed drives cadence using 1.08 m Walk and 1.54 m Run cycle travel. Speed-based blending preserves the moving gait clock. Unequal authored support durations remain: Walk 60% left / 62% right; Run 42% / 43%. Support can release earlier during acceleration; deceleration cannot re-ground an already released foot until its next receiving phase.

Input moves the capsule immediately and interrupts Idle attention using pose/velocity residuals rather than waiting for an observation hold. Stops replant one foot at a time between the narrower gait and asymmetric Idle base. Bounded world contact correction uses existing rigid leg articulation and translation; there are no invented knees/ankles or scale changes.

## Validation and limits

Fresh separate-process tests pass **41 checks at 30 FPS and 41 at 60 FPS**, with 60 Hz physics. The 1× and 2× comparison settings also pass 41 checks at 30 FPS. Checks include Idle speed independence, travel/cadence matching, immediate interruption from three Idle moments, gait phase, both lead feet, support/flight stops, short taps, floor clearance, rigidity and upper-layer mask availability. Detailed evidence: `runtime30.json`, `runtime60.json`, `runtime1x.json`, `runtime2x.json`.

At the default pace, steady straight-line Walk/Run contact-center drift is below **0.06 mm/s**, and maximum floor penetration is **0.12 mm**. This measures the lowest sole height and center anchor; a rigid boot can still rock around its edges because the character has no ankle.

Sharp reversals remain the main limitation. The correction is capped at 14 cm to protect the hip attachment, then releases its anchor. Across the stress test, excess contact residual reaches **8.6 cm at 30 FPS / 4.8 cm at 60 FPS**, with brief pivot slip. No claim of perfectly planted 180° turns is made. Optional rifle-layer changes still produce large arm pose changes (up to 43° between 30 FPS samples); that smoke test does not certify combat, firing, strafing, draw or holster transitions. Terrain, slopes and device performance remain untested. Desktop offline movie timings are not phone benchmarks.

This is a **Pending gameplay review candidate**, not production-ready locomotion. Production speeds, weapon systems, WorldMap, its existing jump integration, all Blender sources, Actions, Showcase and manifest remain unchanged. No new Blender Action was authored, so no additional Showcase entry is needed. Run v3 retains its explicit artistic approval as the preferred Run baseline.

See [the exported library notes](../../../../game_mobile_3d/assets/characters/expressive_locomotion_v1/README.md) and `preservation_validation.json` for rebuild and preservation evidence.
