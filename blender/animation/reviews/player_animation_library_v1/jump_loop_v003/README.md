# Walk/run + jump loops V003 — Blender review

2026-10-10. The user rejected V002's held airborne stride and requested continuous
walking/running footwork with a clean loop. V003 adds **Walk + Jump LOOP V003** and
**Run + Jump LOOP V003** to Player Review → Jump (study only) in the same
`../player_animation_library_v1.blend`. Space plays; Side makes the leg cycle easiest
to compare. V002, stationary jump and all older animations are preserved.

| Action | Loop period, 30 FPS | Closing key | Push / contact, seconds | Preview arc |
|---|---|---|---|---|
| `Jump_Walk_Loop_v003` | 28 frames / 0.933333 s | F29 equals F1 | 0.200000 / 0.733333 | 0.50 m |
| `Jump_Run_Loop_v003` | 26 frames / 0.866667 s | F27 equals F1 | 0.133333 / 0.666667 | 0.58 m |

Each scene shows **three continuous cycles**, 84/78 displayed frames, without a
duplicated closing frame, rest holds or preview cuts. The camera and review lights
follow forward travel; pose, vertical support and phase repeat. The long runway
position resets when Blender wraps the full preview, not between its three cycles.

## What changed and why

The new user clip is preserved as `references/user_runtime_problem.mp4` (218 frames,
30 FPS, 7.267 s); metadata/hash and extracted frames accompany it. It is evidence
of the reported game appearance, not a measurement of reference-game physics.
V002 curve audit found 10°/8° right-leg endpoint mismatch and only 2.85°/5° movement
over its eight-frame held interval. Its earlier geometry audit did **not** test
loop quality; preserve that historical result rather than calling V002 a good loop.

V003 derives a periodic copy from the existing Walk/Sprint lower-body gait, with
six Fourier harmonics and scaled stride. Source keys stay unchanged. Both legs keep
stepping during ascent and descent; arms counter-swing, torso absorbs contact, hips
sway laterally. The full stride continues through the loop join. New curves have
matching values and tangents at F1/P+1, with Cycles modifiers and no waiting interval.
Walk and Run retain distinct stride, arm swing and lean. Timing/arc/stride are
authored review choices, **not user-approved final animation**.

## Preservation and limits

- 320 previous Actions and all previous scene ranges/FPS retained. Two new pose
  Actions plus two separate preview travel Actions: 324 total, 59 sidebar choices.
- Same mesh/material/UV/weights and 14-bone rest rig, full arms/hands. Original
  neutral shoulder inset remains in old assets; new moving poses use the existing
  8 mm shoulder clearance adjustment. No knees, ankles, stretch or scale tracks.
- Pose includes periodic Hips lateral sway and subtle gait leg location channels.
  **No Root translation, forward travel or ballistic arc is in the pose Action.**
  Carrier Y supplies only preview motion (1.45/2.5 m/s); carrier Z contains the arc
  plus a smooth sole support correction. Do not export that combined Z as Hips.
- Ground support uses actual evaluated sole corners, with ~0.3–1.214 mm clearance.
  This prevents penetration; it does **not** lock foot X/Y to the ground. Rigid feet
  can roll/slide. Exact gait transition blending, variable speed, early/late contact,
  weapons, slopes and phone performance are still unverified.
- Current Godot V002 integration was already changed in another work stream when
  this task began. This task modifies Blender and documentation only.

## Contract for a later game integration

1. Export the new **pose** Action with a loop duration of P/30 seconds. Preserve the
   closing sample for interpolation, but do not play it as an extra held frame.
2. Maintain normalized gait/jump phase across repeats. A wrap continues the same
   movement; do not restart the old entry/exit fade, reset to idle or replace the
   moving legs with V002's held stride on every hop.
3. Physics owns world height and travel; the carrier is excluded. Recompute support
   from final composed soles, or bake only a separately derived support correction.
   Do not copy the old V002 exporter timings/height decomposition blindly.
4. When changing walk/run or leaving the loop, match gait phase and blend once at
   the transition. One final pose writer must resolve gait/jump/weapon layers.
   The old runtime's per-hop blending/masks are **not validated for this new Action**.
5. Verify actual game footage, contacts and repeated inputs after export. Blender
   continuity is not proof that an unchanged game controller will play it correctly.

## Evidence and reproduction

[`walk_loop_1x.mp4`](walk_loop_1x.mp4) and [`run_loop_1x.mp4`](run_loop_1x.mp4) show
actual sequential scene renders, 3/4 + Side together, three cycles at 1×/30 FPS.
Contact sheets show airborne stepping and the actual end/next-start samples.
`media_validation.json` records full decode and media hashes.

`validate_loops.py` checks source hashes, rest/mesh preservation, curve endpoints and
tangents, three repetitions, floor contact, camera bounds and constant relative
light placement. Across 1,298 evaluated samples, repeated poses agree within
0.36 µm; endpoint channel error is zero, tangent error below 1.1e-6 per frame.
Airborne right-leg sweep is 43.18° walk / 53.35° run. Quarter-frame SAT finds no new
overlap in 21 nonadjacent rigid-part pairs beyond the original neutral baseline
(10 µm tolerance); existing Chest/ForeArm seam overlap and adjacent joints are not
claimed eliminated. Read `validation.json` for measurements, `manifest.json` for
Action/slot/camera and preservation hashes. Parent `verify_review.py --skip-renders`
checks all selections. Intermediate files are under `.validation/jump_loop_v003/`.

`build_loops.py` creates only new scenes/Actions and rejects name collisions.
`integrate_library.py` exposes them additively; render/package/encode scripts never
save render settings over the shared library. **Pending human visual review.**

## Subsequent runtime integration request

The user subsequently requested these two loops in main WorldMap and a jump above
one block. See [runtime V003](../../../../../game_mobile_3d/assets/characters/jump_loop_v003/README.md).
`export_runtime.py` reads this saved library without changing it; a versioned GLB
appends two clips to V002. Runtime physics uses a 1.20 m arc independently of the
preview. Earlier Blender-only statements above describe the original study scope.
Integration does not establish artistic approval.
