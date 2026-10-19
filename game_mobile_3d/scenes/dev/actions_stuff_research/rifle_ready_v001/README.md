**Aim lift correction after user feedback,2026-10-19:** The initial Ready→Aim blend contained an unintended axial arm spin from incompatible source roll frames. Runtime-only equivalent rectangular-arm frame retargeting removes it, while preserving shoulder/palm/long-axis/occupied volume and exact rifle pose. Carrier attachment is recomputed, not rotated with the arm-frame correction. Approved Blender source and Ready clips are unchanged.30/60FPS transitions and contacts pass; details in the Aim integration review.

**2026-10-19 — Approved Aim integrated:** Hold right mouse to Aim; release to Ready. Right-drag still orbits. The exact `Crossbow_Aim_ActionsStuff_Refined_Test_v001` is in a separate `aim_approved_library.res` / `aim_profile.json`; the existing Ready library/profile are untouched. The0.24s reversible upper-body layer preserves the approved7deg head lean, breathing, right grip and animated support. Ground gait/root/legs and physical Jump/Landing remain in the current pipeline. Latest explicit user travel targets are2.70/~7.55m/s, animation1x, acceleration40/deceleration35. This supersedes the older1.25x travel note below. No new project/scene/Action or Fire/Recoil. Research-only; see `../../../../../docs/animation/reviews/rifle_aim_gameplay_v001/README.md` for validation, limits and Aim-only rebuild instructions.

**2026-10-18 — latest user tuning: animation1× / travel1.25×:** User found the accelerated rifle gait less natural. The SAME `ActionsStuffWalkRunTest` now defaults to `locomotion_animation_multiplier=1.0` and `movement_speed_multiplier=1.25`: normal Walk1.25Hz / Run1.60Hz, travel2.25/6.28875m/s, acceleration40/deceleration35m/s². This supersedes the earlier1.5× playback/travel preferences. Approved hand/shoulder/gun-sway data, Blender Actions/Showcase, Idle, camera and jump physics are unchanged. The optional retiming adapter remains reversible but is bypassed at1×. Actual movement/cadence, Idle/jump and rifle contacts/transitions pass at30/60FPS. No new Action, project/scene or production change.

**2026-10-18 — Rifle Walk/Run animation playback 1.5× (user requested):** In the SAME `ActionsStuffWalkRunTest`, `locomotion_animation_multiplier=1.5` now retimes the shared rifle gait/clip cursor. Actual Walk cadence1.875Hz / Run2.40Hz matches the already approved1.5× travel (2.70/7.5465m/s); travel is not multiplied again. Approved poses, shoulder placement, support life and gun-sway amplitudes/relative timing remain in the same immutable library/source Actions. Idle/lifetime, input/filter/blend clocks, physics and camera stay real-time. Ground phase seeds the existing jump bridge before takeoff; jump layers retain original timing and authored phase overrides. 30/60FPS measured phase/actual travel/contact/transition checks plus native30FPS gameplay capture pass. No new Action/scene/project, production or Blender change. This supersedes the previous note preserving original gameplay locomotion cadence only; immutable source timing remains unchanged.

# Approved Rifle Ready locomotion — gameplay integration

2026-10-18 update. Research-only, not production eligible. The user approved the Blender results and explicitly authorized this integration. No additional artistic gate is required before playing it.

Open `res://scenes/dev/ActionsStuffWalkRunTest.tscn` in the existing `game_mobile_3d` project and press **F6**. F5 still launches the existing main game. WASD walks, Shift runs, Space jumps, R resets, right-drag orbits, and the wheel zooms. The scene defaults to `rifle_ready = true`; setting that existing scene property to false restores the preserved unarmed research pipeline. No second scene or project was created.

## Approved sources

| State | Blender Action | Complete bake |
| --- | --- | --- |
| Idle | `Rifle_Ready_Idle_ActionsStyle_v004` | 10.8 s |
| Walk | `Rifle_Ready_Walk_ActionsStyle_v0012` | 7.2 s; 0.8 s gait |
| Run | `Rifle_Ready_Run_ActionsStyle_v002` | 90 s; 0.625 s gait |

