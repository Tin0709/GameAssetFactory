# Rifle_Stylized_V2 — Preferred rifle reference

**2026-10-12: explicitly selected as the preferred rifle model and future animation reference.** Source geometry/materials/proportions remain unchanged. Godot integration is a separate Pending candidate; production replacement has not been authorized. See [Godot preparation and fit review](godot_integration/README.md). Historical Pending build notes below are retained.

Latest user steering replaces the early compact silhouette with proportions matched closely to the attached M4A1 reference: 1.20m length, flatter 0.3618m height, longer stock/barrel, shallow layered receiver, open carry handle, broad ribbing, triangular sight and curved detachable magazine. Markings use a small packed atlas; no reference geometry or texture file was imported.

- `Rifle_Stylized_V2.blend`: current Pending geometry source. Reopen it to see the latest saved revision.
- `Rifle_Stylized_V2.glb`: selected-only export, 1,620 triangles, two meshes/surfaces, one material, embedded 1024×512 nearest atlas and nine attachment/reference nodes. Latest user corrections align the serial with the magazine base, arrange two matching curved bands with equal margins, close the handle/magazine joints, darken the barrel and related fittings, and reduce the rectangular muzzle cap about 30% in length and thickness.
- `compact_checkpoint/`: preserved earlier 1.01m compact candidate, independently selectable in the same showcase.
- `review/`: current side, three-quarter, shallow-angle views of both sides, ready and holster renders, alongside same-camera production comparisons.
- `build_rifle.py`: original compact builder; `build_reference_revision.py`: latest reference revision with protected Pending iteration/backups.

Open `../showcase/Open_Weapon_Showcase.cmd` and select **Rifle — Stylized V2** in **N → Weapon Library** for studio inspection and static character fit. [Full workflow, fit findings and limitations](../showcase/README.md). Current production and approved animations remain untouched. Awaiting visual approval.
