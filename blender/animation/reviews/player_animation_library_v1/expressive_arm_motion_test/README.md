# Expressive arm motion — small capability test

2026-10-10. **Blender-only, original animation. User-approved as a proof-of-capability result.** The subsequent run-test request explicitly states: “The Expressive_Arm_Motion_Test was successful and approved as a proof-of-capability result.” This approval is scoped to this proof, not production locomotion or a new rig. Primary reference: [Animation Style Guide](../../../../../docs/animation/ANIMATION_STYLE_GUIDE.md), especially rigid articulation, shoulder attachment, independent timing, torso opposition and restrained head motion. This tests those principles; it does not reconstruct Dungeons II's rig or copy reference keyframes.

## Review

- Open [expressive_arm_motion_review.blend](expressive_arm_motion_review.blend). It opens the isolated `EXPRESSIVE_ARM_MOTION_REVIEW` scene at the forward pose. Play frames **1–24**, **30 FPS**. Select `EAM_Player_Rig` to inspect Action **`Expressive_Arm_Motion_Test`**.
- [Front + three-quarter motion video](expressive_arm_motion_1x.mp4): actual sequential Cycles renders, 1x speed, three repeats for review. One pass is 0.8 seconds; the F1–F24 key interval spans 23/30 seconds. This is a neutral-to-neutral gesture, not a gait loop.
- [Three-pose comparison](three_pose_review.jpg): front above, three-quarter below; F1 neutral, F7 backward, F14 forward/outward.
- All 24 frames: [front](front_all_frames.jpg), [three-quarter](three_quarter_all_frames.jpg). Original 640×640 PNGs are under `frames/`.

## Rig evaluation before authoring

Inspected the current saved library, with 326 existing Actions, and its established `JD1_Player_Rig`/`JD1_Player_Mesh` source. The active Godot player is separately the later V004 scene loaded by WorldMap, not the older V003 entry in historical guidance. No runtime asset or script was changed.

| Item | Direct finding and implication |
|---|---|
| Skeleton | 13 bones: Root → Hips → Spine → Chest → Neck → Head; each UpperArm is a Chest child, each ForeArm its own UpperArm child; both whole legs are Hips children; WeaponCarrier is a Chest child. |
| Shoulder pivots | Rest heads at X ±0.337500, Y 0, Z 1.350000 m, at the top of the arms; upper-arm length 0.337500 m. Existing neutral pose offsets produce X ±0.305500 m: the established 32 mm inset is preserved. Rest positions and pose offsets are distinct. |
| Independent controls | Direct FK upper-arm rotations are independently addressable. No bone constraints or rotation locks were present. The test rig has no NLA tracks or drivers fighting the new Action. |
| Rigid geometry | 64 vertices, each with exactly one weight of 1.0. One Armature modifier. Full arms/hands remain the original mesh and texture; forearms stay aligned for a continuous block silhouette. |
| Torso/head | Spine, Chest and Head can rotate separately. The head inherits the chest chain, so its small local compensation is necessary to keep the face comparatively quiet. |
| Limits | No dedicated clavicle/shoulder-girdle control; shoulder centers move with Chest. Fixed inset and broad cuboid corners limit clearance near the head and hips. Whole rigid legs offer no knee/ankle absorption. None of these prevents this small upper-body test. |

The initial rotation-only backward pose hid too much of the far arm in three-quarter view. This was a **pose/projection limitation**, not a missing joint. Increasing its outward arc corrected the silhouette without translating the shoulder or changing the rig.

## Exactly what changed

**No rig improvement/replacement was necessary.** The study adds an isolated scene, a copied armature with identical rest matrices, a copied mesh object referencing the **same mesh datablock**, two review cameras and copies of existing review-stage objects. One new Action animates only UpperArm.L, UpperArm.R, Spine, Chest and Head rotation. No new deform bone, weight edit, mesh edit, material edit, scale animation, shoulder translation, root motion or leg animation was introduced. The new armature avoids assigning the experimental Action to an existing actor.

The saved source library remains byte-for-byte unchanged. The standalone study contains all 326 earlier Actions plus the new test, **327 total**. Its old review sidebar remains historical; use the new scene/timeline for this test. No sidebar entries or old clip selections were replaced.

Save/reopen retention: the two pre-existing unused image copies `Player_Cuboid_V5_Face_Atlas_64.002` and `.003` have Fake User enabled **only in the study copy** so Blender retains them on reopen. Their pixels are unchanged. This is a datablock-retention flag, not an appearance or rig change.