`profile.json` pins source files, Action hashes, periods, rifle calibration and tiny independent support-hand motion. `approved_library.res` retains all evaluated bone position/rotation/scale channels, sampled at the native 240 Hz bake times plus source breakpoints. The complete long Run loop retains the combined gait/bob period. Existing approved source files/curves are unchanged; only Showcase approval metadata was updated.

The new Walk carries the approved ±3° Chest-led sway/60 ms lag; Run carries ±9°/40 ms and the latest Walking-matched shoulder attachment. The contact solver preserves authored moving shoulder origins instead of projecting them to the old fixed rest socket; intermediate rendered poses interpolate the movement weight. The accepted Idle clip and its contact solve are preserved.

The actual Rifle Stylized V2 uses the existing character, skeleton, weapon socket and marker arrays. Its approved placement is retained. After state blending and pose inertialization, the right grip is reattached to the displayed right arm and the straight left arm follows the approved moving support target. This preserves the tiny support-side breathing response rather than pinning it to a constant point. The same contact correction is applied to intermediate rendered poses so the weapon and hands share one displayed pose. There are no new knees or elbows.

## Transitions and limits

- Idle/locomotion blend takes 0.14 s, without delaying movement input. Idle observation stops advancing immediately on movement; its cursor resets only once fully hidden.
- Walk/Run reuses the existing approximately 0.22 s controller blend and cumulative gait phase. Foot-support release/replant, responsive turning and collision-driven jumping remain in the existing architecture. Current user-requested scene travel speeds are 2.70/7.5465 m/s (1.5× the previous 1.8/5.031), with planar acceleration/deceleration scaled equally. Source-query calibration preserves Walk/Run classification and the approved animation cadence; jump height/gravity and camera are unchanged. The scene exposes `movement_speed_multiplier` for reversible tuning. Upward velocity excludes stale floor flags at fast takeoff, including 30 FPS.
- The approved steady clips retain their full motion. During Walk/Run crossfades, clip time is mapped to a common gait phase; their internally baked independent bob clocks therefore briefly time-warp. This is a bounded gameplay adapter, not a new implementation of the complete source crossbow controller VM.
- Space keeps the existing approved Jump/Landing core and legs, with the ready arm set carried relative to the animated Chest. There is no newly authored Rifle Jump Action. Aim, firing and reload behavior are outside this integration.
- Horizontal camera smoothing, vertical jump dead zone, angle, distance, controls and physics are unchanged. Render interpolation uses the existing single skin presentation pipeline; no second character or blur effect is added.

The existing export guard excludes `scenes/dev/actions_stuff_research/` from commercial exports. WorldMap and production gameplay remain unchanged.

## Rebuild

From the repository root, use an external writable staging directory. Replace executable names with their installed paths on macOS/Windows:

```sh
blender --background --disable-autoexec --python game_mobile_3d/scenes/dev/actions_stuff_research/rifle_ready_v001/export_approved.py -- --stage /absolute/external/stage
godot --headless --audio-driver Dummy --path game_mobile_3d --script res://scenes/dev/actions_stuff_research/rifle_ready_v001/build_library.gd -- /absolute/external/stage
```

Each clip is loaded from its own source file and verified against its Action hash. The builder preserves the existing accepted Idle and calibration; it asserts that the supplied Idle hash matches rather than silently replacing it. The prior complete runtime set is in `backups/2026-10-18_before_sway/`.

Raw sample tables, capture movies and temporary fixtures stay outside Git. The compressed runtime `.res` is approximately 10 MiB and is a required research runtime asset. It is below the 25 MiB ordinary-Git warning threshold; no new LFS pattern or tracking migration was introduced.

Current validation and actual Godot screenshots: `docs/animation/reviews/rifle_ready_gameplay_v002/README.md`; earlier integration evidence remains at `docs/animation/reviews/rifle_ready_gameplay_v001/README.md` from the repository root.
