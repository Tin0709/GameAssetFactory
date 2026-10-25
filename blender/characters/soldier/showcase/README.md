# Current: Layered2D Hair + Bandana · Pending

The same library now opens with **SOLDIER_HairCards_v001** and **SOLDIER_Bandana_2D_v001** on the actual unchanged Soldier, in the existing main scene / **Hair & Bandana** view layer. SOLDIER Library provides Original /2D Hair /2D+Bandana comparisons, independent accessory visibility, isolated previews and head/full-body views. Original chunky hair, face, rig, clothing/equipment and all facial Actions remain intact. Both new assets are Pending and Blender-only; Godot is unchanged. See [construction, controls and comparisons](../assets/haircards_v001/README.md). The same soldier quick-open command loads the new selector; earlier viewer windows are preserved.

# Current: Facial Expressions · Pending

The same library now opens in its existing main scene, **Facial Expressions** view layer. The **SOLDIER Library** sidebar includes18 original facial presets,10 situation previews, playback/loop/intensity/gaze/blink controls and close/gameplay review cameras. Skin and standalone Backpack remain selectable and unchanged. All facial work is Blender-only and Pending; existing Godot gameplay is untouched. Read [facial research, architecture and review](../facial/README.md). Use the same `open_blender_viewer.py soldier` command for the complete panel. The following earlier notes describe the preserved base assets and opening history.

# SOLDIER Asset Library

Open **SOLDIER_Asset_Library.blend** here. The existing skin candidate is registered **Pending**, with an actual-render asset thumbnail and packed reference/four-view preview. No Godot integration.

- `SOLDIER_ASSETS/01_SKINS/SOLDIER_Skin_v001_PENDING`: complete skin with rigid base, clothing, hair and rig.
- `02_HAIR_VARIANTS`, `03_CLOTHING_UPGRADES`, `04_EQUIPMENT`, `05_FUTURE_UPGRADES`: empty groups for future additions.
- Native asset catalogs in `blender_assets.cats.txt`; Asset Browser can use **Current File**. `registry.json` mirrors the saved scene registry.

Skin review remains in SOLDIER_ASSET_LIBRARY. Default three-quarter camera for each review. Numpad0 camera view, F12 render; other cameras Front, Front_3Q, Left_Side, Back, Right_Side, Back_3Q. `START HERE — SOLDIER LIBRARY` is packed inside the file.

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

## Standalone backpack —Pending

The same library now contains `SOLDIER_Backpack_v001_PENDING` under `SOLDIER_ASSETS/04_EQUIPMENT`, catalog SOLDIER/Equipment. The file opens in **SOLDIER_BACKPACK_REVIEW**, showing only the backpack and its studio. Switch the scene selector to **SOLDIER_ASSET_LIBRARY** to review the character. The backpack is excluded from the character review and has no parent/rig/attachment.

Reference-matched brown canvas, twin front and side pockets, real strap loops and open square adjusters; latest refinements add stepped voxel corners, segmented padding/piping and small block fabric details. One packed1024pixel atlas, one mesh/material; all original skin data remains unchanged. Review/render files and focused rebuild scripts are in `../assets/backpack_v001/`. The initial skin-only builder is guarded against deleting additional library assets.

If the library is already open, choose File>Revert in that SOLDIER window to load its latest saved contents.

## SOLDIER Library sidebar

Open with the existing Terminal command below so the repository-local sidebar is explicitly registered:

```sh
python3 "$HOME/Desktop/Game Dev/GameAssetFactory/scripts/open_blender_viewer.py" soldier
```

Press **N** in the3Dviewport if needed and choose **SOLDIER Library**. The panel groups **Soldier Skin v001** under CHARACTER and **Backpack v001** under EQUIPMENT, shows Pending status and provides Front/3/4/Side/Back view buttons. Asset selection switches existing review scenes and cameras without changing the model or attaching equipment. Reverting the file in this viewer rehydrates the same panel through its persistent load handler.

An older Soldier window opened without the UI bootstrap is left intact; the updated command opens a viewer with the panel. Subsequent launches reuse a viewer that already has the bootstrap. Raw double-click opening does not run external Python; use the command for this sidebar, as with the other project viewers.

Latest backpack refinement: broad low-contrast pixel blocks, no granular speckles, fewer repeated relief details,512atlas and3,744triangles. The existing skin and all approved gameplay remain unchanged.

Latest Pending review — bushier reference haircut and ragged survival clothing: open the same Soldier library, Hair & Bandana view. Default now shows the whole character.61 flat hair cards keep the current brown palette; the full red wrap/knot/tails remain exact. The existing skin/clothing receives broad low-noise dirt, real cutout tears and35 flat frayed cloth tabs. Original head material, body geometry, wrist rings, source shared meshes/Face review and all34Actions are preserved. Authoring and checks: `../assets/worn_clothing_v001/`; five full-body views and shirt/trouser closeups in its `review/`. No Godot change or artistic-status promotion.


## Sword Combo v001 — Pending (2026-10-25)

Use **SOLDIER Library → ANIMATIONS → Sword Combo v001**. The existing library now previews the original three-hit Action on copies of the current worn Soldier skin, hair and red bandana. Play/Pause, Restart, Hit 1/2/3 and six review angles are provided. The same independently registered Action remains in Animation Showcase; original Soldier assets and all Godot gameplay are preserved. See `../../../animation/reviews/player_animation_library_v1/sword_combo_original_v001/README.md` for provenance, original timing and validation.
