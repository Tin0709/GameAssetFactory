# Snappy Leg Exchange Timing — controlled test v001

2026-10-14 · **Pending artistic review** · Walk_Snappy_LegTiming_Test_v001.

The control is unchanged OneStep v002, as recommended by the deep research. V028 is an additional reference comparison; its different body/hop motion prevents it being the sole control. Only Leg.L/Leg.R channels change. Hip, torso, bounce, head, arms, root, cadence and appearance remain exact.

## Original-speed review

[Actions & Stuff / V028 / new test](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_snappy_leg_timing_v001/reference_v028_leg_timing_1x.mp4) · [Four-way comparison including unchanged v002 control](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_snappy_leg_timing_v001/controlled_four_way_1x.mp4).

[Isolated side A/B: v002 versus timing only](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_snappy_leg_timing_v001/isolated_side_AB_1x.mp4) · [Front / three-quarter / side](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_snappy_leg_timing_v001/leg_timing_three_views_1x.mp4).

Each video contains **six continuous alternating model steps**, three strides, 63 frames at 30 FPS / 2.1 seconds. No holds, replay pauses, endpoint padding or moving time normalization. Reference frames30–92 remain uncut at their recorded1× speed. Reference Walk repeats about20 frames versus our21; natural cadence drift is retained and labelled.

## Research used first

- [Exact local Player Deep Research](C:/Users/ADMIN/Desktop/GameAssetFactory/docs/animation/ACTIONS_AND_STUFF_PLAYER_DEEP_RESEARCH.md), especially sections4/6/11/12/14: repeated compact–exchange–open order; motion spacing, rig limitations and controlled comparisons.
- [Exact local evidence README](C:/Users/ADMIN/Desktop/GameAssetFactory/docs/animation/research/actions_and_stuff_deep_2026_10_14/README.md), its three Walk cycle atlases, annotations, timeline, body graphs and limb diagnostics. The atlas F30–50,50–70 and70–90 and the actual plots were inspected.
- [Animation Style Guide](C:/Users/ADMIN/Desktop/GameAssetFactory/docs/animation/ANIMATION_STYLE_GUIDE.md): rigid shape/attachment, purposeful spacing and sole/corner/loop verification.
- [Animation Expansion Guide](C:/Users/ADMIN/Desktop/GameAssetFactory/docs/animation/ANIMATION_EXPANSION_GUIDE.md): support ownership, one-variable studies, preserved approved Actions and artistic review.
- Actual V028 and OneStep v001/v002 source/evidence from previous studies; V028 and v002 were freshly rendered read-only for this comparison. No research source was edited.

**Observed evidence:** the reference becomes compact and exchanges legs around F33–35,53–55 and73–75: about15–25% of a full stride, or30–50% of one receiving-to-receiving step. Placement-like silhouettes recur at F30/40/50 etc. Exact release, sole contact, 3D path and acceleration are not measurable from these recordings. Shoe traces are rejected for that purpose in the research. Raw/corrected cap graphs establish visible ordering, not a target hip curve.

**Original experimental hypothesis:** move our exchange earlier toward the middle of that compact/exchange family, while preserving its spatial path and all body motion. The20 ms lead is a chosen test value, smaller than one source frame of uncertainty; it is **not** an Oreville timing measurement or copied keyframe data. No proprietary assets were imported.

## Exactly what changed

Both leg clocks gain a smoothly introduced20 ms lead while the foot is still in late stance. The lead stays constant through recovery/passing, preserving the original fast-swing spacing and peak speed. It fades between180–350 ms, providing more time for braking and placement, and becomes zero at the original contact. The monotone clock never reverses. This does not speed up the overall animation.

| Event after opposite receiving | v002 control | New timing test |
|---|---|---|
| Authored release |65 ms |45 ms |
| Measured departure above0.5 mm, both feet |67.2 ms |47.4 ms |
| Whole-leg lift crest |125.0 ms |105.2 ms |
| Sole passes hips sagittally |155.2 ms |135.4 ms |
| Peak forward sole speed |9.325 m/s |9.326 m/s |
| Next authored contact |350 ms |350 ms, unchanged |
| Full stride / nominal travel |700 ms /1.59936 m/s |unchanged |

Left/right measured departure and passing times agree within the0.52 ms sample grid. Existing290 mm piston target and fore/aft reach remain; measured sole extrema differ by less than0.02 mm. Hip height/timing and all arm/head motion are exact copies of v002, not adjusted to flatter the new leg timing.

### Necessary contact correction, disclosed separately

Retiming a planted foot without compensation would make it slide. While the mapped source foot remains planted, a Y-only translation cancels the difference in nominal travel between source time and actual time. It then fades continuously to zero during the first30 ms of the original recovery path, before its original rear-reach extreme. Maximum correction is31.99 mm. This is the sole spatial exception, required to keep contact and avoid a release discontinuity.

