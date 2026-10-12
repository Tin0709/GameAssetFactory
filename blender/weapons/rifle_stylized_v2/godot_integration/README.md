# Rifle Stylized V2 — Godot preparation

The user explicitly selected this model on2026-10-12 as the preferred rifle and primary reference for future weapon animation. **Production replacement remains unapproved.** The original Blender source and existing source export are unchanged.

## Open the isolated candidate

Open game_mobile_3d/scenes/dev/RifleStylizedV2IntegrationTest.tscn in Godot and press **F6**. F5/WorldMap and the existing locomotion test remain unchanged.

- WASD/arrows move; Shift runs; Space jumps; L drops for falling review.
- **B** compares V2 against the preserved production R13 rifle.
- **H** switches ready/back static fit.
-1/2/3 select front/three-quarter/side; C switches gameplay/detail camera.
- E retains the existing rifle-layer toggle; T/Y retain speed comparisons.

The candidate is already equipped for inspection. H is explicitly a static back-attachment comparison; it does not certify holster/draw choreography.

## Export and source preservation

Fresh export: game_mobile_3d/assets/weapons/rifle_stylized_v2_test/Rifle_Stylized_V2.glb.

Source dimensions:1.200m long,0.093m wide,0.3618m high.1620 triangles; two rigid meshes including detachable magazine; one material, embedded1024x512 nearest atlas. Nine markers include RightHandGrip, LeftHandGuide, Muzzle, AimReference, RecoilPivot, HolsterAttach and the legacy Grip_Point/Support_Hand_Point/Muzzle_Point aliases. No skin, animation, collision, firing behavior or extra rig was added.

The fresh export's complete binary payload (geometry, UVs, normals and texture) is byte-identical to the existing source GLB; material and mesh definitions match. JSON-only differences carry authoring extras. Source .blend hash0d8c2d0fb05e8be82d5c2a3485eb3cd1a40acdc70c1e656ed2f4322e17bad03f is unchanged. [Export evidence](export_validation.json).

Blender +Y forward/+Z up converts once in glTF to -Z forward/+Y up. Existing R13 socket orientation is reused; no second axis conversion or corrective mesh edit. Ready and Chest-back mounts use uniform1.05 scale in the test, removing legacy .8925X versus1.05YZ width compression. Marker X is zero, so the right grip and left support targets remain equal to the preserved R13 targets. Muzzle references come from V2, preserving its longer barrel.

## Character fit and limits

Native expressive Idle/Walk/Run, turn bank, jump/fall layers and rig remain read-only.82 checks at30/60 renderFPS verify marker export, original grip/support target equality, attachment invariance during seven gameplay phases, proportion-preserving scale, Chest back parenting and old/new selection. These prove transform/socket consistency, not independent hand surface-contact certification.

Rendered ready front/three-quarter/side and back comparisons are included here. Static BVH checks on the authored R13 ready/stowed snapshots find no V2 head/chest/off-hand intersections. The original hold already overlaps the dominant arm; V2 has31 upper-arm/110 forearm triangle pairs versus17/104 for R13. Existing55deg stowed snapshot has13 right-forearm pairs versus6 original. Counts are triangle overlap diagnostics, not penetration depth. Those right-arm/grip/stowed clearances still need artistic review. No source/model was distorted to conceal them.

Back test keeps the existing R13 Chest anchor/orientation. The central Blender showcase retains its separate10deg nearly horizontal presentation alternative. Do not copy that world-space preview matrix directly into the Chest socket. Holster/draw transport, aiming/recoil/reload, obstacle clearance, muzzle effects and actual phone performance remain unvalidated. Keep the model swap test-local until those and the user's gameplay review pass.

## Review

[Original-speed actual Godot review](gameplay_1x.mp4),213 frames at30FPS; no video retiming.

- [V2 ready three-quarter](v2_ready_threequarter.png)
- [V2 ready front](v2_ready_front.png)
- [V2 ready side](v2_ready_side.png)
- [V2 back, rear angle](v2_back_rear.png)
- [Previous rifle ready](previous_ready_threequarter.png)
- [Previous rifle back](previous_back_rear.png)

All18 Weapon Showcase entries remain selectable from the SAME existing file. V2 is Preferred reference; integration Pending. The compact checkpoint and legacy rifles remain. Reopen via blender/weapons/showcase/Open_Weapon_Showcase.cmd, N > Weapon Library.270 real saved-file mode/view checks pass, with zero character Actions in that showcase. The concurrent pistol entry/default is preserved.

Backups: .validation/rifle_v2_integration/before/ includes the chosen source/export/textures, earlier rifles and production rifle, old showcase/manifest, and documentation. before_preferred_update/ additionally preserves the expanded18-entry library. [Preservation evidence](preservation.json). Approved animations, Animation Showcase, production scenes/scripts and existing rifle assets remain unchanged.
