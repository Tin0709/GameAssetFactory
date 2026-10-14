# Snappy Run leg recovery — gameplay review

2026-10-14 · **Experiment completed; candidate rejected for gameplay at30FPS.** The separate Blender Action remains Pending for comparison. Approved Run is still the default; production gameplay is unchanged.

Open `game_mobile_3d/scenes/dev/SnappyLocomotionFastJumpTest.tscn` and press F6. WASD/arrows move, Shift runs, Space jumps, **B / Run A/B** compares approved Run and the experiment, Tab retains Snappy/Expressive comparison. `SnappyLocomotionTest.tscn` also exposes B at its preserved native speeds; it has no jump branch. Candidate A/B is diagnostic, not acceptance or promotion.

## Muted original-speed30FPS footage

- [Approved / candidate gameplay comparison](approved_vs_candidate_30fps_1x.mp4)
- [Approved Run gameplay](gameplay_approved_30fps_1x.mp4)
- [Candidate gameplay](gameplay_candidate_30fps_1x.mp4)
- [Native-frame run comparison before jump](run_before_jump.jpg)
- [Native-frame run comparison after landing](run_after_landing.jpg)

397frames/30FPS,13.233s, same input demo and unchanged gameplay camera. Captured from an always-updating offscreen viewport using the actual Godot4.7.2 Mobile renderer on Apple Metal, with explicit rendering to avoid macOS occlusion freezing the recording. This changes capture presentation only, not controller/camera/physics. Encoded clips are muted and unretimed. Fixed simulation FPS is not a phone benchmark. Frame provenance and active source hashes are in the linked JSON evidence.

## Result

| Focused validation |30FPS|60FPS|
|---|---:|---:|
| Checks |1021|1021|
| Failed guards |45|0|
| Approved steady maximum leg step |58.85°|31.36°|
| Candidate steady maximum leg step |81.29°|47.75°|

The45 failures at30FPS concern the displayed leg-step/pop-risk guard, including live A/B. The source is continuous; these numbers do not establish a mathematical discontinuity. They show that the sharper exchange takes overly large steps between rendered poses at the unchanged fast gameplay cadence. This is sufficient for a conservative rejection under the user's30FPS requirement.

Walk↔Run, **direct Run→Idle stops**, reversals, Run→Jump→Landing→Run and both leading-foot phases were exercised in16 phase windows per A/B style at each FPS. Matched start-foot fixtures produced identical paired jump-request phases; phase waits explicitly fail on timeout. Source support profiles and final displayed sole measurements are used. Final matched trials introduce no additional correction clamps; earlier unmatched-fixture differences are preserved under `.validation` and are not treated as causal evidence.

No planted-foot skating or extra hip rebound was detected by the focused guards. Maximum measured floor penetration is0.504mm at30FPS and0.303mm at60FPS, within the inherited2mm guard. Steady and live-A/B hip target error is0. Scale, movement response, existing2m jump, current75%cadence and original travel speed remain preserved. A/B blends only the two leg samples over140ms inside the existing pose writer; it never resets gait phase, receiving IDs or anchors. No renderer, controller, camera or jump asset was modified.

[30FPS full report](focused30.json) · [60FPS full report](focused60.json) · [Decision summary](experiment_result.json) · [Media verification](media_validation.json).

The legacy native test passes72checks at both30/60FPS with the candidate. The45-check fast/jump candidate test passes at30FPS; the initial unmodified baseline run recorded one Walk-startup correction-limit failure, retained in `.validation/run_snappy_leg_recovery_v001/baseline_fast30.json`. Broader smoke tests do not supersede the focused30FPS rejection.

## Review limits

This is a flat-floor isolated test. Terrain, weapons and phone hardware are not certified. The source geometry suite excludes torso/leg adjacency from intersection rejection; its reported no-overlap result applies to non-adjacent pairs. Artistic improvement remains the user's judgment. Do not overwrite approved Run or promote this candidate; no second animation experiment was started.

[Blender review and reference comparison](../../../../blender/animation/reviews/player_animation_library_v1/run_snappy_leg_recovery_v001/README.md).
