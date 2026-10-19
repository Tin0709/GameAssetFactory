# Sniper Sand Block V1 Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans inline. Steps use checkbox syntax.

**Goal:** Add the supplied sand/graphite sniper as a separate Pending prop in the existing Weapon Showcase.

**Architecture:** Self-contained Blender authoring, saved-file geometry validation and GLB export, following the existing sand weapon sources. Reuse the accepted pistol pixel palette and rifle optical-glass settings. The existing library registers it as kind Rifle, with a Sniper label.

**Tech Stack:** Blender Python, Cycles, glTF 2.0, current library registration scripts.

**Spec:** `blender/weapons/sniper_sand_block_v1/reference.png`; the user's request and preceding preferences for red-orange transmitting lenses and visible dark pixel texture.

## Global Constraints

- +Y forward, +Z up, RightHandGrip at origin; WEAPON_EXPORT only for library/export.
- New source folder; preserve all previous sources and approval records.
- Same Weapon Showcase, new Pending entry; no gameplay, animation or Git commits.
- Reference side-view proportions: stock 22%, receiver/handguard 50%, exposed barrel/brake 28% of overall length; long scope about 38%.

## Review Focus

- Optic must have an open metal tunnel and two recessed transmitting red-orange lenses.
- Muzzle bore and both brake slots must be real cavities.
- Stock opening and trigger guard must remain open from either side.
- Native/GLB markers, dimensions and packed nearest-filtered texture must agree.
- New registration must preserve six old entries, sixteen archives and preferred rifle.

### Task 1: Author the reference prop

**Files:** Create `blender/weapons/sniper_sand_block_v1/{build_sniper.py,validate_asset.py,README.md}` and its saved Blender/GLB/palette outputs.

**Interfaces:** Produce grip-centered `Sniper_Sand_Block_V1` root and rigid frame/magazine/bolt/lens meshes in WEAPON_EXPORT.

- [x] Write and run saved-file validator; expect missing source initially.
- [x] Build side-view-scaled silhouette, stock cheek pad/opening, bolt, slotted handguard, long scope and slotted muzzle.
- [x] Run native/GLB topology, openings, optical materials, markers and texture checks.

### Task 2: Inspect and refine visual details

**Files:** Create `render_details.py`, `review/*.png` and reports in the same source folder.

**Interfaces:** Read saved source only; output five full views and four close inspections.

- [x] Compare side proportions and all four detail regions against the reference; correct visible discrepancies.
- [x] Rerun validator after any source change.

### Task 3: Register and verify the existing library

**Files:** Existing showcase manifest, blend and verification report only; baseline in `.validation/sniper_sand_block_v1_20261019/`.

**Interfaces:** Existing `register_weapon.py --kind Rifle --id sniper_sand_block_v1`; default selection becomes new sniper.

- [x] Register the validated source under the existing update lock.
- [x] Run `test_library.py`; require 105 mode/view selections for seven entries.
- [x] Compare baseline source hashes and manifest records; previous assets and approvals remain exact.
- [x] Deliver the review image and viewer refresh instruction.
