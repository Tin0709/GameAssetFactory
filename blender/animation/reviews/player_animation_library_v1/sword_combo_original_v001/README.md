# Sword Combo Original v001 — Pending

One original connected three-hit combo, authored for the existing 13-bone straight-limb GAF rig. Blender review only. No approved Action, weapon source, skin source or Godot gameplay was edited.

## Review

Open the existing **SOLDIER_Asset_Library.blend** through the existing `soldier` launcher. Choose **SOLDIER Library → ANIMATIONS → Sword Combo v001**. Play/Pause and Restart run the combo; Hit 1/2/3 inspect the proposed contact poses. Front, 3/4, both sides, back and back 3/4 remain available. Normal orbit/zoom works outside camera view.

The independent canonical Action is also registered Pending in **Animation_Showcase.blend**, with the existing Sword Sand Block V1 attached to WeaponCarrier. Rifle and unarmed previews still switch independently. The same Action signature is used in both libraries; there is no duplicate animation variant.

## Proposed choreography and numerical design

All values below are **P: original authoring proposals**, not measurements of MD2 bone tracks.

| Event | Frame at 30 FPS | Time from F1 | Intent |
|---|---:|---:|---|
| Guard | 1 | 0.00 s | Quiet balanced start |
| First compact load | 6–7.5 | 0.167–0.217 s | Shoulder opens; left foot receives |
| Hit 1 | 10 | 0.30 s | Right-to-left descending sweep |
| Returning load | 21 | 0.667 s | Connect directly from first follow-through |
| Hit 2 | 25 | 0.80 s | Left-to-right returning sweep |
| Finisher load | 37–40 | 1.20–1.30 s | Higher, longer overhead preparation |
| Hit 3 | 43 | 1.40 s | Stronger descending finisher |
| Receive | 46 | 1.50 s | Torso and free arm absorb momentum |
| Settled guard | 59–61 | 1.933–2.00 s | Feet recover; exact compatible endpoints |

One Action, F1–61, 30 FPS; 2.0 s between endpoints, 61 encoded frames in the preview movie. Baked at 240 samples/s, linear native channels over smooth scalar and spherical authoring curves. Unit bone scales, no elbow/knee articulation, no object/root travel. Shoulder-to-palm grip radius 0.622 m. Foot lifts are small explicit steps (approximately 0.024–0.032 m), with a fixed toe-out rather than spinning feet. No neutral reset between attacks.

Contact markers describe visual intent only: no hitbox window, cancel gate, combo buffer, root-motion policy, hit-stop or runtime damage event is implemented or claimed.

## Evidence boundary

- **S / Actions & Stuff:** existing verified controller/layer, grounded-limb and timing principles inform the design. No source animation curves were copied into this Action.
- **O / MD2 footage:** existing genuine gameplay crops and frame analyses in `docs/animation/style_system/MD2_COMBAT_FRAME_ANALYSES.md` informed connected sweeps, body loading and discrete impact/readability. These observations do not reveal a skeleton or authored keys.
- **Published MD2 values:** prior research records damage 14/16/22, raw KnockbackStrength 500/500/800 and AttackSpeedMultiplier 1/1/1.4. These are qualified public-publication values, not independently authenticated local animation assets. They are not used as pose angles, physical mass, clip durations or proven playback multipliers.
- **P / original:** every bone transform, arc, pose, timing, step, follow-through and recovery here is newly authored. No MD2 skeleton, keyframes, curves, notifies or blend parameters have been obtained.
- **U:** actual MD2 bone tracks, rest hierarchy, sample rates, exact impact/cancel windows and animation blending remain unavailable. A bounded official-source check added no authorized numerical track dataset; no encrypted index was rescanned and no protected asset was extracted.

Official developer discussion checked: https://news.xbox.com/en-us/2026/09/26/minecraft-dungeons-ii-the-sift-new-mechanics-better-exploration-and-more-official-xbox-podcast/amp/ . It discusses design/gameplay, not numerical animation tracks.

## Soldier appearance adapter

The Soldier library's original 10-bone rig, meshes, UVs, materials, face/hair assets and prior Actions remain intact. The preview copies the current worn body/clothing, layered hair cards and red bandana. Rigid Arm.L/R groups map to UpperArm.L/R on an unchanged copy of the Showcase rest rig; vertices are rebound through measured rest-pivot matrices. Skin proportions and straight full limbs are preserved. The preview has its own camera data/studio, within the same existing library file. No backpack is equipped. Hair/cloth secondary physics and facial combat performance are not part of this initial sword Action.

## Reusable authoring workflow

1. Record S/O/P/U provenance, choose existing rig and weapon, measure grip markers and rest pivots. Back up library/manifest and hash protected sources.
2. Set guard, directional load, proposed contact, follow-through, receiving and recovery poses. Decide explicit foot support before adding curves.
3. Connect attack exits to the next load; coordinate hips → chest → arm/weapon, with head/free-arm counterbalance. Hold one rigid grip transform.
4. Interpolate orientation on the quaternion sphere and scalar motion with bounded smooth curves; bake a single compatible Action without helpers/constraints that runtime cannot reproduce.
5. Evaluate at 30/60 FPS and subframes. Inspect soles, limb shape, hand-to-weapon transform, body clearance and endpoints. Render front/3/4/side at **1× real time**; refine actual pixels.
6. Register independently Pending, attach the existing prop, refresh/save/reopen the established library and switch back to earlier clips. Recheck protected hashes before review.
7. Collect human pose/timing feedback before any Godot integration. Future runtime work must define turn/cancel gates, movement ownership and hit events separately.

## Validation

`geometry_validation.json`: 481 native subframe samples; includes 30/60 FPS sample grids. Minimum body sole ~0.000600 m; maximum rigid grip translation residual ~0.000021 m; arm rigidity and unit scales pass; endpoint matrices equal. Additional sampled blade centerline/head/torso checks and a fresh review of Soldier surfaces found no intersections in the tested samples. These are sampled diagnostics, not a guarantee for every future prop or runtime blend.

`soldier_preview_validation.json`: actual saved file reopened; all six selectors and six cameras, contact/restart controls, canonical Action hash, original 14 mesh/UV/material-index signatures, 34 prior Action signatures and original rest matrices pass against the live pre-apply backup. Existing facial preview scratch Actions are compared to that live session, preserving its changes rather than restoring stale on-disk state.

Source scripts are in `authoring/`; reproducible build/validation logs and preservation snapshots are under `.validation/sword_combo_original_v001_20261025/`. Source-derived/reference material stays dev/research only; no production eligibility is asserted by Pending registration.
