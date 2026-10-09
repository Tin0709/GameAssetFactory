# Blender plant studies V1

Current source is the already open `dungeons_ground_style_v2.blend`. Every authored edit and save ran through the foreground Blender MCP, in that same window. The window reflects the saved changes immediately; no Revert or reload is required. Background Blender runs only read saved source to audit/render, never save source or reload the live window. These assets are **Blender-only studies awaiting artistic review**; current exports are local to this study, with no game integration.

## White flowers

`FLOWERS_White_1Block_V1` contains editable `ENV_WhiteFlowerPatch_1m_V1`: five flowers, four blunt white planar petals and one flat yellow centre each, thin segmented stems and two leaves. The latest requested revision enlarges heads only **1.5×**, with **12° upward petal cup**; stems, leaves, head-centre heights, roots, UVs, colours and material remain exact. Every face is an individual zero-thickness plane, matte opaque and double-sided. The patch has **200 vertices /50quads /100triangles**, one mesh and one material.

Reserved planting footprint is **1×1m**. Current local bounds: X −.457284719… .438642144, Y −.450048119… .388332754, Z0… .471032411m. Head centres remain .300,.360,.400,.315,.370m. Bottom-centred origin; identity rest export; display offset `(15,3.2,1)` is only for review. Original sRGB palette: whites `#f3f4e9/#e7eee4`, yellow `#e8bf42`, greens `#4c7c3b/#628947`. No image pixels or geometry were copied from the reference.

Rest export: `exports/white_flower_patch_1m_v1.glb`, SHA256 `fc6b9ad353744985115c45effa014d06e26e34bbd8299d53bf8d742c7ce3c4ea`.

## Blue, red and yellow flower variants — 2026-10-09

`FLOWERS_Colored_1Block_V1` adds `ENV_BlueFlowerPatch_1m_V1`, `ENV_RedFlowerPatch_1m_V1` and `ENV_YellowFlowerPatch_1m_V1`. Each uses an independent copy of the current enlarged, upward-cupped white-flower mesh: five flowers, a reserved **1 × 1 m** planting footprint, height .471032411 m and 100 triangles. Only petal/centre corner colours change; geometry, stem/leaf colours, roots, grouping and both wind UV channels are exact copies. The original matte, double-sided vertex-albedo material is shared unchanged.

Dominant sRGB colours were sampled from the user's supplied screenshots: blue petals `(69,105,232)/(113,141,238)`, purple centre `(66,45,151)`; red petals `(234,47,43)/(189,37,40)`, dark red centre `(153,34,26)`; yellow petals `(252,233,78)/(251,211,56)`, warm gold centre `(238,155,37)`. These are source albedo values, not a claim that rendered pixels match reference lighting. The new variants await artistic review.

`REVIEW_Flower_Color_Variants_V1` displays an unchanged linked white comparison at X15 and the blue/red/yellow assets at X17/19/21, Y0, Z1 above copied original V3 blocks. The local viewport camera frames all four colours while the original scene camera, lights, frame78, full/half blocks, leaves and all existing plant/animation data remain unchanged. `add_colored_flowers_v1.py` creates the variants through the live MCP connection with a saved pre-edit live backup; preservation measurements and actual same-camera three-colour before/after renders plus the final four-colour render are in `.validation/colored_flowers_v1/`.

Independent blue/red/yellow copies in `REVIEW_WIND_ColoredFlowers_V1` extend the existing optional stronger-wind study at X23/25/27, Y6.2, Z1. They retain its posed mesh and wind-rest attributes; this addition neither registers the handler nor edits old animation. The existing saved `RUN_Blender_Strong_Wind_V1` discovers these copies when run. This is Blender-only preview data, not newly verified runtime animation.

Rest-only GLBs are `exports/blue_flower_patch_1m_v1.glb`, `red_flower_patch_1m_v1.glb` and `yellow_flower_patch_1m_v1.glb`, each exported at the origin with one mesh/surface and the original colour/UV contract. The current `dungeons_ground_style_v2.blend` was saved in the same live session; no Revert or reload is needed. No game integration or background Blender authoring occurred.

## Shoulder-height golden meadow grass

Compatibility names `TALL_GRASS_Golden_1Block_V1` and `ENV_TallGoldenGrass_1m_V1` are retained, but the older2.3m tall requirement is superseded. Current highest seed tip is **1.350000024m**, matching the R15 rest shoulder/upper-arm top. Measurement uses source joint world transforms and mesh vertices weighted>.9 to Arm.L/R; source rest stature is1.8m, with no scene model scale. This is a rest-source measurement, not animated game extents.

