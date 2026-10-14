# Original Running.mp4: comparison evidence

Research only. No existing assets, Actions, Blender scene, project files, or UI were modified. Native decoding and all new analysis outputs are isolated beside this memo. Source frames are zero-based throughout.

## Provenance and native timing

- Original: `/Users/tin/Desktop/Game Dev/GameAssetFactory/references/motion/actions_and_stuff/Running.mp4`, 853,333 bytes; freshly computed SHA256 `3db973b8dccf5e37d94cb6ed5a7e61fe6f45386c50d438112d058c5c23af55a2`. It matches the prior `source_media.json` and `cycles.json` exactly. The old Windows path is historical provenance, not a different source.
- Fresh macOS AVFoundation decode: **349 frames, 250 × 380**, presentation timestamps exactly `i/30`, timescale 30000; every gap is 1000 ticks = 1/30 s. Native sampling is therefore 30 FPS. AVFoundation's nominal float is 30.00008583; that is not evidence of a different playback cadence.
- First PTS 0; final frame PTS 11.600 s; 349 samples displayed at 30 FPS occupy **11.633333 s**. AVAsset container duration is 11.646646 s, slightly longer; do not confuse the container tail with a video frame interval. AVFoundation returns invalid/unspecified per-sample durations here, recorded as null; PTS gaps establish the sample spacing.
- Fresh exact duplicate pixel pairs: **[1,2], [2,3], [144,145], [295,296]**. Old ledger values `[2,3,145,296]` identify each pair's second frame and agree. Raw BGRA SHA256 determines exact equality. RGB MAE from CoreImage PNGs is a separate diagnostic with slightly different color conversion than historical OpenCV.
- **Video pack version, settings, original real-game capture speed, pre-recording edit/retime, and mirror status are unknown.** No authenticated metadata ties this video to the supplied 1.12 mcpack. The observed cadence difference does not establish a version change.
- `native_decode_manifest.json` records every frame's PTS and raw pixel hash; `provenance.json` records original/evidence/PNG hashes. `native_frames/frame_0000.png` through `frame_0348.png` are a fresh decode of this exact original. Swift/AVFoundation needed unsandboxed native decoder startup; no app UI was opened or changed.

## Clean continuous window and cadence

Use **F30–97 inclusive** for playback: 68 untouched native samples, **2.266667 s**, approximately four strides. **F98 is a comparison endpoint still only**, not an extra playback sample. This begins after the play overlay fades and ends before the near-repeated F99→100 and F105→106 samples. There are no exact duplicates or exploratory near duplicates (adjacent RGB MAE <0.2 on 0–255 pixels) inside F30–98. This threshold is a stutter diagnostic, not a motion-quality metric.

This is unobscured forward-running presentation near the front view. The camera/background pans and yaws; it is clean for ordered silhouettes, not a calibrated straight-path experiment or proof of zero turn weight. F143 changes to rear view; the late F294–348 near-standing pose is not a stable running cycle and should not be used to fit sprint posture. The original full 349-frame video remains context, not a loop to repeat.

Fresh inspection of consecutive frames supports the existing **approximately 17-frame local same-side recurrence** at receive-like F40→57→74→91. Similar late-return families recur around F30/47/64/81/98. At recorded 30 FPS, 17 intervals = **0.566667 s per stride, 1.764706 strides/s**, about 3.529 steps/s. These are local visible recurrences, not source keys or a universal pack period.

Assign visual events **±1 native frame (±33.3 ms)**. A practical local period range is 16–18 frames (0.533–0.600 s; 1.667–1.875 strides/s); this is an observational tolerance, not a statistical confidence interval. Across the previously marked F40→91 three-stride span, allowing ±1 frame on each endpoint gives 51±2 intervals /3 = 16.33–17.67 frames, approximately 1.70–1.84 strides/s. Shared endpoints/camera/foreshortening make individual intervals correlated. Do not report subframe contacts from this evidence.

## Phase and visible relationships

Use receive-like **F40 as a provisional alignment marker**, then F49 as the opposite extended-side family and F57 as same-side recurrence. Assume neither physical contact nor anatomical left/right. F40's long low leg is screen-left; F49's is screen-right. Exact ground contact, support duty, flight time, world pelvis height, pitch angle, and limb angular velocity remain unmeasured.

