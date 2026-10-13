# Slow body float / freer head — v023 — Pending

Same `Walk_Snappy_Test_v1`, selectable in the existing20-entry Animation Showcase. User explicitly selected **one slower body bounce across two steps**, and requested smoother bounce with a freer head. This supersedes the earlier body dip on every receiving foot; it does not change the leg steps.

The body now completes one analytic sine rise/fall over the full0.7s two-step stride, rather than two bounces. Its130mm vertical excursion moves from0.635m to0.765m, peaking at25%phase and reaching its low point at75%. Continuous sine motion rounds both turnarounds and joins smoothly at the loop. Receiving-side torso roll/yaw remains leg-driven. The smaller excursion retains the existing waist-gap bound while the body floats on a slower rhythm.

The head has a more visible secondary response:94.5ms body-height history, authored independent lift2.8–87.2mm,28ms lift smoothing,35ms pitch/roll smoothing and4deg bounded pitch. The evaluated head-height fundamental trails the hips by83.0ms. It catches up after the torso changes direction instead of remaining rigidly attached to the same vertical pulse. The lift range describes the authored secondary offset, not literal visible neck clearance.

The leg world motion and original rotation curves remain preserved, including270mm piston lift,137.5mm common leg hop,0.27m tracks, contactsF1/F11.5 and existing support/recovery. Same21frames/30FPS, closingF22excluded,1.59936m/s diagnostic travel; the Action remains in place. Local leg position curves compensate for the different hips, keeping evaluated leg trajectories unchanged. Arm/root local curves, rig proportions, meshes and materials stay exact.

[Front / three-quarter / side at original speed](walk_snappy_three_views_1x.mp4) shows eight complete cycles (168frames/5.6s). [Previous v022 comparison](previous_vs_bounce_1x.mp4), [approved Walk comparison](approved_vs_snappy_1x.mp4), [front](snappy_front_1x.mp4), [three-quarter](snappy_three_quarter_1x.mp4), [side](snappy_side_1x.mp4), [overhead](snappy_overhead_1x.mp4), [Blender source](walk_snappy_review.blend).

Evaluation: this pass changes the bounce rhythm itself, producing a slower continuous float above the quick legs. The head has clearer delay and independent travel. The two footsteps now sit on different halves of the body wave, so review that broader rhythm alongside the retained alternating shoulder response. Leg flight remains intentionally stylized. Godot start/stop/turn/weapon/terrain blending remains unvalidated; no runtime changes.

Verification:673subframe motion samples and512matched comparison samples pass. Leg matrix difference0.000000238; cadence/speed/fixed channels exact. Evaluated body/head RMS vertical speed decreases76.2%/74.7%versus v022, reflecting both the slower rhythm and smaller body excursion. These are animation diagnostics, not physical certification. No floor penetration, nonadjacent overlap or unexpected support loss. Grounded drift0.00116mm, rigid error0.00026mm, waist separation66.4mm under75mm. No collision/ground/rigidity guard relaxed.

Loop pose/tangents and second-order velocity seam pass (0.00214m/s under0.006). Raw first-order estimate0.01550m/s and legacy pass=`False` remain separately reported. Old per-foot compression-timing assertions are replaced by the user's one-cycle/two-step body rhythm; the leg contact and geometry checks remain unchanged. Fourier comparison confirms one dominant body cycle per stride and83ms head lag within the70–200ms response guard.

All19other Action signatures and manifest entries, approved Walk/Run/Rifle Ready, paused Rifle Idle and previous versions remain unchanged.110Showcase selection/slot/timing/source/view/save/reopen/inactive-retention checks, actual GUI play/wrap/pause/restart and8videos/1428decodedframes at30FPS pass. The GUI test left the review playing; this does not require keeping that window open. Godot, production and Weapon Showcase are preserved; no Running Action created.

SourceSHA256 `337c4bec31363adf37aa0df12626f8514dddee06266a55cd239fcc14a2b8cd18`; ActionSHA256 `3bb8835bbba0b2e14203ed2e08d482ff03da945153d673592658aca2e9b452fe`.

[Motion](motion_validation.json), [comparison](comparison_validation.json), [Showcase](showcase_validation.json), [GUI](gui_playback.json), [appearance](appearance_validation.json), [phase review](phase_review.json), [media](media_validation.json), [registration](registration.json), [preservation](preservation.json), [design](design.json), [previous v022](../slower_bounce_v022/README.md).

Pending user review. Earlier research and checkpoints remain preserved; no proprietary assets or keyframe data imported.
