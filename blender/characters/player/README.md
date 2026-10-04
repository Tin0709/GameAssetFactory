# Player / Wayfinder survivor

Official reusable player foundation for the mobile isometric project. Open `player_base.blend` in Blender. The `ASSET` collection contains only `Player_Base` and `Player_Rig`. Preview camera and three lights are retained from the existing asset pipeline; only render output resolution was raised to 1024 square. Do not import those preview lights into the game.

- Height: 1.87275 meters; soles at Z = 0; origin at (0, 0, 0).
- Orientation: Z up, character faces -Y; positive X is character left.
- 2,828 triangles, 1,496 vertices, six shared opaque materials, no image textures.
- One mesh with separate clothing/anatomical forms, one armature modifier, applied scale/rotation.
- 20 bones: 19 deform bones and one non-deforming Root. Maximum two normalized influences per vertex.
- Saved in relaxed A-rest pose, no actions, keyframes, constraints or animation clips.
- `player_preview.png`: transparent RGBA beauty preview. `deformation_check.png`: temporary combined test pose, not an animation.

## Skeleton

```text
Root
└─ Hips
   ├─ Spine
   │  └─ Chest
   │     ├─ Neck
   │     │  └─ Head
   │     ├─ Clavicle.L
   │     │  └─ UpperArm.L → Forearm.L → Hand.L
   │     └─ Clavicle.R
   │        └─ UpperArm.R → Forearm.R → Hand.R
   ├─ Thigh.L → Shin.L → Foot.L
   └─ Thigh.R → Shin.R → Foot.R
```

Root provides global/root motion; Hips supports bounce and weight shifts. Separate Spine/Chest/Neck and clavicles support breathing, anticipation, recoil, hit reactions and shoulder follow-through. This is an FK deformation skeleton prepared for animation, not a full animator control/IK rig. Bone local Y follows each segment; local Z aims forward where possible. Rotation is XYZ; non-root location and all scale channels are locked to prevent accidental edits (animators can unlock deliberately).

## Weight and deformation validation

Explicit anatomical weights avoid automatic cross-limb contamination. Elbows and knees use graduated two-bone transitions across multiple loops. Hair, facial details, hands and boot bodies retain rigid weights for stable silhouettes. Sleeve/shoulder transitions blend into clavicles. Jacket hem follows Hips and transitions into Spine/Chest higher up.

Tested an 80-degree elbow bend, 85-degree knee bend, torso bend/twist, and head tilt/30-degree turn, both numerically and in a combined rendered pose. Corrected overly narrow elbow weights, broadened knee transitions, and tapered the hidden trouser waist to prevent it protruding through the jacket during torso twist. All 1,496 vertices have normalized weights; no unweighted vertices; no invalid bone references. See `deformation_report.json` for measured motion/stretch. Extreme poses will still need animation-specific review; no full animation cycle has been authored.

`validate_player.py` can be executed inside Blender to repeat the numerical checks; it restores the relaxed pose by default. Setting `PLAYER_KEEP_TEST_POSE=True` in the execution namespace retains the temporary pose for visual inspection only. `build_player.py` records the authoring recipe and regenerates/overwrites this new asset; use only intentionally in a dedicated session loaded from the base scene.

## Mobile considerations

Flat Principled materials, opaque surfaces, no subdivision, no shader textures and only a small cyan emission accent. Six materials can produce up to six material batches; atlas/material consolidation can be considered later if crowd or draw-call profiling warrants it. Rig has no runtime constraints. Enable character shadows only after device profiling. This source asset has not yet been exported or integrated into Godot.

The source `blender/base_scene.blend` was SHA-256 checked before and after authoring and remained unchanged. The old zombie prototype was not modified.