The rest of the full leg world-space path—including X/Z, rotation and original lift/reach shape—is simply sampled at the new time. Leg local transforms are rebaked against the unchanged animated hip parent; no body compensation is hidden in the edit. Matched-source path verification error is0.0002 mm, and rotation difference is0.000000 rad. **The Foot Recovery Path experiment has not begun.**

## Phase and native-frame evidence

Static sheets align referenceF30+i, V028F1+1.05i and control/testF22+1.05i. These are diagnostic model subframes against actual source frames; the videos remain native speed. All cameras, crops, lighting, character and floor are held consistent for the models.

![First-step receive/recovery/exchange at aligned phases](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_snappy_leg_timing_v001/phase_aligned_1.jpg)

![Open/braking/contact at aligned phases](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_snappy_leg_timing_v001/phase_aligned_2.jpg)

![Timing curves; hip curves overlap exactly](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_snappy_leg_timing_v001/timing_curves.png)

The three [native30FPS side strips](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_snappy_leg_timing_v001/native30_side_1.jpg) ([middle](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_snappy_leg_timing_v001/native30_side_2.jpg), [later](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_snappy_leg_timing_v001/native30_side_3.jpg)) contain every frame of one full stride for the actual control and test. The largest one-frame sole-center displacement is296.3 mm, versus294.2 mm for the control. The worst test interval is zero-based video frames14→15 (left swing); control is4→5 (right swing). These are large existing fast-swing distances, not proof of fluidity. Those intervals and their surrounding frames are explicitly shown. No discontinuous curve reset or extra held frame is introduced at contact/loop; the large native spacing may still read as a snap and needs artistic judgment.

**Provisional visual evaluation:** the early exchange is more decisive in the native sequence: the leg is already lifted at the old release frame and passes beneath the torso earlier, while landing remains on the same beat. Braking gets more space instead of raising peak speed. This is a modest timing improvement to exchange clarity, not yet evidence of the satisfying full Actions & Stuff rhythm. The piston shape, waist seam and existing body performance remain visible, so timing alone cannot fix them. Original-speed user preference is the artistic verdict; no technical score or similarity percentage substitutes for it.

## Isolation, contacts and loop

- All non-leg curve signatures are exact against v002; **897 paired evaluations show zero upper-body/world-pose difference**. Character rig/proportions, meshes, materials and source statuses remain unchanged.
- **2689 geometry samples:** grounded support throughout; no floor penetration or nonadjacent block overlaps. Nominal-travel active sole-corner drift0.0025 mm; floor clearance at least0.399 mm; rigid-distance error0.0002 mm. This is stability at the stated in-place diagnostic travel, not arbitrary gameplay foot locking.
- The inherited rigid-leg waist separation stays about60.2 mm, and head/chest clearance remains33.8 mm. Passing a historical75 mm limit does not make the seam visually acceptable; it remains a known baseline limitation.
- Registered playback is **F22–42 /30 FPS, closingF43 excluded**, using v002's already-authored second stride. All original Action keys F1–43 and every non-leg curve are retained. Its original one-shot full-span edge has a0.006143 m/s second-order mismatch in ForeArm.R, identically present in control/test; no arm repair is permitted in this isolated experiment. The existing second stride avoids that edge and gives pose error0.0000000 m and second-order velocity difference0.003673 m/s, under0.006 at the historical0.01-frame sample interval. Raw first-order difference0.015195 m/s is retained separately, not called a legacy pass.
- Review repeats only the selected stride in temporary in-memory render copies. Saved body curves are untouched. Actual GUI playback loops, pauses and restarts atF22; all24 entries, slots, timing, props and inactive save/reopen pass85 checks.
- All23 previous Actions/manifest entries and6251 protected existing files remain exact, including Godot, approved animations, v001/v002/V028 sources/reviews and deep research. Eleven H264 videos decode at30 FPS,693 frames total. Original reference SHA:2b4930b899230814606fc3f6ce341e6966b82a91d6a5d4a665e3057938beab0c.

Source SHA:24f18208240279e4865979b5b116830c857ec3d13e50ca2370abfa28cfd4406f. Action SHA:f231b92435d21e8d8d17fb820181a6137fa3559ec3054e6171a5d19c63fac18d. Machine-readable validation, isolation, timing and research-input hashes are beside this README.

No Godot export or gameplay edit, no approved Walk replacement, no new rig or Foot Recovery Path work. Future runtime integration must account for earlier support release, actual displacement and weapon/transition composition; it is not certified by this Blender study. **Stopped for artistic review.**
