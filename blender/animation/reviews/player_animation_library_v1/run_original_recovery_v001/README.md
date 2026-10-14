# Original Run Recovery v001 — Pending review

14 October 2026. Separate Blender experiment: **`Run_Original_Recovery_Test_v001`**. The approved **`Run_Snappy_Test_v001`** remains unchanged and selectable.

Open the existing [Animation_Showcase.blend](../../../showcase/Animation_Showcase.blend), choose `Run_Original_Recovery_Test_v001` in **N → Animation Library**, then **Play**. Front / 3/4 / Side change the camera; enable **Loop playback** for continuous review. Playback is F1–17 at 30 FPS, closing F18 excluded: the approved Run's same .566667 s cadence. The separate authoring source is [run_original_recovery_review.blend](run_original_recovery_review.blend).

## Review media

- [Front / 3/4 / side, six continuous cycles](candidate_three_views_1x.mp4).
- [Approved versus candidate — side](approved_vs_candidate_side_1x.mp4), [front](approved_vs_candidate_front_1x.mp4), [3/4](approved_vs_candidate_three_quarter_1x.mp4).
- Individual views: [front](candidate_front_1x.mp4), [3/4](candidate_three_quarter_1x.mp4), [side](candidate_side_1x.mp4).
- Static renders: [front](candidate_front.png), [3/4](candidate_three_quarter.png), [side](candidate_side.png).
- [All 17 native side frames](all_native_side_frames.jpg) and [focused recovery comparison](recovery_comparison.jpg).

Each video is 102 frames at 30 FPS: six uninterrupted 17-frame cycles, without inserted holds, duplicated closing poses or cadence normalization. Approved and candidate use identical cameras, lighting and materials. The native Action clock is not a measurement of the existing Godot review's distance-driven playback.

## What changed

Only the free leg's sagittal recovery and the rigid translations required to keep its sole-height envelope changed. Original quintic event curves reduce the rear opening, bring the leg through a compact gathered pose earlier during the opposite step's rebound, then spread forward opening and braking across the remaining swing. Supported motion and late foot placement retain the baseline. This is an independently authored trajectory on our own approved Run, rather than the previous experiment's phase-advance warp.

Body rebound, forward lean, torso/head coordination, arm drive, lateral leg tracks, rig, mesh/UV/weights, rigid limb scale and overall cadence are preserved. No elbow or knee behavior was added. There is no shared jump lift or added foot-height pulse.

| Measured native change | Approved Run | New candidate |
|---|---:|---:|
| Two-step cycle | 566.67 ms | 566.67 ms |
| Left passing phase | .63603 | .62362 — 7.03 ms earlier |
| Right passing phase | .64200 | .62362 — 10.42 ms earlier |
| Maximum displayed leg-angle step at native 30 FPS, 64 starting offsets | 26.18° | 23.97° |
| Peak exchange speed, left / right | 9.34 / 9.54 m/s | 8.72 / 8.66 m/s |

Passing means the sole-cap center crosses the hip's fore/aft plane. It is not a new foot-contact event. The improvement is earlier, more compact gathering and more distributed opening, rather than simply higher exchange speed.

## 30 FPS assessment

The reviewed native frame sheets show a modest tightening through gathering, particularly in the side view around F10–12. Opening remains readable and the approved body/arm rhythm is intact. Front-view differences are subtle. The lower maximum displayed angular step supports a more controlled exchange than a strong phase advance; it does not by itself prove a more satisfying animation or a dramatic change in running identity. Keep this candidate **Pending** for the user's visual judgment.

This is a deliberately restrained experiment. No Godot playback, transition, movement-speed or mobile-performance claim is made.

## Verification and limits

Saved-source validation sampled 2,177 times. Non-leg curves and evaluated world poses match exactly; supported leg vertices match exactly. Lowest-sole height differs by at most **.00474 mm**. Minimum ground clearance remains about .398 mm; identity scales are retained. Nonadjacent overlap checks pass, and maximum waist separation remains 58.93 mm within the existing 75 mm review bound.

Adjacent torso/leg overlap is **not collision-clearance certified**. The SAT overlap proxy is roughly 210–215 mm in both versions; its right-side minimum worsens by about 1.43 mm. This pre-existing joint behavior is disclosed rather than hidden behind the nonadjacent test. The robust second-order loop velocity estimate passes (.00256 m/s under .006); the historical raw first-order probe remains false (.0741 m/s). Loop pose difference is zero. These checks do not establish C2 continuity or remove the baseline's rigid-joint tradeoffs.

[Motion validation](motion_validation.json) · [Authorship and original parameters](authoring.json) · [Media validation](media_validation.json) · [Showcase reopen/selection checks](showcase_validation.json) · [Preservation checks](preservation_validation.json).

The saved central Showcase was reopened and all 36 Actions passed source-signature, slot, timing and selection checks; all 35 previous entries remain exact. A separate native Blender GUI window also completed four wraps, pause/restart, then two further wraps. It remains open with the new candidate selected and paused for review. [GUI playback evidence](gui_playback_validation.json) · [Blender screenshot](blender_gui_review.png).

Actions & Stuff was used only for broad coordination principles. The builder reads our approved Run and original authored parameters; it does not read the resource pack, source curves, sampled proprietary poses or source-derived reconstruction. Walking research, all previous Run sources, approved Actions, production assets and Godot are preserved. No gameplay integration or production promotion was performed.
