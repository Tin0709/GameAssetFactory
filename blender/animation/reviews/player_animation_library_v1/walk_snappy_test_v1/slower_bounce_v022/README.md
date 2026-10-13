# Slower, softer body bounce — v022 — Pending

Same `Walk_Snappy_Test_v1` in the existing Animation Showcase. The latest request keeps the legs and walking speed while making the body rise and fall more slowly and smoothly.

The evaluated leg world motion, original leg rotation curves,21-frame cadence at30FPS (0.7s), tracks, lift, contacts and1.59936m/s diagnostic travel remain unchanged. This is an in-place Action; no controller changes. LEFT receives atF1 and RIGHT atF11.5; closingF22 is excluded. Leg local positions compensate for changed hips so the legs retain their world motion.

The body uses broader35ms periodic smoothing and8.4ms total settling delay. Its vertical excursion is10%softer, measuring277.8mm. The body cycle frequency stays the same; this pass slows its vertical motion within the unchanged step cycle. Evaluated RMS vertical speed is12.6%lower than v021; acceleration-change RMS is42.5%lower. The head reacts with32ms lift/34ms pitch/24ms roll smoothing; its vertical speed is12.3%lower. These are comparative animation diagnostics, not physical certification. Receiving-side tilt, torso yaw and arm/root local curves stay exact. The body is seated2mm lower to retain the waist-gap guard.

[Front / three-quarter / side at original speed](walk_snappy_three_views_1x.mp4) shows eight complete cycles (168frames/5.6s). [Previous v021 comparison](previous_vs_bounce_1x.mp4), [approved Walk comparison](approved_vs_snappy_1x.mp4), [front](snappy_front_1x.mp4), [three-quarter](snappy_three_quarter_1x.mp4), [side](snappy_side_1x.mp4), [overhead](snappy_overhead_1x.mp4), [Blender source](walk_snappy_review.blend).

Evaluation: the torso travels through a broader, softer rise and fall while the steps stay crisp. The head follows smoothly without exaggerating each direction change. The retained137.5mm common leg hop remains deliberately energetic. Review the original-speed comparison to judge this gentler upper-body balance. Godot start/stop/turn/weapon/terrain blending remains unvalidated.

Verification:673subframe motion samples and512matched comparison samples pass. Maximum leg matrix difference0.000000238; cadence, speed and fixed channels match v021. No floor penetration, nonadjacent overlaps or unexpected support loss. Grounded drift0.00104mm; rigid error0.00026mm. Waist separation peaks59.1mm under the retained75mm limit. The initial unregistered35ms/full-excursion candidate exceeded that limit by0.55mm; its source/report remain in validation and are not claimed as passing. No geometry guard was relaxed.

Loop pose/tangents and second-order velocity seam pass (0.00264m/s under0.006). Raw first-order estimate0.01629m/s has legacy pass=`False`; it remains separately reported. Absorption is measured at the actual post-contact minimum (73.7ms;78.5mm dip), instead of the earlier fixed-time sample. The amplitude comparison verifies the deliberate90%body excursion. These timing/amplitude checks describe artistic changes, not relaxed collision/ground/rigidity thresholds.

All19other Actions and entries, approved Walk/Run/Rifle Ready, paused Rifle Idle, rig, assets and previous versions are preserved.110Showcase selection/slot/timing/source/view/save/reopen/inactive-retention checks pass. Actual GUI playback/wrap/pause/restart and8videos/1428decodedframes at30FPS pass; latest review playing. Godot, production and Weapon Showcase unchanged; no Running Action created.

SourceSHA256 `4c75bbee017655be0c6c48af3acd76c9825ed9f412f75df7e5b469e141cc9d17`; ActionSHA256 `8ff9228c1ace46d19b6b6588d943d0d2ce68b0cfd0e5a29a91836a68781fe899`.

[Motion](motion_validation.json), [comparison](comparison_validation.json), [Showcase](showcase_validation.json), [GUI](gui_playback.json), [appearance](appearance_validation.json), [phase review](phase_review.json), [media](media_validation.json), [registration](registration.json), [preservation](preservation.json), [design](design.json), [previous v021](../smooth_follow_v021/README.md).

Pending user review. Earlier reference observations remain preserved; no proprietary assets or keyframe data were imported.
