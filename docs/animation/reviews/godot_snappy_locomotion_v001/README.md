# Snappy locomotion gameplay review — 2026-10-14

The current recommended test is [Fast + Jump](fast_jump/README.md), matching the user's existing Expressive test speed, camera angle, distance and zoom. The earlier native-speed test and all its evidence remain preserved here.

Open `game_mobile_3d/scenes/dev/SnappyLocomotionTest.tscn` and press F6 for native1.59936 m/s Walk /2.5 m/s Run. WASD/arrows move, Shift runs, Tab switches style,1/2/3 select front/three-quarter/side,4 follow,R reset,F9 demo,F8 frame cap. This original variant has no jump branch.

- [Native Snappy original-speed gameplay](gameplay_snappy_1x.mp4)
- [Native Expressive original-speed gameplay](gameplay_expressive_1x.mp4)
- [Live style toggle](gameplay_style_toggle_1x.mp4)
- [Same-control comparison](snappy_vs_expressive_1x.mp4)
- [Source motion diagnosis](source_motion_diagnosis.json)
- [Read-only export validation](export_validation.json)
- [Artistic approval verification](approval_validation.json)
- [30 FPS report](runtime30.json) / [60 FPS report](runtime60.json)

Native test:72 checks pass at each rendered frame rate, physics60 Hz. The source export reproduces loop boundaries within0.000001 m, unit scale and the actual Action signatures. Single inherited pose writer; no competing animation layers. Gait phase persists across A/B, receiving-phase gated140 ms Walk/Run handoff, distance-driven cadence and sole-height-aware support retain the source Walk hop. Cached rigid-leg support, limited twist and smooth carried release handle direction changes; sequential stop replant finishes both feet before Idle. Reset cancels every contact/replant cache. Tab is reserved before GUI focus consumes it.

Movies are397frames/30FPS fixed-step engine captures, not phone performance benchmarks. Same capsule controls/travel in both styles; Expressive cadence is distance-driven, not an exact legacy pace replay. Old production scripts, scenes, settings, approved libraries, all prior Blender Actions and source backups are unchanged. Showcase metadata alone records the user's explicit artistic approval of current Snappy Walk v003 and Run V1; production promotion remains unapproved.

Stop for gameplay/artistic review. No additional animations begun.

[Final preservation audit](preservation_validation.json):7430 baseline files checked, no unexpected changes or missing files; all original Godot files exact.
