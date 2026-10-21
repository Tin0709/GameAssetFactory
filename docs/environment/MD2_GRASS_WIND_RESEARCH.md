# MD2 Grass Wind v001 — research and Blender review

Status: Pending. Scope is the existing environment Blender study only. No Godot integration or character interaction is authorized in this pass.

## Design and implementation plan

The user's detailed brief is the design contract: soft anchored bending, a shared moving gust field, distinct short/tall responses, restrained secondary flutter, a 20-second original-speed field preview, individual/field/static comparison views and nine controls in the existing viewer. Preserve all existing source meshes, materials, cameras and approved libraries. Finish the preceding pale-stalk fan refinement first; its published geometry is the wind baseline.

Selected approach: one native Geometry Nodes deformation group on separate Pending copies, evaluated from rest coordinates and scene time. Each card receives explicit root, normalized height, length and group-phase attributes on independent mesh copies. Existing 3/4 horizontal rings are sufficient for a restrained piecewise curve; no source topology changes. World-space sampling coordinates and inverse object heading make rotated neighbors respond to the same wind. Static meshes remain available. This continues the existing review-only wind workflow while replacing its per-frame Python mesh writes for this new grass family.

Alternatives considered: the older Python frame handler is easy to extend but depends on script registration and edits every vertex on the CPU; rigid object rotation is cheap but fails the requested root/upper-blade behavior. Geometry Nodes keeps native review animation self-contained after opening and exposes the same rest/mask contract intended for a later GPU shader. Blender modifier evaluation is not evidence of Godot/mobile performance.

Execution checklist:

- [x] Fan the pale central seed cards outward and verify preserved roots, Z, leaf cards, UVs and materials.
- [x] Inspect the accessible actual TikTok sequence before choosing motion; investigate official gameplay and primary technique references.
- [ ] Add separate wind-capable copies, shared native nodes and mixed field in the same scene/library.
- [ ] Add controls, individual short/tall views, close/gameplay field and static comparison routes.
- [ ] Check roots, zero strength, finite bounds, heading coherence, non-accumulation and 30/60 time sampling against evaluated native geometry.
- [ ] Render and inspect a 20-second original-speed preview and contact sheets; reopen source and verify original assets/other files.
- [ ] Open the existing environment viewer ready for visual review; keep Pending and stop before player interaction/Godot.

Review focus: root attachment under gusts; short grass not shaking like a carpet; secondary motion not tearing cards apart; direction/strength controls working after reopen; world field remaining coherent for rotated clumps; source assets unchanged; restoring original static routes/timeline.

## Evidence and limitations

Research observations, timestamped frame evidence, actual selected defaults, native validation results and the Godot recommendation will be recorded here before delivery. Motion settings are authored adaptation values, never undocumented Minecraft Dungeons II internals.
