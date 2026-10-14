# Actions & Stuff source Running v001

**Research only · Pending visual review · 14 October 2026**

`Run_ActionsStuff_Source_Test_v001` reconstructs the supplied resource pack's Run contribution and relevant steady controller layers on the unchanged GameAssetFactory character. It is separate from every original/commercial Run and from the accepted Walking study. No proprietary reconstruction is eligible for production export.

On Mac, double-click **[Open_Source_Run_Research.command](Open_Source_Run_Research.command)**. It opens the existing [Animation_Showcase.blend](../../../showcase/Animation_Showcase.blend), loads its sidebar and selects this study. Use **N → Animation Library → Run_ActionsStuff_Source_Test_v001 → Play**. This is a **six-second continuous research take**, F1–180 at 30 FPS. Loop playback is disabled because the source's independent lifetime bob does not repeat with the short Run cycle. Replay resets the declared study clocks; no seam was invented or smoothed.

## Start with these comparisons

- [Original Running.mp4 / source reconstruction / approved Run — front](reference_source_approved_front_1x.mp4).
- Same comparison from [3/4](reference_source_approved_three_quarter_1x.mp4) and [side](reference_source_approved_side_1x.mp4). The original recording retains its own camera in all three.
- [Source front / 3/4 / side together](source_three_views_1x.mp4).
- [Full six-second source take](source_full_take_1x.mp4), without artificial cycle repeats.
- [Separate video-cadence diagnostic](video_cadence_diagnostic_front.mp4): changes only gait-clock rate to the recording's observed recurrence, keeps native bob timing, and is **not** the registered source-authentic bake.
- [Same-time comparison sheet](reference_source_approved_phase_sheet.jpg).

The primary videos preserve original 30 FPS samples F30–97, the pack's canonical forward clock and the approved Run's own clock. A provisional leg-family alignment is made at reference F40; phase drift thereafter is retained, not concealed through per-cycle resets. Static source renders: [front](source_front.png), [3/4](source_three_quarter.png), [side](source_side.png).

## What is actually reproduced

The archive and all named resources were freshly verified. Forward Run is `animation.oreville_ans.fngydr` in `animations/f2da1071.json`; the player binding and controllers are in `entity/dtr.json` and `animation_controllers/616f2ff7.json`.

The study retains original leg rotations, vertical/fore-aft offsets and the **1.07 leg-scale pulse**, default linear key interpolation, asymmetric waist bounce, torso twist, shoulder/arm movement and head expressions. It includes settled grounded sprint posture, independent lifetime bob and the source's held-item arm attenuation under an explicitly assumed main/right-hand profile. Local channels are accumulated before transformation. No original Run curves or generic running formula were used to build this Action.

All native rest bones, mesh, UVs, weights, materials and straight arm/leg structure are retained. A verified research-only viewer exception permits just the source leg-Y scale channels; ordinary Actions retain their existing scale restriction. The source stretch elongates a straight block and does not introduce knees or elbows.

## Match assessment and known differences

This has the source's substantially different raised leg recovery, offset/rotation coordination, asymmetric body beat and stronger torso involvement. It is a reconstruction of source channels rather than another Snappy Run refinement. The comparison is for judging visual closeness; it does not establish pixel-equivalent Minecraft runtime playback.

The supplied pack's full-speed forward rate is **1.6 cycles/s**, or **18.75 recorded frames per cycle at 30 FPS**. The recording locally recurs around **17 frames**, with approximately ±1-frame visual-event uncertainty. Its pack version, exact runtime inputs and capture/edit history are unknown. We cannot attribute this difference to a verified version change. The diagnostic makes the timing discrepancy visible without altering the registered Action.

Primary humanoid/cape geometry is absent from the archive. Native proportions and virtual shoulder pivots are therefore adaptations. The recording's item/hand identity, lifetime-bob phase, head look and turn weights are not recoverable exactly. Entity-relative Head handling is modeled with parent-rotation compensation; complete Bedrock composition and negative directional-weight semantics remain unvalidated. These limits are detailed in [Reconstruction notes](RECONSTRUCTION_NOTES.md).

## Verification

The saved source was reopened and checked at 942 transform times, including exact original breakpoints. Maximum matrix-component difference from the evaluated source/profile is **1.67×10⁻⁶**; leg-scale channel error is **2.42×10⁻⁷**; forearm helpers remain identity. The constant display floor is −33.674 mm and sampled minimum clearance is about .407 mm. This is native retarget geometry, not original Minecraft contact certification. No foot locking or time-varying floor correction was added.

[Source verification](source_validation.json) · [Controller profile](manifest.json) · [Media checks](media_validation.json) · [Decoded video samples](decoded_media_validation.json) · [Native playback checks](gui_playback_validation.json) · [Showcase checks](showcase_validation.json) · [Preservation checks](preservation_validation.json).

Original pack SHA-256: `9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d`. Original video SHA-256: `3db973b8dccf5e37d94cb6ed5a7e61fe6f45386c50d438112d058c5c23af55a2`.

All previous Actions and sources, accepted Walking, the player master library, production assets and Godot are preserved. This delivery stops at Blender research and visual review.
