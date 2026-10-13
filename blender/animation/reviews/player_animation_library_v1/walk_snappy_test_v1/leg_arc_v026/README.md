# Continuous leg recovery — v026 — Pending

Latest user request: keep improving the leg movement toward the supplied video. This is a leg-only refinement of the same `Walk_Snappy_Test_v1`, still index19 in the20-entry Animation Showcase. Current v025 body/head/arms/root curves and evaluated world poses are exact; lighter150mm body bounce and restrained side sway remain.

Forward recovery now uses a C2 quintic path with optimized intermediate velocity and acceleration. It preserves the existing receiving/push positions and velocities, maximum forward/backward reach and their timing, plus the passing position. The purpose is continuous travel through passing rather than an abrupt change in pace. Original independent left/right support duties remain64%/66%. At matched512samples, actual sole-center fore-aft jerk is24.6%lower left /26.3%lower right; RMS acceleration is about15–16%lower. Foot-center RMS speed rises about3.3–3.5%within the swing because timing/spacing are redistributed; clip cadence and diagnostic travel speed remain unchanged.

Whole-leg pitch receives14ms periodic smoothing blended through swing only with a C3-continuous boundary weight. Pitch jerk is54.2%lower left /56.2%lower right and angular acceleration about32–34%lower. No knee or deformation is added. The sole envelope is solved after rotation so the270mm net piston lift,137.5mm common hop and v025 lowering profile are retained. Supported world leg transforms are preserved within0.000000119; no planted-foot smoothing or new slide. At sampled points, base reach extrema change by less than0.002mm and net-lift extrema are exact. The extrema guard allows0.05mm for sampling error.

Same21frames at30FPS,0.7s two-step loop, closingF22excluded, primary receivingF1/F11.5,0.27m tracks and1.59936m/s diagnostic travel. In-place Action; the diagnostic speed is not a Godot runtime change. Rig, rigid proportions, geometry and materials remain exact.

[Original-speed front / three-quarter / side](walk_snappy_three_views_1x.mp4), [v025 comparison](previous_vs_bounce_1x.mp4), [approved Walk comparison](approved_vs_snappy_1x.mp4), [front](snappy_front_1x.mp4), [three-quarter](snappy_three_quarter_1x.mp4), [side](snappy_side_1x.mp4), [overhead](snappy_overhead_1x.mp4), [source](walk_snappy_review.blend).

Evaluation: the lifted leg flows through the step with less change in acceleration and less angular chatter. The familiar lift height, softer arrival and current body rhythm remain. This is still a stylized piston walk with intentional flight/waist separation; numerical smoothness does not establish artistic approval or Godot transition readiness. Review the original-speed v025 comparison for whether the recovery reads naturally at this cadence.

Reference: consecutive frontF0–47 and backF100–123 from the user's241-frame recording were inspected. The visible target is a flowing lifted-leg descent with upper-body reaction continuing through receiving-like silhouettes. Exact sole-contact timing, original rig and interpolation cannot be determined from the moving camera/terrain. [Reference observations](reference_reinspection.json), [front sheet](reference_consecutive_000.jpg), [front continuation](reference_consecutive_024.jpg), [back sheet](reference_consecutive_100.jpg). No proprietary animation assets or keyframes imported.

Verification:673motion samples,512matched comparisons and337head/chest checks pass. Body/head/arms/root world difference0.000000000. Grounded drift0.00353mm, rigid error0.00025mm; waist separation59.7mm under75mm; head/chest minimum separating-axis gap3.32mm. No floor penetration, nonadjacent intersection or unexpected support loss. Loop pose/tangents and second-order velocity seam pass (0.00345m/s under0.006). Raw first-order estimate0.01253m/s and legacy guard=`False` remain separately recorded; it mixes real acceleration with seam continuity. No existing geometry/contact guards relaxed.

Current Showcase reopening/switching/slots/views/inactive retention pass25targeted checks. Actual GUI play/wrap/pause/restart and8videos/1428decodedframes at30FPS pass. All19unrelated Actions/entries and all previous sources/reviews including v025 remain preserved. Approved Walk/Run/Ready, paused Rifle Idle, Weapon Showcase, Godot and production remain unchanged. No Running Action created.

SourceSHA256 `4fc765d58722ecbee30b449b78c5a2a794d1fd85df2b10143268a7ed20eb237e`; ActionSHA256 `e0a67106bd7d2f6a533e4884210978889fd8c8a95c385c8a19bfbf7d18444362`.

[Motion](motion_validation.json), [comparison](comparison_validation.json), [Showcase](showcase_validation.json), [GUI](gui_playback.json), [appearance](appearance_validation.json), [head clearance / phases](phase_review.json), [media](media_validation.json), [registration](registration.json), [preservation](preservation.json), [design](design.json), [previous v025](../spring_polish_v025/README.md).

Pending user review. Blender only.