| Source frames in example stride | Approximate phase | Visible ordering |
|---|---:|---|
| 40–41 | 0–6% | One leg extended low; the opposite silhouette foreshortens/gathers. Cap/chest image lowers. |
| 42–44 | 12–24% | Leg shapes draw close/overlap and the other sole becomes higher in the image; upper silhouette rebounds. |
| 45–48 | 29–47% | Opposite long leg opens/extends toward a low receiving-like arrangement; head/chest tilt changes and begin lowering. |
| 49–50 | 53–59% | Opposite extended-side family, then compact/lower presentation. Camera yaw changes markedly here. |
| 51–54 | 65–82% | Another compact exchange and upper rebound, followed by opening on the first side. |
| 55–57 | 88–100% | Long low leg returns into the F40-like family. Endpoint is visually similar, not pixel-identical. |

The rise/gather/open sequence is visible; a mechanically bent knee or exact vertical whole-leg translation cannot be uniquely recovered from foreshortening. Item-bearing screen-left arm and free screen-right arm have different silhouettes and excursions. Their framing changes against the chest/legs; do not enforce mirrored empty-hand arcs from this clip. Cap/head tilt changes relative to shirt/shoulder slope and the leg exchange. This supports coordinated secondary motion, but does not measure a precise head delay, elastic interpolation, or a separate head controller.

**Torso lean:** the near-frontal/rear view cannot resolve sagittal forward pitch or separate waist pitch from camera elevation. A small +5° sprint waist pitch is compatible with these images, but the video cannot measure or require +5°. Alternating projected head/chest roll is visible. It does not identify a persistent turn bank or a separate lateral layer.

**Pack branch compatibility, not state identification:** parent source inspection reports grounded sprint `xahrzd→ucaryc`, held after 1.25 s, adding waist RX +5°, left-arm RY +8°/RZ −10°, right-arm RY −8°/RZ +10°, with separate lifetime bob `tdrcwc`. Small outward arm posing and coordinated torso/head variation are compatible with the video. Held-item asymmetry, perspective, locomotion curves, and bob can produce overlapping effects; there is no observed sprint-toggle or controlled baseline to attribute these values uniquely. Include the verified source sprint/bob state when reconstructing that state; do not claim the video proved layer ownership.

The verified turn bank `ktgnrt` is zero when `bdjsdw=0`. Background movement and slight view/facing changes prevent ruling out a nonzero contribution in the recording. They also do not prove one: camera orbit and locomotion roll explain overlapping cues. A **zero-turn forward baseline** is an explicit reconstruction condition. Any turn-weight sensitivity view must be labeled as a separate hypothesis, never a measured video parameter.

## Comparison plan

1. **Primary: original video at 30 FPS + exact canonical source clocks.** Show F30–97 once, continuously, beside 68 source samples at 1/30 s spacing. Preserve verified forward rate **1.6 cycles/s, 0.625 s**, sprint state and independent lifetime bob clock. Use one visible leg-family alignment (e.g F40) and keep both clocks continuous thereafter; no per-cycle phase resets or forced short loop. Four recorded local strides correspond to only **3.626667 canonical source cycles** over this display duration. The expected relative drift is about **0.373333 cycle**; disclose it instead of timing-fitting the production source.
2. For the parent's six-second canonical take, a convenient candidate is video F40 ↔ source t=**2.5 s** if source phase 0 is the matching extended-side family. Then video F30–97 maps to source t=**2.166667–4.400000 s**, source Blender F66–133 for F1=t0/30FPS, already beyond sprint settling. Verify the actual source-side family before using this. If the opposite side matches, offset source phase by 0.5 (0.3125 s, fractional render-frame offset is allowed). This chooses a temporal origin only and does not alter curves or clocks. It does not determine the recording's unknown lifetime-bob origin.
3. **Optional diagnostic, prominently labeled “video-cadence diagnostic — forward clock changed.”** Evaluate only forward phase at **30/17 = 1.764706 cycles/s** (1.102941× canonical forward rate). Keep independent lifetime bob at its native 122.5°/s and retain the same pose/state/camera conditions. This tests cadence's contribution to perceived mismatch; it is not a source-authentic bake, video provenance result, or production replacement. Global video retiming would also retime independent bob and therefore answers a different question.
4. Side/front fixed-camera source views may diagnose silhouette, but only the near-front source presentation can directly compare the original shot. Do not normalize every frame's character size/position, solve millimetres from pixels, invent flight/contact ratios, or reproduce the camera pan as a claimed source turn value. Show the full original separately for context if useful. F40–141 is longer but contains repeated/near-repeated samples and stronger camera/view changes; it is not the clean primary window.

Useful artifacts: `clean_window_F030_053.jpg`, `clean_window_F054_077.jpg`, `clean_window_F078_098.jpg` cover every selected sample and the endpoint. `cycle_F040_057.jpg` shows all 18 native endpoint-inclusive samples of one approximate stride. `phase_observations.csv` is qualitative ordering only. Original prior cycle sheets and ledgers are hash-listed in `provenance.json`.
