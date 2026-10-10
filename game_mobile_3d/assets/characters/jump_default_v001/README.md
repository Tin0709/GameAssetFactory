# Jump Default V001 — WorldMap review

User-authorized integration on 2026-10-10; **SPACE** jumps, WASD/Shift retain movement, R resets. Main F5 is WorldMap. **ARTISTIC STATUS: AWAITING HUMAN REVIEW.** Earlier scenes and deferred V2 block-jumps stay unchanged.

Source: [saved player library](../../../../blender/animation/reviews/player_animation_library_v1/player_animation_library_v1.blend), Action `Jump_Default_v001`, F1–25/30 FPS, 0.8 s. [Exporter](../../../../blender/animation/reviews/player_animation_library_v1/jump_default_v001/export_runtime.py) runs with background Blender on that saved file, scripts disabled; never saves or changes the live Blender window.

`player_r15_jump_default_v001.glb` keeps native R15 geometry, UVs, normals, indices, material, images and all 36 animation definitions. Adds the 120 Hz pose-only clip and the original two forearm joints/rigid vertex bindings, preserving authored elbow movement. Existing Arm.L/R names remain for the weapon system. 13 skin joints, plus the legacy non-deforming WeaponSocket added at runtime. No changed mesh/proportions, scale or carrier/root travel. `export_validation.json` records SHA protection and evaluated vertex reconstruction error. `source.json` is the sampled audit/timing record; runtime samples the imported GLB.

Import uses `res://tools/jump_default_post_import.gd` to retain exact existing imported R15 clip tracks, including legacy clip adapters and masked strafe tracks. Preserve `.glb.import`: 120 FPS, optimizer disabled, immutable tracks retained, named skins. Do not reuse automatic import defaults.

WorldMap creates `CuboidPlayerJumpReview.tscn` before child readiness. New controller inherits existing horizontal movement and smooth-step logic; new visual inherits R15's single pose writer. Physics owns a 0.63m jump with 4/30s anticipation, 14/30s flight and 6/30s recovery. Collisions can shorten/extend flight; pose waits before contact until support. Held guns keep current grips/recoil/stow-draw while body/legs use the jump. Unarmed and stowed guns allow the full authored arm pose. No duplicate targeting or root-motion controller.

Validation and actual gameplay recording are linked from [RESEARCH](../../../../docs/graphics/RESEARCH.md#animation-nhảy-block--blender-v1-và-v2-chờ-review). No phone-performance verification. Rigid legs still limit landing compression and perfect foot locking.