28 broad square-ended blades use four bend rings `(0,.22,.65,1)` with outward quadratic fan; exterior blades are shorter, middle blades mostly upright. Each pale gold head retains four evenly spaced paired tiers, wider below and narrower above, now united into **one continuous planar36-corner outline per stem**. Finite-width internal attachment edges replace the prior point-only touching cards; outer tips and tier silhouette are exact retained. There are no overlapping interior faces or thickness. Source topology: **1344 vertices /84greenquads +28goldngons /1120triangles**. The triangulation of every head is one shared-edge face component. The extra triangles retain all original tier corners; mobile performance has not been approved or measured.

Roots reserve **1×1m**. The explicitly requested bush fan may overhang: bounds X −.622704566… .593890429, Y −.608415186… .587437630, Z0…1.350000024m; upper canopy spans **1.216595×1.195853m**. Head-pivot heights .789867…1.184725m. Original greens `#346939/#4b7c43/#628949/#789b50`, pale gold `#d9ce8f/#e7dca9/#c6bb82`. One matte opaque double-sided vertex-colour material, one editable mesh. Display offset `(21,3.2,1)` is review-only.

Rest export: `exports/tall_golden_grass_1m_v1.glb`, SHA256 `956712f96913aa7afe0e783d1d8946a160f1afa278d0f3c11d20c4df67be5dfc`.

## Reuse contract

Both rest GLBs export only the selected canonical asset at origin, one mesh/one surface; no lights, camera, rig, animation, morph, texture or collision. Blender Z-up converts once to glTF Y-up. `COLOR_0` stores **linear albedo**, authored via `color_srgb`; it is not a bend mask. Source `UV0.x` is normalized stem attachment height, roots0, all head vertices1. Each white leaf uses one attachment mask on its whole plane. Source `UV0.y` stores actual shared head-pivot height in metres. Standard glTF V-flip means decode imported height as **`1-UV.y`**, including negative values when the pivot exceeds1m. Source UV2 encodes per-stem root `(X+.5,Y+.5)`; imported local XZ root is **`UV2-.5`**. Preserve these channels rather than lightmap-unwrapping or clamping them. FACE integer attributes retain editable flower/stem/part grouping.

## Existing grass and local stronger wind

`REVIEW_Flowers_And_Original_Grass_V4` retains a copy of the [original v4 grass](../grass_block_reference_v4/README.md), with original mesh/atlas/material and quiet Blender wind. The .65-height meadow version shares that exact source data; original library bytes remain untouched. Existing V3 grass-block plinth copies share original block data/material. Original scene camera, lights and materials are preserved.

`REVIEW_Blender_Strong_Wind_V1` contains **four independent mesh copies**: white flowers, original-height grass, .65-height grass, golden meadow grass. They carry a live frame-change wind preview, **96frames at24FPS =4seconds**, with roots fixed, each head and white leaf rigid, and all faces planar. Grass motion amplitudes `.036/.016m` are twice the original copied v4 `.018/.008m`. The golden/white wind uses bounded rotation and stronger visible sway; maximum audited vertex travel is .2242m. Canonical rest meshes/exports and the quiet grass reference remain intact. No geometry-node groups or original driver/key data were edited.

Use Timeline Play in the current window. The preview range is frames1–96. After opening this file in a future session, run the saved text `RUN_Blender_Strong_Wind_V1` once to register its local handler; the latest read found playback stopped and its handler unregistered; run that text before playing wind again. Motion is **Blender-only**, not runtime approval. Saved rest exports contain none of this preview motion.

## Source helpers and evidence

Live builders/revision helpers assert `not bpy.app.background`, target this exact study and export only into `exports/`. The head revision uses the preserved original baseline to prevent cumulative enlargement. Later shoulder/dense/connected revisions are explicit one-time corrections to captured baselines. New geometry studies do not change original sources. See compact JSON manifests and the existing [art direction](../../../../docs/graphics/ART_DIRECTION.md), rather than a duplicated research report.

Read-only audits first observed missing-model failures, then compare source corners with binary GLB positions/normals/UVs/linear colours and meaningful original-data fingerprints. Phase backups and reports are under ignored `.validation/flower_patch_v1`. Current reports: `validation_source_and_glb.json`, `validation_connected_golden_source_glb.json`, `validation_blender_strong_wind.json`. Original91objects/37meshes/14materials/16images/5cameras/4lights remain unchanged; original source digest `cec5b726e2f2f87154017b384a9d142b476e0d525f7457bed0f843407db81d90`. Current connected-head pre-edit digest `144be2720217c7b60820fc2f88e916daeef7ad113fc08162dbac75cd7bff0d2c`; only the authorized golden mesh changed in that phase. Wind phase preserves all prior authored data. Audited roots drift0m, head/leaf pair-distance error<4.45e−7m, face planarity<2.63e−7m, loop frame1==97 exactly.

