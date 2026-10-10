# Authored World Map

Main scene: `res://scenes/WorldMap.tscn` (F5). B compares the imported/native look with the current review; V switches overview, H toggles haze, R returns to the safe centre. User playtests keep normal audio.

`World Map.litematic` is an unchanged copy of the user file. `manifest.json` records hashes, complete original states, counts, mappings and independently audited exposed area. `runtime.json` keeps all 42,996 non-air cells, including marker/paired-upper entries which do not render.

## Coordinate and mapping contract

- One block = one metre. Godot block corner = Minecraft coordinate + `(-77,0,-56)`; bottom-centred asset adds `(.5,base_y_offset,.5)`. Negative region size does **not** mirror the map.
- Red Wool's 396 markers define outer faces X/Z ±50 m. Four invisible walls extend Y−2…62; no wool mesh. The enclosed ring includes its edge cells (interior98), while requested outer footprint is100×100. Keep the12,101 scenery cells outside it.
- Warped Slab→grass half; Granite Slab→dirt half; Oak Slab→leaf half; Coarse Dirt→dirt; Dandelion→yellow; Azure Bluet/Oxeye Daisy→white; Cornflower→blue.
- Present additional states: stone slab→stone half, oak leaves→leaf A, poppy→red. Tall-grass lower/upper pair→one tall patch. Unknown states fail import rather than silently disappear. No random planting or layout changes.
- Half-block placement preserves top/bottom/double state. Terrain contacts clip only hidden portions, including across10m chunks. Leaf cores also remove shared contacts but retain authored outer/interior foliage.
- **Latest user override:** all117leaf blocks are walk-through. Terrain and invisible perimeter still collide. Existing smooth-step controller and old animations remain. On 2026-10-10 the user requested replacing the active jump with [Stationary/Walking/Running V002](../../characters/jump_set_v002/README.md), temporarily triggered with **SPACE**. Holding SPACE while sprinting repeats only after contact/recovery; releasing SPACE or sprint stops the next repeat. Default V001 remains archived. The subsequent request activates [moving LOOP V003](../../characters/jump_loop_v003/README.md), retaining Stationary V002 and all old clips, with a 1.20 m physics apex for 1 m block ascent. Same-Action repeats retain continuous blend; different Actions blend once. Terrain/layout and graphics stay unchanged. V003 awaits artistic review. Earlier V2 block-jumps remain deferred.

## Reproduce / reuse

Latest movement override2026-10-10: [Jump + Land V004](../../characters/jump_gif_v004/README.md)
now runs for stationary/walking/running. Grounded moving stride is retained;
airborne/contact transitions blend without forcing neutral legs first. Camera holds
ground Y during flight and still follows X/Z. Earlier V001–V003 stay archived;
terrain placement, collisions and V5 graphics are unchanged. Awaiting user review.

From repository root (use installed Python, Blender and Godot executable paths):

```text
python scripts/import_world_map.py "game_mobile_3d/assets/maps/world_map/World Map.litematic"
python -m unittest discover -s scripts/tests -v
blender --background --factory-startup --python scripts/export_world_map_assets.py
godot --headless --editor --path game_mobile_3d --audio-driver Dummy --import
godot --headless --path game_mobile_3d --audio-driver Dummy --fixed-fps 60 --script res://tests/validate_world_map.gd
godot --path game_mobile_3d --audio-driver Dummy --rendering-method mobile --rendering-driver d3d12 --script res://tests/validate_world_map_leaf_contacts.gd
```

18 GLBs and their native import contract are in [world_map_v1](../../environment/world_map_v1/manifest.json). Export opens the specified saved Blender read-only, with scripts disabled; it does not save or reload the user's live window. Preserve short-grass COLOR bend data and plant UV/UV2 attachment/root metadata. Source instructions: [WHITE_FLOWERS_V1.md](../../../../blender/environment/studies/dungeons_ground_style_v2/WHITE_FLOWERS_V1.md).

`world_map_look.gd` applies reversible scene-local materials/light; do not bake that look into source art. Path borders modify top-surface colour at same-height grass/dirt contacts only; source cells/collisions remain exact. Ground noise is fixed in world space. Cloud shade is a shared moving colour attenuation field, **not** simulated volumetric clouds. Native assets remain available through B and in the source blend.

Current evidence, visual limits and review status belong in [RESEARCH.md](../../../../docs/graphics/RESEARCH.md#worldmap--map-litematica-và-lượt-review-hiện-tại), not duplicate reports here.
