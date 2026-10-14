# Repository audit — 2026-10-14

Pre-change snapshot: clean `main` at `5ca8d324fe77fe6d8775202a2a28688491592cf4`, upstream `origin/main`, remote `https://github.com/Tin0709/GameAssetFactory.git`. Remote main agrees. App inventory shows this chat active; Research, Commit project changes and Making Weapons were not loaded. No messages sent or other tasks altered. Recheck HEAD/index before staging to guard concurrent changes.

| Content | Decimal size | Decision |
|---|---:|---|
| Entire checkout including Git |31.56 GB|Conservative preservation|
| Tracked working data /7491 files |6.44 GB|Preserve|
| `.git` objects/history/LFS |22.25 GB|Preserve; no gc/prune/history rewrite|
| `blender` |5.94 GB|Preserve sources, Showcases and historical reviews|
| `.validation` |2.77 GB|Preserve drafts/backups/scripts; archive only verified raw review videos|
| `docs` |409 MB|Preserve research/reviews; add setup navigation|
| `game_mobile_3d` |158 MB incl. generated cache|Preserve source/import recipes; leave live cache alone|

Categories: essential sources include scripts/scenes/controllers/maps/audio/textures/rigs, AGENTS and instructions. Approved/Pending assets include all Blender Actions, central Animation/Weapon Showcases and weapon versions. Historical experiments are valuable and remain tracked. Reproducible raw AVI intermediates whose final H264 review exists can be archived externally after SHA256 verification. Unclear files (including validation drafts, NPY analysis caches, `.git` temporary/dangling objects, local configuration and duplicate historical .blend files) remain in place.

No tracked caches or ordinary Git files over50 MiB.350 tracked LFS paths,330 unique objects,4.34 GB current unique LFS payload. All current objects hash correctly locally and the authenticated GitHub LFS download batch confirms all330 remotely available. No upload/history migration is needed for preserved assets. Git connectivity check succeeds with existing dangling objects;13 old temporary Git objects (~2.8 MiB) remain untouched. A full-history clone is substantially larger than the current tree; shallow single-branch clone is documented.

No filename case collisions or Windows-incompatible tracked names.168 tracked code/launcher files contain machine paths/executable names, mostly historical authoring/review tools. Fix the active launch/MCP/export/import entry points safely; retain historical provenance and list unresolved files separately. Do not run historical builders en masse. Essential Godot res:// references and Blender external files will be checked independently. Ignored .validation is local evidence, not a clone dependency; important source studies/research are already tracked. Per-user Blender add-ons/Codex configuration and original desktop video paths are manual migration items.

Cleanup authorization: archive only8 rawAVI intermediates (~202 MB) under `.validation/snappy_gameplay_v001` (including the earlier Forward+ debug capture) to the user's existing external `Unuse Files` folder, with byte-verified backup and restoration manifest. Final review MP4s, all .blend sources, NPY analysis caches and validation backups remain. No mass renames, artist edits, `git clean`, force push or LFS pruning.
