# Sniper — Sand Block V1

Pending visual review. New reference-based game prop in the same Weapon Showcase, registered as kind Rifle for the existing static fit system. No prior weapon source or approval was replaced.

The supplied multi-view image is `reference.png`. Its side view fixes the silhouette: raised cheek rest, stepped stock opening, raked grip, small trigger guard, shallow receiver, angled bolt handle, straight box magazine, five horizontal vents per side, long exposed barrel and two slotted brake windows per side. The scope has two real recessed red-orange transmitting lens meshes and an open metal tunnel; the knurled upper adjustment and side cap remain solid outside that tunnel.

`Sniper_Sand_Block_V1.blend` is the authoring source; `.glb` is the standalone game-prop export. Four rigid meshes: frame, magazine, bolt and lenses. Three materials: packed nearest-filtered 256×256 sand/graphite atlas and two optical glass materials. Accepted high-contrast dark pixel texture is copied from the pistol palette. +Y forward, +Z up; RightHandGrip/root at origin. Geometry spans 1.1932m long × 0.112m wide × 0.29823m high, 8,004 triangles. No Action, rig or moving mechanism is authored.

`build_sniper.py` rebuilds only this Pending source with explicit `--rebuild`; `--no-render` skips the full review views. `validate_asset.py` reopens the saved source, checks closed component topology, real stock/trigger/vent/brake openings, deep muzzle bore, clear optical tunnel and transmitting glass, then imports the GLB to check exact dimensions, texture pixels and markers. `render_details.py` reads the saved file without resaving it. Five full and four close review PNGs live in `review/`.

Run the existing launcher after closing an older Weapon Showcase window:

```sh
python3 "$HOME/Desktop/Game Dev/GameAssetFactory/scripts/open_blender_viewer.py" weapon
```

Select **Sniper — Sand Block V1**. The launcher can activate an already-open window without reloading its contents. Static Rifle Ready/Holster snapshots are inherited previews, not validated sniper gameplay poses. This task changes no production asset, gameplay, animation or previous weapon source. Preservation baseline and review evidence: `.validation/sniper_sand_block_v1_20261019/`.
