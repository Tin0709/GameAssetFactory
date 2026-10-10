# Animation review workflow

Read `docs/graphics/ART_DIRECTION.md`, relevant `docs/graphics/RESEARCH.md` records and `ANIMATION_STYLE_GUIDE.md` before animation work. Preserve full arms/hands, proportions, textures, production rigs, existing independent Actions and Godot compatibility. Back up every file before changing it.

The permanent review workspace is [Animation_Showcase.blend](../../blender/animation/showcase/Animation_Showcase.blend). Its [README](../../blender/animation/showcase/README.md) documents the N-panel, registration and refresh. Its manifest is the source of clip ranges, FPS, source paths/hashes, original Blender 5.2 slots and explicit review status. Do not bulk-import legacy Actions.

Author new tests in separate saved studies. Register compatible tests with `register_animation.py`; all new entries start **pending**. Use unique versioned Action names. Refresh the viewer, inspect the actual motion/pixels and save the updated showcase after retaining its backup. Never replace an existing Action or silently alter a rig to make it compatible. Failed compatibility must be reported.

After explicit user approval, update only the relevant manifest status/approval note, refresh and save. Technical validation, registration, a proposed animation or runtime integration is not artistic approval. Approved studies should remain registered in the central library for future sessions.

Current explicitly approved exploratory references: `Expressive_Arm_Motion_Test` (1–24), `Run_Expressive_Test` (1–18, preserve closing key 19), `LowerBody_Recovery_Test` (1–48); all 30 FPS. Original sources remain under `blender/animation/reviews/player_animation_library_v1/`. The user subsequently approved the viewer and explicitly requested `Jump_Takeoff_Test` only. It is registered as **pending**, F1–24 at 30 FPS; no full arc, landing, production jump or Godot integration is implied.

Approved artistic direction: preserve the subtle **“nhúng nhúng”** weight shift/compression near the ground—soft but controlled, light but weighted, alive and blocky. Use the approved recovery as the primary compression reference; avoid replacing it with a deep exaggerated squat or rubber motion. Carry this preference into future takeoff and landing studies.

Validate slot bindings, partial-pose reset, playback range/timing, switching, actual GUI playback and save/reopen. Compare source and viewer with identical pose/camera/materials. Blender-only review does not establish Godot runtime transitions; keep export/integration a separate requested task. Keep pending animations visibly pending until reviewed.
