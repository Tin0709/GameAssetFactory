**APPROVED2026-10-13:** current same-v16 in [shoulder_support_v006](shoulder_support_v006/APPROVAL.md). Source and Action preserved; separate [Rifle Ready Idle review](../rifle_ready_idle_expressive_test/README.md) remains Pending.

**Latest same-v16 review — 2026-10-13, Pending:** [left hand farther forward and higher beneath the rifle](shoulder_support_v006/README.md), retaining the closer shoulder seating and higher muzzle. Same `Rifle_Ready_V2_v16_Test`, one Ready/18 total.

**Latest same-v16 refinement — 2026-10-13, Pending:** [closer shoulder seating and lifted left-hand support](shoulder_support_v003/README.md). Select the same `Rifle_Ready_V2_v16_Test` in the existing Showcase. Only one Ready entry,18 total; earlier source/review checkpoints remain historical comparisons.

**Latest same-v16 refinement:** [Left arm closer to body and higher — current review](left_arm_tuck_v001/README.md). This supersedes the pose shown below. Only v16 remains in the active Showcase; older Ready entries were removed by user request.

# Rifle Ready v16 — a little farther forward, Pending

Select **Rifle_Ready_V2_v16_Test** in the SAME `blender/animation/showcase/Animation_Showcase.blend`, N → Animation Library. This saved entry is Pending. All32 earlier Actions and entries, including v15, remain unchanged and selectable.

The user requested another small forward adjustment toward [the supplied reference](user_ready_reference.jpg). The straight right arm rotates forward at its existing shoulder, moving the right palm **36.6mm farther forward than v15** and the receiver-center guide39.3mm forward. The40.1° front-view diagonal, actual barrel/whole-arm parallel alignment, original arm lengths and5mm wristward grip seating remain. The left straight arm follows underneath; its hand stays slightly below the rifle with a sampled**17.7mm** no-touch surface gap. Its shoulder is10mm lower than v15. Body, head, legs, root and four-second breathing are unchanged.

[Front](revised_front.png) · [Three-quarter](revised_three_quarter.png) · [Side](revised_side.png) · [Reference-angle review](reference_angle.png) · [Matched v15/v16 comparison](ready_comparison.png) · [Closer side comparison](side_clearance_comparison.png) · [Authoring source](rifle_ready_v16_review.blend)

Across121frames, bidirectional vertex-to-surface samples give the closest rifle/chest gap at approximately108.4mm in v15 versus127.6mm in v16. These are samples, not an exact triangle edge-to-edge minimum. The receiver-center depth guide is a separate measurement. [Forward clearance evidence](chest_clearance.json) confirms the gain, unchanged right shoulder and unchanged front diagonal over the entire loop. The left palm center remains about52mm below the rear-handguard underside guide, distinct from its surface gap.

No rifle/head, rifle/chest, rifle/legs, rifle/left-upper-arm, opposite-arm or head/arm triangle intersections occur in the full cycle. Intentional right-hand grip overlap and small stock/right-upper-arm seating remain. No rig, geometry, material, scale, appearance or Godot changes; moving weapon layers remain unvalidated.

F1–120 at30FPS, closing121 excluded. 693 fresh-reopen checks pass for prior Action signatures/manifest entries, rig, slots/switching, visibility/timing, modeled barrel alignment, hand seating, unchanged body, floor clearance, planted support, rigid scale and seam pose. [Loop velocity](loop_quality.json), [hand clearance](hand_clearance.json), [validation](validation.json), [GUI play/wrap/pause/restart](gui_playback.json), [inactive Action save/reopen](inactive_action_retention.json), [contact diagnostics](intersection_diagnostics.json), [protected-file audit](preservation.json).

Backup: `.validation/rifle_ready_v16/before/`. Source SHA256 `bab0ba220d6801f94a46072e38bc1f1434f70c0e50e18b9cc83e47b2aa92280d`; Action SHA256 `6b52ded845d407dc4e0e9effcda22c52f1dde7664499e923ee2ab3c508ed015c`. Every previous Ready version, approved animation, Aim/Back Holster, Weapon Showcase and Godot file is preserved. **Pending Blender review. Stop here.**
