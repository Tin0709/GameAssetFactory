# Lower piston recovery — Pending

`Walk_Snappy_Test_v1` in the existing Animation Showcase, F1–30 at 30 FPS; closing F31 excluded. This replaces the rejected high recovery in the active entry. All previous saved sources and reviews remain preserved.

The rejected piston test translated the leg so far upward that most of it disappeared inside the torso. Lowering the peak to 180 mm leaves a readable hanging leg. The leg draws under the hip, rises almost vertically, then advances while lowering. It no longer uses the previous 86–88° hip kick. The original proportions, rigid limb lengths and rest rig are unchanged.

The strong body snap is exactly preserved: the same 110 mm contact drop over 80 ms, 130 mm total hip height range, torso counter-motion, head and arm motion. Only leg location/rotation curves differ from the preserved v003 source. This is a modest lift, superseding the earlier request for a stomach-height experiment.

## Review

- [Original-speed front / three-quarter / side video](walk_snappy_three_views_1x.mp4)
- [Previous hip arc versus lowered piston, original speed](previous_vs_piston_1x.mp4)
- [Approved Walk versus experiment, original speed](approved_vs_snappy_1x.mp4)
- [All 30 frames inspected](cycle_inspection.png)
- [Vertical pull front](vertical_lift_front.png), [three-quarter](vertical_lift_three_quarter.png), [side](vertical_lift_side.png)
- [Forward placement three-quarter](advance_three_quarter.png)
- [Review source](walk_snappy_review.blend)
- [Existing central Showcase](../../../../showcase/Animation_Showcase.blend)

Reopen the existing Showcase to load the corrected saved Action. Select `Walk_Snappy_Test_v1`, which remains Pending. Refreshing the list alone does not replace an Action already cached in an older open Blender session.

## Evaluation and checks

The lower recovery keeps the trouser silhouette visible rather than reducing it to a floating boot. The raised leg is nearly vertical at peak; its modest forward pitch develops during descent. Alternation and the accepted body compression remain pronounced. Upper-leg overlap under the shirt is still used to represent rigid piston translation; this is an artistic experiment, not an anatomical knee solution.

961 subframe samples: rigid error below 0.00025 mm, no floor penetration, no unsupported interval or nonadjacent block overlap. Nominal-travel support-edge drift is 0.00329 mm. Both soles peak at approximately 180.4 mm. Loop pose error is zero; finite seam velocity difference is 0.00546 m/s, below the unchanged 0.006 guard. All non-leg curves match exactly and 121 evaluated non-leg pose comparisons have zero difference. These numerical checks supplement the full-cycle visual inspection; they do not establish artistic approval.

The loop retains LEFT receiving phase 0 and RIGHT phase 0.5, 0.27 m contact tracks, 64/66% support, 30% double support and no flight. Root remains stationary; the 1.02 m/s nominal travel used for foot checks is separate from the Action. Start/stop replants, runtime translation blending, weapon overlays and gameplay transitions remain untested. No Godot integration, Running Action or rig changes were made. Rifle Idle remains paused.

Validation: [motion](motion_validation.json), [registration](registration.json), [Showcase/reopening](showcase_validation.json), [appearance](appearance_validation.json), [GUI playback](gui_playback.json), [media](media_validation.json), [preservation](preservation.json).

Stop for user review before further animation work.
