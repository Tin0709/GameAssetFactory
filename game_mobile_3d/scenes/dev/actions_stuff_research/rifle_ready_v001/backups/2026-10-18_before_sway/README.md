# Approved Rifle Ready locomotion — gameplay integration

2026-10-17. Research-only, not production eligible. The user approved the Blender results and explicitly authorized this integration. No additional artistic gate is required before playing it.

Open `res://scenes/dev/ActionsStuffWalkRunTest.tscn` in the existing `game_mobile_3d` project and press **F6**. F5 still launches the existing main game. WASD walks, Shift runs, Space jumps, R resets, right-drag orbits, and the wheel zooms. The scene defaults to `rifle_ready = true`; setting that existing scene property to false restores the preserved unarmed research pipeline. No second scene or project was created.

## Approved sources

| State | Blender Action | Complete bake |
| --- | --- | --- |
| Idle | `Rifle_Ready_Idle_ActionsStyle_v004` | 10.8 s |
| Walk | `Rifle_Ready_Walk_ActionsStyle_v001` | 7.2 s; 0.8 s gait |
| Run | `Rifle_Ready_Run_ActionsStyle_v001` | 90 s; 0.625 s gait |

`profile.json` pins source files, Action hashes, periods, rifle calibration and tiny independent support-hand motion. `approved_library.res` retains all evaluated bone position/rotation/scale channels, sampled at the native 240 Hz bake times plus source breakpoints. The complete long Run loop retains the combined gait/bob period. Existing approved source files/curves are unchanged; only Showcase approval metadata was updated.

The actual Rifle Stylized V2 uses the existing character, skeleton, weapon socket and marker arrays. Its approved placement is retained. After state blending and pose inertialization, the right grip is reattached to the displayed right arm and the straight left arm follows the approved moving support target. This preserves the tiny support-side breathing response rather than pinning it to a constant point. The same contact correction is applied to intermediate rendered poses so the weapon and hands share one displayed pose. There are no new knees or elbows.

## Transitions and limits

- Idle/locomotion blend takes 0.14 s, without delaying movement input. Idle observation stops advancing immediately on movement; its cursor resets only once fully hidden.
- Walk/Run reuses the existing approximately 0.22 s controller blend and cumulative gait phase. Foot-support release/replant, responsive turning and collision-driven jumping remain in the existing architecture. Travel speeds remain 1.8/5.031 m/s.
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

Raw sample tables, capture movies and temporary fixtures stay outside Git. The compressed runtime `.res` is approximately 10 MiB and is a required research runtime asset. It is below the 25 MiB ordinary-Git warning threshold; no new LFS pattern or tracking migration was introduced.

Validation and actual Godot screenshots: `docs/animation/reviews/rifle_ready_gameplay_v001/README.md` from the repository root.
