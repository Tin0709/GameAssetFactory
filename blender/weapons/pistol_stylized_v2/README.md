# Pistol_Stylized_V2 — Pending

Original blocky pistol inspired by the supplied Korth silhouette: long faceted slide, stepped rear chamber, rear serrations, loop hammer, angular open guard and angled grip. The Sketchfab page returned 403; the attached image was the visible reference. No downloaded mesh was used.

Latest corrections: muted brown grip panels (sRGB 107,77,62) and upper trigger/guard joints extended into the frame to close the visible gaps. Previous candidates are backed up in `.validation/pistol_stylized_v2/iteration_*`.

## Review and source files

- `Pistol_Stylized_V2.blend`: packed source with one `WEAPON_EXPORT` collection.
- `Pistol_Stylized_V2.glb`: three rigid meshes and attachment nodes, no rig or Action.
- `../showcase/Weapon_Showcase.blend`: same central library, 18 entries, pistol Pending.
- Open `../showcase/Open_Weapon_Showcase.cmd` to load **N → Weapon Library** automatically. Current pistol/rifle appear first; click a row and select Standalone / Character ready / Character holster. Direct opening of a blend cannot restore a custom Python panel unless its script is explicitly run.
- `review/`: standalone, side, muzzle, held full/detail, holster full/detail and separated-parts PNGs rendered from the saved showcase.

## Budget and workflow

1,204 triangles: frame 804, slide 344, magazine 56. Three rigid meshes/draw surfaces, one opaque material, one packed nearest-sampled 64×64 atlas. Dimensions 0.27360m long × 0.04145m wide × 0.219m tall. Closed manifold components, positive volumes, flat normals and small single-segment chamfers. This exceeds the older 150–350 triangle guide target to retain layered forms, hollow barrel, open magazine well and guard. Mobile performance is not measured.

Rifle-family graphite/gunmetal/steel palette with the requested brown accent. Metallic 0.12, roughness 0.5, no emission/transparency. Grip-centered root, identity mesh scale/rotation; Blender +Y forward/+Z up converts once to Godot -Z forward/+Y up.

Exported markers: RightHandGrip, LeftHandGuide, Muzzle, AimReference, RecoilPivot, HolsterAttach, Grip_Point, Support_Hand_Point, Muzzle_Point and MagazineFeed. Exact coordinates are in `asset_report.json`.

Slide pivot (0,-0.050,0.103); independent reference travel 18mm local -Y. Magazine pivot (0,0.013,0.050); extraction vector (0,-0.035,-0.11) through the open grip well. These parts/markers support future aim/recoil/reload work; no animations or gameplay behavior were integrated.

## Character fit and checks

Existing R13 F1 ready and F62 holster poses are static snapshots. Ready pose clears head, chest and off-hand; dominant hand contact is expected with the solid block hand. The existing production hip mount intersects chest, right hand and leg with both the original pistol and this candidate. The holster preview is a mount review, **not a resolved collision-free fit**. Tested clear outboard offsets left the pistol detached from the hip and were not adopted. A tailored holster mount/draw choreography needs further review.

`verification.json` confirms topology, GLB axes/markers, material/texture count, brown panel coverage, closed trigger joints and independent rigid-part travel. All 35 protected files retain their hashes. Existing library entries are preserved against a fresh baseline including concurrent preferred-rifle updates. `../showcase/library_verification.json` passes 270 selections (18×3 modes×5 views). No phone, recoil, reload or animation-transition certification is implied. Stop for user visual review before production replacement.
