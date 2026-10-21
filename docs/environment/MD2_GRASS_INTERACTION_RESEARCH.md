# MD2 Grass Interaction v001 — research and Blender review

Status: Pending; one new interaction candidate in the existing environment library. Wind v001 remains Pending and is preserved unchanged. No Godot gameplay/WorldMap integration in this task.

## Design contract and implementation plan

The user's detailed brief requests natural proximity/movement-directed bending, fixed roots, stronger running response, softer short grass, smooth recovery toward ongoing wind, six controls, one original-speed fixed-camera proxy demonstration and a practical Mobile implementation proposal. No grass, character, weapon or approved animation redesign.

Source footage research precedes motion design. Genuine player-passage footage has been found; current samples do not isolate an unambiguous bend/recovery response from wind, jumping, occlusion and camera movement. Therefore numerical interaction settings and spring behavior are explicitly authored adaptations of the requested result, not measured MD2 internals. Detailed timestamped evidence will follow below.

Selected Blender method: one fixed-step shared2Dspring field with displacement/velocity state, sampled from a FloatImage by a new native Geometry Nodes modifier on separate review objects. Reuse immutable existing wind meshes/metadata and the exact original first Wind modifier group. The new modifier reads incoming wind positions and adds bounded, root-masked interaction curvature; when interaction is zero/disabled its output must exactly match Wind. One deterministic cache supports scrubbing and equivalent time at30/60FPS. A simple1.8mblock-character proxy follows one route; no approved character data/Actions are touched. A shared field update avoids individual blade physics or per-clump simulation scripts.

Alternatives: per-blade rigid bodies are unnecessarily costly; pure instantaneous distance displacement snaps after exit; a full native simulation-zone cache adds review complexity and does not directly solve the future Mobile architecture. The shared grid provides visible recovery and a clear GPU-field analogue. Blender's NumPy/cache/ImageTexture implementation is a review tool, not a phone performance result or a claim that its code ports directly to Godot.

Plan:

- [x] Back up the current Wind library and8,879protected files; identify immutable Wind data/code.
- [x] Inspect genuine player-passage frames and primary technique references; keep observed/unknown separate.
- [ ] Create one Pending field/proxy/interaction group in the same scene/library, sharing existing grass meshes/materials.
- [ ] Add six controls and fixed gameplay/close/wind-only review routes through the existing launcher/sidebar.
- [ ] Verify Wind unchanged, exact off/zero equivalence, roots/widths, directional falloff, standing contact, run/walk response, recovery, scrubbing and30/60equivalent times.
- [ ] Render and inspect one clear original-speed preview covering short/walk, tall/run, dense passage, standing, exit and recovery.
- [ ] Publish guarded native file, document actual evidence/limits, open the existing viewer and stop for visual approval.

Review risks: stale GN image evaluation; feedback/recursion in Blender handlers; proxy/grass timeline mismatch; preserving Wind controls and native group; root attachment under combined deformation; abrupt field-boundary/direction flips; state after reverse scrubs; static/Wind/interaction UI transitions; cache cost on control changes. All new work stays Pending.
