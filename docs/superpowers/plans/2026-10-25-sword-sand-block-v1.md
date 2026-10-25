# Sword Sand Block V1 Implementation Plan

> **For agentic workers:** Execute inline with superpowers:executing-plans; preserve the established local Blender source/viewer workflow.

**Goal:** Recreate the user's stepped graphite/silver sword with a gold guard, wrapped grip and framed pommel in Blender.

**Architecture:** One self-contained source folder with two rigid meshes, a packed pixel atlas, GLB and native review renders. Extend the existing library's registration to kind Sword with standalone-only preview; the seven firearm entries keep all their existing preview modes and metadata.

**Tech Stack:** Blender Python, Cycles, glTF, repository-local Weapon Library.

**Spec:** `blender/weapons/sword_sand_block_v1/reference.png`. The image defines proportions and decorative details; its labels are reference content only. Reference side silhouette spans about580pixels, blade420pixels, guard130pixels across and grip60pixels long. Use1.9mm per side-reference pixel, +Y towards tip, +Z across blade, grip at origin.

## Global Constraints

- New Pending source and entry only; preserve all seven prior source packages, statuses and sixteen archived entries.
- Use the same Weapon Showcase. Sword has no firearm pose or gameplay/animation work.
- Author in the established checkout/new asset folder; baseline all prior weapon files and use the central update lock for registration. No Git staging, commits or worktree change.
- Small regenerable renders and sources stay well below25MiB per file; existing LFS rules already cover Blender/GLB.

## Review Focus

- Stepped silhouette and broad silver edging must read from both sides.
- Guard ends, dark face inserts, five grip segments and recessed pommel end must be geometric details.
- Core fuller remains shallow and symmetric; no coplanar dark render artifacts.
- Native/GLB topology, packed atlas, dimensions and markers must agree.
- Switching from a firearm Ready/Holster to Sword must return to standalone without missing fit data; switching back must preserve firearm previews.

### Task 1: Author and inspect the sword

**Files:** New `blender/weapons/sword_sand_block_v1/{build_sword.py,validate_asset.py,render_details.py,README.md}` and outputs.

**Interfaces:** WEAPON_EXPORT with grip-centered Sword_Sand_Block_V1 root, Sword_Blade and Sword_Hilt children.

- [ ] Run the saved-file validator before build; confirm missing source.
- [ ] Build the reference silhouette, faceted silver edges, shallow fuller, gold guard, five grip wraps and recessed pommel.
- [ ] Render side, opposite, top, front, hero and four details; compare with the reference and refine.
- [ ] Verify saved topology/GLB roundtrip/markers/atlas and source dimensions.

### Task 2: Add standalone Sword support

**Files:** Existing `showcase/{register_weapon.py,gaf_weapon_library.py,test_library.py}` plus `test_sword_preview.py`.

**Interfaces:** Per-entry preview_modes, defaulting to the existing three firearm modes. Sword registrations receive only STANDALONE; unsupported mode requests normalize safely.

- [ ] Run the real saved-library sword selection test before registration; confirm missing Sword.
- [ ] Add Sword registration and standalone mode handling; preserve existing firearm behavior.
- [ ] Register the finalized source under the existing update lock.
- [ ] Run saved-library mode/view coverage and Sword/firearm mode-transition checks.

### Task 3: Deliver and preserve

**Files:** Same showcase manifest/blend/README/reports; evidence under `.validation/sword_sand_block_v1_20261025/`.

- [ ] Audit all prior source/file hashes, active/archive records and preferred rifle.
- [ ] Confirm nine final render files, new Pending entry and new default selection.
- [ ] Open the saved model in Blender or activate the existing viewer; report reload needs accurately.
