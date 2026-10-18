# Approved rifle Walk/Run sway — existing gameplay update

2026-10-18. The user approved the latest Blender results and requested immediate integration. Research-only, not eligible for commercial exports. No new scene/project/candidate.

Open `res://scenes/dev/ActionsStuffWalkRunTest.tscn` in the existing `game_mobile_3d` project, **F6**. **WASD** walk, **Shift** run, **Space** jump, **R** reset; right-drag orbit, wheel zoom. F5/main WorldMap is unchanged.

- Idle: unchanged `Rifle_Ready_Idle_ActionsStyle_v004`, 10.8 s.
- Walk: approved `Rifle_Ready_Walk_ActionsStyle_v0012`, 7.2 s full clock / 0.8 s gait; ±3° Chest sway, 60 ms holding response.
- Run: approved `Rifle_Ready_Run_ActionsStyle_v002`, 90 s full clock / 0.625 s gait; ±9° Chest sway, 40 ms holding response and latest Walking-matched shoulder placement. Source is `walk_matched_shoulders/run_walk_matched_shoulders.blend` (Action SHA `433d33c3b73c9f5aedd0420b2ab27123521270d22373c83fedae464717d9e76b`).

The existing evaluated PRS pipeline preserves source leg scale, core bounce, head behavior, both straight arms, actual Rifle Stylized V2 and ~1.55 mm support-side life. Each clip is exported from its own manifest-pinned source; older same-named Actions elsewhere are never substituted. Showcase approval metadata updated; source curves/files unchanged.

A regression with the new Blender poses measured the old fixed-rest support solve changing the moving left-arm transform by 0.0413; preserving the authored moving shoulder reduces this to <0.0000007. Render blends use the interpolated movement weight. Accepted Idle contact behavior is retained, and all 103,720 Idle track keys/times/values are exactly equal after saving/reloading the resource.

30/60 FPS checks pass: right-grip transform error <0.0000026; left-support error <0.006 mm; ordinary jump camera-height span 0; no extreme leg resets/floor penetration. 33 independent Blender fixtures pass PRS/rifle placement parity. Existing direction, jump, camera and render-presentation regressions pass. The native Metal capture exercised actual physics, one jump/ground landing and 240 frames at 30 FPS; screenshots below are from that scene. These checks do not claim phone performance or eliminate the inherited gait-phase crossfade clock adaptation.

Existing responsive movement, phase sharing, ~0.14 s Idle blend, Walk/Run controller blend, jump/landing core/legs, speeds 1.8/5.031 m/s and comfortable camera are unchanged. Jump carries the approved arm set relative to the existing Chest; no new rifle Jump Action. Previous runtime library/profile/scripts and their checksums remain together under `game_mobile_3d/scenes/dev/actions_stuff_research/rifle_ready_v001/backups/2026-10-18_before_sway/`; prior source studies/Showcases are preserved. `rifle_ready=false` still selects unarmed research.

Raw export tables and AVI capture stay outside Git in the task workspace. The required compressed runtime resource and its retained backup are each ~10 MiB, below the ordinary-Git 25 MiB warning threshold; no new LFS pattern, tracking migration, history rewrite or push. Existing dev export exclusions still apply.

![Walking, actual Godot](front_56.png)
![Running and jump, actual Godot](front_94.png)

See `validation.json` for machine-readable evidence and the existing runtime README for rebuilding.
