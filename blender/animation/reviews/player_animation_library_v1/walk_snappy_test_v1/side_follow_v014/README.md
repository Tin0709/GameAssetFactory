# Snappy Walk — visible hop, receiving-side follow,25%faster — Pending

Current same `Walk_Snappy_Test_v1` in the existing20-entry Animation Showcase. No new production or Running Action. All older approved Actions and previous sources are preserved; Rifle Ready Idle remains paused.

The user's chosen rhythm is **foot lands → body dips → body rises as the other leg comes through**. The latest requests add more visible floor clearance, a downward follow on the side of the lowering leg, and25%overall speed.

Current motion:

- 24frames at30FPS,0.8second cycle (+25%over the previous1second); closing25excluded. LEFT receivingF1, RIGHTF13. All channels share the same retime.
- 110mm common hop. Actual lowest character point reaches110.40mm above the floor at both passing crests; [side peak](visible_hop_peak_side.png), [front](visible_hop_peak_front.png), [3/4](visible_hop_peak_three_quarter.png).
- Body dips54.375mm over42.7ms after contact, then rises through the opposite leg's recovery. Body crest follows incoming-leg40%swing phase: F8.104/F19.816. Stronger vertical pass was50%greater than v010; subsequent clearer common hop adds35mm. Current hip range is235.5mm.
- Receiving-side roll follows actual lowering and receiving phase: hips/spine/chest/head3/4/5/2deg, with small delays. Hips/torso centers stayX.006m; head follows the tilted neck naturally. At receiving poses, the loaded shoulder is about53–57mm lower than the other. Both hips and receiving shoulder descend with the lowering leg, measured in [phase review](phase_review.json).
- Continuous C2 piston recovery and270mm net lift retained,0.27m planted tracks,4mm inward swing tuck, same fore/aft contact endpoints and step-following yaw. Full rigid arms remain straight; their local curves and Root are exactly retimed. No scaling or rig changes.

[Front / 3/4 / side original-speed review](walk_snappy_three_views_1x.mp4) contains seven full cycles,5.6seconds, so the review itself loops on the Action boundary. [Previous75mm contact rhythm vs current](previous_vs_bounce_1x.mp4), [approved Walk comparison](approved_vs_snappy_1x.mp4), [overhead](snappy_overhead_1x.mp4), [front](snappy_front_1x.mp4), [3/4](snappy_three_quarter_1x.mp4), [side](snappy_side_1x.mp4), [source](walk_snappy_review.blend).

Evaluation: floor clearance now reads clearly in side view; the downward shoulder follow connects the lowering leg to the upper body. The centered body and smooth piston arc preserve the blocky silhouette. The110mm hop is intentionally expressive and should be judged at actual speed; this remains an artistic Pending experiment. Nominal support is shortened by deliberate flight, not a certified physical gait. Godot start/stop/turn/weapon/terrain blending remains future work.

Reference analysis is preserved from the supplied8.033second/241frame recording: [annotated consecutive front phases](../bounce_timing_v008/reference_annotated_phases.jpg), [back sequence](../bounce_timing_v008/reference_back_cycle.jpg), [observations and uncertainties](../bounce_timing_v008/reference_analysis.json). Visible compression/rebound and alternating rigid recovery informed the original paths; exact source contacts, rig and curves remain unknown. No proprietary animation data was imported.

Verification:769subframe samples, no floor penetration/nonadjacent overlap/unexpected support loss; planted drift0.00073mm and rigid error0.00025mm. Intentional waist separation54.1mm is bounded75mm, expanded from the earlier45mm guard for the stronger user-requested body excursion; this is a changed bound. Loop pose/tangents and second-order velocity seam pass (0.00360m/s under0.006). Raw first-order value0.01138m/s fails the legacy guard and remains reported; the second-order estimator removes acceleration bias and is not an unchanged legacy pass. Straight arms, retimed fixed channels, rest rig and all19other Actions pass.110Showcase selection/slot/view/timing/source/save/reopen/inactive-retention checks and actual GUI play/wrap/restart pass; fresh review window remains playing.8videos/1428frames decode at30FPS.

SourceSHA256 `647b0542cf4dcfe0a23324a646c7956022cb7a5517869e63e0785ee3d2cd162e`; ActionSHA256 `25d7e226c3ec7abd65a8b2c49e8cc4b0415a758403fe1b94a81f21cdd8d3e29b`. See [motion](motion_validation.json), [Showcase](showcase_validation.json), [appearance](appearance_validation.json), [GUI](gui_playback.json), [media](media_validation.json), [registration](registration.json), [preservation](preservation.json). Pending user review; Godot, production, Weapon Showcase and paused Rifle Idle unchanged.
