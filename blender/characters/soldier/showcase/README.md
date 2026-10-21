# SOLDIER Asset Library

Open **SOLDIER_Asset_Library.blend** here. The existing skin candidate is registered **Pending**, with an actual-render asset thumbnail and packed reference/four-view preview. No Godot integration.

- `SOLDIER_ASSETS/01_SKINS/SOLDIER_Skin_v001_PENDING`: complete skin with rigid base, clothing, hair and rig.
- `02_HAIR_VARIANTS`, `03_CLOTHING_UPGRADES`, `04_EQUIPMENT`, `05_FUTURE_UPGRADES`: empty groups for future additions.
- Native asset catalogs in `blender_assets.cats.txt`; Asset Browser can use **Current File**. `registry.json` mirrors the saved scene registry.

Default three-quarter camera. Numpad0 camera view, F12 render; other cameras Front, Front_3Q, Left_Side, Back, Right_Side, Back_3Q. `START HERE — SOLDIER LIBRARY` is packed inside the file.

Latest appearance: original head/torso/legs and no neck; older3×12×4 slim arms; large eyes and short brown eyebrows, no nose/mouth; layered dark-brown3D hair with slightly thinner relief; thicker shirt/wraps/bands/trouser panels and subtle skin contact shadows below the rings. One material,3,904triangles, zero Actions. Blender review only.

For future additions, add separate Pending collections/assets under the appropriate category; preserve reviewed versions and existing asset IDs. Do not overwrite approved original player assets. Current source recipe and six render views remain in `../../player/reviews/survivor_reference_v001/`; this library is the main place to review and extend this skin.

## Quick open from Terminal

```sh
python3 "$HOME/Desktop/Game Dev/GameAssetFactory/scripts/open_blender_viewer.py" soldier
```

Works from any working directory, uses the existing detached launcher and reuses an already-open library window. `--dry-run` prints the resolved path without launching.

## Native opening fix —2026-10-21

The original background-built Asset Browser had null `SpaceFile.asset_params`; GUI first draw crashed in `file_banners_update`. The builder now retains the initialized source candidate layout. Native asset registration/catalogs remain intact; open Asset Browser/Current File through Blender when needed. Do not change editor type to ASSETS in background mode and save without GUI initialization.

The existing `soldier` command was launched successfully and the fixed file was opened in a native Blender window with the character visible. `opening_fix_validation.json` confirms identical meshes, rigid weights, rest rig, UVs, material assignments and packed images. The one-off layout probe fails on the original file and passes after the fix. Original failing file is backed up outside the repository. If macOS still offers recovery of the previous crashed windows, choose **Don't Reopen**, then use the normal soldier command.