Actual source pixels: `blender_golden_connected_shoulder_detail.png`, `blender_current_four_plants.png`, and `blender_only_stronger_wind.gif` in the evidence directory. These show Blender studies; they do not establish Godot or phone performance.

## Current modular leaf blocks and archived plus assembly

The earlier bulk3×3×2m bush remains **PAUSED, frozen and hidden**. The current library is `LEAF_MODULES_1Block_V1`, with separate A/B/C1m cores. The previous image-inferred `LEAF_CLUSTER_Plus_6Blocks_V1` combines five lower cells `(0,0,0),(±1,0,0),(0,±1,0)` and one uppercentre `(0,0,1)`, with a 3×3m footprint and 2m height. It is now hidden for comparison; the two exact schematic assemblies described below are the active review. These are Blender studies awaiting visual review; no game integration was performed.

Latest appearance uses the supplied512×512 PNG's **exact pixel layout**, with the subsequent requested lighter greens and transparent black. Original input is preserved byte for byte as `textures/leaf_modules_user_provided_512.png`, SHA256 `843cebc821ccb8fdd19cd709ef648890eac2cb5fb561c50b7fbd41d3afca7ed7`. All six gold RGB levels remain unchanged. Only the four green levels are remapped, darkest to lightest, to colors read from the unchanged V3 `grass_top_0.png`:

| Source RGB | Current RGB |
| --- | --- |
| 32,77,11 | 70,112,47 |
| 38,96,13 | 76,122,49 |
| 43,109,14 | 84,130,52 |
| 52,131,17 | 97,143,60 |

The current derived RGBA PNG is `textures/leaf_modules_user_pattern_grass_green_cutout.png`. Alpha is0 exactly where the original RGB is black and1 elsewhere; black occupies30.46875% of the input. No blur, noise, veins or replacement pattern was generated for this current texture. It uses nearest filtering, direct image RGB and double-sided native **MASK**, cutoff.5. Source `Color` attributes remain preserved author data but are omitted from current leaf GLBs so they cannot double-tint the texture. The whole logical0–1 tile maps once to each1m cube face, without variant phase or half-tile wrapping. Active UV layer `UV_UserLeafTile_1RepeatPerMetre` gives512texels/m technically, or16coarse pixel cells/m in this supplied bitmap.

Each1m core keeps its actual geometric holes and small internal clumps. A reversible Mask modifier `REVIEW_Temporarily_Omit_Protruding_Leaves` omits original `leaf_part1` edge/top sprigs. All original `*_CrossBranches` objects remain hidden in viewport/render; their authored2× fixed-root planes and UVs remain intact for restoration. They are absent from current exports. These archived large branches are superseded by the new small bushy layers.

Current `*_BushyFoliage` children contain52small cutout quads:10on each side and12on top, staggered and tilted to soften the cubic outline. They share the current outer texture/material. Separate `*_DenseInterior` children add36crossed internal cutout quads, all strictly inside the1m core. Their isolated material multiplies **linear albedo by.88**; current gold and green pixel positions remain identical. The glTF material carries `[.88,.88,.88,1]`. No world, lighting, exposure, AO or original asset material was changed.

| Module | Current triangles | Full foliage X/Y/Z span (m) |
| --- | ---: | --- |
| A | 2176 | 1.350456 /1.348945 /1.180056 |
| B | 2156 | 1.334731 /1.314140 /1.176785 |
| C | 2138 | 1.329496 /1.305528 /1.165683 |

The grid core remains1×1×1m with bottom-centred origin and identity rest export. A/B/C review centres are25.5,27.6,29.7m X, separated2.1m on neutral ground beside a copied1.8m R15 rest actor. Full plant row, original scene camera/lights, original grass sources, white flowers, golden meadow grass and existing wind previews remain preserved.

The earlier six-cell plus assembly is now a frozen, hidden comparison. It uses isolated copied cores with internal facing sides omitted at occupied neighbours. Bushy layers appear only on exposed sides; dense interiors share their library meshes. The former four tiny coplanar sprig overlaps were fixed with0.15mm offsets on three assembly-only archived sprig cards; those sprigs are currently masked. Current raw core overlap audit reports0positive-area pairs. Structural bounds remain `[-1.5,-1.5,0]…[1.5,1.5,2]`; full foliage bounds are `[-1.666870,-1.655897,0]…[1.670809,1.683637,2.176785]`. The assembly contains9834current triangles. Foliage overhang and intentional noncoplanar interpenetration are separate from the metre grid.

