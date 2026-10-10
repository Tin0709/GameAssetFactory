# Animation Showcase implementation plan

> Execute inline using superpowers:executing-plans; no subagents required.

**Goal:** One Blender 5.2 file with the three explicitly approved tests, automatic selection/ranges, playback and persistent controls. Finish the viewer for human review; Jump Takeoff remains deferred by the user's follow-up.

**Architecture:** A minimal showcase contains one unchanged actor, three original slotted Actions, the existing review stage/cameras and a saved manifest. A small installed add-on provides the N-panel without enabling blend-script auto-execution. Native Action Editor remains available. A transactional refresh imports only named compatible entries and refuses overwrites or incompatible rigs.

**Requirements:** Latest user brief in this conversation. Preserve source files and Godot; three Actions only; retain Run F19 closing key while playing F1–18. Reset all pose channels on selection. No automatic approval; new manifest entries default to pending. Back up before rebuilding or installing.

**Files:** `blender/animation/showcase/Animation_Showcase.blend`, `animation_manifest.json`, `gaf_animation_library.py`, `build_showcase.py`, `verify_showcase.py`, `README.md`; workflow instructions in `docs/animation/ANIMATION_WORKFLOW.md` and `AGENTS.md`.

## Steps

- [x] Back up saved/live sources, instructions and Blender preferences; hash protected runtime/source files.
- [x] Write and run a failing integration check for the absent viewer.
- [x] Audit exact source rigs/Actions/slots and sample evaluated source geometry.
- [x] Build minimal showcase and manifest; implement reset/bind/range, playback/loop/restart/view controls and compatible refresh/import.
- [x] Install only this add-on; preserve script trust settings and other enabled add-ons.
- [x] Verify all selections in shuffled order against source evaluated vertices, stored hashes, three-Action count and closing-frame rules.
- [x] Verify real GUI playback, pause, restart, loop and one-shot behavior; save/reopen and verify fresh-process automatic registration.
- [x] Inspect actual rendered pixels, document use/import workflow and approval boundary, update animation instructions, then deliver viewer for review.

Review additionally reproduced and repaired future-import hazards in rotation-mode compatibility, integer/nonfinite timing and evaluation-setting fingerprints. Regression checks passed; source Actions were not edited.

## Review focus

Missing or corrupt manifest must leave the current selection intact; incompatible rig/action must be rejected before file mutation. Slot identifiers and action content stay original. Partial actions must never inherit the previous clip's legs or torso. One-shots may replay with a reset, but that must not be called a seamless loop. Installed controls must work with automatic blend scripting disabled.
