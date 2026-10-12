# Rifle Ready v8 — Pending Blender review

Select **Rifle_Ready_V2_v8_Test** in the existing `blender/animation/showcase/Animation_Showcase.blend`. The actual Rifle Stylized V2 is attached and synchronized. F1–120 at 30 FPS, four-second loop; F121 closes the cycle and is excluded from playback. Front / 3/4 / Side buttons remain available.

The latest explicit clarification supersedes the earlier 90-degree request: **the long barrel follows the straight right arm's diagonal**. The grip remains centered in the right block hand. The shoulder-driven arm reaches farther forward than v6, giving the rifle more torso clearance; the left straight arm maintains its handguard support. Both elbows stay straight. Planted idle-derived legs, calm head and restrained breathing remain.

## Review

- [Front](revised_front.png), [three-quarter](revised_three_quarter.png), [side](revised_side.png).
- [Matched previous-v7 / revised-v8 comparison](ready_comparison.png): previous perpendicular version above, aligned version below. Same camera, frame, lighting and render settings.
- [Authoring source](rifle_ready_v8_review.blend).

The silhouette now has a continuous right-arm/rifle diagonal rather than the crosswise barrel in v7. The weapon remains below the face and ahead of the torso. Perspective foreshortening can hide the parallel alignment from a single view; inspect the side view as well. Small stock/right-upper-arm seating remains. Forearm intersections include the intentional solid-hand grip/support contacts; these triangle-pair counts do not establish contact depth or finger-level grip fit. Head, chest, opposite-arm and leg intersections were absent at the reviewed resting frame. No mesh cutting, elbow overlap trick, deformation or rest-rig change was introduced. Moving weapon layers, draw/holster choreography and Godot compatibility still need separately approved gameplay validation.

## Verification

- 304 fresh reopen/switch/slot/visibility/timing/pose checks passed, including all 121 evaluated frames. All 24 previous Actions and manifest entries retain exact signatures/data.
- Both elbows: 0.0000 degrees. Maximum hand-target error: 4.2e-07 m. Maximum `abs(1 - barrel.dot(right_arm))`: 7.5e-08.
- [Loop pose/velocity and planted-leg checks](loop_quality.json), [detailed validation](validation.json), [contact diagnostics](intersection_diagnostics.json).
- [Fresh GUI playback](gui_playback.json): Play, wrap, Pause and Restart. [Inactive save/reopen](inactive_action_retention.json): all 25 Actions retained after switching to Walk in a scratch copy.
- [Protected-file hash audit](preservation.json). Backups: `.validation/rifle_ready_v8/before/`; source/manifest/library hash guards checked before updating the same Showcase.

Source SHA256: `9d6f5a1c66a6f687b08948eada4e0dcf4c0f8e60ffb77d611bc3f135959b31ea`. Action SHA256: `6ad6e876fe98d4442cef6dc1e19577ab39b9b6e04d2b904cf1eff69ca0497bd6`.

Only Rifle Ready was refined. All earlier Ready versions, Aim, Back Holster, approved animation sources, preferred rifle model, Weapon Showcase and Godot are preserved. This version is **Pending**, not approved; stop for user review.
