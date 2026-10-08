# Grassland E2 Implementation Plan

> For agentic workers: use superpowers:subagent-driven-development for isolated authoring and scoped review.

Goal: A playable, attractive 50x50 grassland using every actual current Blender environment asset, enemies OFF by default, preserving the original40x40 map and production character/combat behavior.

Architecture: Versioned map scene/script and deterministic composition data build25 terrain chunks with2500 1m cells and chunked MultiMeshes. Existing V4 grass shader/motion and approved lighting/camera are reused. Scene-local manual enemy controls reuse the existing spawn director and combat registry. New Blender scatter exports are isolated copies; original sources stay unchanged.

Spec: C:/Users/ADMIN/.codex/attachments/3149a41f-f935-44fd-a23c-0bc5aa1c75d0/Pasted text.txt
Tech stack: Blender5.2, glTF2 GLB, Godot4.7 Mobile, GDScript, shared GPU vegetation shaders.

Global constraints: Preserve oldGrassland and sourceBlender bytes. No character speed/cadence/animation/combat rewrite. All6rocks,4groundchunks,8flowerclumps plus V4 grass/dirt blocks and grasspatch must appear. Flat traversable terrain Y1; keep paths and central clearing unobstructed. New scene selected for F5 by changing only run/main_scene in project.godot; oldscene remains callable.

Review focus: deterministic seed and no ambiguous density behavior; no terrain zfighting or gaps; no blockers in paths/spawn; OFF startup/controls/cleanup and no autoONspawn; masks keep vegetation roots fixed and GPU offsets/culling coherent.

Task1 — native asset export
- Create blender/environment/export_scatter_e2.py and game_mobile_3d/assets/environment/grassland/scatter_v1/.
- Read existing environment_scatter_set_v1.blend only; export18 native marked meshes at origin, applied identityscale. Do not export labels/platforms/vignette/refcopies. Preserve packed original pixels/UV/materials.
- Filename convention: lowercase Blender objectname + .glb. export_manifest.json assets entries include name,category,variant,file,res_path,dimensions_m,triangles and sourceSHA256. scatter_atlas_v1.png sharedopaque128px texture.
- Validate GLB count/bounds/Yup/geometry/UVs/opaque nearest/material texture/absence of animations and sourcehash preservation before gameimport.

Task2 — new map and controls
- Create scenes/Grassland_50x50.tscn, scripts/grassland_50x50.gd, scripts/grassland_50x50_layout.gd, optional scene-local spawnadapter and materials/grassland_flowers.gdshader.
- Use res://assets/environment/grassland/scatter_v1/export_manifest.json and convention above. Reuse unchanged V4 terrain/grass GLBs/atlas/lookdev shaders and grassland_motion.gd.
- Deterministic clusters, winding dirt paths/patches, centralspawnclearance, openarea+densemeadow areas.25terrainchunks (10x10cells), efficient MultiMesh repeatedprops, merged limitedrockstaticcolliders. Groundvariations are shallow scenicdecor outsidepaths. Density exports forgrass/rock/flower/dirt; qualitycontrols vegetationvisibility/shadows without regeneratinglayout.
- Exact review interfaces: get_environment_summary()->Dictionary with counts,assetcoverage,seed,terraincells; get_review_landmarks()->Dictionary for named walking/sprinting/rocks/flowers/dirt routes; set_enemies_enabled(bool),spawn_review_enemies(int),set_graphics_quality(bool).
- Reuse SpawnDirector via scene-localadapter: enabledfalse initialtarget0, disable automaticphysics timer, manualspawn methods onlyafterON. Adjust Y to terrainheight and boundedpositions; reuse realCuboidZombie and registry. OFF clears scene-local enemies/projectiles and invalidates cached target; no global modechanges.
- Dev panel: EnemySpawningOFF/ON, Spawn1,Spawn5 disabledwhileOFF; reuseT/K ifno conflict. HUD Defeated/update_status compatibility for existing combat service. Keep existing weapon inputowner, WASD/Shift/drawholster/strafe/camera unchanged.
- Meaningful tests cover2500cells,densityclusterdistribution,all18props+V4assets,clearpaths,determinism,OFFnoenemies,togglemanualspawn1/5,OFFclear/nofurtherspawn and collision/traversal. Run gamewithrealrenderer for shadersandvisualreview.

Task3 — independent gameplay review and final display
- Inspect assetexports and mapcode/results independently. Validate preservationhashes and importlogs.
- Exercise actual player walk/sprint, grassrecovery, flowerswind, rock/path/flowertraversal and allmanualenemy controls. Capture overview/gameplay performance and reportcounts,limitations and modifiedfiles.
- Open realgame on newscene, enemiesOFF. Stop forhuman artisticreview.

Ruling: User supplied complete execution requirements and explicitly authorized real-game integration, including this previously review-only asset set. Continue reversible implementation without an additional design approval gate. Isolation is additive versioned assets/scenes with baseline hashes; .git is read-only, so no commits/worktrees.
ARTISTIC STATUS: AWAITING HUMAN REVIEW.
