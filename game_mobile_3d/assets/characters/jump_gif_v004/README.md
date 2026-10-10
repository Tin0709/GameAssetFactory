# Jump + Land V004 — WorldMap review

2026-10-10. Explicit user selection: use the saved straight-arm V004 for
**stationary, walking and running** jumps. F5 still runs WorldMap; SPACE jumps,
WASD/Shift retain the existing speeds, held SPACE while running repeats after
supported recovery. V001–V003, their source Actions and earlier scenes remain.
**ARTISTIC STATUS: AWAITING HUMAN REVIEW.**

## Source and import

[Blender guide](../../../../blender/animation/reviews/player_animation_library_v1/jump_dungeons_gif_v004/README.md)
documents the two GIF references, straight arms, 324 preserved Actions and the
same saved `player_animation_library_v1.blend`. The runtime GLB appends
`Jump_DungeonsII_Combined_v004` to the unchanged V003 binary/geometry/skin/UV/material
and all 42 old raw clips; 43 imported clips result. The post-import script copies
the previous imported clip masks, keys, interpolation and loops unchanged.

141 samples at 120 Hz, 22 pose tracks; length35/30 s. Preview carrier/arc/world
travel, Root motion and scale are excluded. `source.json` stores the sampled
source pose; `export_validation.json` records SHA256, unchanged source/base and
maximum vertex reconstruction error **6.405e−7 m**. Re-export only through the
connected foreground Blender using the study's `export_runtime.py`; do not reload
or background-save the user's library.

## Motion and camera contract

- Same complete nonperiodic V004 for all states: takeoff5/30 s, nominal
  contact22/30 s, end35/30 s. Physics retains a **1.20 m** apex and owns collisions;
  the Blender preview's 0.62 m arc is not exported into the capsule.
- A raised surface enters Land on actual collision. The current pose blends
  toward authored contact over4/30 s, with recovery lasting13/30 s. A long drop
  holds the last aerial pose; no takeoff replay or midair jump impulse.
- User clips `144458` and `145052` exposed held parallel landing legs and closed
  legs at moving anticipation. Moving takeoff now keeps Hips/legs on the live
  Walk/Sprint gait while grounded, then blends into V004 over**7/30 s after
  lift-off**. Stationary takeoff keeps the complete authored anticipation.
- At actual landing, moving lower-body release begins immediately and blends
  back to the continuously advancing gait over**6/30 s**. Upper body continues
  Jump Land. The gait-release request latches so slowing down cannot restore a
  closed-leg pose midway through recovery. Stationary landing stays authored;
  starting movement during recovery also requests gait release.
- There is one final pose writer. Its final sole correction uses the composed
  legs, not the unblended source. Unarmed forearms remain straight; weapon grips,
  aim/recoil/holster and the20° torso limit retain the existing weapon layers.
- Gameplay camera stores supported ground Y, holds it through anticipation and
  flight, and follows X/Z normally. New landing elevation settles with a0.16 s
  exponential response. Reset immediately replaces the anchor; overview remains
  fixed. The cutaway target still uses actual player position.

## Verification and actual pixels

Evidence is in `game_mobile_3d/.validation/jump_gif_v004/`:

- `checks_red_takeoff.json` reproduces both moving anticipation failures;
  `checks_red_landing_slide.json` reproduces zero landing stride. The earlier
  2/30 s release also produced a46.59°/render-frame snap at30 FPS and was replaced.
- `checks_final_30.json` / `checks_final_60.json`:31 checks each. Live grounded
  anticipation matches the same underlying gait phase with0° leg error. Authored
  legs match after the airborne blend, unarmed elbows0°, jump-camera Y drift0 m,
  X/Z-follow error0 m, physics apex approximately1.196–1.200 m.
- `edges_final_30.json` / `edges_final_60.json`:31 checks each, including early
  contact, ceiling,10m drop, held repeats/release, reset/death, three weapon grips,
  and an original WorldMap1m terrace with smooth-step assistance off. Maximum
  consecutive right-leg angle in the held-run30 FPS fixture is32.88°; this is a
  bounded transition check, not a perceptual smoothness score or foot locking.
- `import_checks.json`:43 checks, all42 prior imported clips retain their keys,
  paths, lengths, loops, interpolation/enabled flags and transitions; one V004 added.
- WorldMap1052 checks/394 raycasts and smooth-step100 checks pass. Tests use
  process-local Dummy audio. User F5 keeps normal audio.

[Actual game video](../../../.validation/jump_gif_v004/gameplay.mp4),
[contact sheet](../../../.validation/jump_gif_v004/contact_sheet.jpg),
[walk transition frames](../../../.validation/jump_gif_v004/walk_transitions.jpg),
[run transition frames](../../../.validation/jump_gif_v004/run_transitions.jpg),
[capture metadata](../../../.validation/jump_gif_v004/capture.json) and
[full decode/hash](../../../.validation/jump_gif_v004/video_checks.json) show Mobile/D3D12,
872 frames/30 FPS/1280×720,29.067 s. Reviewed stationary/gameplay view, close walk
and run, held-run release, original terrace ascent and rifle. The clear review row
is original terrain; no replacement floor/material/lighting. Tall plants sometimes
cover the feet. Rigid legs still roll/cross during gait; no knees/ankle IK or full
foot locking is claimed. This offline desktop capture does not measure phone FPS.

```text
godot --headless --path game_mobile_3d --audio-driver Dummy --fixed-fps 30 --script res://tests/validate_jump_gif_v004.gd -- --report=final_30
godot --headless --path game_mobile_3d --audio-driver Dummy --fixed-fps 30 --script res://tests/validate_jump_gif_v004_edges.gd -- --report=final_30
godot --headless --path game_mobile_3d --audio-driver Dummy --script res://tests/validate_jump_gif_v004_import.gd
godot --path game_mobile_3d --audio-driver Dummy --rendering-method mobile --rendering-driver d3d12 --fixed-fps 30 --write-movie res://.validation/jump_gif_v004/gameplay.avi --script res://tests/review_jump_gif_v004.gd
```

Repeat the two motion suites at60 FPS. Encode real AVI pixels with
`tests/encode_jump_gif_v004_review.py` through foreground Blender; its temporary
scene is removed and the original review scene restored. Keep the source GLB,
library and frozen graphics presets intact.
