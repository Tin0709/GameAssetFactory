# Walk Snappy v1 — Pending Blender review

2026-10-13. `Walk_Snappy_Test_v1` is a separate selectable Action in the **existing** `blender/animation/showcase/Animation_Showcase.blend`; 20 entries total. Rifle Ready Idle work is paused at the user's request and preserved byte-for-byte. Approved Idle, Walk, Run and Rifle Ready remain intact. No Running Action, rig, Weapon Showcase, Godot, export or production change.

Open the existing Showcase, hover the 3D viewport and press **N → Animation Library → Walk_Snappy_Test_v1** (Pending). Use **Front / 3/4 / Side**, **Play**, **Loop playback** and **Restart**. Reopen the disk file if an older Blender window still shows19 entries; Refresh Library also reloads the manifest/imports the missing Action. Do not save a stale window over this update.

## Review media — all original speed, 30 FPS

- [Three-view review, six1s cycles](walk_snappy_three_views_1x.mp4)
- [Approved Walk vs Snappy, same6s duration, neither retimed](approved_vs_snappy_1x.mp4)
- [Front](snappy_front_1x.mp4), [three-quarter](snappy_three_quarter_1x.mp4), [side](snappy_side_1x.mp4)
- Still views: [front](snappy_front.png), [3/4](snappy_three_quarter.png), [side](snappy_side.png)
- [Frame-by-frame source analysis and future Run brief](REFERENCE_ANALYSIS.md)
- [Complete rendered30-frame cycle](snappy_cycle_sheet.jpg)

## Motion evaluation and comparison

| | Approved Walk (preserved) | Snappy experiment |
|---|---:|---:|
| Loop |36frames /1.2s |30frames /1.0s; closing31 excluded |
| Contact |LEFT1 /RIGHT19 |LEFT1 /RIGHT16 |
| Support L/R |60% /62% |64% /66%;30% double support, no flight |
| Leg tracks |0.27m |0.27m |
| Hip lateral /fore-aft /vertical range |38 /36 /22mm |30 /40 /35mm |
| Nominal virtual travel |0.90m/s |1.02m/s;1.02m per cycle |

Cadence rises20%, but the timing design also changes: shorter swing windows, an early accelerated recovery with a softer arrival, rapid receiving compression by2.1frames after each contact and a longer rise/release. The swing time-warp stays monotone and continuous. Arms ease near extremes and travel more quickly through the middle, with independent22°/25° pitch amplitudes and small unequal delays. Torso partially counters pelvis yaw, while head facing/roll remain restrained. Body weight response is more readable without increasing lateral wobble. In the rendered cycle, contacts and opposing silhouettes are clear; the quick passing frames still interpolate smoothly. Artistic quality remains subject to the user's review.

Compression is produced through rigid pelvis/body placement and whole-leg articulation, never mesh scaling. All block proportions and full straight arms remain unchanged. Constant close foot tracks and slight inherited toe-out remain; no artificial knees or ankles.

## Contact and loop evidence

Fresh saved-source audit:961 subframe samples over one cycle, plus integer/half-frame coverage implicit in that sampling. Zero unsupported samples, zero tested nonadjacent block overlaps, no floor penetration. Maximum rigid-length error0.00028mm. Supporting sole-edge drift under nominal1.02m/s virtual travel is0.00191mm; support height error0.00181mm. Boundary pose difference0; channel tangent difference0.00000128; finite vertex velocity mismatch0.00219m/s using0.01-frame differences. All19 previous Action signatures and rest rig are exact. See `motion_validation.json`, `showcase_validation.json`, `appearance_validation.json`, `gui_playback.json`, `media_validation.json` and `preservation.json` for actual results.

**Scope of the foot test:** this is an in-place clip. A stance sole travels backward relative to the rig, cancelling virtual forward−Y travel at the designed speed. The active support edge stays anchored; the entire sole is allowed to rock as a rigid block. This does not certify every toe/heel corner as flat or establish zero sliding at arbitrary gameplay speeds, sharp turns, slopes or blended poses. Pose-only leg translations preserve block rigidity and ground reach, with maximum local offset about110mm; no rig/rest transform change. No runtime tests were performed for this Blender-only task.

## Future Godot transition contract

Root and rig object remain identity/in-place, forward−Y, existing bone modes and scale preserved. Shared LEFT phase0 /RIGHT0.5 matches approved Walk/Run. Receiving windows0–.14 and.5–.64; left release.64, right release.16 of global cycle. Keep the support side/phase through Walk↔Run; do not reset to frame1. Match distance cadence to the1.02m cycle and let physics/controller own travel. The wider/toed-out Idle stance needs support-aware replants for starts/stops. A generic long crossfade cannot prove stable contacts. Use compatible full-body/upper-body masks for weapons; arbitrary interruptions, terrain,30/60FPS runtime and phone performance are unvalidated. No Godot export/integration is authorized here.

The source `walk_snappy_review.blend` is an authoring/review study, not a second central Showcase. All previous entries remain selectable in the original Showcase. Stop after this Walk; await artistic review before Run.
