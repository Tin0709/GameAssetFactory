# Original player incident-light field

`field.res` contains original GAF map-owned lighting, never MD2 radiance/code.
11,160 grid points (9,650 empty receivers), 4 × 2 × 4 m spacing. Each stores
six cosine-integrated RGB sky and unit-white-sun bounce directions. The two
float32 arrays total 1,607,040 bytes plus 11,160 validity bytes/metadata; compressed
resource about 1 MB. Runtime samples three body heights, trilinearly renormalizing
only empty corners. Outside/unsupported locations retain previous lighting.

Regenerate from this checkout with the existing tools; choose NEW scratch folders:

1. Set `GAF_SHOWCASE_PLAYER=original`; run Godot Mobile with
   `--script res://tools/export_world_map_terrain_light.gd -- <export-folder>`.
   Clear that environment variable before normal play.
2. `python -m scripts.graphics.actor_irradiance --source <export-folder> --output <bake-folder>`.
3. Run Godot headless with `--script res://tools/pack_world_map_actor_light.gd -- <bake-folder>`.

The exporter must include the ambient recipe identity. Actor normalization,
material fingerprints and recipes must match the independently validated terrain
cache, in addition to the source-map hash. Stale/malformed/unsupported data falls
back. The pack tool writes only this original Resource. Source mask data is NOT
in this asset: private editor-only material code loads it externally.

These are low-frequency diffuse probes, not Lumen or sharp reflection captures.
The rough specular term is an original proxy using the field and F0; skin wrap
width .15 is an original energy-normalized approximation, not native SSS.
No runtime ray tracing, new draw passes, geometry or collisions. Static-grid
interpolation can leak near thin walls; moving occluders/secondary-hit clouds
are not represented. Current new-player terms require the validated Day context.
See `docs/graphics/unified_showcase_v001/PLAYER_SPATIAL_LIGHT.md` at repository root.
