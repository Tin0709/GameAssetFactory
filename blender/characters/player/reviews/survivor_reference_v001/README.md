# SOLDIER skin v001 — Pending Blender review

Main review library: `blender/characters/soldier/showcase/SOLDIER_Asset_Library.blend`.
This folder keeps the same source candidate, rebuild recipe and actual Blender renders. No additional skin variant or gameplay integration was created.

## Current user direction

- Keep the original V6 head, torso and legs exactly, without neck geometry. Restore the older3×12×4 slim arms:0.16875m width,0.675m length,0.225m depth;25% narrower, shoulder inner faces remain attached. Only arm width and arm-bone pivotX change; original rigid weights and all other bones remain exact.
- Large9×7pixel eyes with short brown eyebrows, per the latest correction. No nose or mouth. Earlier no-eyebrow instruction is superseded.
- Warm dark-brown chunky3D hair, retaining its staggered lock layout. Latest refinement reduces only the outer relief by20% and crown excess height by15%.
- Stronger3D clothing for distance readability: shirt/sleeve layer15mm, white wraps20mm, black bands17mm, trouser panels20–28mm and lower hems12mm. No extra accessories.
- Soft warm skin contact shadows directly below both arm bands, fading over two pixel rows. Footwear remains painted on the original leg blocks.

## Structure and review

Three rigid character meshes (original/slim base,3D clothes,3D hair), one10-bone rig and one shared opaque nearest-filtered512×512atlas.3,904triangles total. No new Actions or anatomy joints.

Open the main SOLDIER library. Whole current skin is one Pending native Blender asset in `SOLDIER_ASSETS >01_SKINS`; future hair/clothing/equipment/upgrades have empty organized groups and native asset catalogs. Reference and four-view review are packed. Default Front_3Q camera; six named cameras and `renders/` contain front, front3/4, both sides, back and back3/4. `review_four_views.jpg` and `review_six_views.jpg` are actual Blender renders; `reference_comparison.jpg` includes the unmodified supplied image.

## Verification and preservation

`model_validation.json` and `reopen_validation.json` record direct source comparison: original head/torso/legs/non-arm rest skeleton, original weights, documented slim arms and shoulder seating, no neck gap, three character meshes, one material, packed media and zero Actions. Approved source files and Godot are read-only and preserved. This remains Pending for artistic review; do not integrate into gameplay yet.

Rebuild only while Pending: Pillow Python `make_atlas.py`, Blender `build_candidate.py`, Pillow `package_review.py`, Blender `verify_candidate.py`; then run the Soldier showcase `build_library.py` and `verify_library.py`. Recipes refuse to overwrite reviewed library/candidate status.
