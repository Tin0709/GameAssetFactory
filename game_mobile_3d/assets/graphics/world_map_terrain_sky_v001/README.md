# Original terrain upper sky visibility

This is experimental original GAF lighting, not recovered MD2 Lumen or native
shader data. `visibility.res` contains original mineral-surface signatures,
50894float values, the current map hash and calibrated ambient-profile color.
The source has15527unique vertical receivers;1024upper-hemisphere voxel rays
estimate their scalar luminance accessibility. Lower-hemisphere fill is retained.

`world_map_terrain_sky.gd` validates complete live mineral-surface coverage and
source vertex/normal/index signatures before adding a R_FLOAT CUSTOM0stream to
generated meshes. Original positions, normals, UV/UV2, colors and indices remain
exact in scoped tests. Live material-owner references follow replacement meshes
so B restores the original materials; old generated meshes are released.
Opaque/cutaway shaders use the same ambient-only factor. No runtime rays, new
texture, collision rebuild, extra draw or source GLB edit is introduced.

F12 compares the effect. Source-context/profile/renderer guards retain prior
lighting when unsupported. The203576logical stream bytes remain allocated while
disabled; the67543byte compressed cache also has CPU/resource overhead.

Authoring commands, for an explicitly resumed development session only:

```
godot --path game_mobile_3d --rendering-method mobile --rendering-driver d3d12 --audio-driver Dummy --script res://tests/export_world_map_terrain_sky.gd -- ABSOLUTE_NEW_EXPORT_FOLDER
python scripts/graphics/terrain_sky.py --source ABSOLUTE_NEW_EXPORT_FOLDER --output ABSOLUTE_NEW_BAKE_FOLDER --rays 1024
godot --headless --path game_mobile_3d --script res://tests/pack_terrain_sky.gd -- ABSOLUTE_COMPLETED_BAKE_FOLDER
```

The exporter/baker refuse existing output folders. Existing NumPy is an offline
authoring dependency, not a game runtime dependency. Do not rebake unchanged
data just to resume. Source queries recognize authored half-grid corners without
moving source geometry. Ray entry into the source AABB and tied-axis crossings
are explicit; zero/nonfinite rays are rejected by the public authoring model.

The final public bake differs from the prototype in15values by at most5.9605e-8.
535native checks passed before that final repack, alongside7fallback checks and
60HDR probes. The final cache was rendered, but its whole-frame comparison to
the previous capture failed and remains UNDIAGNOSED. Do not call final image
acceptance complete; inspect existing images before any new capture.

Other limits:static solid terrain only, scalar/luma occlusion rather than RGB
transport, no dynamic canopy/multiple bounce. At512held triangle centres,
interpolation error mean.01384/p95.04457/max.27043;1.37%exceed.1. This is a
coarse visual approximation, not a universal accuracy or MD2-parity guarantee.
Clean causal GPU timing and real phone30/60/120FPS/thermal acceptance are open.

See repository-root `GRAPHICS_HANDOFF.md` and the private Research handoff for
saved source exports, native logs, comparison images, failed controls and exact
resumption steps. Work is stopped at the user's checkpoint request.
