# Deferred jump pose export

The user deferred jump animation on 2026-10-09: the game currently uses the original R15 locomotion and smooth step ascent. This JSON is preserved for a later request and is **not loaded by the player**. It is not artistic approval.

Source/review: [Blender V2](../../../../blender/animation/studies/block_jump_v2/README.md). Exporter: `blender/animation/studies/block_jump_v2/export_runtime.py` (run with Blender background; `-- --validate-only` checks the saved export without rewriting it).

Four new pose-only clips, 96 Hz, parent-relative rest-inclusive `p` and XYZW `q`; map UpperArm.L/R to runtime Arm.L/R. No Root, scale, WeaponCarrier or preview travel. Physics must own world movement. `export_validation.json` records rig/mesh reconstruction checks and preservation hashes. Do not overwrite old animation libraries when enabling these later.
