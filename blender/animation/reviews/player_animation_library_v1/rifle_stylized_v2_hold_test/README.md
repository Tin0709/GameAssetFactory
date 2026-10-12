# Rifle Stylized V2 — Blender holding review

Status: **Pending**. Stop here for explicit Blender review; no Godot replacement/integration is authorized.

Open the existing central [Animation Showcase](../../../showcase/Animation_Showcase.blend), then **N → Animation Library**. Select one of:

| Action | Review use | Timing |
| --- | --- | --- |
| Rifle_Ready_V2_Test | Lower ready, relaxed trigger grip and front support | F1–120, 30 FPS |
| Rifle_Aim_Hold_V2_Test | Raised holding/aim silhouette beside the face | F1–120, 30 FPS |
| Rifle_Back_Holster_V2_Test | Stowed back fit, relaxed straight arms | F1–120, 30 FPS |

All use a four-second quiet hold loop, with closing F121 excluded. The model follows the existing WeaponCarrier bone in the same Action as the arms. The viewer reuses one rifle assembly and hides it for older unarmed entries. Use Front / 3/4 / Side; orbit for the rear. The separate authoring source is [rifle_hold_review.blend](rifle_hold_review.blend); it is not another showcase.

If the list still ends at Full_Jump_Expressive_v2_Test, reopen the central file in a fresh Blender window. Refresh imports registrations, but an already-running old addon cannot display the new attached-prop behavior until it reloads. Preserve any personal unsaved edits separately first.

## Fit evaluation

- **Grip:** the right block hand meets the unchanged grip/trigger region, with no invented finger deformation. Small hand/weapon overlap represents a block-style grasp; this is not finger-level trigger calibration.
- **Support:** the left hand supports the rear portion of the handguard, with a relatively extended forearm and separated arm silhouettes. Both segments remain rigid. Existing elbow hinges are used because fully straight arms cannot reach both grips on this unchanged rifle/character combination without moving shoulders excessively or intersecting the head.
- **Alignment:** the raised rifle is biased beside the right side of the face, and the sight height is close to eye height. It remains laterally offset to clear the large cuboid head; exact right-eye sight/crosshair calibration is still a limitation, not a certified aim solution.
- **Scale:** original model scale 1.0, original proportions, geometry, UVs, material and packed texture preserved. Character proportions and rig rest data are unchanged. The rifle reads as a full-size 1.20 m rifle on the 1.80 m character.
- **Holster:** thin rifle width faces the back, with a 15° diagonal barrel-up layout. Stock clears hips, barrel clears head, and both arms remain straight. This is a stowed fit only, not a draw/stow transition or a newly modeled harness.
- **Shoulders:** pose-only lowering of approximately 130 mm plus 40 mm right-side clearance avoids head corners while keeping block segments attached visually. Inspect this slumped shoulder silhouette before approval; no rig, mesh or rest transform was rebuilt.
- **Remaining overlaps:** F1 diagnostics find no rifle/head, rifle/chest, arm/head or opposite-arm surface crossings. Aim has no rifle/upper-arm crossings; stowed has none against any body part. Ready retains a small stock/right-upper-arm seating overlap (10 polygon pairs). Forearm pairs remain at the intended grip and handguard contacts. Pair counts measure surface intersections, not penetration depth or artistic approval; deep/finger-level fit is not certified.

## Review media

| Pose | Front | 3/4 | Side |
| --- | --- | --- | --- |
| Ready | [Front](Rifle_Ready_V2_Test_front.png) | [3/4](Rifle_Ready_V2_Test_three_quarter.png) | [Side](Rifle_Ready_V2_Test_side.png) |
| Aim/Hold | [Front](Rifle_Aim_Hold_V2_Test_front.png) | [3/4](Rifle_Aim_Hold_V2_Test_three_quarter.png) | [Side](Rifle_Aim_Hold_V2_Test_side.png) |
| Back Holster | [Front](Rifle_Back_Holster_V2_Test_front.png) | [3/4](Rifle_Back_Holster_V2_Test_three_quarter.png) | [Side](Rifle_Back_Holster_V2_Test_side.png) |

[Rear holster detail](Rifle_Back_Holster_V2_Test_rear.png) · [Original-speed three-pose review](rifle_holds_1x.mp4) · [Review sheet](review_sheet.jpg).

All stills use the established stage/light transforms, materials and camera views. The existing lights were temporarily enabled for rendering only; their saved central visibility/settings remain unchanged. The optional rear camera is presentation-only and not saved over a library camera.

## Validation and preservation

[224 reopen/switch/slot/prop/timing checks](validation.json), [full-cycle rigid scale/feet and loop checks](loop_quality.json) and [actual GUI playback](gui_playback.json) passed: all three played, wrapped, paused and restarted after fresh reopening. All fifteen prior Action signatures and the rest rig match the backup. [Asset integrity](asset_integrity.json) verifies original character/floor meshes, UVs, weights, materials, lights and original V2 model data. [Intersection diagnostics](intersection_diagnostics.json) are F1 observations, not an all-poses gameplay collision certificate.

Backups and inspection scripts: `.validation/rifle_hold_blender_v1/before/`, with the first registered fit preserved under `before_final_fit/`. No Godot file, original rifle source or approved Action changed. Concurrent Weapon Showcase/pistol cleanup belongs to another session and was preserved; its current manifest still contains Rifle Stylized V2. These full-body studies do not yet establish upper-body weapon masks, moving grip retention, recoil/reload or draw/holster choreography.
