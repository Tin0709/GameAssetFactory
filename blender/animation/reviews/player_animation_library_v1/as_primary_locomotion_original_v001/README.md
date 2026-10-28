# Original Walk / Run — A&S-primary, Pending

Milestone 1 only. Two newly authored motions on the existing original 13-bone Showcase character. Idle, MD2 references, earlier hybrid Runs and Godot are preservation controls. No new Jump/Combat, no integration or artistic approval implied.

Open **Open Original Walk Run Review.cmd**. It opens the existing `blender/animation/showcase/Animation_Showcase.blend`, loads the repository's panel without changing preferences, and plays **Original Walk / Run — A&S-inspired, Pending**. Space pauses. Use the panel's Front / Side / Three-quarter views. The other new review entry is **Original Walk→Run→Walk — traveled contact review**: 4.5 seconds, continuously advancing phase, real presentation travel over a one-metre grid. Select the individual Actions in the same library to study their keys.

| New Pending Action | Cadence | Calibration speed | Full-cycle stride |
|---|---:|---:|---:|
| `Walk_ASInspired_Original_v001_PENDING` | 1.20 Hz | 1.80 m/s | 1.50 m |
| `Run_ASInspired_Original_v001_PENDING` | 1.60 Hz | 4.30 m/s | 2.6875 m |

Both loop at **60 FPS, frames 1–150**, with duplicate closing sample151. The comparison shares a real-time clock: three Walk cycles / four Run cycles per2.5seconds. It does not force equal cadence. The finite `PREVIEW_ONLY_WalkRun_PhaseTransition_Original_v001_PENDING` is also registered Pending, but is an inspection take, not a production locomotion clip. Its Empty owns travel; reusable character Root remains in place.

## What is original

All pose keys come from `motion.py` and `build_original.py`, with no source-animation data loaded. Direct pack evidence is used for motion principles: load/release contrast, faster pickup versus forward replacement, a held open silhouette, shared semantic phase, phase-offset torso/arms/head, and restricted head motion. This is not a literal source reconstruction. The unchanged original GAF mesh, rigid weights and rest skeleton are reused; source-study Actions are inspected, not sampled into the new motions.

Original contact intent:50%cycle Walk stance perfoot;28%Run, rolling actual sole edges. The mass curve rounds box-edge cusps. Swing clearance prevents the floor-clamped scrape found and fixed during review. Arms swing opposite the matching legs; helpers retain identity, no elbow/knee articulation, no animated scale. Original offline contact construction maintains anchors while the transition speed changes; it is not recovered A&S terrain IK or a plain crossfade guarantee.

## Measurements and review limits

Actual reopened source measurements (`measurements.json`): hip range48.80mm Walk /93.63mm Run; global head pitch at most1.80° /2.50°; chest yaw range16° /34°. Intended rolling-contact velocity RMS0.0029 /0.0141m/s, max0.0045 /0.0268m/s at the stated calibration speed. Sampled floor penetration0, scale error0, cycle pose error0. Review output sampled at30/60/120Hz. Independent4,001-sample-per-cycle check found no remaining nonplant floor scrape under its0.36mm criterion.

Not a universal zero-slide claim: airborne near-ground motion is measured separately. Linear bake velocity seam remains small but nonzero; see JSON. The rigid whole-leg origin can rise28.83mm Walk /58.36mm Run into the hip junction; finite transition offsets also include−20.58mm. Inspect this artistic choice and run clearance from all views. No limb length changes.

`Walk_Run_Original_Pending.gif` is actual Blender output:75frames,2.5seconds, average30Hz, no interpolated frames. The authored source is `as_primary_locomotion_authoring.blend`. Original keys, metadata, transition trace, measurements and reopen/GUI checks are beside it. Regenerable frames, immutable pre-edit backup and full preservation snapshot stay in ignored `.validation/animation_showcase/as_primary_locomotion_original_v001/`.

## Speed is not cadence

These are nominal stride calibrations, not changes to the existing7m/s controller. Feeding7m/s to the fixed4.3m/s keyed stride would slide; do not hide that by arbitrarily speeding playback. Future approved integration must map physical distance to reachable contacts / stride construction. `motion.calibrated_run(speed)` is a checked original authoring helper for3.5–7m/s: it retains1.6Hz and the same feasible contact sweep by adjusting stance duty (at7m/s:17.2%, stride4.375m). That checks analytic support feasibility only; it does not change these saved clips or implement/validate a Godot runtime adapter. Further speed/turn/terrain work belongs after artistic approval.

Direct source authority remains the private `MD2 Research/reports/expressive_locomotion_design` audit, not our old recreated Walk/Run. Pack verifier35pointers/5members passed. Detailed proprietary source expressions stay outside production. Approval, original provenance and future engine readiness are separate.
