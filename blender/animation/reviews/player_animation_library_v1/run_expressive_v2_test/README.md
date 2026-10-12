# Run Expressive v2 Test

**Pending user review — 2026-10-12.** Separate `Run_Expressive_v2_Test` in the existing [Animation Showcase](../../../showcase/Animation_Showcase.blend). The current refined Walk is explicitly approved; its exact source and Action remain unchanged. Original Run, approved Idle v3, all earlier Actions and comparison checkpoints remain preserved.

Open the Showcase, choose **Run_Expressive_v2_Test**, enable Loop and press Play. Playback is **F1–22 at 30 FPS**, with closing key **F23 excluded**: 0.733 seconds per cycle. Original slot `OBRUN_Test_Rig` is retained. The separate [authoring source](run_expressive_v2_review.blend) contains actor `RN2_Test_Rig` / `RN2_Test_Mesh`; no rig rebuild, material, proportion, texture or Godot change was needed.

## Review

- [Front](run_v2_front_1x.mp4), [three-quarter](run_v2_three_quarter_1x.mp4), [side](run_v2_side_1x.mp4).
- [Three views together](run_v2_three_views_1x.mp4): six cycles, 4.4 seconds, original speed.
- [Approved original Run versus Run v2](old_run_vs_run_v2_1x.mp4): 6.6 seconds, unchanged native timing; original Run begins at its left receiving F10 to align the initial lead foot. Old poses are rendered on the same unchanged actor/stage/camera as v2.
- [Approved refined Walk versus Run v2](walk_vs_run_v2_1x.mp4): 13.2 seconds, eleven Walk cycles and eighteen Run cycles, unchanged native timing. Both start at left receiving contact.
- [Traveling contact diagnostic](run_v2_contact_travel_1x.mp4): three cycles at nominal 2.1 m/s, temporary actor/camera translation and floor markers only. No travel Action is saved or imported.
- [Stride poses](run_v2_pose_sheet.jpg) and [complete cycle](run_v2_complete_cycle.jpg).

Every video uses 30 FPS and omits duplicate closing keys. These are Blender review videos, not gameplay footage.

## Motion evaluation

The new gait carries the approved Walk's close support logic into a faster rhythm. Tracks remain **0.27 m** apart; toe-out reduces to **3°**, with very small unequal lateral leg lean. Sideways hip travel is **26 mm** total, quieter than Walk's 38 mm. Fore/aft hip travel increases to **50 mm**, and a receiving dip followed by push-off produces **43 mm** of hip-height range. This is stride-driven loading and release, rather than an independent breathing or bouncing loop.

Measured maximum fore/aft leg split is **64.8°**, versus **45.6°** in the refined Walk and **102.6°** in the original Run. V2 uses a 22-frame cycle versus Walk's 36 and the original Run's 18: a deliberately more grounded progression from Walk, with less extreme rear kick than the original exploratory Run. It is separately Pending, not a replacement of that approved Action.

Straight full arms use unequal 39°/42° driving amplitudes, delayed shoulder response and controlled outward arcs. The forward body lean and partial torso counter-rotation support the stronger stride; the head remains forward-readable, below 4° world rotation per axis. Both receiving poses retain opposing arm/leg motion. No knee, ankle, elbow bending or mesh scaling is invented.

Support occupies **42% left / 43% right** of the cycle, with **15% total flight**, no double support. Whole rigid boots rock on their lowest sole corners/edges. At nominal straight travel, measured planted drift is about **0.003 mm**; saved-source checks find no floor penetration, thigh intersection, detached waist or nonadjacent body collision. The rigid-leg limit remains: absorption and recovery use block rotation and bounded hip overlap rather than anatomical knee/ankle articulation. Slopes, turns and variable speeds are not validated here.

## Gait phases and transition contract

| Event | Walk | Run v2 | Meaning |
| --- | --- | --- | --- |
| Left receiving contact | F1 / phase 0 | F1 / phase 0 | Left receives, right supports in Walk but recovers in Run |
| Right receiving contact | F19 / phase 0.5 | F12 / phase 0.5 | Opposite lead foot |
| Left loading | — | Around F2.65 | Hip low after receiving |
| Left release → flight | — | F10.24 → F12 | Brief unsupported interval |
| Right loading | — | Around F13.65 | Opposite receiving dip |
| Right release → flight | — | F21.46 → F23 | Last interval repeats into left contact |
| Playback / closing | F1–36 / F37 excluded | F1–22 / F23 excluded | Seamless repeating Actions |

The same rest rig, pose rotation modes, slot convention, identity object/Root and forward **−Y** convention are preserved. The controller owns world travel; nominal speeds are **0.9 m/s Walk** and **2.1 m/s Run v2**. Matching receiving corners differ by roughly 5 mm or less; other limbs and velocities differ deliberately. Phase alignment is a useful starting contract, not proof of a safe crossfade.

Walk's 22% double support changes to Run's 15% flight. Future blending must preserve the receiving foot, coordinate speed/phase and release support intentionally; merely interpolating both Actions at arbitrary times will slide feet. Test both lead feet, acceleration/braking, interrupted short taps, arbitrary re-entry and speed changes. Idle v3's wider fixed stance needs a support-aware replant. No idle/start/stop Action or Godot transition was added.

This is a full-body absolute Action, not additive. Weapon layers need an explicit Chest/shoulder/arm mask while hips/legs retain support. Dense offline authoring keys preserve contact for review; export resampling/compression, actual controller blending, weapons, slopes/turns and measured mobile performance targeting **30 FPS** remain future authorized validation. Blender approval alone does not establish production readiness.

## Preservation and validation

Backups, working-tree snapshots and source/library hash guards are under `.validation/run_expressive_v2_test/`. The approved Walk source is used only through a byte-identical authoring copy. All twelve earlier Actions and their sources remain unchanged; only the exact current Walk's approval metadata changes. Previous Walk revisions remain archived in their established checkpoint folders.

[Saved-source checks](validation.json) evaluate 705 subframe poses, rigid dimensions, floor/contact/support phases, intersections, waist attachment, unchanged appearance/rest/weights and original Action signatures. The loop has zero measured pose error and matching channel tangents; the 0.01-frame finite vertex-velocity difference is about 0.0124 m/s, including finite-step acceleration and float error. [Gait verification](gait_verification.json) checks phase/support fractions, arm opposition and restrained head behavior. [Evaluated gait comparison](gait_comparison.json) records motion ranges and receiving-corner differences.

[Showcase verification](showcase_verification.json), [interactive playback](gui_playback.json), [media checks](media_verification.json) and [final preservation audit](final_verification.json) bind checks to saved file/Action hashes. New animations must continue using the same central library and start Pending; preserve this Action after any later explicit approval.
