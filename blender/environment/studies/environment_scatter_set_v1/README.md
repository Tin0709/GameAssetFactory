# Meadow scatter set 01 — Blender artistic review

Open `environment_scatter_set_v1.blend`. It contains exactly one scene, `ENV_Scatter_Set_V1_Showcase`, with 18 new reusable meshes:

- Rocks: two small (0.30 / 0.40 m), two medium (0.58 / 0.68 m), two larger (0.86 / 0.95 m).
- Ochre ground: flat tile, broken edge, raised core, stepped chunk; 0.65–1.0 m wide and 0.12–0.23 m high.
- Flowers: two compact clumps each in purple, yellow, white and red. Five or seven flower heads with four chunky petals, raised square centres, stems, blunt leaves and small root grass. Approximately 0.22–0.40 m tall; no huge bush silhouettes.

All 18 meshes have bottom-centred local origins, identity object scale/rotation, UV_Atlas, asset metadata/tags and category/color collections. Rocks and dirt have exposed voxel surfaces welded into closed meshes; flowers are native cuboid parts in one reusable mesh per clump. No subdivision, bevels, modifiers, wind animation or exports are included. Catalog positions are presentation translations; roots in mesh-local coordinates remain Z=0.

The muted original 128×128 scatter atlas is opaque, packed and nearest sampled. Soil uses V4 ochre RGB (162,130,77) top, (133,101,58) sides, (117,88,52) bottom. Leaf green is (91,135,66). Rock and floral colors complement that palette with sparse restrained pixel flecks.

Three read-only appended V4 reference objects are distinct from the new 18: grass block, static square grass leaves, bare dirt block. Their original mesh/material/packed texture data are copied into the study. Wind shape keys/drivers were removed only from the local grass copy. Two flower clumps are additionally shown as linked instances on the reference grass block in the same scene, and do not add reusable asset counts. Source V4 and every recorded production environment file are hash-preserved.

The scene includes overview, rock, ground, flower and V4 compatibility cameras; soft neutral studio lighting; category/color labels; separated catalog plinths; and a dimensional reference vignette. `preview_overview.png` shows every new asset. `preview_rocks.png`, `preview_ground.png`, `preview_flowers.png` and `preview_v4_compatibility.png` are native Cycles renders. `thumbnails/` contains 18 native 500×500 isolated previews, named exactly like the asset objects. `manifest.json` maps every asset to measurements/topology/thumbnail; `validation_report.json` records a fresh-open structural and source/production preservation audit.

`build_study.py`, `refine_previews.py`, `render_thumbnails.py` and `validate_study.py` are study-only authoring/review utilities. They never call the original V4 builders or write production exports. This host emits nonfatal thumbnail-cache permission messages outside the workspace. Windows Blender also rejected overwriting its original blend, so the refined scene was saved to a new study filename and promoted to the canonical review file after Blender exited.

Artistic status: **AWAITING HUMAN REVIEW**. The style is a deliberately blunt voxel/stepped meadow interpretation; human approval is required before any production migration. No Godot files were edited, no GLB was exported, and no Git commit was made.

