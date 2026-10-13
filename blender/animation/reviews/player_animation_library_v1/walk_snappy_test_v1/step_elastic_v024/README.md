# Elastic step bounce / closer head — v024 — Pending

Same `Walk_Snappy_Test_v1` in the existing20-entry Animation Showcase. Latest user steering rejects the slow two-step body float and asks for a slime-like bounce along with the legs, with the head closer and smoother. This supersedes the earlier one-body-bounce-per-two-steps choice.

The body returns to **one rounded dip/rebound per step**. It absorbs56ms after receiving, rises through a smooth170mm excursion and eases through its crest before the next step. Two continuous cosine pulses per0.7s stride provide smooth position/velocity/acceleration and loop continuity. Hip height is0.660–0.830m. The slime quality comes from loading and elastic rebound; all character parts remain rigid, with no animated scale or changed proportions. Receiving-side roll/yaw and restrained torso pitch keep the upper body responsive.

The head stays closer: authored secondary lift is8.2–35.8mm, compared with2.8–87.2mm in v023. The oscillating lift excursion is about67%smaller. It retains70ms height-history response,28ms lift smoothing,35ms pitch/roll smoothing and2.5deg bounded pitch. Evaluated vertical motion stays closely coupled to the torso (about7.5ms lag at the body-step harmonic), while pitch retains softer follow-through. The lift numbers describe authored offset, not literal neck clearance.

The leg world motion/original rotation curves,21-frame cadence at30FPS, closingF22excluded, contactsF1/F11.5 and1.59936m/s diagnostic travel remain unchanged. Same270mm piston lift,137.5mm common leg hop and0.27m tracks. Local leg translations compensate for the changed hips. Arm/root local curves, rest rig, geometry and materials stay exact; the Action remains in place.

[Front / three-quarter / side at original speed](walk_snappy_three_views_1x.mp4) shows eight complete cycles (168frames/5.6s). [Previous slow-float comparison](previous_vs_bounce_1x.mp4), [approved Walk comparison](approved_vs_snappy_1x.mp4), [front](snappy_front_1x.mp4), [three-quarter](snappy_three_quarter_1x.mp4), [side](snappy_side_1x.mp4), [overhead](snappy_overhead_1x.mp4), [Blender source](walk_snappy_review.blend).

Evaluation: the torso again belongs to the stepping rhythm, with a soft receiving dip and rounded spring-up rather than the slower independent float. The head has a much smaller separation and quieter reaction. Review the original-speed comparison for the balance between springiness and softness. The retained leg flight remains stylized; Godot start/stop/turn/weapon/terrain blending is unvalidated.

Verification:673subframe motion samples and512matched comparison samples pass. Leg matrix difference0.000000238; cadence/speed/fixed channels exact. No floor penetration, nonadjacent overlap or unexpected support loss. Grounded drift0.00122mm; rigid error0.00022mm; waist separation45.1mm under retained75mm. An additional337sample head/chest check passes with minimum separating-axis gap1.12mm. The initial closer-head candidate revealed6.88mm overlap; its source, reports, central snapshot and media are preserved in `.validation/walk_step_elastic_v1/head_clearance_candidate/`. Corrected head baseline adds8mm clearance without changing its oscillation amplitude. The initial candidate was briefly registered before this extra check; the final registered source is corrected. No geometry guard relaxed.

Loop pose/tangents and second-order velocity seam pass (0.00523m/s under0.006). Raw first-order estimate0.01841m/s and legacy pass=`False` remain separately recorded. Body rhythm checks now verify two pulses per stride and the requested56ms loading phase. Derivative magnitude is not required to be lower than the rejected half-tempo experiment; rhythm intentionally speeds up. Geometry, leg contacts and loop checks remain unchanged.

All19other Actions/entries, approved Walk/Run/Rifle Ready, paused Rifle Idle and older checkpoints are preserved. 25targeted current-candidate Showcase/reopen/switch/slot/view/inactive-retention checks pass; the unchanged complete library had110checks in v023. Actual GUI play/wrap/pause/restart and8videos/1428decodedframes at30FPS pass. Godot, production and Weapon Showcase unchanged; no Running Action created.

SourceSHA256 `ab68b72d8fbe3727caa45882693777e4af26e619d5b2cfa6cc5baa00fcb27329`; ActionSHA256 `355ae1891a12860f3031b7c5092866d1c6db5c3c59d99ab7c1d4fe7321aa8108`.

[Motion](motion_validation.json), [comparison](comparison_validation.json), [Showcase](showcase_validation.json), [GUI](gui_playback.json), [appearance](appearance_validation.json), [phase/head clearance](phase_review.json), [media](media_validation.json), [registration](registration.json), [preservation](preservation.json), [design](design.json), [previous v023](../slow_float_v023/README.md).

Pending user review. No proprietary assets or keyframe data imported.
