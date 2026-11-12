# WorldMap night terrain bounce preview

Open game_mobile_3d/project.godot and press F5. Press L, select Night, then open Lighting mix.

- **Night terrain bounce (preview)**. Try 65%. It blends some of the existing diffuse sky light with a precomputed directional sky and first bounce. Terrain, cutaway and grass roots share the field.
- **Night stone color balance (preview)**. Try 72%. It softens the blue cast in the stone's diffuse incident light, preserving its linear luminance before the material and color pipeline.
- Set both to 0% for the existing look. Use Save mix for slot to keep the values. Lighting recipe v45 includes both controls and older recipes import them at 0%.

These are optional and neutral by default. The weights follow the existing night transition, with exact bypass at Noon. They apply in the private source-atlas WorldMap Combined look, with Mobile and verified terrain transport. B suspends the result for the original graphics comparison. Neither control changes the lamp, direct shadows, reflections, the shared fog volume or player motion.

The existing scene resource worldmap_regional_sky.tres provides map identity, receiver IDs, root mapping and the hash for a private, external RGB9E5 layer. Runtime samples a single 256 × 271, 277,504-byte texture. The night field loads only when either control is requested in scope. If the map does not provide a matching profile, or loading or proof validation fails, the preview falls back to the stock material response. Map authors need a matching transport and receiver bake before assigning a profile to new geometry. No private bytes are imported through res://.

The shape uses an existing captured MD2 night sky and an independently implemented bounce solve on WorldMap geometry. Its hue control is an art adjustment. The placement of the native scene's light and atmospheric gradients remains an open visual difference. Evidence and comparison frames are recorded in the private MD2 Research workspace under godot_lab/world_map_unified_showcase_v001/terrain_night_spatial_fill_v001.

