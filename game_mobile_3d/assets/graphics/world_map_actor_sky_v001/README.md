# Original GAF crown visibility

These two resources contain only numerical visibility data derived from our original Forest Canopy V3 authoring. No MD2 assets or native coefficients are included. Each stores9375canonical half-metre probes and three Vector4 polynomial groups per probe. The CPU payload is900000bytes across both resources, plus overhead; it remains cached when disabled. Metadata identifies the original generator hash and asset.

Rebuild with the existing Python/numpy authoring environment:

```
python scripts/bake_world_map_actor_visibility.py --output <scratch-folder>
godot --headless --path game_mobile_3d --script res://tests/pack_actor_visibility.gd -- <scratch-folder>
```

The packer writes only these new original resources. It does not modify the GLBs, Blender files or frozen lighting presets. Validate changed source geometry against the original mesh bounds/volume before adopting a regenerated cache.

WorldMap uses Shift+F11 for local actor visibility and F11 for global directional ambient. The response is a static original SH2/cosine approximation, with two height anchors, dominant-direction max over the existing ten crowns and an authored0.75bounce reserve. It omits colored bounce and per-vertex horizontal variation; voxel-boundary error can be much larger than its mean. It is not exact native MD2 GI. Mobile-only rendering support; unsupported/native material contracts preserve their original fallback. Clean performance and actual phone acceptance remain open. Private measurements and full scope: MD2 Research/godot_lab/world_map_spatial_fill_v001.
