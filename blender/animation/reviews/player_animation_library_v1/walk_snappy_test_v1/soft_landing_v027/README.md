# Longer, softer leg descent — v027 — Pending

Same `Walk_Snappy_Test_v1`, index19 in the existing20-entry Showcase. Latest request asks the legs to ease into the ground more softly while keeping the walking speed and current body bounce. This pass changes only leg translation. Body/head/arms/root curves and evaluated world poses, leg rotation curves/world orientation and forward/backward leg travel remain unchanged from preserved v026.

Vertical release begins31.5ms earlier in each step. A normalized `t^3*(1-t)^6` piston curve keeps the270mm net lift and essentially the same ascent duration, but gives the descent20.0%more time left /20.8%right. The piston peak-to-arrival interval grows157.5→189.0ms left and148.75→179.67ms right. The sixth-order arrival progressively reduces the piston motion near the ground; its derivatives through order5 vanish at contact. The unchanged common hop also contributes to actual sole movement, so this is not a claim that all total-foot derivatives vanish to that order.

Actual evaluated sole height, including the existing common hop, has34.5%lower RMS vertical speed left /34.7%right over the same final100ms before receiving. Peak downward speed in that window is33.2%lower left /31.4%right. This addresses the visible fast drop, rather than smoothing the horizontal swing alone. Because the270mm piston crest now occurs earlier than the137.5mm common-hop crest, their combined maximum sole height becomes370.2mm left /366.8mm right instead of407.4mm. Net piston lift and common-hop amplitude themselves are preserved.

Receiving phases remainF1/F11.5. Vertical support releases earlier, changing the nominal duty fractions64%→59.5%left and66%→61.5%right; the forward/backward trajectory still follows the exact v026 path. Supported world leg poses remain exact until the new release, rather than claiming the old longer support interval is unchanged. Both feet keep the same grounded travel speed and no new planted sliding. This leg translation experiment preserves rigid proportions and needs future runtime support/blending validation.

Same21frames at30FPS,0.7s two-step loop, closingF22excluded,0.27m tracks and1.59936m/s diagnostic travel. The body retains its exact150mm bounce and restrained sway, and the head retains its close secondary reaction. In-place Action; no Godot movement or gameplay change.

[Original-speed front / three-quarter / side](walk_snappy_three_views_1x.mp4), [v026 comparison](previous_vs_bounce_1x.mp4), [approved Walk comparison](approved_vs_snappy_1x.mp4), [front](snappy_front_1x.mp4), [three-quarter](snappy_three_quarter_1x.mp4), [side](snappy_side_1x.mp4), [overhead](snappy_overhead_1x.mp4), [source](walk_snappy_review.blend).

Evaluation: the lifted leg gets more of the step to descend, with a quieter final approach and less overall drop height at the combined crest. The body still carries exactly the same rhythm. Review the original-speed v026 comparison for whether the feet now settle softly enough. The animation remains a stylized rigid piston walk; passing numerical checks does not establish artistic approval.

The target remains the continuous leg lowering seen in the user's reference. [Consecutive front frames](reference_consecutive_000.jpg), [front continuation](reference_consecutive_024.jpg), [back frames](reference_consecutive_100.jpg), [reference observations](reference_reinspection.json). Exact original rig/contact/curves are unknown; no proprietary keyframe data imported.

Verification:673motion samples,1024matched comparisons and337head/chest samples pass. Non-leg world pose difference0.000000000; leg world orientation difference0.000000000; horizontal sole-center difference0.000000030m. Grounded support drift0.00146mm, rigid error0.00025mm; waist separation59.7mm under75mm; head/chest separating-axis gap3.32mm. No floor penetration, nonadjacent intersection or unexpected support loss. Loop pose/tangents and second-order velocity seam pass (0.00377m/s under0.006); raw first-order estimate0.01253m/s and legacy guard=`False` are retained separately. Earlier release is explicitly reflected in foot/support checks and manifest duty metadata; no geometry/drift/loop threshold relaxed.

Current Showcase switching/slots/views/reopening/inactive retention pass25targeted checks. Actual GUI play/wrap/pause/restart and8videos/1428decodedframes at30FPS pass. All19unrelated Actions/entries and older sources/reviews remain preserved, including v026. Approved Walk/Run/Ready, paused Rifle Idle, Weapon Showcase, Godot and production are unchanged. No Running Action created.

SourceSHA256 `0ff3dbeff6d101dc87dbe70e6b9eb8ec2de0150d165974f5a88422556b881901`; ActionSHA256 `8d9d809cc0078f98b1f6b6b43f6a7c8365c70bc11160e9efb9bdaaf42fbd5cb6`.

[Motion](motion_validation.json), [comparison](comparison_validation.json), [Showcase](showcase_validation.json), [GUI](gui_playback.json), [appearance](appearance_validation.json), [head clearance / phases](phase_review.json), [media](media_validation.json), [registration](registration.json), [preservation](preservation.json), [design](design.json), [previous v026](../leg_arc_v026/README.md).

Pending user review. Blender only.
