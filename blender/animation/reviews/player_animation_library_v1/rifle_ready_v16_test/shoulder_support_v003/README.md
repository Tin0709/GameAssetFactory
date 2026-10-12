# Rifle Ready v16 — closer shoulder seating and lifted support, Pending

Open the SAME `blender/animation/showcase/Animation_Showcase.blend`, N → Animation Library → **Rifle_Ready_V2_v16_Test**. This remains the only Ready entry;18 Actions total. No v17 or duplicate Ready Action was created.

The latest user steering asks the rifle even closer to the shoulder and the left hand closer beneath the rifle. This checkpoint slides the actual unchanged Rifle Stylized V2 **another25mm toward the right shoulder**, totaling50mm across this refinement. The prior6° whole-right-arm upward lift is retained (front muzzle-down diagonal34.07°). The modeled barrel remains parallel to both straight right-arm segments. The actual pistol-grip center sits55mm wristward of the nominal palm center, inside the solid block-hand region; it is not artificially centered after the requested slide.

Compared with the immediately preceding checkpoint, the left palm moves**12.2mm inward and49.8mm upward**, with6.1mm back toward the torso. Its nearest sampled surface gap closes from1.50mm to**0.45mm**, and the palm is about34.8mm below the rear-handguard underside guide. This places the block hand visibly beneath the rifle. The contact is an edge/near-contact treatment; the current solid hand has no fingers or wrapping articulation. The latest request supersedes the earlier32.5mm deliberate hovering gap.

Both full arms remain straight with connected elbows. Body, head, legs, root and breathing are unchanged across121 evaluated frames; all17 unrelated Actions remain exact. Original geometry, UVs, materials, proportions and rest rig are preserved. There are zero unwanted rifle/head/chest/left-arm/leg/cross-arm intersections across the cycle. Small stock/right-upper-arm seating remains (22 overlapping triangle pairs at maximum), as does intentional right-hand grip contact. These are Blender-only checks, not gameplay layer certification.

[Front](revised_front.png) · [Three-quarter](revised_three_quarter.png) · [Side](revised_side.png) · [Near-front view](reference_angle.png) · [Matched comparison](ready_comparison.png) · [Source](rifle_ready_v16_review.blend)

Same F1–120/30FPS, four-second restrained hold breathing; closing121 excluded. Fresh reopening, all18 Action/slot/timing/prop switches, three views, actual GUI playback/wrap/pause/restart, inactive save/reopen retention, rigid lengths and loop pose/velocity checks pass. [Pose/contact measurements](pose_and_contact.json), [Showcase checks](validation.json), [GUI playback](gui_playback.json), [Loop](loop_quality.json), [Retention](retention.json), [Preservation](preservation.json).

Previous checkpoint/source: [shoulder_support_v002](../shoulder_support_v002/rifle_ready_v16_review.blend). The earlier [left-arm tuck review](../left_arm_tuck_v001/README.md) is also preserved. Immediate pre-edit backup: `.validation/rifle_ready_v16_support_v3/before/`; earlier pre-lift backup: `.validation/rifle_ready_v16_support_v2/before/`. Older archives retain their cleanup/restore location described in `CLEANUP_ARCHIVE.md`.

Source SHA256 `4bdd64879a666c1d5d25b2868151fe0c87d07d7b56dcd8b0ae1a685bf796ef98`; Action SHA256 `8347e39db2d3766a7ac32ab693d29bf0181d094307d532464308a29c75f1c0eb`. Pending artistic review. Aim/Hold, Back Holster, Weapon Showcase and Godot remain unchanged. Stop here for the user's Blender review.
