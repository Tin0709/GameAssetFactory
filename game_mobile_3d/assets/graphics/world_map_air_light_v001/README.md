# Original GAF air-light support

`brdf.res` is an original64x64 RG16F GGX integration LUT (1024 samples/texel).
`visibility.res` contains11160 original static GAF-map sun visibility probes,
8940 unoccluded. Source map/material/ambient/sun identity is embedded and checked
against the current terrain cache. No MD2 asset/shader/texture data is included.

Bake with `scripts/graphics/environment_light.py` using the existing original
authoring export and actor lattice, then pack via
`tools/pack_world_map_air_light.gd -- <bake directory>`. The baker refuses
overwriting its output. Preserve old caches for comparison.

See `docs/graphics/unified_showcase_v001/ENVIRONMENT_LIGHT_COMPOSITION.md` for
runtime guards, controls, private source boundary, tests and visual limitations.
