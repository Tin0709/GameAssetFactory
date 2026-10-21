# Soldier loadout — dev only

User requested Soldier Skin v001 + Rifle Sand Block V1 in the existing ActionsStuffWalkRunTest,2026-10-21. This folder contains a read-only source export and a one-time appearance adapter; no Action/controller rewrite or backpack attachment. Existing source statuses are preserved.

The source inverse binds retain slim-arm pivot centres, clothing/hair geometry and UVs. Existing bone names drive the same single merged skin through the accepted render presenter. Rifle retains the accepted mount and barrel basis; firing uses its actual muzzle marker. `soldier_loadout=false` restores the previous appearance in the same scene.

Run `Blender --background --factory-startup --python <this folder>/export_skin.py` to rebuild from the existing libraries without saving them. Source hashes are pinned in `sources.json`. All resources are covered by the enabled research release-export guard.

Evidence and actual native gameplay: `docs/animation/reviews/soldier_loadout_gameplay_v001/` at repository root.
