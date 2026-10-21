# SOLDIER facial implementation plan

> Execution: inline under executing-plans; user already requests a complete Blender result and final artistic review. No redundant permission gate or new project/worktree.

Goal: reusable18-preset facial/situation system inside the one existing Soldier library.
Architecture/spec: DESIGN.md; pure state evaluator → native face-channel Actions/drivers → existing sidebar. Blender5.2.2/Python, one atlas, rigid head. No Godot/source Action edits.

Global constraints: Pending only; no mouth/nose/head deformation; preserve original geometry, materials, rig rests, equipment and libraries; back up first; source research clearly distinguishes external Persona definitions from verified pack behavior.

Review focus: switching midway through a hurt/fire reaction; paused scene/manual frame scrubbing; reopen with/without UI bootstrap; multiple scene/view layers; gaze/blink extremes at all intensities.

- [x] 1. Source audit and reusable evaluator: research_source.py/source_evidence.json; expression_model.py and test_expression_model.py. Test meaningful recovery/priority/duplicate firing/blink determinism/range cases before engine implementation. Expected: all18 names, bounded finite channels, exact context recovery, no accumulated6Hz or repeated events.
- [x] 2. Native library asset build: sample_body.py (read-only source poses), make_face_atlas.py, build_facial.py. Copy the actual Soldier only for one isolated view layer; add one face mesh/controller,18 canonical facial Actions, situation presets and preview-only body bakes. Verify original object/data/Actions before save/reopen. Expected: one library, old objects unchanged, no original Action edits, no face clipping at extreme control settings.
- [x] 3. Sidebar/control integration: facial_ui.py and minimal soldier_library_ui.py hook. All selection/playback/intensity/gaze/blink/neutral/situation operations work, selection crossfade is bounded, equipment/skin navigation still works. Expected: operator roundtrips/reopen/native30FPS playback and no accumulated handlers/actions.
- [x] 4. Render/review/preservation: verify_facial.py, render_review.py; close/isometric/original-speed media and source report. Expected: all18 Pending,9required situations selectable, native simple drivers, protected Blender/Godot files exact except requested Soldier library/UI/registry, no extra permanent library. Fresh review followed by fixes for material issues, then open Soldier Facial Expressions and stop for artistic review.

Ledger: source scan completed;660 reachable player definitions, external Persona blink definition absent, no reachable blink alias. Backed up central file/UI/registry/catalog and hashed8,666 existing Blender/Godot files outside .godot/cache before mutation.

Fresh review: two material findings repaired with reproduced RED→GREEN checks: priority onset continuity and captured Hurt replay at loop seams. Selection entry now lives on frames1–4 and canonical repetition begins at5; native operators verify the consumed entry. Body Jump/Landing timing restored to source seconds. All10 pure tests and432native geometry/control samples pass; original26objects,4materials,6images and2scenes match authored data after reopening. No new scene. 2,101Godot files unchanged. Final media rendering/GUI handoff remains in progress.

Completion evidence: final front/3Q/gameplay and combined reels each decode864frames/28.8s at30FPS. Actual render contact sheet inspected; native playback advanced117frames in4.05s with18presets and Facial Expressions active. Fresh review defects are resolved;10pure and432native cases pass. All original26objects/4materials/6images and2scenes preserved, source libraries and2,101Godot files unchanged. Public Soldier viewer opened for final artistic review. No Godot integration.
