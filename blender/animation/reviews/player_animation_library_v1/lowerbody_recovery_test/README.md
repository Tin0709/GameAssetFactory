# Lower-body recovery test

2026-10-10, Asia/Saigon. **Original Blender-only motion study; awaiting user review.** The user explicitly approved both `Expressive_Arm_Motion_Test` and `Run_Expressive_Test` as successful exploratory steps in the request for this study. That approval supersedes the older run README's pending status, and applies to those explorations only. This new test has not yet received artistic approval.

Main references: [Animation Style Guide](../../../../../docs/animation/ANIMATION_STYLE_GUIDE.md), [approved arm exploration](../expressive_arm_motion_test/README.md), and [approved run exploration](../run_expressive_test/README.md). The study carries forward their rigid articulation, attached shoulder arcs, controlled asymmetry and restrained gaze. It adds original lower-body timing and contact poses; no reference-game curves or rig were copied.

## Review files

- [Three-angle review video](lowerbody_recovery_review.mp4): front, three-quarter and side together, 1x speed, three **one-shot replays**, with labeled end holds/cuts. These resets are edits for review, not animation loop seams.
- [Single uninterrupted pass](lowerbody_recovery_1x.mp4): 48 actual rendered frames, 30 FPS, 1.60 seconds. The F1–48 key interval spans 47/30 seconds; F48 is displayed for one frame.
- Individual 1x passes: [front](front_1x.mp4), [three-quarter](three_quarter_1x.mp4), [side](side_1x.mp4).
- [Native Blender study](lowerbody_recovery_review.blend): scene `LOWERBODY_RECOVERY_REVIEW`, rig `LB_Test_Rig`, Action **`LowerBody_Recovery_Test`**, frames **1–48**, **30 FPS**. The saved file opens at maximum absorption, F18. Select the named scene and play its timeline; the historical Player Review sidebar remains unchanged.
- [Key poses](recovery_pose_sheet.jpg), all 48 frames in each view: [front](front_all_frames.jpg), [three-quarter](three_quarter_all_frames.jpg), [side](side_all_frames.jpg).
- [Approved run support versus new study](baseline_support_comparison.jpg): identical review camera, lighting, mesh, material and actor scale. The actions serve different purposes; this comparison does not imply equivalent physical events or altered source-run timing.
- [Decoded video samples](decoded_review_samples.jpg), [geometry/contact validation](validation.json), [fresh saved-file verification](saved_file_verification.json), [video decode checks](media_verification.json).

## Current run limitation

Source inspection and the approved run's rendered front/three-quarter/side sequences show a successful shoulder/stride language, with a less developed load/recovery vocabulary:

- Compression is a short, bilateral cyclic support pulse. The run uses up to about 55 mm of support-leg retraction; that number describes its leg-location channel, not a measured anatomical knee bend or this study's hip drop.
- Hip height is primarily tied to the repeating support/flight pattern. There is little lateral transfer, and the same left/right support shape repeats. A separate receiving side and stabilizing side are not emphasized.
- Torso motion follows periodic gait accents. A quick downward event followed by delayed torso absorption and a longer lower-body recovery is not independently tested there.
- Free-leg recovery is energetic, but releasing the stylized hip overlap into a deliberate settled support remains a limitation. The existing whole-block legs cannot bend at knees/ankles, and rigid boots roll across sole edges.

These observations identify the next improvement; they do not revoke approval of the run. Existing upper-body quality is retained as the reference rather than increased indiscriminately.

## Authored motion

| Frames | Support and motion |
|---|---|
| F1 | Compact staggered moving-ready stance; quiet gaze, low asymmetric arms. |
| F1–7 | Small pelvis shift over the left side, 28 mm hip lowering, restrained counterbalance. |
| F7–13 | Left foot remains supported. Right foot unloads, clears the floor by about 28 mm at its peak, and replants 75 mm farther forward. No whole-body flight. |
| F13–18 | Weight moves toward the receiving right side; hips lower to the main compression. The left foot stays down as stabilizing support. |
| F18–22 | Pelvis begins recovering while spine/chest and arms finish their response. Secondary peaks occur later than the hip bottom. |
| F22–33 | Longer recovery from compression, release of the hip overlap, then a small 11 mm rise above the initial hip height. |
| F33–42 | Soft settle into a stable moving-ready pose, retaining the new staggered foot placement. |
| F42–48 | Brief quiet ending; no jump, takeoff, aerial hold, gait replacement or production transition. |

Measured hip height ranges **0.548–0.685 m**, with **0.126 m** lowering from the initial ready pose. Lateral hip travel ranges **−0.040 to +0.048 m**. These are original authored/evaluated values, not inferred sequel parameters. Pelvis pose translation is part of this local support study; `Root` and actor world transforms stay fixed, with no preview carrier or capsule trajectory.

The contact solver is an **offline authoring tool**. It aims each existing rigid leg toward its hip and bakes rotations/locations into ordinary bone channels. A low sole corner/edge stays at its ground anchor during rigid roll; this does not claim that every sole vertex lies flat or remains planted. The right foot's replant deliberately moves its anchor during the unloaded interval. No runtime IK, constraints, drivers or new bones are introduced.

## Rig, shape and pose limits

