# MD2 Grass Wind v001 — Pending Blender review

Existing library: `../dungeons_ground_style_v2.blend`. Same scene; no new permanent library/project/scene/Action. Launch with:

```sh
python3 "$HOME/Desktop/Game Dev/GameAssetFactory/scripts/open_blender_viewer.py" asset
```

The existing Grass MD2 sidebar now opens **Grass MD2 — Wind · Pending**. Its native field begins playing at original speed. Use Mixed field / Close-up / Gameplay / Static–Wind; expand Individual Short / Tall Wind for all11tufts/clusters. Nine controls expose enabled, direction, strength, speed, gust strength/frequency, variation and separate short/tall responses. Play/Pause and Restart control the20sreview. Default loop is seamless; arbitrary speed/frequency edits need not loop in20s. Returning to static views restores the live static timeline, including its playback synchronization.

## Output

- [Field,20s,24fps,1×](review/MD2_Grass_Wind_Field_20s_1x.mp4)
- [Close-up,20s,24fps,1×](review/MD2_Grass_Wind_Close_20s_1x.mp4)
- [Time comparison](review/Wind_Field_Timing_20s.jpg)
- [Static / wind still](review/Still_Compare_240.png)
- [Research and Godot proposal](../../../../../docs/environment/MD2_GRASS_WIND_RESEARCH.md)

The shared native Geometry Nodes group evaluates from immutable rest attributes. Roots stay fixed; a height-weighted curve, traveling gust and small tip term move the independent Pending copies. Existing3/4card rings and UVs are retained. World origin/heading drivers keep rotated clumps coherent; reviewed transforms are unit scale and Z rotation. The7×5block field contains47clumps/1,790grass triangles. No individual blade physics or character interaction exists.

## Evidence / limits

Actual TikTok, official trailer and uploader gameplay samples were inspected; labeled reference comparisons are in `research/`. Source footage supports planted footprints and upper-dominant coordinated sway, but not exact frequencies, amplitudes or engine internals. All numerical motion settings and the gust front are our authored adaptation. Keep Pending until visual approval.

Native fresh-read verification passes: original data exact, root error0m, ring-width residual<0.1µm, default20sseam<0.1µm,30/60FPS equal-time difference0, deterministic scrub/no cumulative drift, zero strength/disabled exact rest, frozen speed, world headings and15exact render/viewport routes. Fresh preservation uses a temporary evaluation layer to normalize hidden-object matrix caches; it is removed, never saved. Native frame-sync mutation needs scene.update_tag for consistent FPS checking. These are correctness checks, not phone performance proof.

`.validation/md2_grass_wind_v001/` contains pre-wind/post-fan library/hash, source meshes, native preservation/check reports, protected-file hashes, reviewer evidence and render frames. The latest authorized pale-seed fan refinement is already part of the static baseline. Wind adds11independent meshes/one group/one review layer; all existing source grass, terrain, flowers, Soldier, other Blender libraries and all Godot files remain unchanged. The catalog is extended additively.

Blender5.2uses `modifier.properties.inputs[identifier]['value']`; drivers are attached through the owning Object path. No global auto-run preference change or external frame handler is needed. Renderer/software APIs must be reverified when upgrading.

Do not rerun the guarded additive builder against the completed central library. It stages a copy only after matching the pre-wind SHA. Do not start gameplay integration or player/zombie grass interaction without the next user instruction.