Reuse `exports/leaf_block_1m_v1_a.glb`, `_b.glb`, `_c.glb`. Current exports include the **evaluated core plus BushyFoliage and DenseInterior**:3meshes/3surfaces,2nativeMASKmaterials,1embedded packed PNG. No old CrossBranches, original part1 sprigs, rig, morph, animation, camera, lights or collision is included. Outer material factor iswhite; interior factor is.88linear. These leaf UVs are texture coordinates and do not use the flower wind metadata. Leaf modules are static; existing stronger plant-wind previews remain separate Blender-only studies. No mobile performance claim is made.

## Leaf-module reproduction and evidence

Foreground authoring stages are preserved as source helpers. `add_leaf_modules_v1.py` and `refine_dense_leaf_modules_v1.py` describe the earlier18cell geometric core; their old vertex-colour export contract is historical. `add_textured_leaf_branches_v1.py` and `revise_leaf_pattern_and_2x_branches_v1.py` describe the now-hidden large branch stage. `add_leaf_plus_6blocks_v1.py`, `apply_exact_user_leaf_texture_v1.py`, `apply_black_leaf_cutout_v1.py`, `apply_grass_green_leaf_cutout_v1.py`, `temporarily_omit_leaf_protrusions_v1.py`, `add_bushy_leaf_layers_v1.py` and `add_dense_leaf_interior_v1.py` reproduce the successive requested corrections from their recorded phase baselines. They assert foreground execution and this exact source path, reject duplicate generation and preserve original data. Do not replay an earlier phase on the current file. To refresh current rest exports, run `export_current_leaf_modules_v1.py` through the connected foreground MCP; it selects only the current three meshes, applies evaluation for export and uses `export_vertex_color='NONE'`.

Current authoritative audit is `validate_bushy_leaf_modules_v1.py`; the old module/branch/pattern audits dispatch to it when current interior objects exist. Its fresh-open source/GLB report is `.validation/flower_patch_v1/validation_latest_bushy_leaf_modules.json`. It verifies original input bytes/RGBA, exact permitted green remap, unchanged gold/layout, black cutout, source UV face mapping and physical density, evaluated Mask geometry, planar bounded bushy/interior cards, nativeMASK/nearest/embeddedPNG, white/.88factors, identity transforms, source-corner/binary agreement, six-cell grid, internal-face removal, and phase preservation. Latest additive bushy/dense phases preserve all prior authored data exactly.

Actual current source pixels in the ignored evidence directory: `blender_leaf_module_a_bushy_dense_current.png`, same-camera `blender_leaf_module_a_bushy_before_dense_interior.png`, `blender_leaf_modules_bushy_dense_calibration.png`, and `blender_leaf_plus_bushy_dense_angle_a.png`/`_b.png`. The detail pair uses ortho2.1 to include the foliage envelope. All authored changes are live in the same saved Blender window; no Revert is needed. Background Blender processes only loaded source for these audits/renders and never saved the source.

## Current exact user schematic assemblies

The active review now contains **two separately translated designs from the supplied litematic files**, replacing the inferred plus layout. `USER_BushDesign_Litematic_V1` has six full leaf blocks with a structural 3×3×2m envelope. `USER_111_Litematic_V1` has five full blocks and four bottom half slabs with a structural 3×4×2m envelope. Each Minecraft block is one metre; the right-handed mapping is Minecraft(X,Y,Z) → Blender(X,-Z,Y). Stored Minecraft coordinates and slab states are preserved in `user_litematic_layouts_v1.json` and `user_schematic_bushes_v1_manifest.json`. Only display translations and horizontal recentering are added. The original inferred plus and paused bulk bush remain hidden comparisons.

