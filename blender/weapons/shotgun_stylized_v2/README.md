# Shotgun_Stylized_V2 — Pending, 2026-10-12

Original blocky shotgun inspired by the user-supplied Stevens Model 520A image: traditional dropped wood stock, curved wrist, squared double-step receiver, long thin barrel, lower magazine tube and separate wood fore-end. The reference URL is https://sketchfab.com/3d-models/low-poly-stevens-model-520a-275af36ee49545f3bdf117329f72745f . Its page returned 403; the attached image was the visible reference. Geometry and detail layout were authored locally, not downloaded or copied from the model.

Latest requested gap correction: lower tube, cap and action bar raised **10.3mm**; the wood fore-end is lifted and its roof reduced to preserve sliding clearance. Barrel-to-tube gap is now **2.45mm** (previously 12.75mm), and barrel-to-pump gap **0.79mm** (previously 4.99mm). Barrel, muzzle, stock and overall dimensions remain fixed. Original wider-gap candidate is backed up under `.validation/shotgun_stylized_v2/iteration_*`.

## Source, export and central review

- `Shotgun_Stylized_V2.blend`: packed source, one `WEAPON_EXPORT` collection, grip-centered root.
- `Shotgun_Stylized_V2.glb`: two rigid meshes and eleven reference nodes; no rig or Action.
- `../showcase/Weapon_Showcase.blend`: SAME library, now 19 entries. Shotgun is independently selectable and Pending; previous models, Preferred rifle status and preview matrices are preserved.
- Open `../showcase/Open_Weapon_Showcase.cmd`, then **N → Weapon Library**. Newest registered weapon appears first and is selected initially, followed by the current weapon family and historical versions. Choose Standalone / Character ready / Character holster and inspection angle. Reopen after rebuilding to refresh an already open Blender window.
- `review/`: actual saved-showcase standalone, side, muzzle, held, stowed and pump-back renders; transparent isometric; common-scale rifle/shotgun/pistol comparison. No separate showcase was created.

## Geometry and palette

Measured dimensions **0.97797m long × 0.05250m wide × 0.19663m tall**. **1,084 triangles**: Base 828, Pump 256. Two rigid meshes/draw surfaces, one opaque material and one packed **64×64** nearest-sampled atlas. Flat normals and small single-segment chamfers; closed manifold component surfaces with positive signed volume. The budget exceeds the guide's historical 300–700 triangle target to retain the hollow barrel, open pump channel/guard, layered stock/receiver and structural chamfers. Phone performance has not been measured.

Rifle-family graphite/gunmetal/steel with the same muted brown as the new pistol grip and a darker brown inset. No numbers, commercial logos, alpha surfaces, emission or extra material. Broad fore-end grooves replace the reference's fine microdetail. Metallic 0.12 and roughness 0.5 match the pistol's simple family material.

## Axes, markers and rigid pump

Blender +Y forward/+Z up converts once to Godot -Z forward/+Y up. Grip root and static mesh rotation/scale are identity. Exported markers: RightHandGrip, LeftHandGuide, Muzzle, AimReference, RecoilPivot, HolsterAttach, Grip_Point, Support_Hand_Point, Muzzle_Point, ReloadPort and PumpReference. Exact values are in `asset_report.json`.

RightHandGrip is (0,0,0); Muzzle (0,0.767,0.073). The left guide and pump pivot are (0,0.356,0.0483). Pump has independent **55mm local -Y** reference travel, stays on its tube and clears the receiver; base stays fixed. No pump/recoil/reload Action or firing behavior was authored. The magazine tube remains fixed; this design has no detachable box magazine.

## Existing character fit and limits

The central library reuses existing R13 F1 ready and F62 stowed snapshots without changing character proportions, rig or Actions. The new ready preview has no head/chest/off-hand surface intersections and expected dominant-arm contact. **The old pose does not reach the new fore-end with the left hand**: this is a visible fit limitation, not a completed two-hand hold. New LeftHandGuide is physically inside the pump; its height is 21.7mm below the legacy target, which is retained on original entries. Tailored grip/support alignment and pose/aim/recoil/pump/reload transitions need separately reviewed animation work. Current ready/back mounting and scale come from the existing Shotgun entry; no new production mount was invented.

The F62 stowed preview has no tested head/chest/arm/leg surface intersections. From the front the gun is mostly occluded behind the body; use Back view in the library to inspect it. Static triangle-pair counts in `fit_report.json` are diagnostics, not penetration depth or transition certification.

`verification.json` confirms saved topology/part count, GLB normals/UVs/marker conversion, independent pump travel, source budget and hashes for 37 protected files. All previous 18 manifest entries and library metadata are preserved exactly, apart from the intended newest default selection. `../showcase/library_verification.json` passes **285** selections (19 weapons × 3 modes × 5 angles), ordering/isolation/framing and reopening. No production/Godot or approved animation edits by this task; concurrent rifle-animation work is left untouched. Model remains Pending for user visual review.
