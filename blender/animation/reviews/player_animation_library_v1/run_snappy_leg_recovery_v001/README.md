# Run Snappy Leg Recovery v001 — Pending experiment

2026-10-14 · `Run_Snappy_LegRecovery_Test_v001` · **Pending artistic review; rejected for gameplay at30FPS.** Approved `Run_Snappy_Test_v001` remains the baseline and default. This is one completed experiment, not a production replacement.

The free leg gathers earlier, exchanges more quickly, then opens and brakes into placement. Only its world sagittal motion is retimed. A bounded sin⁴ phase advance peaks at0.080cycle/45.3ms; actual passing occurs23.44ms earlier on each side. Peak source exchange speed rises approximately56–57%. These are authored measurements, not measured forces or the reference's hidden timing.

All non-leg curves and evaluated upper-body poses are exact copies. Support-leg geometry is exact across2,177 paired samples; vertical sole envelope differs by at most0.00133mm. Same17 unique frames/30FPS, closing18 excluded,2.5m/s nominal source travel, low brief flight and straight rigid limbs. No whole-character jump lift, scaling or rig changes.

## Review at original speed

Each video contains five uninterrupted17-frame cycles:85frames/30FPS,2.833s. The closing key is never inserted as an extra frame. The reference uses original Running.mp4 F40–124 at30FPS; its camera/proportions differ and exact contacts remain unknown.

- [Candidate: front / three-quarter / side](candidate_three_views_1x.mp4)
- [Approved / candidate: side](approved_vs_candidate_side_1x.mp4)
- [Approved / candidate: front](approved_vs_candidate_front_1x.mp4)
- [Approved / candidate: three-quarter](approved_vs_candidate_three_quarter_1x.mp4)
- [Actions & Stuff / approved Run / candidate](reference_approved_candidate_1x.mp4)
- [Phase comparison](side_phase_comparison.jpg)

Separate [front](candidate_front_1x.mp4), [three-quarter](candidate_three_quarter_1x.mp4) and [side](candidate_side_1x.mp4) videos are retained. Shared stage cameras, materials and lighting; same12-sample denoised Cycles rendering in both versions. The five repeats use the17 unique source frames without retiming or holds.

## Validation and preservation

[Saved-source geometry/motion checks](motion_validation.json): exact support and upper body, unit scale, no non-adjacent SAT intersections; maximum waist separation58.93mm within the existing75mm guard. Torso/leg adjacency is excluded from SAT intersection rejection, so this is not certification against adjacent-part penetration. Review the full mesh frames visually.

Second-order loop velocity estimate0.002566m/s passes the0.006guard; pose seam0. Raw first-order estimate and its legacy false/pass label remain separately reported. A smooth source seam does not prove smooth sampled gameplay.

[Registration](registration.json) preserves all33 existing entries/Actions, including five concurrent Blockbench additions, and appends exactly one Pending entry to the existing `Animation_Showcase.blend` (34total). [Real GUI verification](showcase_validation.json) checks every Action/slot/timing, three views, two playback wraps, pause/restart and inactive save/reopen retention.

The [isolated Godot review](../../../../../docs/animation/reviews/godot_snappy_run_leg_recovery_v001/README.md) rejects this candidate at30FPS: faster recovery becomes too abrupt at the unchanged fast gameplay cadence/reach. All1,021 focused60FPS checks pass, but that does not satisfy the30FPS target. No further source variant was authored after that rejection.

Source and Action hashes are recorded in [authoring.json](authoring.json). All approved sources and previous Action versions remain unchanged. This experiment stops here for human review.
