# MD2_Grass_Interaction_v001 — Pending

One original Blender interaction candidate in the existing environment library and scene. Wind v001 remains unchanged and Pending. No Godot integration or approved character Action changes.

Open the existing viewer:

```sh
python3 "$HOME/Desktop/Game Dev/GameAssetFactory/scripts/open_blender_viewer.py" asset
```

The **Grass MD2 — Player Interaction** section opens the fixed gameplay camera and starts the20-second preview at1×. Controls: interaction enabled, radius, strength, bending response, recovery speed and route speed. `Play / Pause`, `Restart`, fixed gameplay, close-up and unchanged Wind comparison are available in the same window. The previous short/tall/Wind routes remain available below.

The neutral1.8mproxy walks through short grass, runs through tall grass, crosses the dense center, stops from10.5–13.5s, then leaves. At18–20s the field has recovered to Wind alone. It uses no approved character data or Blender Actions. Route speed changes do not alter Wind time/speed.

Implementation:43linked clumps /2,566grass triangles; original11Wind meshes/materials shared without edits. The exact original Wind modifier runs first. A second native Geometry Nodes group samples one64×48float image using immutable root positions and combines contact curvature with incoming wind. Roots and ring widths stay fixed. A120Hzcritical spring grid caches60Hzsamples deterministically; a single image upload/group tag per frame serves every clump. Disabled, zero-strength and fully recovered outputs match the first Wind modifier exactly.

These motion settings are authored adaptations. Genuine MD2 footage confirms player passage, but does not establish a measurable player-caused bend/recovery response or Mojang's implementation. See [research and limitations](../../../../../docs/environment/MD2_GRASS_INTERACTION_RESEARCH.md).

The default desktop cache is29.5MB and rebuilds synchronously in about0.50s on this host when numeric controls change. It is a review tool, not a Mobile benchmark. Flat terrain, heading-only transforms and one proxy are the present scope. A future Godot architecture is documented; gameplay remains untouched.

Preview: `review/MD2_Grass_Interaction_20s_1x.mp4`,480native frames at24FPS, no retiming. Native contract/preservation evidence: `.validation/md2_grass_interaction_v001/verification.json` from repository root. Keep status Pending until explicit artistic approval. `build.py` stages guarded additions only; never rerun over a completed central candidate.
