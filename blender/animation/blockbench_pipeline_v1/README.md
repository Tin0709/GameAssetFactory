# Blockbench manual pose bridge v1 — Pending review

Created 2026-10-14. Validated with **Blockbench 5.2.2** and **Blender 5.2.2 LTS**. No Godot or production animation changes are included.

## Delivered files

- `Player_Rigid_Proxy_v001.bbmodel`: independent Generic Model authoring proxy, five test clips, six rigid body cuboids, and a locked rifle reference.
- `gaf_rigid_blender_bridge.js`: local Blockbench plugin. Exports the selected animation's evaluated transforms.
- `bridge_contract.json`: measured Blender rest matrices, 13 bone names/parents/pivots, UUIDs, proxy geometry and compatibility hash.
- `import_blockbench.py`: import core; creates a new Pending Action in memory without changing the rig, active Action, files or review status of older Actions.
- `import_to_review.py`: background command for future unique review imports. Saves a separate source study, backs up/registers Pending, and refreshes the existing showcase.
- `blockbench_import_source_v001.blend`: source study for the five delivered Actions, using the existing armature/mesh. It is not a second showcase.
- `validation/`: numerical checks, saved-file/GUI checks, paired preview images and test logs.

## Setup and manual authoring

1. Open `Player_Rigid_Proxy_v001.bbmodel` in Blockbench. Keep **Generic Model** format. Work in **Animate** mode; use the `south` view to see the character's front (+Z).
2. In **File → Plugins**, choose **Load Plugin from File** and select `gaf_rigid_blender_bridge.js`. The export command appears under **File → Export → Export pose/keyframes to Blender (Pending)**. The local plugin has been loaded and tested in an isolated Blockbench profile; install it once in your usual profile if needed.
3. Duplicate a test animation and give it a unique versioned name, for example `BB_Rifle_Ready_Pose_v002`. Animate bone groups, not body cubes. Select `UpperArm.L` / `UpperArm.R` to rotate a **whole straight arm**. Leave both locked `ForeArm` helpers unchanged. Each leg is one `Leg.L` / `Leg.R` segment. There are no knee bones.
4. Set the clip length explicitly. Use numeric ordinary decimal keyframe values. Save your working `.bbmodel`, then export the selected clip. The plugin samples at **120 Hz** for **30 FPS** review; it also includes original key times and the final boundary. Duration is rounded up to a whole playback frame, holding the final pose if required.
5. Import from a separate background Blender process; do not execute the helper in an editor with unsaved work. On this machine:

```sh
'/Applications/Blender.app/Contents/MacOS/Blender' \
  --background '/Users/tin/Desktop/Game Dev/GameAssetFactory/blender/animation/showcase/Animation_Showcase.blend' \
  --python-exit-code 1 \
  --python '/Users/tin/Desktop/Game Dev/GameAssetFactory/blender/animation/blockbench_pipeline_v1/import_to_review.py' \
  -- '/absolute/path/BB_Rifle_Ready_Pose_v002.samples.json'
```

An optional second argument supplies a unique Action name. Use letters, digits and underscores. Existing Action names and source folders are refused; revisions never overwrite approved Actions. The helper saves the source under `imports/<Action>/source.blend`, registers **pending**, and refreshes/saves the same `Animation_Showcase.blend`. Close/reopen a previously open showcase to avoid reviewing stale cached data. The helper protects on-disk concurrent changes; save/close any other editing session of the showcase before running it.

6. In Blender, select the clip from **N → Animation Library**. The five supplied tests are at the end of the existing list. Technical checks and importing do not grant artistic approval.

For scripting, `import_clip(existing_rig, clip_json, contract_json)` creates an independent Action without assigning or saving it. The existing `register_animation.py` and library refresh remain the registration authority. The convenience helper uses them; it does not bypass their compatibility checks.

## Geometry and rest policy

The character is 1.8 m tall. Body width/depth are 0.45/0.225 m; head is a 0.45 m cube; each leg is 0.225 × 0.225 × 0.675 m; each full arm is 0.16875 × 0.225 × 0.675 m. Measured float coordinates are retained in the contract.

The proxy preserves all **13 names, parent relationships and rest pivot positions**. Original `UpperArm` and `ForeArm` bones remain present, because the existing mesh weights use both. Each proxy arm is a single continuous cuboid parented to its shoulder group; the forearm helper is locked and has no visible elbow. Import rejects independent forearm motion and writes its local pose transform as identity. Original Blender bones, weights, topology, materials and rest transforms are retained. No proxy mesh is imported into Blender.

Neutral means the **actual rig rest pose**, with zero local pose channels. The showcase's reset baseline contains 32 mm shoulder offsets; full-channel imported Actions explicitly override those offsets so a previous clip cannot contaminate neutral. This is intentional and does not change the showcase reset baseline or any existing Action.

