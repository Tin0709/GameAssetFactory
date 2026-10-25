# Sword — Sand Block V1

Pending visual review. Separate game prop matching the supplied multi-view `reference.png`: broad graphite blade with stepped silver edges and short faceted tip, gold crossguard with dark inserts, five graphite grip wraps, and framed gold pommel with an actual recessed end.

The side reference defines the proportions at1.9mm per pixel. +Y points towards the blade tip, +Z lies across its width and +X is the broad-face normal. `RightHandGrip` and the root are at the grip center. Dimensions:1.10732m long ×0.0894m thick ×0.25707m across the guard;2,724triangles. Two rigid meshes (`Sword_Hilt`, `Sword_Blade`), two matte materials sharing one packed256×256nearest-filtered atlas. A shallow symmetric channel and blade-root plates add the reference's face detail. No animation, skeleton or gameplay behavior is authored.

`Sword_Sand_Block_V1.blend` is the editable source, `.glb` is the exported game prop. `build_sword.py -- --rebuild` explicitly rebuilds this Pending source; `--no-render` skips the full review set. `render_details.py` reads the saved source without resaving it. Five full views and four close inspections are in `review/`.

`validate_asset.py` reopens the saved file and checks component manifoldness, UVs, the blade's narrowing steps, both shallow face channels, five grip wraps, grip-centered origin and recessed pommel. A GLB reimport checks exact dimensions, markers and texture pixels. `asset_report.json` and `validation.json` record the measured result.

This is a Sword entry in the same Weapon Showcase. Its preview is Standalone; the seven firearm entries keep their existing Ready/Holster previews. The Sword switches safely to Standalone when selected from a firearm fit. No sword holding pose is implied.

Open the existing viewer with:

```sh
python3 "$HOME/Desktop/Game Dev/GameAssetFactory/scripts/open_blender_viewer.py" weapon
```

Select **Sword — Sand Block V1**. An already-open viewer needs a reload/reopen to read the updated file. Preservation baselines, prior candidate and test logs are under `.validation/sword_sand_block_v1_20261025/`. No prior source or approval is replaced.
