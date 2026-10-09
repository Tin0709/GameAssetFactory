# World Map Litematica implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development for independent asset export and import audit; parent integrates gameplay. No commit/push requested.

**Goal:** Reconstruct the supplied World Map exactly on its metre grid using assets from the user's specified `dungeons_ground_style_v2.blend`, with an invisible Red Wool boundary, ready through F5.

**Architecture:** Preserve the existing GameplayMap prototype as a comparison scene. Decode the schematic to a compact, versioned runtime package with original coordinates/state IDs and source hashes. Build visible terrain by spatial chunks, retain partial faces next to slabs, batch authored plants/leaves, and derive collisions/border/spawn from the same cells. Preserve existing player, camera, environment and animations.

**Tech stack:** Python NBT reader, read-only Blender 5.2 export, Godot 4.7 Mobile.

**Spec:** User messages on 2026-10-09: exact World Map reconstruction; specified source blend; Warped Slab→grass half, Granite Slab→dirt half, Dandelion→yellow flowers, Azure Bluet/Oxeye Daisy→white flowers, Cornflower→blue flowers, Coarse Dirt→dirt, Oak Slab→half leaf. Red Wool is invisible boundary extended to bottom.

## Constraints and rulings

- No geometry/texture copies from Minecraft; use the existing authored blend assets.
- Preserve all source data and other working-tree changes. Existing main worktree is required for continuous F5 review; no reset/commit/push.
- Read schematic block/entity data only; never execute it.
- 1 block = 1 m; coordinate translation only from Minecraft to Godot, no reflection or rotation of map.
- Ruling: the marker's outer extents define the requested 100×100 boundary (X27…127/Z6…106), translated to ±50 m. Preserve scenery outside that border; never render the 396 red markers.
- Ruling: unlisted but present poppy→red flower, stone slab→stone half, oak leaves→full leaf; tall grass lower/upper pair→one authored tall golden patch. No random scatter or replacement terrain.
- Preserve normal user audio; tests use Dummy. 30 FPS phone target remains unverified.

## Review focus

- Negative region X size must not mirror the layout; verify against independent packed decoding.
- Full-block faces beside half slabs must retain their exposed half, including chunk boundaries.
- Tall-grass upper entries are structural partners, not duplicate plants; retain every flower location.
- Border must block walk/sprint diagonally and on high ground without any visible red geometry.
- Source GLB material/color/alpha, origins and transforms must match saved Blender data; no live-file save.

## Tasks

- [ ] Export current full/half terrain blocks, current leaf modules/full and half, white/blue/red/yellow flowers and tall grass from the specified saved blend to `game_mobile_3d/assets/environment/world_map_v1/`; record source/asset hashes, dimensions, material contract and source preservation. Asset export agent owns this folder's GLBs/import hook plus `scripts/export_world_map_assets.py` only.
- [ ] Add `scripts/import_world_map.py` using existing NBT reader; copy schematic into `assets/maps/world_map/`, validate state coverage, offsets, duplicates, paired plants and exact red perimeter. Tests exercise signed dimensions and cross-word packed entries. Save exact logical data/manifest and exposed half-face counts.
- [ ] Add focused world-map terrain/plant builder and scene/controller; preserve `GameplayMap` flat/procedural prototype, make the reconstructed scene F5 main. Invisible vertical bounds encompass all terrain and player height. Spawn selects a clear walkable location near centre, not inside leaves or a wall.
- [ ] Test logical occupancy/visible face areas/collision and border in Godot; audit source-state totals against runtime instances, render actual same-scene gameplay/overview/detail views and a movement clip. Fix independent review findings.
- [ ] Save concise conclusions/reproduction/limitations to existing graphics docs; update AGENTS main scene guidance, check Git worktree/status and explain integration without committing.