**No rig change was necessary.** The copied 13-bone rig has identical names, hierarchy and rest matrices. The new mesh object references the same original 64-vertex mesh datablock, including full arms/hands, unit weights, UVs, texture pixels and materials. No mesh edits, scaling, stretching, soft skinning, rest-pivot corrections or proportions changes were made.

Compression uses bounded overlap of the unchanged rigid legs into the torso, as in the approved run. The maximum **leg local-translation magnitude is 149.05 mm**; this includes the support compensation and is not a pure vertical retraction measurement. Although every block keeps its actual dimensions, its **exposed length changes** during hip overlap. This is a visible stylization and the principal remaining limit; the test does not establish human knee/ankle compression.

The initial pass had shallow head/upper-arm overlap (up to 1.16 mm) near ready/recovery and 1.72 mm between the legs at compression. Isolated pose probes traced these to clearance, not missing rig controls. A little more arm spread at ready/recovery and **2 mm outward leg pose offset per side** cleared them. The established 32 mm shoulder inset is unchanged; these adjustments never alter the rest skeleton. First-pass file, frames and metrics are retained in the backup directory.

## Visual assessment and readiness

**Improved:** the pelvis now visibly leads the load; the small receiving step and lateral shift give the compression a support change. Downward compression is quicker than recovery, and the delayed chest/arm response helps the body read as carrying weight. Front view exposes the side-to-side transfer; three-quarter view shows the hip/torso relationship and attached arms; side view best reveals lowering, forward absorption and the recovery overshoot. The face remains calm and block faces stay straight. This is an assessment of the Blender sequence, pending the user's judgment.

**Still limited:** deeper compression exposes the whole-leg sliding/overlap treatment. There is no knee folding, ankle articulation or independent toe push-off. The 75 mm receiving step is deliberately small, and the ending is a moving-ready pose, not a demonstrated blend into an advancing run. Both-leading-foot versions, weapons, slopes, interruptions, variable impact strength and actual engine support composition are untested.

**Readiness:** this provides a workable basis for the next **small takeoff/landing quality test**, subject to the user's review of this compression style. It does not establish readiness for full jump production. A future test should verify ground release, actual contact, overlap release and recovery into continuing support before expanding into a production jump. No such jump test or Godot integration was started here.

## Validation and preservation

Fresh-process verification loads the saved `.blend` and checks **753 evaluated times** at 1/16-frame spacing. Nonadjacent block intersections and camera bounds are checked at 1/8-frame spacing, with every rendered integer frame available for visual inspection.

- **328 earlier Actions preserved**, including both approved tests; **329 total**, adding only `LowerBody_Recovery_Test`.
- Original mesh, UVs, weights, materials/images, rest armatures, old Action curves, text data, original scene timing and object/animation bindings match the pre-change snapshot. Approved run, approved arm and master-library file hashes remain unchanged.
- Maximum rigid-segment distance change **0.234 micrometers**, at floating-point scale. No scale tracks.
- No sampled floor penetration or interval without support. Maximum support height **0.488 mm**, including the intentional 0.4 mm margin.
- Maximum supported low-corner horizontal anchor error **0.013 mm**. This is a stationary-stage corner/edge-roll measurement, not full-sole locking or runtime gait evidence.
- No sampled nonadjacent block intersections after the pose corrections. Adjacent attachment overlap is intentional and reviewed visually.
- Three-angle framing retains the actor throughout. Exact metrics and sample scope are in the linked JSON files; none certify runtime animation or phone performance.

All three individual videos and the composite contain the 48 actual sequential Blender renders; the review video has 189 decoded frames including labeled replay holds. Media checks verify count, 30 FPS and dimensions; the uninterrupted composite is compared against every corresponding source composite after H.264 decode.

## Backups, boundaries and reuse

Before any Blender changes: [approved saved-run backup](../../../../../.validation/lowerbody_recovery_test/approved_run_disk_before_test.blend), [live-state backup](../../../../../.validation/lowerbody_recovery_test/live_before_test.blend), [backup hashes](../../../../../.validation/lowerbody_recovery_test/backup_manifest.json), and [authored-data snapshot](../../../../../.validation/lowerbody_recovery_test/original_data.json). The first authored pass is also retained as `first_pass.blend`, `first_pass_frames/` and `first_pass_validation.json` there. RESEARCH was backed up before its small status update.

The source library, approved exploration files, production GLBs, project configuration, Godot scenes/controllers and unrelated assets were not replaced. Current inspected runtime remains WorldMap → `CuboidPlayerJumpGifV004.tscn`, with its existing V003/R15 inheritance. Existing Godot compatibility is preserved by unchanged runtime resources and the original rig/mesh contract. **This new Action has not been exported/imported or tested in Godot.** Future export must include its location channels, ordinary rotations and unit scale; rotation-only export would lose contact behavior. No new phone-performance claim.

Scripts: `build_test.py` adds the isolated scene/actor/Action and bakes authoring calculations; `validate_test.py` and `verify_saved.py` inspect the evaluated/saved data; `render_review.py`, `package_review.py` and `encode_review.py` produce and check actual review media. Build only from a freshly backed-up approved source; it rejects an existing Action of the same name. Keep experiments versioned, and never overwrite the approved explorations or old Actions.
