**APPROVED2026-10-13:** current `Rifle_Ready_V2_v16_Test` in shoulder_support_v006 is the preferred Ready baseline. [Exact approval](APPROVAL.md)

# Rifle Ready v16 — closer left-hand support, Pending

Open the SAME `blender/animation/showcase/Animation_Showcase.blend`, N → Animation Library → **Rifle_Ready_V2_v16_Test**. Only one Ready entry,18 total Actions. This is another checkpoint of the same Action, not v17 or a duplicate entry.

The latest screenshot asks the LEFT hand closer beneath the rifle. Relative to the immediately preceding checkpoint, its palm moves **80.0mm forward and51.1mm upward**, also24.4mm toward character-left to follow the front support area. The full arm remains straight; shoulder has only10mm forward pose offset with no additional vertical shift. Palm is now62.0mm below the established rear-handguard underside guide, compared with113.2mm. This substantially reduces the center-to-support separation. The nearest sampled surface gap is6.83mm; it is a small clearance, not full finger wrapping. The nearest-surface number alone does not describe where the palm sits: the earlier5.39mm minimum was already at a different forearm/hand edge.

**Rifle and right arm are EXACTLY unchanged across121frames** in this last edit, as are body/head/legs/root/breathing. All17 other Actions and entries remain exact. The rifle retains the preceding requested70mm total shoulderward seating, cumulative11° whole-right-arm upward lift (front muzzle-down diagonal29.07°), modeled barrel parallel to the straight right arm and75mm wristward grip seating. The preceding lift included15mm outward right-shoulder clearance to avoid the upper arm/head corner. Actual grip is toward the wrist/sleeve edge and still needs artistic inspection; solid block hands have no fingers. Original geometry/materials/proportions/rest rig are unchanged.

Zero unwanted rifle/head/chest/left-arm/leg or cross-arm triangle intersections across121frames. Both elbows straight and connected, rigid lengths/scales preserved. Small existing right stock/upper-arm seating remains (22 overlapping triangle pairs maximum). These are Blender review checks, not gameplay-layer certification.

[Front](revised_front.png) · [Three-quarter](revised_three_quarter.png) · [Side](revised_side.png) · [Near-front](reference_angle.png) · [Before/after](ready_comparison.png) · [Source](rifle_ready_v16_review.blend)

F1–120/30FPS, closing121 excluded, same four-second hold breathing. Fresh reopening, all18 Action/slot/timing/prop switches, three view buttons, actual GUI playback/wrap/pause/restart, inactive save/reopen retention and loop pose/velocity checks pass. [Pose/contact](pose_and_contact.json), [Showcase](validation.json), [GUI](gui_playback.json), [Loop](loop_quality.json), [Retention](retention.json), [Preservation](preservation.json).

Earlier sources and views remain: [closer shoulder v004](../shoulder_support_v004/rifle_ready_v16_review.blend), [higher muzzle v005](../shoulder_support_v005/rifle_ready_v16_review.blend), [v003 review](../shoulder_support_v003/README.md). Immediate backup `.validation/rifle_ready_v16_support_v6/before/`; earlier `.validation/rifle_ready_v16_support_v4/before/` and `...support_v5/before/` preserve the incremental changes. The active library still contains only v16.

Source SHA256 `22017e77d5a722d087c46bd839e38fbec5a30ac5a56bb4b326e86cbbbbee3fde`; Action SHA256 `e12357dab1a854a4642f293e8049747f7e17b426ff69f1a4c331327b47e91743`. Pending artistic review. Aim/Hold, Back Holster, Weapon Showcase and Godot unchanged. Stop here for review.
