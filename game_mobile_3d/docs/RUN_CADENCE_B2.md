# Run cadence B2

The only gameplay runtime edit is `scripts/player_animation_v2.gd`: configurable
`run_animation_speed_scale = 1.60` multiplies the existing continuous authored
Run clock. No phase reset, clip resource changes, root motion, IK, new bone
correction, controller or weapon edits. The 0.13s blend and Walk are unchanged.
The imported Run remains 0.6666666865s; playback cycle is 0.4166666791s.

## Measurement

641 samples of the actual imported Run's skeleton-space global transforms.
Forward is +Z. Effective foot is the bottom-center of each rigid 0.675m leg.
Support intervals use the lowest of the four sole corners <=12mm above floor.
The center trajectory avoids jumping between toe/heel corners. This is a
practical estimate for rigid cuboids, not an exact anatomical ground contact.

- Right support: cycle phase 0.9828 through wrapped 0.2609, 0.18542s,
  backward displacement 0.58312m, mean local velocity -3.14491m/s.
- Left support: phase 0.48125–0.75938, 0.18542s, displacement 0.61059m,
  mean local velocity -3.29309m/s.
- Average implied ground speed at 1x = 3.21900m/s.
- Effective step = implied speed * half-cycle = 1.07300m.
- Effective full-cycle travel = implied speed * 0.666667 = 2.14600m.
  These effective travel estimates include flight time; measured stance
  displacement itself is approximately 0.597m per supporting leg.
- Mean-slip matching multiplier = 6.25 / 3.21900 = 1.94160.
- Minimum RMS-slip multiplier = -6.25*mean(v)/mean(v²) = 1.57965.
  v ranges -5.32356 to +0.64570m/s; one scalar cannot plant the entire support.

## Candidate evaluation

| Scale | Net support drift | RMS slip m/s | Cycle s | Cycles/s | Steps/s |
|---|---:|---:|---:|---:|---:|
| 1.000 baseline | +56.20cm | 3.400 | .66667 | 1.500 | 3.000 |
| **1.600 selected** | **+12.74cm** | **2.699** | **.41667** | **2.400** | **4.800** |
| 1.65036 (-15%) | +10.53cm | 2.710 | .40395 | 2.476 | 4.951 |
| 1.79598 (-7.5%) | +4.84cm | 2.807 | .37120 | 2.694 | 5.388 |
| 1.94160 matched mean | 0cm mean | 2.992 | .34336 | 2.912 | 5.825 |
| 2.08722 (+7.5%) | -4.16cm | 3.250 | .31940 | 3.131 | 6.262 |
| 2.23284 (+15%) | -7.79cm | 3.566 | .29857 | 3.349 | 6.699 |

Positive = forward relative to ground. The full JSON also evaluates 1.35, 1.50,
1.65, 1.80 and 2.00. Rendered candidate previews use 1.00, 1.50, 1.60, 1.65,
1.94160 with the actual gameplay camera; these overrides exist only in the test.
1.60 gives brisk readable cadence, near the RMS optimum. 1.94160 gives a busier
5.825 steps/s while increasing oscillatory slip. The selected net drift falls
about 77%, but RMS slip falls only about 20%; remaining slip is still visible.
Mean forward slip at 1.60 is 1.0996m/s, absolute slip ~0.234m per support.

## Validation and review

36 headless and rendered integration checks pass, including 11.04 continuous
Run cycles through circles/diagonals, start/stop, direction changes, wall/floor
collision, camera, 3 weapon profiles, exact authored rotations, unit bone scale,
zero Root translation and no Run clock resets. The existing 798 movement/weapon
regression checks also pass. Walk=4.25m/s and Run=6.25m/s remain unchanged.
Source GLB and Blender test/production hashes remain unchanged. No phone device
performance test was performed. Sandboxed rendered tests reported only the
known user:// shader-cache permission warning, not gameplay errors.

Reports: `tests/run_cadence_measurement.json` and
`tests/run_cadence_integration_validation.json`. Visual comparison:
`tests/run_cadence_comparison.gif`. This is a recommendation awaiting visual
approval; no weapon alignment, Walk, Sprint, IK or Blender changes follow it.

Exact code/document files changed or added in B2:

- scripts/player_animation_v2.gd (runtime property and clock multiplier)
- tests/validate_blocky_v7_integration.gd (cadence-aware timing and circles QA)
- tests/measure_run_cadence.gd (new offline skeleton sampler)
- tests/analyze_run_cadence.py (new mathematical comparison)
- tests/review_run_cadence.gd (new temporary rendered candidate overrides)
- tests/assemble_cadence_review.py (new comparison GIF)
- docs/RUN_CADENCE_B2.md (this report)
