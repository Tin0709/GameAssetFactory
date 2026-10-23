# Rig constraints and attachment contracts

This is a preservation guide, not authorization to rebuild a rig. Start from the exact source pinned by the [Animation manifest](../../../blender/animation/showcase/animation_manifest.json), then read its study evidence. The [Showcase rig inspection](../../../blender/animation/blockbench_pipeline_v1/rig_inspection.json) and [original arm audit](../../../blender/animation/reviews/player_animation_library_v1/expressive_arm_motion_test/rig_audit.json) document native transforms, weights and rotation modes. Their historical measurements remain useful; a current source hash match does not replace a fresh native evaluation when editing.

## Keep the correct rig

The player Animation Showcase has **13 bones**: Root, Hips, Spine, Chest, Neck, Head, UpperArm.L/R, ForeArm.L/R, WeaponCarrier and Leg.L/R. Root/Hips/legs use Euler XYZ; the others use quaternion rotation. Its rest signature is `cb913716b708b9f975b350f4a80a57d8244f1903ced498a6b3ce0fc5f8391b2f`. Preserve hierarchy, rest matrices, weights, original Action slots and identity rig-object transform.

The Soldier skin has a separate **10-bone** rig with reseated slim-arm pivots. Older articulated sources also exist; bone names or similar silhouettes do not make these contracts interchangeable. [Soldier validation](../../../blender/characters/player/reviews/survivor_reference_v001/model_validation.json) confirms original non-arm geometry/rest transforms, rigid weights and the explicitly requested slim-arm change. Never transfer those rest-pivot changes into the Showcase to force compatibility.

**No neck means no visible neck geometry. Keep the technical Neck bone.** The head meets the torso. Whole arms and legs remain rigid blocks: no invented elbow, knee or ankle. Current straight-arm authoring retains ForeArm helpers and their weights with identity local pose rather than adding independent forearm articulation. Do not delete helpers merely because the visible arm is continuous.

## Dimensions and support

The measured character is 1.8m tall. Head: .45m cube; torso: .45m wide × .225m deep × .675m tall; each leg: .225 × .225 × .675m. Slim arms are .16875m wide × .225m deep × .675m long, corresponding to 3×12×4 pixels. See the [Blockbench bridge contract](../../../blender/animation/blockbench_pipeline_v1/README.md).

Showcase shoulder rest roots are X±.3375/Z1.35m; hip height .675m; leg roots X±.1125m. Its neutral pose includes 32mm shoulder offsets. Reset the complete pose before binding a partial Action. Contact authoring anchors the actual lowest sole corner/edge and allows rigid rocking; it does not invent a deforming foot. Keep reusable Actions in place and put world travel in physics or a separately identified review carrier.

Original custom work uses unit scales. Do not add rubber scaling unless requested. Existing provenance-bound research Run/Jump scale exceptions are narrowly validated in [the library addon](../../../blender/animation/showcase/gaf_animation_library.py); preserve their authored data without turning those exceptions into a general style rule.

## Weapon frames

Preserve **RightHandGrip, LeftHandGuide, Muzzle, AimReference, RecoilPivot, HolsterAttach**, plus legacy **Grip_Point, Support_Hand_Point, Muzzle_Point**. [Rifle integration notes](../../../blender/weapons/rifle_stylized_v2/godot_integration/README.md) distinguish the actual Chest mount from the static Showcase alternative.

Character previews attach through WeaponCarrier. Blender +Y forward/+Z up converts once to Godot −Z forward/+Y up. Read exact mount, palm and shoulder matrices from the [current runtime profile](../../../game_mobile_3d/scenes/dev/actions_stuff_research/rifle_ready_v001/profile.json). Aim/Recoil use evaluated moving attachments; their first sample is not a substitute for the full curve. Static fit, marker parity and artistic approval do not certify every dynamic contact.