Backups were created before study changes: [saved disk library](../../../../../.validation/expressive_arm_motion_test/library_disk_before_test.blend), [loaded live library](../../../../../.validation/expressive_arm_motion_test/library_before_test.blend), and the initially connected [unsaved startup scene](../../../../../.validation/expressive_arm_motion_test/startup_before_test.blend). The original source hash and backup path are in [manifest.json](manifest.json).

## Motion design

| Phase | Authored behavior |
|---|---|
| F1 | Exact established neutral; no new permanent shoulder spread. |
| F4–8 | Ease into backward extension. Right arm reaches −57° pitch / −44° spread at F7; left arm peaks later at F8 with −48° / +29°. These are authoring Euler inputs, not world-space anatomical measurements. |
| F9–14 | Accelerate through the swing, retaining outward clearance. Right reaches +78° pitch / −38° spread at F14; left reaches its forward peak at F15, +64° / +38°. Unequal amplitude and timing avoid identical mirrored rods. |
| F15–20 | Ease out of the broad forward pose and recover. Chest and spine oppose the stronger side's swing; their pitch reaction stays small. |
| F22–24 | Very small arm/chest overshoot and head recovery, then exact neutral. Feet and hips stay fixed throughout. |

Quaternion rotation curves use auto-clamped Bezier handles. Head compensation peaks later than the main chest accents (F8 and F15), providing restrained overlap rather than exaggerated bobbing. The strongest backward/forward direction change is easier to read in three-quarter view; front view primarily reveals outward spread and asymmetry. The exact keys are recorded in `manifest.json` and `build_test.py`.

## Evaluation and limitations

**Current rig is sufficient for this proof.** The rendered extremes show wide, independently directed arms, visible negative space beneath them, intact shoulder attachment and straight block edges. The revised far-arm spread improves the backward silhouette in both supplied views. Unequal timing and the small torso/head response make the frame progression less mechanical than rotating both arms identically. This is an artistic assessment of the rendered pose sequence, not user approval or a quantified match to the sequel.

**Still stiff:** the feet/pelvis are deliberately static, both straight arms have no elbow overlap, and the 24-frame neutral-to-neutral gesture has a compact recovery. It cannot establish the weight transfer or continuous rhythm of a run/jump. Those are outside this test. A future optional shoulder control could make small clearance corrections easier, but a new deform hierarchy or replacement rig is not justified by these results.

The 185-sample geometry check includes eighth-frame in-betweens. It detects shallow new head/upper-arm overlaps up to **3.430 mm** and leg/forearm overlaps up to **1.896 mm** near entry/recovery. They are not conspicuous at the supplied framing; they remain a documented limitation, not a collision-free claim. F1, F7, F14 and F24 have **no new nonadjacent overlaps** relative to neutral. Existing adjacent attachment overlap is intentionally excluded from this diagnostic and visually reviewed. No conspicuous hand-through-torso or detached shoulder appears in the rendered sequence. Future larger motion ranges should be checked again rather than inheriting an unconditional clearance pass.

## Validation and compatibility

[validation.json](validation.json) records the evaluated results:

- Maximum within-segment distance change **0.242 micrometers**; maximum elbow seam error **0.267 micrometers**: floating-point scale, not visible rubber deformation.
- Foot drift **0** and final neutral vertex error **0** in the sampled evaluation.
- Full actor remains inside both cameras throughout all 185 samples.
- Original Actions, mesh geometry/UV/weights, rest matrices, material data and authored texture pixels preserved. Three image filepath hashes differ only because Save As rebased relative paths into this subfolder; their original-path-normalized hashes match, including pixel and packed-byte hashes. No unexpected source-data changes.
- The MP4 decodes to 72 frames at 30 FPS, 1280×720; both views use all 24 sequential rendered frames, repeated three times.

Existing Godot compatibility is preserved by leaving the production GLBs, scenes, controllers and source library untouched. This new Action has **not** been exported/imported or tested in Godot; its eventual export must include the established neutral offsets/straight forearms as appropriate. No runtime visual or phone-performance result is implied.

Reproduction scripts: `build_test.py` (fresh source library, refuses existing test/backup), `validate_test.py` (read-only evaluated checks), `package_review.py`, and `encode_review.py`. Rendering runs in the connected foreground Blender through `render(view, start, end)` from the builder. Do not run the builder again over this study file or overwrite its backups.
