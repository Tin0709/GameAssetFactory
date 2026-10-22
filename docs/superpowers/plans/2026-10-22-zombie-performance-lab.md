# Existing lab: adjustable zombie performance test

Goal: In ActionsStuffWalkRunTest only, retain the 30×30 terrain/grass/player, remove lighting review props, default to 20 simultaneous zombies and provide a 0–50 exact batch selector plus Spawn and Kill All.

Architecture: Scene-local opt-in keeps legacy four-zombie fixtures available. Add two narrow spawn/script hooks to the existing encounter; a dev-only subclass owns batch positions, replacement and bounded death retirement. The approved AI/visual/ragdoll code is inherited unchanged. A compact focus-free CanvasLayer exposes count, spawn, kill, living/ragdoll counts and existing CPU/frame metrics. Lighting accepts an optional review-props flag.

Constraints: Same scene/project, WorldMap/Blender/approved player/rifle/grass/lighting remain untouched. Native physics keeps a four-ragdoll budget and 1.2s lifetime for admitted corpses. Spawn replaces a group, including old corpses/projectiles/targets. R restores the last applied count. Spawn 0 gives a true no-zombie baseline. All 0–50 actors appear in one batch; no wave streaming or hidden throttling.

- [x] Prove the new behavior absent with an actual-scene failing check (default20/spawn interface).
- [x] Add encounter hooks, dev batch subclass and capped-death adapter; deterministic non-overlapping positions inside the field, chase active.
- [x] Wire the scene opt-in, suppress only review props, add compact live controls and metrics.
- [x] Verify exact 0/1/20/50 counts, limits, replace/reset, immediate Kill All, double kill, 4-ragdoll cap, short cleanup/native resource release; preserve four-zombie regression via explicit opt-out.
- [x] Native Mobile render and gameplay sampling at 0/20/50, UI capture, audit protected files, open the existing scene with 20 and normal audio.

Rulings: Work in the explicitly requested current checkout because this lab reuses large local research assets. No parallel implementation or new scenes. Kill All retires the oldest corpses when the existing four-ragdoll budget fills, rather than enabling 350 active physical parts. Other AI, damage and firing behavior remain exact.

Outcome: Implementation and native sampling complete. Read-only final review found a minor R-at-edge clearance issue; failing edge check reproduced it, then resetting player before encounter rebuilt the group correctly (134 checks, fixed30/60). The first short firing expectation was too strict for a crowded20-target clip; a separate fresh native run proves a lethal hit with unchanged firing behavior. Final source audit and playable launch are recorded in the validation folder.