The proxy uses simple part colors, not the production skin/UVs. Its rifle is a locked geometry reference extracted only from the assembly already present in the showcase. The actual Blender character retains its original appearance.

## Coordinate conversion

Column vectors are used. Export JSON stores **row-major 4×4 matrices**, converted from THREE's column-major arrays. At 16 Blockbench units per Blender metre:

```text
C : (x, y, z) Blender → (16x, 16z, -16y) Blockbench
D_i = C⁻¹ · P_i · S_i⁻¹ · C
Bposed_i = D_i · Brest_i
```

`S_i` is the Blockbench rest world transform; `P_i` is its evaluated posed world transform; `Brest_i` is the original Blender bone's rest matrix. Blender `Bone.convert_local_to_pose(..., invert=True)` resolves parent and bone rest transforms to local animation channels. Rotation modes remain the existing mix of Euler XYZ and quaternion. Quaternion signs and Euler branches are made continuous before baking. Every Action keys all bones' location, rotation and unit scale; there is one OBJECT slot, layer, strip and channel bag. Only the new Action is created.

Blockbench Generic Model evaluates Euler rotations in THREE **ZYX** order. Blender Euler order names use a different multiplication convention: a seed pose derived from a Blender matrix uses mathutils **XYZ** to match THREE ZYX. The importer avoids this naming trap by consuming evaluated matrices. The arbitrary WeaponCarrier rest orientation is accounted for by the same rest-matrix solve.

## Validation findings

The supplied Actions are `BB_Neutral_Test_v001`, `BB_RightArm_Test_v001`, `BB_LeftArm_Test_v001`, `BB_HeadTurn_Test_v001`, and `BB_Rifle_Ready_Pose_v001`. All are **Pending**, F1–31 at 30 FPS, with one-shot timing. The arm/head tests transition from rest to a pose over 0.5 s, then hold. Neutral and Rifle Ready are static holds. The Rifle test round-trips F1 of the approved `Rifle_Ready_V2_v16_Test`; it does not revise that approved source.

Each import has 121 samples. Each comparison uses 241 independently evaluated Blockbench reference times, including the midpoints between import samples. The tests compare Blender's actual skinned vertices, all bone transforms, actual Blockbench cube corners, whole-arm/leg pairwise distances and forearm identity. The original Ready bone matrices and its rifle reference vertices are also compared directly. See `validation/pose_validation.json`, `rifle_preview_validation.json`, `showcase_validation.json`, and `gui_validation.json` for measured results. Paired front and three-quarter images are under `validation/previews/`.

Visual validation found two seed-reference problems before final delivery: very small scientific-notation literals were interpreted as Molang expressions, and the initial seed conversion used the wrong Euler naming convention. Decimal quantization and the corrected seed matrix conversion fixed them; a new independent comparison against the approved Ready reference guards the result. Rifle preview extraction also had to enable its hidden collection before evaluating attached mesh world transforms. The importer itself continues to use evaluated matrices. The rejected intermediate is archived under `.validation/blockbench_pipeline_v1/rejected_scientific_literals/`.

All **28 existing Actions**, including **12 approved Actions**, retain their content signatures, slots and original registration entries. The saved showcase contains **33 Actions** and the same single original armature. Complete pre-change showcase/manifest backups, including all approved Actions, are under `.validation/blockbench_pipeline_v1/before/`; the existing registration helper also made timestamped backups under `.validation/animation_showcase/registrations/`.

## Limits and future animations

- v1 is version-pinned to Blockbench 5.2.2. Revalidate before changing the editor version or proxy contract. Do not rename/reparent bones, edit rest pivots/geometry, convert formats, unlock forearms or add joints.
- Smooth numeric bone rotation/translation keyframes are supported through evaluated sampling. Molang, scientific-notation strings, animation controllers, effects, blending/override, muted channels, global-rotation mode, animated scale, shear, reflections and step/discontinuous keys are rejected. Ordinary decimal values are required. Constraints, NLA, drivers or a changed Blender rig are rejected.
- Baked transforms match at sample times; interpolation between samples is an approximation. Faster future motion may need 240/480 Hz and new dense reference checks. A manually edited `.bbmodel` must be exported again through this plugin; arbitrary Bedrock/glTF Euler channels are not interchangeable with this sample format.
- This preserves evaluated poses, not Blockbench's editable curve structure or original keyframe tangents. Exported files retain timestamps, source duration and loop intent. Registration remains conservatively non-seamless until pose AND velocity seams are separately checked. Test clips here are one-shots, not locomotion/weapon layers.
- Root translation is possible as bone motion, but physics/world travel ownership, gameplay layering, foot contacts, interruption and animation transitions still need separately authorized Godot validation. No Godot, production animation, controller or export changes were made.
- A static Ready round-trip proves transfer fidelity and straight limbs. It does not establish a new artistic approval, dynamic weapon handling quality, production readiness or mobile performance.
