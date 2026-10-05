# Assets

`characters/` contains the runtime GLB exports of player V6 and zombie V2, with named animations, ten-bone skins and original embedded 64x64 atlases. Godot extracts the small atlas PNGs alongside each GLB during import. One opaque nearest-sampled material per model; 72 triangles per actor. The game does not need Blender installed.

See `../GAMEPLAY_TEST.md` for reusable scenes, controls, validation and the repeatable export recipe. Source hashes and preserved actions are recorded in `characters/export_manifest.json`.