The supplied files are copied byte-for-byte into `schematics/Bush design.litematic` and `schematics/111.litematic`. Their SHA-256 values are respectively `a896423c7f45c43bc3c9951fdbccaf9c67305bb27b78111ff13385e67580b3e0` and `c119e3511faf52b0bd55195b94e482287c2fc3b5bc0bcc1b635436452036321b`. Schematic data are layout provenance only. The container interpretation was checked against the [Litematica container source](https://github.com/maruohon/litematica/tree/ornithe/1.12.2/src/main/java/litematica/schematic/container); it does not authorize executing block content.

`LEAF_MODULES_HalfBlock_V1` adds separate editable A/B/C slab templates with **1×1×.5m cores**, bottom-centred origins and identity rest transforms. Full templates remain unchanged. Slab side geometry is clipped to .5m and side UV height spans 0… .5; the top retains the full XY tile. Bushy top rise is halved above the new .5m core. Each slab has 32 outer cutout planes and 18 interior planes. All edges retain 512 technical texels/m (16 coarse image cells/m); the vertical image is cropped physically rather than squashed. Actual slab foliage height is .583… .590m, with modest lateral overhang separately from the unit core.

Assemblies use isolated core copies and exposed outer leaf layers, with linked interior meshes. Full-to-bottom-slab contacts remove only the occluded lower half; the seven exposed upper half sides in `111` remain. Complete facing contacts are removed. The focused audit finds zero positive-area coplanar core face overlaps. Intentional noncoplanar foliage interpenetration remains. The current green remap, black transparency, unchanged gold pattern, nearest two MASK materials and .88 linear interior factor are shared with the full modules. No old large branch cards are restored.

| Design | Full / half blocks | Current triangles | Actual foliage X/Y/Z span (m) |
| --- | --- | ---: | --- |
| Bush design | 6 / 0 | 9924 | 3.350456 / 3.348945 / 2.180056 |
| 111 | 5 / 4 | 12406 | 3.350456 / 4.348945 / 2.180056 |

Half-template study exports are `exports/leaf_slab_1x1x05m_v1_a.glb`, `_b.glb` and `_c.glb`: respectively 1382, 1450 and 1318 triangles, three meshes/surfaces, two MASK materials and one embedded PNG. There are no vertex colours in the binary, rig, morph, animation, camera or lights. Assemblies are editable Blender studies and are not integrated into the game.

`add_user_schematic_bushes_v1.py` is the foreground-only, exact-file guarded authoring stage; `leaf_planar_geometry_v1.py` preserves corner UVs/colours during partial clipping. `validate_user_schematic_bushes_v1.py` is the focused read-only background audit. Its report is `.validation/flower_patch_v1/validation_user_schematic_bushes.json`. It verifies all 15 cell transforms and stored states, physical UV density, half source/GLB corners and embedded image, partial-contact preservation, and every prior authored fingerprint. On fresh open it temporarily evaluates the newly hidden old-plus collection to eliminate stale derived bounds/world-matrix caches, then restores its flags. No prior data are excluded. The sole prior collection visibility change is the explicitly superseded plus comparison becoming hidden.

Current actual source pixels are `.validation/flower_patch_v1/blender_user_two_exact_schematic_bushes.png` and `blender_user_111_full_and_half_leaf_detail.png`. The overview includes metre marks, the standalone half leaf and the copied real 1.8m R15 actor. Both new collections are framed together in the current material-preview window. Source changes were authored and saved only through live MCP in this exact blend; no Revert or manual reload is needed. Background processes only read source for validation and rendering. This is Blender-only review, not artistic approval or phone-performance evidence.

## Stone, grass and dirt half blocks — 2026-10-09

`HALF_BLOCKS_DI_V3_V1` contains `ENV_StoneSlab_DI_V3`, `ENV_GrassSlab_DI_V3` and `ENV_DirtSlab_DI_V3`, each exactly **1 × 1 × .5 m**, with independent meshes, bottom-centred origins, identity scale and 12 triangles. They reuse the unchanged approved V3 materials and packed textures. Top and bottom retain a full tile; vertical sides use half a tile at the original 32 pixels/m. Grass sides take the upper half so the grass cap keeps its original physical thickness.

The slabs are displayed at X7/9/11, Y−3.8 in front of their original full blocks. A new local viewport camera frames both rows without changing the original scene camera, lighting, frame78 or animation. `create_half_blocks_v1.py` is an additive live-session authoring script guarded against the wrong file or existing slab names; inspect its output before saving. It first saved all unsaved live work to `.validation/half_blocks_v1/live_before_half_blocks.blend`. The live source was subsequently saved to the same `dungeons_ground_style_v2.blend`; no Revert is needed. No background Blender process was used for this addition.

The preservation audit found zero changes to existing objects, meshes, materials, authored images, cameras, lights, worlds and scene settings, including after rendering and saving. All three closed meshes measure .5 m³. Live Blender render `.validation/half_blocks_v1/half_blocks_review.png` and measurements `validation.json` are review evidence. These new slabs await artistic review and are not integrated into Godot.
