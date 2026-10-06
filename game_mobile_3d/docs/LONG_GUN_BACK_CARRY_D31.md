# D3.1 long-gun back carry

The old stable mount inherited the authored WeaponCarrier endpoint and its barrel-down orientation. M4A1 and Shotgun shared BackWeaponSocket/BackWeaponMount; Shotgun already had transport clearance. Release is frame 16 (0.625 s), DONE frame 18 (0.708333 s), unchanged.

The shared BackWeaponSocket remains attached to Chest and the cached authored BackWeaponMount endpoint is unchanged. `back_canonical()` supplies a visual offset expressed in Chest space and converted into that mount's space. Long guns now lie at 20 degrees from horizontal, stock upper-right and barrel lower-left. Their broad side faces the back, bringing the nearest gun surface to approximately 1 cm from the torso in the neutral pose.

Final Chest-space asset origins (meters): M4A1 `(0.025, 0.110, -0.180)`; Shotgun `(0.005, 0.095, -0.177)`. Existing weapon scales 1.12/1.14 are unchanged. No hip/Pistol placement changed.

Matching the new pose solely at release would rotate the weapon too abruptly. Only the weapon visual transform now settles during the final 0.383333 s of the existing transition, beginning 0.30 s before release. The early hand/shoulder transport and all authored bone tracks remain unchanged. Temporary sweep clearance avoids head intersections (M4: at most 6 cm back/3.5 cm sideways; Shotgun: at most 8.5 cm back), vanishing at both ends. Release still preserves the world transform; the existing release-to-DONE interval finishes the settle smoothly. No new event, state, animation or bone writer.

## Validation

- D3.1 rendered fixture: 1,808 checks, no failures. Idle, normal movement, Sprint, front/side/rear/elevated gameplay views, turns and sampled late Holster frames for both long guns.
- Actual-controller directional/diagonal Sprint fixture: 353 checks, no failures; stable mount, continuous Run clock, Root travel 0, no sprint firing.
- D3 A-M regression: 1,127 checks, no failures; switching, awareness, Draw cancellation, firing and Sprint priority preserved.
- D2 transition regression: 9,088 checks, no failures. Reparent errors are below 1e-6 m and 0.0015 rad (quaternion numerical precision).
- D0 regression: 112 checks, no failures using the required fixed 60 FPS fixture. An initial run omitted `--fixed-fps 60` and failed its clock measurement; the corrected deterministic invocation passed.
- Triangle/rigid-box SAT sampled 32 phases per Idle/normal movement/Sprint/category: no head or deep torso intersections while stowed. Transition tests also show no head intersections. Weapon meshes, skinning and Idle/Run source channels remain identical in the asset regression.

The pose stays stable relative to Chest, including turns and diagonal movement. It has a flatter silhouette and reduced apparent stand-off in the unchanged gameplay camera. No discontinuity was apparent in sampled handoff images; global-preserving reparent measurements pass.

Remaining overlap: rigid forearms/hands can intersect stock/barrel during extreme backward Run swing; this is visible in some close rear contact views. Idle/normal movement arm tests are clear. The existing short Shotgun stock/chest overlap at initial Holster entry (0-0.0333 s) remains. The pose is a visual-review candidate, not a claim of fully collision-free arms. Locomotion and weapon geometry were deliberately preserved.

## Scope and review

Production file changed: `scripts/player_weapon_socket.gd` only. Controller, camera, collision, weapon behavior, firing, cadence 1.60, Hold_V2, Holster timing, Blender and GLB assets were not changed for D3.1. Runtime work consists of a small number of transform interpolations only during Holster; stowed weapons use the existing native Chest attachment, with no continuous polling or new production nodes.

Tests: `tests/validate_back_carry_d31.gd`, `tests/validate_back_carry_d31_live.gd`, `tests/inspect_back_carry_d31.py`, `tests/back_carry_d31_body_boxes.json`, generated reports, and the updated D2 expected final visual transform. Body boxes come from the preserved GLB's rigid skinning/inverse bind transforms. Review: `tests/review_back_carry_d31.gd`.

No runtime errors/warnings in the final checks. Godot uses mobile D3D12 for GPU review. Screenshots: `.validation/back_carry_d31/`.

Interactive harness starts M4A1 STOWED with the back facing the unchanged gameplay camera. WASD/Shift and 1/2/3 are the existing movement/weapon controls; K uses the existing enemy spawn to review Draw/Holster. Waves and level-up prompts are disabled only in the review harness. No production scene resource was edited.
