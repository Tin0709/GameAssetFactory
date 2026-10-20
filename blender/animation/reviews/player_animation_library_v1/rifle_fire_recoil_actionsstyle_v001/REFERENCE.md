# Verified reference and original rifle adaptation

The actual local `Actions Stuff 1.12 (resources).mcpack` was read directly as a ZIP archive. SHA256: `9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d`. File hashes, selected conditions and numeric landmarks are in `authoring/source_reference.json`; the pack is not redistributed.

## Actual player graph

- `entity/dtr.json`: player aliases `kcexxa` → `controller.animation.oreville_ans.njvelc` and `ybphcg` → `controller.animation.oreville_ans.knoyhk`; release alias `dtfqyg` → `animation.oreville_ans.pomlkz`.
- `animation_controllers/616f2ff7.json`: ordinary crossbow handling `njvelc.ltqtzr` layers `rrvlnm` then `dubgwy` (the latter weighted by `1-v.jkpkmj`). Charged state `knoyhk.gjhnog` layers `jawwtn` / `asxvzc`, with its base-pose condition and 0.1 s state blend. The verified release transition is `q.all_animations_finished&&!q.item_is_charged` into `knoyhk.ikvaib`, playing `dtfqyg`, with 0.15 s blend. Release returns to default when the weapon is no longer a crossbow or all animations finish; use/charged input can return to `gjhnog`. Shield branches are present.
- `animations/f2da1071.json`: release `animation.oreville_ans.pomlkz`, 0.875 s, `hold_on_last_frame`. Waist/head rotations, both arm rotation/translation and right-item rotation/translation are authored. Numeric release keys have default linear interpolation; the separate charging animation uses Catmull-Rom. Source angles/Molang trigonometry are degrees and translations are model units/pixels, not metres.

Neutral-look release landmarks: waist 0° → −6° at 0.0417 s → −10° at 0.1667 s → +1.1° at 0.625 s → 0° at 0.875 s. Head reaches +8.1° at 0.0417 s and −15.4° at 0.25 s before recovering. Right-arm pitch begins −55°, reaches −76° at 0.1667 s and reaches 0° at 0.6667 s. These are local source-channel observations, not final Blender world angles.

The release also toggles scale on helper `hmhadkja89l_92f5d6` at 0.125 s. It is not player body squash; the unchanged character/rifle has no equivalent helper. It is therefore documented rather than mapped to limb scale.

## What was transferred

The verified handling suggests a quick coordinated weapon/arm impulse, offset body/head response, and restrained opposite recovery. The new rifle recoil implements those principles with independently designed timing, amplitudes, envelopes and left-support coordination. It does not copy the crossbow release keyframes or claim that source provides automatic rifle behaviour.

The source release lasts 0.875 s and recovers into ordinary uncharged handling. Our automatic-rifle study instead returns to the approved Aim sample in 0.1667 s. Neither that duration, the 6 Hz review burst, the wrist-near pivot nor the recovery envelope is a source controller fact. No source automatic-fire RPM was identified in these player crossbow states.

The approved reference Action/source remain byte-exact: Action SHA `4b4d072c8b6b909155207505eae19fc1dbd4bc15b227544c61791a6c7eae883f`; source SHA `bb5b4822b9ec4cc118b0fddc154bcb80e0c1a05105efe43d4246bd22878fab71`. Rifle V2 source SHA `0d8c2d0fb05e8be82d5c2a3485eb3cd1a40acdc70c1e656ed2f4322e17bad03f`.

## Rig and rifle limits

The unchanged 13-bone rig uses rigid full arms with identity ForeArm helpers, no visible elbow bending, no scale pulse, and unchanged meshes/materials/proportions. Shoulder translation absorbs a small original recoil around the fixed grip. The support side follows the existing weapon-space contact rather than reproducing the crossbow’s different fore-end dimensions. The existing head lean, rifle attachment and planted lower-body pose are the approved reference. Inherited rigid-cube seating/floor penetration is explicitly retained; this shot does not certify the approved base as collision-free or production-licensed.

### User-requested strength change, 2026-10-20

Recoil envelopes are now multiplied by 1.5 without retiming. A maximum 0.9° full-left-arm axial clearance correction retains the existing support point and head-contact limits. This is a rig-fit adjustment, not a newly discovered source behaviour. The source pack observations and approved Aim base remain unchanged.
