# Step-following body turn — Pending

`Walk_Snappy_Test_v1` remains a single selectable Pending entry in the existing Animation Showcase. F1–30 at30FPS, closingF31 excluded. Older sources, the stronger bounce, the softer hop, the wider/higher step and the intermediate no-yaw pose are preserved.

The latest clarification replaces lateral sliding with a **step-following body turn**. When the left leg advances, the left side of the body moves forward; the opposite side follows the right step. The body stays centered over the walking line, with no lateral roll. Hips turn about5°, spine6.5°, chest8° and head3°, with restrained successive delays. Turn direction is driven by the relative forward/back position of the legs, not an unrelated oscillation. The head follows less than the chest.

The previous leg paths are preserved exactly: forward/back reach is25.44%longer than the original piston experiment (another12%over v005), stepping lift is270mm (+50%over180mm), and the whole character hops35mm over a140ms window each step. The soft downward contact load stays36.25mm over80ms, retaining the requested75%reduction from the stronger145mm probe. Contact tracks remain0.27m apart; cadence remains one second per alternating cycle. All original rigid proportions remain unchanged.

## Review

- [Front / three-quarter / side at original speed](walk_snappy_three_views_1x.mp4)
- [Overhead original-speed review](snappy_overhead_1x.mp4)
- [Previous softer-hop version versus latest experiment](previous_vs_centered_1x.mp4)
- [Approved Walk comparison](approved_vs_snappy_1x.mp4)
- [All30frames](cycle_inspection.png)
- [Higher piston lift](vertical_lift_three_quarter.png), [whole-body hop from side](rebound_side.png)
- [Review source](walk_snappy_review.blend)
- [Existing Animation Showcase](../../../../showcase/Animation_Showcase.blend)

Reopen the existing Showcase to load the saved corrected Action, then select `Walk_Snappy_Test_v1`. A list refresh alone does not replace an older Action already cached in an open Blender session. The entry remains Pending.

## Evaluation

The body advances its leading side with each step while staying over a fixed lateral center. The chest turn is more readable than the restrained head turn, and the shoulders inherit that rotation while retaining their original arm swing. Vertical rebound, softer receiving and the higher piston step remain the dominant rhythm. The brief waist separation is intentional, approximately26–28mm. Upper-leg overlap under the shirt is still used for this rigid piston style. This is a stylized hopping-walk experiment awaiting artistic review.

## Checks and limits

961subframe samples verify fixed lateral body centers (maximum range below0.0002mm), negligible body roll and step-following yaw error below0.00009°. All121sampled leg world pose matrices match v006 within1.8e-7 per component. Arm/forearm/root channels and all19other Actions remain exact. Rest rig, meshes, weights and materials are unchanged.

Rigid length error is below0.00186mm, nominal-travel support-edge drift below0.00306mm, with positive floor clearance, no nonadjacent block overlap and no unexpected support loss. The intended hops add approximately252ms thresholded airborne time per one-second cycle; nominal support is50/52%, double support30%, flight28%. Primary receiving phases LEFT0/RIGHT0.5 remain, with additional hop touchdowns. Nominal travel1.279488m/s is used only for contact checks and is separate from the in-place Action.

Loop pose error is below0.000067mm; channel tangents remain continuous. The raw first-order finite seam comparison is0.00708m/s and still fails the legacy0.006guard. The second-order one-sided estimate at the same0.01-frame step is0.00376m/s, below0.006. The more accurate estimator separates acceleration from discontinuity; this is not an unchanged legacy pass.

Showcase reopening, Action/slot/view switching, inactive retention, GUI playback/wrap/restart, eight original-speed videos and preservation are verified separately. Root remains stationary. Future runtime physics, start/stop replants, phase-aware blends and weapon layers must account for the extra flight and contacts; these are untested. No Run Snappy Action, Rifle Idle continuation, rig, Godot or production change is included.

Evidence: [motion](motion_validation.json), [registration](registration.json), [Showcase](showcase_validation.json), [appearance](appearance_validation.json), [GUI playback](gui_playback.json), [media](media_validation.json), [preservation](preservation.json).

Stop for user review.
