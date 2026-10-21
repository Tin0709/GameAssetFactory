# Survivor Reference v001 — Pending Blender review

**Latest user direction:** preserve the old character's exact head/body/arm/leg shapes and proportions, **no neck**, change the skin. Face has **large eyes, no nose or mouth**. User explicitly allows3D external clothing for **white/black arm bands, relief on trouser legs and the black shirt**. These corrections supersede the initial altered-proportion/volumetric model brief.

Open **Survivor_Reference_v001.blend**. Status **Pending**, no Godot integration. Default camera Front_3Q. `review_four_views.jpg`, `review_six_views.jpg` and individual native Blender PNGs in `renders/` provide the matched views. `reference_comparison.jpg` places the supplied reference beside the candidate on the original body. Reference and four-view sheet are packed into the blend.

## Original body preserved exactly

The original `blender/characters/player/cuboid/player_cuboid_v6.blend` six-cuboid mesh/rig was appended read-only. Original48vertices/36quads/72triangles, vertex coordinates and face order, rigid weights and10-bone rest skeleton are identical. No base part was rescaled, moved or reshaped. Body bounds0.90×0.45×1.80m; head0.45m cube; torso0.45×0.225×0.675m; each arm/leg0.225×0.225×0.675m. Head bottom and torso top meet at1.35m. Existing Neck helper bone remains in the original rig; **there is no neck geometry**.

The original base remains a separate mesh for exact comparison. New external clothing is a second lightweight mesh, bound rigidly to the same original bones and using the same single opaque nearest-filtered512×512 atlas.

## New skin and requested relief

- Large square eyes only; no nose, mouth or painted eyebrows. Plain central lower face, restrained cheek/edge colors.
- Brown staggered fringe/side/back locks are **painted on the original cubic head**, following the reference palette and haircut. No3D hair volume was added after the user specified unchanged head/body shapes. This preserves the old silhouette; it does not reproduce the reference's protruding hair geometry.
- Simple charcoal short-sleeve shirt:6mm external body/sleeve layer and a small hem. Original shoulder/waist heights remain exact.
- White wraps have10mm relief; black wrist bands7.5mm. Both are closed rectangular rings around the original arm blocks, with no arm narrowing or resizing.
- Broad trouser fabric panels and hems have5–11mm relief. Camo/dust texture continues across the panels. No bags, extra accessories or redesigned legs.
- Footwear remains painted on the original foot/leg blocks; no new toe/sole extension was authorized.

Total character budget: **468triangles**,264vertices across two character meshes, one shared material/atlas, unchanged original rig. No Actions/animations, no bent elbow/knee or pose experiments. The complete ASSET collection (body+clothes+rig) is marked as one local Blender asset, **Pending**.

## Review controls

Numpad0: saved three-quarter camera. Numpad1: front. Numpad3: side. Ctrl+Numpad1: back. F12 renders the active camera. Other matched cameras: Front, Front_3Q, Left_Side, Back, Right_Side, Back_3Q. The packed `REVIEW — front / three-quarter / side / back` image is also available in Blender's Image Editor. Rig is hidden in the viewport for readability; it remains intact in ASSET.

No dedicated Character Model Showcase registry was found in the inspected player workflow. This uses the existing separate player-review-file convention under `blender/characters/player/reviews/`, with a review index and asset-marked collection. No new animation was made, so the approved Animation Showcase remains untouched.

## Verification and scope

`model_validation.json` records exact original geometry/rest/weights and clothing budget. `reopen_validation.json` confirms fresh reopen, one original body plus the allowed clothing mesh, valid rigid weights, shared material, packed reference/review, no neck gap and zero Actions. The original body geometry signature matches before and after UV/material replacement. The source `.blend` hash remains unchanged. Six final native Blender renders were inspected; the primary reference is embedded unchanged.

**Blender review only.** No Godot file, gameplay behavior, approved model/Action or production WorldMap changed. Pending is not artistic approval. Earlier discarded geometry experiments are preserved outside the repository, not exposed as review candidates.

To rebuild this Pending candidate: run `make_atlas.py` with a Pillow-enabled Python, `build_candidate.py` with Blender, `package_review.py` with Pillow, then `verify_candidate.py` with Blender. The builder refuses to overwrite any candidate whose status is no longer Pending. Source assets are read-only.
