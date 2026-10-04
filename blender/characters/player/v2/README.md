# Voxel Wayfinder — player v2

Open `player_voxel_v2.blend`. This is a separate version; the original `../player_base.blend`, asset base scene and old zombie project were not changed.

## Visual changes

- Cubic 46 × 43 × 46 cm head, planar face and material-colored stepped hairline. Removed sculpted nose, ears, rounded hair shell and raised eyebrows.
- Straight-sided teal tunic replaces tapered jacket. Nearly square corners and broad planar surfaces replace large bevels.
- Rectangular arms and legs with uniform cross sections; square hands without mitten/thumb bulges; box-shaped brown boots.
- Flat collar, simple leather strap/satchel, dark trousers and one small cyan chest badge retain an original scavenger identity.
- 1.86 m tall, soles at Z = 0, origin at world zero, facing -Y with Z up.

## Budget and rig

1,792 triangles, 1,006 vertices, six opaque materials, no image textures, no subdivision. Small single-segment edge chamfers on accessory/boot forms only; head is a true box. Some planar head subdivisions define material boundaries for the hairline without textures.

`Player_Base` and `Player_Rig` are the only objects in `ASSET`. The rig was rebuilt to fit the straighter limbs while keeping the original 20-bone naming and hierarchy:

```text
Root
└─ Hips
   ├─ Spine → Chest
   │          ├─ Neck → Head
   │          ├─ Clavicle.L → UpperArm.L → Forearm.L → Hand.L
   │          └─ Clavicle.R → UpperArm.R → Forearm.R → Hand.R
   ├─ Thigh.L → Shin.L → Foot.L
   └─ Thigh.R → Shin.R → Foot.R
```

One non-deforming Root and 19 deform bones. New skin weights use at most two normalized influences per vertex, with joint loops and blended transitions at elbows, knees, waist and shoulders. Face and hands stay rigid. Saved in relaxed A-rest with no animations or actions. This is an FK deformation skeleton; animation controls/IK can be added later. Changed rest proportions mean future retargeting should use rest-pose correction, not assume identical bind matrices to v1.

Numerical and rendered checks covered 80° elbow flexion, 85° knee flexion, torso bend/twist and a 30° head turn. No unweighted vertices or invalid bone references. See `deformation_report.json` and `deformation_check.png`. Extreme production poses still need animation-specific review.

`player_voxel_v2_preview.png` is a 1024 × 1024 transparent RGBA preview. Original asset camera and light transforms/settings were retained. These are preview lights, not game runtime lights.

`build_player_v2.py` is the authoring recipe and intentionally overwrites this v2 asset when rerun in a dedicated copy of the player scene. `validate_player_v2.py` repeats the weight/deformation checks and restores the rest pose unless `PLAYER_KEEP_TEST_POSE=True` is explicitly set for visual inspection. No Godot integration or animation clips are included in this revision.
