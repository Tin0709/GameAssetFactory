# Enemy death physics research — Minecraft Dungeons-style rigid mobs

**GameAssetFactory · 18 October 2026 · Research only · Implementation awaits approval**

This document investigates a death system for Android/iOS, starting with our existing straight-limbed Zombie. It contains observations, saved-asset measurements, engineering inferences and proposed experiments. It does not implement a lab, change an animation or establish production readiness.

Evidence labels used throughout:

- **Verified local:** inspected project configuration, source code or saved Blender/GLB data.
- **Verified public:** documented API/source behavior or directly inspected official footage, within the limits stated.
- **Inference:** an engineering conclusion drawn from that evidence; not a claim about Minecraft's internals.
- **Proposal / hypothesis:** a future design or starting parameter requiring approval and testing.

All local paths below are relative to `/Users/tin/Desktop/Game Dev/GameAssetFactory` unless linked otherwise. Public sources were checked on 18 October 2026. Godot engine code links are pinned to the installed build where possible; `/en/4.7/` documentation describes the minor release and can change.

## 1. Executive summary

**Recommendation: test a compact, passive ragdoll with a carefully controlled animation-to-physics handoff, weapon-specific spatial impulses, and an explicit mobile corpse budget.** Begin with Godot's native physical-bone system and seven bodies/six joints on the unchanged native skeleton. Keep full active physical animation as a later option, and plan an original baked-death fallback for crowded or distant cases.

The important findings are:

1. **The existing rig is a good visual fit:** six rigid cuboids, one weight per vertex, no elbows/knees, identity object scale. There is no need to rebuild or segment its visible limbs.
2. **Six visible parts do not imply six native physics bodies.** Legs descend from Hips; Chest is a different descendant of Hips. Native physical joints follow physical *ancestors*. A compact native setup therefore needs a Hips carrier in addition to Chest, Head and four limbs: seven bodies, six joints.
3. **A seamless handoff is the main technical risk.** Current animation includes local translations and a separate Model lunge. Copying bone rotations alone loses motion; copying full transforms alone can still violate fixed joint anchors. Validate the handoff before making the death more dramatic.
4. **The runtime and Blender library are different assets.** The runtime GLB contains legacy Idle/Walk, not the library's Original V1 Actions or the private A&S Attack. The existing visual death is procedural animation, not a ragdoll.
5. **The exact local engine is Godot `4.7.2.stable.official.ed1daf0bf`.** The project leaves its physics backend at `DEFAULT`; exact engine-source inspection suggests GodotPhysics3D for this build. “New projects use Jolt” does not establish this existing project's backend.
6. **Dungeons footage supports the visual target, not an internal implementation claim.** Bodies can end up displaced, rotated and sprawled, followed by cleanup. The inspected Dungeons II montage does not expose enough uninterrupted corpse motion to identify its solver, joints or blending system.
7. **No mobile capacity has been measured.** Suggested Low/Medium/High limits of 2/4/8 active seven-body ragdolls are deliberately modest experiment hypotheses, not achieved performance.

The proposed firearm profiles are our design: Pistol emphasizes destabilization, Rifle emphasizes directional transfer, and Shotgun emphasizes a bounded, distributed pellet response with meaningful off-center torque. They are not claims about firearms or corresponding weapon classes in Minecraft Dungeons.

## 2. Visual motion study and evidence limits

### 2.1 What was actually inspected

Official YouTube gameplay was inspected in the browser, including muted quarter-speed playback and paused frame stepping for the first game. No remote footage was downloaded, extracted into production assets or used to create new animations. Timestamp windows are navigation aids, not measured gameplay event frames.

| Reference | Inspected window | Defensible observation | Limit |
|---|---|---|---|
| [Xbox: Minecraft Dungeons Official Gameplay Demo, X019 Extended Cut](https://www.youtube.com/watch?v=qF2ExS8iDqc&t=194s), published 21 November 2019 | Approximately 03:14–03:26 | Ranged combat, damage flashes and fallen humanoid shapes are visible. Some corpses have poses/orientations different from the standing combat pose. | This is a prerelease co-op demonstration. Effects and other actors obscure individual events; a bright damage flash is not proof of a kill. A white target in this window appears to be a sheep and is not counted as verified enemy-death evidence. |
| [Same official developer demo](https://www.youtube.com/watch?v=qF2ExS8iDqc&t=521s) | Approximately 08:41–08:48, frame-stepped | Multiple bodies lie around the combatants. Around 08:42.15 a creeper near P1 is upright; by approximately 08:42.65–08:43.65 its silhouette is displaced and horizontal. Other fallen shapes later fade/disappear while combat continues. | A creeper is a useful whole-body orientation example, not evidence of loose humanoid arms. Melee, enchantments and explosions overlap; individual impulse magnitude and ground-contact details cannot be isolated. |
| [Minecraft: Dungeons II Official Gameplay Trailer](https://www.youtube.com/watch?v=vBNE3bKMpu8&t=47s), published 20 August 2026 | Approximately 00:47–00:49 | The gear interface cuts into area-effect combat. | Not an uninterrupted death-to-settle sequence. |
| [Same official Dungeons II trailer](https://www.youtube.com/watch?v=vBNE3bKMpu8&t=56s) | Approximately 00:56.5–00:58.5 | Crowd combat, strong impact effects and changing enemy silhouettes are visible. | Effects, hard cuts and brief shots prevent reliable identification of individual lethal hits, joint motion, corpse trajectories or settling. No internal physics claim follows. |

The Dungeons II video's provenance is corroborated by the [official Minecraft gameplay-trailer article](https://www.minecraft.net/ru-ru/article/minecraft-dungeons-ii-gameplay-trailer). The [official Dungeons development article](https://www.minecraft.net/de-de/article/the-road-dungeons) discusses importing environments into Unreal. That establishes an engine-related fact about the first game; it does **not** identify the death controller, physics backend, solver settings or any particular Unreal physical-animation feature.

### 2.2 Visual principles worth reproducing

**Inference from the inspected motion:** the feeling depends on a readable change from intentional locomotion to an uncontrolled trajectory, a body orientation that responds to the hit, varied resting silhouettes, and cleanup that does not interrupt combat readability. Persistent upright locomotion while sliding away would miss that target.

**User-specified targets, not findings proven by these clips:** delayed loose limbs, convincing rotational collapse, stable landings, and distinctly different Pistol/Rifle/Shotgun responses. The available montage does not justify numerical claims about limb lag or a universal tumble duration.

The strongest future visual test is an isolated kill with a visible target before impact, through loss of support, first ground contact and settling. Review front/side/three-quarter views of *our lab*, while retaining the actual gameplay reference as a visual target. Do not infer a 3D contact location or physical impulse from a single isometric projection.

### 2.3 What remains unverified

There is no verified evidence here that either game uses full passive ragdolls for every enemy, animation blending for a specific number of milliseconds, motors/PD control, a particular constraint graph, or weapon-to-mass impulse values. Procedural animation, partial simulation, authored transitions and baked results can resemble one another in edited footage.

A further controlled-footage session should record humanoid deaths from front/side/rear hits, ordinary versus heavy weapons, flat ground versus stairs, and repeated identical situations. Log game/build, enemy, weapon/enchantments, hit location and direction. Keep source footage and observed facts separate from inferred implementation. No Original V1 versus A&S comparison study is needed.

## 3. Technique analysis

| Technique | What it provides | Main limitation for this project | Assessment |
|---|---|---|---|
| Full passive ragdoll | Gravity, contact-driven falls, loose rigid limbs and variable landings | Initialization, limits, contact stability and active-body cost; dramatic motion is not guaranteed by enabling physics | Best first physical baseline after handoff validation |
| Animation-to-ragdoll hybrid | Preserves the current pose and inherited motion before releasing control; can optionally include an original impact beat | A fixed authored entry pose can snap; late release can feel unresponsive | Recommended architecture: immediate pose capture, then release; optional impact beat only after comparison in the lab |
| Partial ragdoll | Simulates selected limbs while other motion remains controlled | Kinematic parents can inject energy; split ownership and collider/visual mismatch require care | A later experiment, not necessary for the first death baseline |
| Active physical animation | Motors/forces try to follow animation while allowing physical displacement | Additional target-pose controller, gain tuning, solver work and stability risks | Defer unless passive/hybrid results cannot meet the brief |
| Procedural impulses and torque | Makes direction, hit point and weapon identity matter | Repeated impulses, bad units or double-counted torque produce explosions or spinning | Required input to the proposed passive ragdoll, not a complete death system alone |
| Pre-baked ragdoll clips | Low runtime simulation cost and predictable silhouettes | Limited terrain adaptation, input variation and entry-pose compatibility | Useful future fallback, generated entirely from our own approved experiment/rig |
| One-body corpse proxy | Very low joint cost; body can move/collide as a whole | Limbs are not physically loose | Emergency/distant fallback, with an original collapsed/baked visual pose |

Godot documents native physical bones, partial simulation, joint configuration and collision exceptions in the [ragdoll tutorial](https://docs.godotengine.org/en/stable/tutorials/physics/ragdoll_system.html). The tutorial's elbow/knee suggestions apply to articulated rigs; our limbs must remain single rigid segments.

**Important distinction:** `PhysicalBoneSimulator3D.influence` is inherited skeleton-pose blending. It does not apply motors that drive physical bodies toward an animation. At intermediate influence, the rendered pose can differ from the physical collider pose. Use full influence for the first collision-fidelity baseline; treat any visual fade as a separate experiment, not an automatic cure for snapping. See [SkeletonModifier3D](https://docs.godotengine.org/en/4.7/classes/class_skeletonmodifier3d.html) and the [installed-build modifier implementation](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/scene/3d/skeleton_3d.cpp#L1085-L1134).

Unreal's [physics-driven animation overview](https://dev.epicgames.com/documentation/unreal-engine/physics-driven-animation-in-unreal-engine) is a useful architectural reference for combining animation and simulation. Its [Physical Animation Component/profile example](https://dev.epicgames.com/documentation/en-us/unreal-engine/applying-a-physical-animation-profile-in-unreal-engine) illustrates additional control beyond passive simulation. Those components and Blueprint nodes are not Godot APIs, and the article is not proof that Minecraft Dungeons uses them.

## 4. Weapon death design — proposed experiments

### 4.1 Shared physical inputs

A lethal-hit payload should distinguish damage from presentation: hit point in world space, incoming shot direction, hit body/region, weapon profile, distance, any pellet group, event ID and source actor velocity. Damage magnitude alone should not determine the physical response.

Conceptually, a positioned impulse contributes linear momentum `J` and angular momentum `(hit_position − center_of_mass) × J`. A centered hit can produce substantial translation with little yaw; an off-center hit naturally changes rotation. Avoid adding the same lever-arm torque again as an independent “spin” term. Any extra angular impulse is an explicitly art-directed component with a cap.

For a selected `PhysicalBone3D`, the documented position argument to `apply_impulse()` is **`hit_world − body.global_position` in global axes**, not an absolute world position or a bone-local point. Apply an impulse once, not once per render/physics frame. The node has `apply_impulse()` and `apply_central_impulse()`; do not assume it has every `RigidBody3D` method. These are [verified 4.7 API conventions](https://docs.godotengine.org/en/4.7/classes/class_physicalbone3d.html).

For a separate angular impulse, the future native adapter can use `PhysicsDirectBodyState3D.apply_torque_impulse()` during `_integrate_forces`, or the corresponding RID operation on `PhysicsServer3D`; a custom `RigidBody3D` proxy has its own torque API. This distinction matters for a functional lab slider. See [direct body state](https://docs.godotengine.org/en/4.7/classes/class_physicsdirectbodystate3d.html) and [physics server impulse operations](https://docs.godotengine.org/en/4.7/classes/class_physicsserver3d.html#class-physicsserver3d-method-body-apply-torque-impulse).

### 4.2 Three profiles with distinct structure

| Profile | Response structure to investigate | Rotation and loose-limb behavior | Controls preventing exaggeration |
|---|---|---|---|
| **Pistol — Light** | Small upper-body disturbance, loss of balance, then gravity-driven toppling. Begin from the actual support/stride pose. | Modest pitch/roll; arm motion follows torso acceleration instead of a scripted windmill. Rigid legs rotate at hips. | Low horizontal impulse and no mandatory upward launch. Test that a nearly balanced passive body actually falls rather than remaining standing. A small off-center destabilizing impulse is a design option. |
| **Rifle — Medium/Strong** | More concentrated directional momentum at the hit region, transferred through torso/pelvis and joints. | Shoulder/chest hits yield different roll/yaw from centered hits. Existing swing and stride velocity remain visible in the fall. | Cap total momentum and angular speed. A normal centered rifle hit must not always perform a full spin. |
| **Shotgun — Heavy** | Aggregate the pellet pattern into a bounded spatial response: distributed torso impulses, a center of pressure and genuine off-center torque. Close-range coverage can disrupt support differently from a distant sparse pattern. | Wider shoulder/hip motion results from torso acceleration and constraint freedom. Backward travel or a rotational collapse depends on hit geometry, not a universal launch animation. | One kill event, one bounded impulse budget. Distance/coverage affects coupling and distribution; do not give every pellet a full-shot impulse or require spin for a symmetric centered pattern. |

These profiles should share a physical setup initially. Otherwise changed friction/joints could hide whether the weapon inputs themselves are meaningfully different. Only after that baseline should weapon-specific damping or a short original impact phase be investigated.

**Numerical hypotheses for an initial sweep, not calibrated ballistics or measured game values:** use a 60 kg total proxy mass and test whole-ragdoll added center-of-mass speed bands of approximately 0.15–0.35 m/s for Pistol, 0.35–0.90 m/s for Rifle, and 0.8–1.8 m/s for a close Shotgun hit. Their total linear-impulse budgets are approximately 9–21, 21–54 and 48–108 N·s respectively, before inherited motion. Applying that entire budget to one light arm would be a very different experiment; specify body distribution and measure actual motion.

Start without a forced upward kick. Add a separately capped vertical component only if the heavy-hit study requires it and ground interaction remains convincing. The target is readable, coherent force, not a physically unsupported promise that a real bullet launches a human-sized body.

### 4.3 Shotgun pellet aggregation

For each connected pellet `k`, retain its hit point, incoming direction and a bounded share `J_k` of the shot's total physical budget. Then investigate:

- Total linear impulse: `J_total = Σ J_k`.
- Total angular impulse about the ragdoll center of mass: `L_total = Σ ((hit_k − COM) × J_k)`.
- A weighted center of pressure for UI/debugging; this alone may not reproduce every distributed torque.
- Per-body distribution whose total momentum remains consistent with the shot-level cap. Do not apply `J_total` at the torso and then apply all pellet impulses again.
- Smooth distance/coverage coupling. Fewer connecting pellets or greater range generally reduce coupling in our proposed model, rather than creating random unlimited spin.
- A centered, symmetric pattern as a required cancellation test: its yaw contributions should largely cancel. An off-center pattern should produce a coherent rotational sign.

A constrained body system redistributes momentum, and multiple hit locations do not guarantee an identical trajectory across backends. If clamping linear or angular budgets, clamp the stored physical response coherently and record the change. Do not treat damage points, kinetic energy, impulse and angular velocity as interchangeable units.

## 5. Current Zombie rig and asset assessment

### 5.1 Authoritative saved library inventory

The saved `mobs_registry` and actual Action datablocks were read from [Mobs_Animation_Library.blend](</Users/tin/Desktop/Game Dev/GameAssetFactory/blender/animation/showcase/Mobs_Animation_Library.blend>). There are five real Actions and one findings entry.

| Entry | Actual animation? | Saved status | Role and restrictions |
|---|---|---|---|
| `Zombie_Idle_Original_V1` | Yes; 4.0 s, 30 FPS | Pending | Our original production candidate; not artistically approved or gameplay-validated merely because it is original |
| `Zombie_Walk_Original_V1` | Yes; 1.4 s, 30 FPS | Pending | Our original production candidate; same qualification |
| `Zombie_Idle_ActionsStuff_Source_Test_v001` / “Idle / A&S source v001” | Yes; 3.6 s | Pending | Third-party source-derived private reference; `research_only=true`, `production_allowed=false` |
| `Zombie_Walk_ActionsStuff_Source_Test_v001` / “Walk / A&S source v001” | Yes; 18 s complete layered loop, 0.75 s stride | Pending | Same reference-only restrictions, regardless of its review status |
| `Zombie_Attack_Player_A&S_Reference_v001` / “Attack / A&S reference” | Yes; 0.75 s, exact endpoint F23.5 at 30 FPS | Reference Only | Verified source reconstruction for private study; not a production Attack asset |
| Zombie Hurt / Hit Reaction — findings | **No** | No Source Clip | A report entry with an empty Action binding, not a Hurt animation |

There is no Death Action in this library. Original Action curve fingerprints match the separate `mobs_library/originals/Mobs_Animation_Library_Original_V1.blend` archive. The reference rig/collection remains separate from the native original rig. Proprietary source-derived motion must not enter production exports or the future Godot lab without an appropriate rights/authorization decision. Changing a review status does not establish reuse rights.

**Verified local runtime distinction:** `game_mobile_3d/assets/characters/zombie_animation_v2.glb` contains legacy `Zombie_Idle` (3 s) and `Zombie_Walk` (1.6 s). It contains none of the newer library Actions and no Attack/Hurt/Death clip. The runtime Attack and current death are procedural code behavior. Do not mistake the newer Blender library's approval state for the runtime's content.

### 5.2 Skeleton, proportions and rigid pieces

Native hierarchy, without altering it:

```text
Root                         utility; no rendered mass
└── Hips                     utility; legs attach here
    ├── Spine                utility
    │   └── Chest            one rigid torso block
    │       ├── Neck         utility
    │       │   └── Head
    │       ├── Arm.L        whole straight arm
    │       └── Arm.R        whole straight arm
    ├── Leg.L                whole straight leg
    └── Leg.R                whole straight leg
```

The native rig has 10 bones. A separate 11-bone research copy adds unskinned `Reference_RightItem` beneath `Arm.R`; it is not a body part to simulate for the unarmed production character.

Saved Blender measurements, in metres with **Z up**:

| Part | Dimensions | Rest center / articulation landmark |
|---|---|---|
| Entire character | 0.90 wide × 0.45 deep × 1.80 tall | Sole plane Z=0 |
| Head | 0.45 × 0.45 × 0.45 | Center Z=1.575; head joint Z=1.35 |
| Torso | 0.45 × 0.225 × 0.675 | Center Z=1.0125; weighted entirely to Chest |
| Each arm | 0.225 × 0.225 × 0.675 | Shoulder X=±0.3375, Z=1.35 |
| Each leg | 0.225 × 0.225 × 0.675 | Hip X=±0.1125, Z=0.675 |

The mesh has 48 authoring vertices, 72 triangles and six disconnected cuboids, all vertices weighted to exactly one bone at weight 1. The GLB has 144 render vertices after splitting for rendering. Both rig objects have identity transforms, XYZ pose rotation modes, no constraints/drivers and no NLA tracks in the inspected file. Godot's imported data is **Y up**: use its actual bone/rest transforms, not a hand-written reuse of Blender coordinates or Euler axes.

**Inference:** this is suitable for rigid-body death. Whole arms and legs can rotate loosely at shoulders/hips while remaining block-shaped. It cannot produce an anatomical kneeling/crumpling fall without changing the artistic constraint; aim for toppling, hip splay, arm lag and torso/head rotation instead.

### 5.3 Native topology and non-destructive adaptations

Godot searches up the skeleton hierarchy for a physical parent. With bodies only on Chest/Head/arms/legs, each leg has no physical ancestor: Chest is not its ancestor. This is confirmed in the [installed simulator's parent search](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/scene/3d/physics/physical_bone_simulator_3d.cpp#L154-L178); a missing physical parent means [no corresponding joint](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/scene/3d/physics/physical_bone_3d.cpp#L847-L869).

**Proposed native graph:** Hips, Chest, Head, Arm.L/R and Leg.L/R; joints Chest→Hips, Head/arms→Chest, legs→Hips. Root, Spine, Neck and the item helper remain nonphysical. The invisible Hips carrier needs sensible mass/inertia and an explicitly validated primitive/offset, not an almost massless point. Its shape must not create an artificial protruding pelvis or harmful duplicate contacts inside the single torso block. Native connectivity also does not guarantee an ideal waist pivot: the Chest bone origin is Z=1.06875, while the hip sockets are Z=0.675. Inspect the resulting native joint frames against the geometry; body-offset tuning alone cannot freely relocate a bone-constrained anchor. Visible torso/leg separation or unsuitable rotation about that anchor is a reason to evaluate an explicit proxy graph.

This requires adding physics nodes/configuration in a future isolated Godot wrapper, not adding elbows/knees, repainting weights or changing the Blender hierarchy. A custom six-`RigidBody3D` proxy can connect limbs explicitly and map the result to the original skeleton, but that adds application-owned joint, pose and lifecycle code. It is the fallback architecture if the native carrier/anchor restrictions prove unsuitable.

### 5.4 Pose compatibility findings

All actual authored/bake key times were evaluated per Action solely for handoff compatibility, without an animation-comparison study. Measured basis-scale deviations were at most approximately `5.96×10⁻⁸`, consistent with floating-point noise rather than animated scaling.

There are significant **translations**, however. Source Attack shoulder basis translations reach roughly 0.15–0.17 m in some bone-local components. Source Walk's Chest-relative-to-Hips local-up component ranges approximately 0.101–0.489 m, versus a rest value of 0.394 m. These are local-axis saved-pose measurements, not observed world travel or runtime benchmarks. Even our original clips use some local translation, so joint compatibility is a general validation requirement rather than something to infer from the absence of scale.

A full transform match and a valid rigid constraint graph are separate conditions. For fixed anchors, the parent and child world anchor positions must coincide. Animated translations can violate that condition even if every body initially matches its visible part. A solver then corrects the error, potentially producing an apparent snap or burst.

**Proposed remedies to investigate:** verify compatible entry poses first; define a physical proxy/anchor policy for translated poses; if necessary project into a constraint-valid pose with a small, explicitly measured visual correction. A custom proxy can offer more anchor control. Do not promise that simply increasing solver iterations preserves arbitrary animated offsets. The native joint offset is constrained by its bone/body mapping, so it is not an unrestricted anchor-editing interface.

### 5.5 Existing death path and specific risks

The existing `CuboidZombie.tscn` uses a CharacterBody3D capsule (radius 0.30 m, height 1.80 m, center Y=0.9), collision layer value 4 and mask value 7. There are no corpse physics bodies/joints in that scene.

`cuboid_zombie.gd:68–79` currently zeroes velocity, stops physics, removes collision and freezes animation before beginning the visual death. `zombie_animation_secondary.gd:118–180` captures local positions/quaternions, chooses one of six directional variants and produces a procedural root fall plus launch/lift/rebound. Its corner correction assumes a global Y=0 floor; it is not a terrain-contact solver. Nominal cleanup is 0.62+0.45=1.07 seconds.

Relevant risks for a future replacement, **not fixes performed in this research**:

- `cuboid_animation.gd:77` resets `Model.position` during `freeze_animation()`. The procedural Attack uses a Model lunge spanning approximately −0.045 to +0.19 m. Capturing after that reset can lose the visible position.
- Current capture does not retain per-body velocities or scale; actor velocity has already been zeroed.
- CharacterBody motion uses fixed physics timing; the manual animation/secondary path runs in render `_process`. A physics handoff needs an explicit sampling/order contract.
- The current corpse/EXP/smoke callbacks assume existing root/Chest locations. Future integration must deliberately choose the physical corpse/impact position rather than silently retaining a stale CharacterBody origin.

## 6. Godot implementation architecture proposal — no implementation

### 6.1 Exact engine and backend evidence

Verified local launcher: `/Applications/Godot.app/Contents/MacOS/Godot`.

- Version: **`4.7.2.stable.official.ed1daf0bf`**.
- Full commit: `ed1daf0bf001b61586d9930840f2f1394092c079`.
- `project.godot` features: `4.7`, `Mobile`; renderer explicitly `mobile`; main scene remains `WorldMap`.
- No project physics/backend/tick override was found. Same-binary standalone defaults report **60 physics ticks/s**, gravity **9.8**, max 8 physics steps/frame, interpolation off and a separate physics thread off. The existing Zombie CharacterBody explicitly uses gravity **18**, so death could otherwise introduce a gravity change.
- Backend setting: **`DEFAULT`**. The generic runtime server wrapper did not identify an effective backend. Exact build source [registers GodotPhysics3D as the manager default](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/modules/godot_physics_3d/register_types.cpp#L48-L54), [registers Jolt without that default assignment](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/modules/jolt_physics/register_types.cpp#L49-L57), and [falls back to the manager default at startup](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/main/main.cpp#L337-L345). **Inference: this configuration is expected to select GodotPhysics3D, not proven measured Jolt.**

The [4.7 Jolt guide](https://docs.godotengine.org/en/4.7/tutorials/physics/using_jolt_physics.html) discusses new-project defaults and backend-specific differences. Do not silently switch this existing project. A backend choice/comparison belongs in an approved isolated lab; its result requires a restart and recorded configuration.

For gravity continuity, separately test global 9.8 and the current actor's 18 m/s² equivalent. A ragdoll gravity scale of approximately 18/9.8 is one *proposal* for matching the existing actor, not an already selected setting. Areas or later project overrides require reading the actual effective gravity.

### 6.2 Responsibilities and single ownership

| Component | Proposed responsibility | Explicit boundary |
|---|---|---|
| Pose source | Produces current original Idle/Walk/procedural Attack pose and two fixed-time samples | Stops writing simulated bones after the handoff |
| Death coordinator | Accepts one lethal event, captures state, transfers ownership, selects a response/profile and corpse budget | Does not call the existing reset-before-capture death sequence |
| Ragdoll adapter | Bone/body mapping, shape offsets, limits, initial velocities, one-time impulses and final-pose capture | Only physics writes the simulated bones while active |
| Corpse budget manager | Admission, settling, parking, removal and pool reset | Does not alter living AI movement or production camera behavior |
| Lab UI/telemetry | Replays controlled trials and records configuration/results | No production integration or rights-restricted Action imports |

`AnimationTree` is optional for selecting/blending authored states; current animation is not automatically an AnimationTree architecture. Godot's [AnimationTree tutorial](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html) and [AnimationMixer timing controls](https://docs.godotengine.org/en/4.7/classes/class_animationmixer.html) help define a future pose source, but adopting them would be a separately reviewed change, not a prerequisite to this research.

### 6.3 Pose-to-body mapping and velocity continuity

Godot's bone “global pose” is relative to the **Skeleton3D**, not world space. Let `S` be skeleton world transform, `P_i` the current skeleton-space bone global pose, and `O_i` the authored body offset. The intended body world transform is:

`B_i = S × P_i × O_i`

The offset places a collider at the rigid piece's center, not necessarily the bone origin. Its inverse is also needed when mapping physics back. The [installed PhysicalBone3D mapping](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/scene/3d/physics/physical_bone_3d.cpp#L92-L100) and [Skeleton3D documentation](https://docs.godotengine.org/en/4.7/classes/class_skeleton3d.html) establish the coordinate conventions.

**Proposed velocity sampling:** keep two consecutive *body-world* transforms at fixed physics times. Approximate linear velocity from the change in body-center position divided by the actual sample interval. Obtain angular velocity from the shortest-arc world quaternion delta divided by that interval. Here COM means a **world-space point**. If the transform origin is not that center of mass, include `ω × (COM_world − origin_world)` when converting velocity. In `PhysicsDirectBodyState3D`, `center_of_mass` is an offset in global axes, so `COM_world = state.transform.origin + state.center_of_mass`; it is not already an absolute world point. Prefer centered primitive shapes to simplify that mapping.

World samples already include actor motion: do not add CharacterBody velocity again. Reject teleport/reset samples and clamp clearly excessive animation-derived speeds under an explicit profile policy. Starting physics does not itself prove that useful limb velocity has been transferred.

### 6.4 Proposed atomic handoff

1. Queue a lethal event once, preserving hit point/direction and the pre-zero actor velocity. Resolve same-shot pellet hits into that single event.
2. At a defined physics boundary, evaluate/sample the current pose, including full local PRS, Model offset and Skeleton world transform. Capture before resetting any animation/controller state.
3. Resolve body transforms and joint compatibility. Keep the current visible pose held while switching ownership; do not route through RESET or a default T-pose.
4. Disable AI/steering, CharacterBody movement and its upright collision capsule/hitboxes in a physics-safe sequence. The capsule must not fight the corpse; collision changes must not leave an unintended visible reset frame.
5. Begin the correctly mapped native simulation and seed per-body linear/angular velocities once before applying the lethal impact. The installed [simulator refreshes current cached skeleton poses on start](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/scene/3d/physics/physical_bone_simulator_3d.cpp#L260-L286); it does not justify starting from a reset pose or ignoring joint validity.
6. Apply the bounded weapon response once. Do not continue overwriting those body transforms every tick.
7. Let physics own the simulated bones. Start with influence 1.0; evaluate a short visual influence ramp only as a separate collider/mesh mismatch test.
8. Capture the settled visible pose at the correct modifier stage, then park/remove according to budget. Reset all ownership, collision and motion history before pool reuse.

Native physical bodies become top-level for simulation, but the actor/skeleton transform still matters to pose mapping. Stop moving a corpse with its former CharacterBody. Test translated/rotated parents and non-origin spawn points; using a single world origin in the lab would hide root errors.

Skeleton modifiers run after animation and have processing/signaling rules. Sample source animation at the intended pre-physics stage; sample the final *visible* corpse pose at `skeleton_updated`/the relevant modifier signal, not an arbitrary later bone read. The [installed source restores unmodified poses after skin updating](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/scene/3d/skeleton_3d.cpp#L328-L388). Merely setting multiple callbacks to “physics” does not prove the required order.

### 6.5 Death during different states

| Lethal starting state | Motion to preserve | Specific risk / planned test |
|---|---|---|
| Idle | Current asymmetry, head/arm pose and small existing motion | Tiny impulse can leave an exactly balanced passive body upright; test support loss without a large shove |
| Walk | Stride phase, world travel, swing-leg velocities and current support | Zeroed actor velocity, frozen feet, floor penetration or doubled travel; sample both lead feet and support transitions |
| Attack | In the existing original runtime: live Idle/secondary pose plus the procedural Model lunge. A future separately authorized original Attack must also preserve its own authored arm motion. | Resetting Model offset; confusing private A&S swinging-arm/shoulder motion with the current original runtime Attack; later original translations or angular limits may require proxy adaptation |
| Jump / upward motion | Vertical and horizontal velocity plus current pose | Ground snapping or flattening velocity during handoff; use synthetic airborne lab states because no Zombie Jump Action is registered |
| Falling / ledge | Downward velocity and orientation; environment-relative position | Reusing the old Y=0 correction, preventing the fall, or freezing an airborne corpse |

For Attack testing in Godot, use our existing original runtime procedural Attack or a separately authorized original replacement. The private A&S Attack remains a Blender reference. The lab must not silently use it as a reusable production animation.

### 6.6 Shapes, mass, constraints and collision policy

**Proposal:** begin with simple boxes close to the six rendered blocks, slightly inset where needed; compare round-ended primitives only if box corners produce unacceptable snagging. Use primitive dynamic shapes, not a concave mesh copied from the visual model. See [Godot's collision-shape guidance](https://docs.godotengine.org/en/4.7/tutorials/physics/collision_shapes_3d.html).

A hypothetical 60 kg distribution is Hips 8, Chest 22, Head 8, arms 4 each and legs 7 each. This is an art-directed proxy, not density inferred from block volume or a Minecraft measurement. The head's large visual volume is not a reason to make it dominate the body's mass. Validate Hips inertia/collider support instead of assigning negligible mass because it is invisible.

Start shoulder/hip/neck constraints with bounded cone/twist motion and a tighter torso-to-Hips articulation. Do not add elbow/knee joints or leave every connection as an unrestricted pin. A parameter sweep might begin with shoulder swing around 45–70°, hip 30–50°, neck 15–25° and a restrained torso carrier range. These are **unvalidated starting hypotheses**; joint-frame orientation, permitted swing/twist spans and pose compatibility come first. Native cone spans are not independent signed asymmetric limits; test another supported joint/controller only if that additional behavior is required. Keep body damping moderate, restitution near zero, and measure contact stability before raising solver cost.

Use a lab-specific collision matrix rather than copying numeric production masks:

- Corpses collide with static terrain/approved platforms.
- Initially disable corpse self-collision and corpse–corpse collision; explicitly exclude the owning live capsule.
- Players/live enemies need not be physically blocked by corpses. Visual overlap is a deliberate quality/performance tradeoff to review.
- Lethal hit detection and corpse collision are separate roles. Dead bodies should not repeatedly consume damage or AI targets.
- Do not rebuild navigation geometry per corpse. Remove dead AI/avoidance participation if present; use a simple temporary obstacle only if later gameplay requires it.

Jolt and GodotPhysics do not support every joint softness/damping parameter identically. The [Jolt differences guide](https://docs.godotengine.org/en/4.7/tutorials/physics/using_jolt_physics.html#joint-properties) lists unsupported soft-limit controls. Do not promise that a backend switch retains the same tuning. Backend contact impulse estimates are also not an authoritative measure of weapon damage.

### 6.7 Known practical issues and lifecycle traps

| Evidence | What it actually establishes | Lab consequence |
|---|---|---|
| [Godot issue #101823](https://github.com/godotengine/godot/issues/101823), open when checked | An interpolation/ragdoll report originating in 4.4 beta1; the reporter corrected its backend from Jolt to GodotPhysics. It does not prove all 4.7.2 ragdolls fail. | Test interpolation off/on, moving parents and low-TPS diagnostic playback on the installed engine. |
| [Issue #95679](https://github.com/godotengine/godot/issues/95679), closed through #96270 with a 4.4 milestone | Historical scaling behavior, not an unresolved universal 4.7 blocker | Retain unit-scale physics hierarchies; validate any variant/model scaling path. |
| [Issue #121207](https://github.com/godotengine/godot/issues/121207), open when checked | A specific slider-parameter forwarding report against a 2026 source build | Do not generalize it to cone constraints; avoid a slider-heavy first design. |
| PhysicalBone3D and RigidBody3D have different public properties | Native PhysicalBone3D supports `can_sleep`, velocities and `_integrate_forces`; it does not inherit the node-level `freeze` property | Use a native lifecycle adapter; do not paste `rigid_body.freeze=true` onto a PhysicalBone. |
| Stop simulation is not “freeze the final skin pose” | Simulation/modifier state and animation pose state are distinct | Capture the final evaluated pose, stop bodies, retain the captured pose and remove unnecessary collisions/process work deliberately. |

`PhysicsDirectBodyState3D` exposes sleeping state and torque operations inside its callback. `RigidBody3D` exposes its own [sleep/freeze modes](https://docs.godotengine.org/en/4.7/classes/class_rigidbody3d.html). Disabling only the simulator's modifier `active` flag is not a reliable substitute for stopping physical simulation. Conversely, stopping alone can reveal the underlying animation/default pose. Validate parking and pooling as visible transitions.

## 7. Mobile optimization and scalable budgets

### 7.1 Initial budget hypotheses

The target remains mobile-first 30 FPS; minimum Android/iPhone devices have not been specified. A 30 FPS display frame is 33.33 ms, not a budget available entirely to ragdolls. Current physics is 60 ticks/s: evaluate that baseline before increasing global TPS or solver iterations. Godot warns that higher tick rates increase CPU cost in [physics troubleshooting](https://docs.godotengine.org/en/4.7/tutorials/physics/troubleshooting_physics_issues.html).

Every value in this table is an **initial experiment proposal, not a demonstrated capacity or selected production quality setting**:

| Quality experiment | Maximum actively simulating native corpses | Body / joint bookkeeping at cap | Suggested priority/lifetime experiments |
|---|---:|---:|---|
| Low | 2 | 14 bodies / 12 joints | Keep the nearest important kills physical; investigate roughly 1 s active windows and 2–3 s total visible retention |
| Medium | 4 | 28 bodies / 24 joints | Investigate roughly 1.5 s active windows and 3–5 s visible retention |
| High | 8 | 56 bodies / 48 joints | Investigate roughly 2 s active windows and 4–6 s visible retention |

These counts exclude living actors, terrain contacts, hit shapes and any fallback body. Costs are not necessarily linear with body count: contacts, constraints, island composition and script/render work matter. An active-window expiry must not visibly freeze a body midair; defer parking until supported/settled, select a safe fallback, or fade/remove according to an explicitly reviewed policy. Count sleeping retained corpses separately from active simulation.

A provisional investigation ceiling could be 1–2 ms **additional** p95 physics CPU time per displayed frame for deaths on a selected target device. That is a planning hypothesis, not a benchmark result or a guaranteed share of 33.33 ms. Accept/revise it only after measuring the rest of the game and burst costs.

### 7.2 Main optimization levers

1. **Reduce simulated work:** seven compact bodies, simple shapes, no self-collision initially, no corpse–corpse contacts and no unnecessary per-contact reporting.
2. **Prioritize perceptually:** reserve simulation for nearby visible lethal hits, especially an important Shotgun kill. Make admission decisions before spawning physics work; do not let all deaths simulate first and trim later.
3. **Sleep or park settled corpses:** sleeping retains bodies and can be broken by contacts. Pose-only parking removes more ongoing work but needs correct final-pose capture and collision policy.
4. **Bound corpse retention:** enforce separate active-body, retained-corpse and memory caps; remove/recycle old off-screen corpses before they accumulate indefinitely.
5. **Pool deliberately:** preallocate a small bounded pool, reset velocities, layers/masks, AI flags, animation parameters, hit IDs, joint/body state and interpolation history on reuse. Pooling reduces allocation bursts but does not make active physics free.
6. **Use original fallbacks:** a future original baked-death bank for distant/over-budget cases; a one-body proxy where some terrain reaction is more valuable than loose limbs. These fallbacks do not exist as new assets today and require later approval/authoring.
7. **Avoid expensive universal solutions:** full active ragdoll motors, whole-crowd self-collision, raising global TPS, and large iteration increases are not the starting point.

Baked deaths need entry-pose and terrain policies too. A flat-ground clip cannot guarantee feet/hands align with stairs. Root placement/tilt is only an approximation; prefer a physical fallback or safe cleanup on unsupported terrain. Never generate production baked clips from private A&S data.

For distance-based detail, prefer admission/parking/baked representation changes over simulating selected bodies at inconsistent ad hoc tick rates. Connected bodies must use a coherent physics step. Change quality outside the most visible part of the fall and avoid repeated threshold toggling.

### 7.3 Required device measurements

Use exported Android/iOS builds on agreed Low/Medium/High devices, with release performance runs and debug diagnostic runs kept separate. Record engine build, backend, renderer, physics TPS, interpolation, resolution, device/OS, thermal state and scene population.

Measure a live-enemy baseline, single deaths, 2/4/8/16 simultaneous deaths, repeated waves and a sustained corpse/pool soak. Capture p50/p95/p99 display-frame time, physics cost per tick and per displayed frame, CPU/GPU distinction, allocation/pool spikes, active/sleeping bodies, collision pairs, joint counts and memory. Warm up shaders and also measure a cold first-death case. Recheck under thermal throttling rather than treating a short desktop editor run as mobile evidence.

[Performance monitors](https://docs.godotengine.org/en/4.7/classes/class_performance.html) and [PhysicsServer3D process information](https://docs.godotengine.org/en/4.7/classes/class_physicsserver3d.html) can support telemetry, but some monitors are debug-only or delayed. Maintain application-owned ragdoll/body/joint counts, and use device-native CPU/GPU profiling and appropriately sampled timing for release-frame distributions. Seeded variation and fixed TPS do not guarantee identical cross-device trajectories; see [Jolt's determinism/sleeping discussion](https://jrouwe.github.io/JoltPhysics/index.html).

## 8. Future Godot Death Physics Lab design — not created

### 8.1 Isolation

**Proposed location, after approval:** a separate small Godot project at `experiments/godot_death_physics_lab/`, containing its own lab scene and settings. Keeping it outside `game_mobile_3d/res://` prevents automatic dependence on production main scenes, autoloads and export content, and allows backend experiments without changing WorldMap's project settings.

Reuse only verified original character geometry/texture/animation sources through a small provenance/hash manifest. Do not load the mixed proprietary reference library as an animation-export source. Keep the existing rig and `.blend` files read-only; any physics definitions are new lab-side nodes/resources. If Original V1 clips need a new preview export, that is part of a later explicitly approved lab task, not work performed now. Their Pending status remains Pending.

If a scene inside the production project is preferred later, run it manually with F6 and explicitly exclude its subtree from production export. That alternative still cannot safely compare physics backends per scene; backend selection is project-level.

### 8.2 Proposed scene responsibilities

```text
DeathPhysicsLab (Node3D)
├── TestEnvironment                 ground, ramp, steps, wall, ledge presets
├── StableCameraRig                 front / side / three-quarter presets
├── LabActors                       original Zombie visuals only
│   └── LabZombie
│       ├── ControlledPoseSource    original Idle/Walk/procedural Attack adapter
│       ├── Skeleton3D
│       │   └── PhysicalBoneSimulator3D
│       │       └── 7 physical bodies / 6 joints
│       └── LabDeathCoordinator     pose/velocity capture and ownership
├── TrialController                 seed, reset, batch, stepping and hit payload
├── CorpseBudgetManager             admission, parking and bounded pool
└── CanvasLayer                     controls, plots/counters and trial record
```

This is a responsibility sketch, not a `.tscn` file or a claim that imported Skeleton3D paths are already known to the lab. A future adapter must bind the actual imported hierarchy by validated bone names/IDs.

### 8.3 Controls and repeatable trials

| Control group | Planned controls |
|---|---|
| Start state | Idle/Walk phase scrub, original procedural Attack phase, root speed/yaw; synthetic upward/falling state with explicit height/velocity |
| Weapon | Pistol/Rifle/Shotgun; near/mid/far distance; hit region and world point; incoming direction; pellet pattern/coverage and seed |
| Response | Total linear impulse, separate angular impulse, body distribution, inherited-velocity multiplier/caps; clear display of units and coordinate frame |
| Physics | Joint-limit preset, body damping, friction/restitution, gravity experiment, self/corpse collision toggles; reset before topology/constraint changes |
| Review | Play/pause, restart/reset, physics-frame step, normal speed and 0.5×/0.25×, front/side/3⁄4 view, visible mesh/collider/anchor overlays |
| Stress | 1/2/4/8/16 deaths in the same physics tick; selectable quality cap and spawn arrangement |
| Monitoring | Active/settled/parked corpse counts, total bodies/joints, collision pairs, CPU/frame-time plots and reset/memory counters |

Each trial records source asset hashes, source phase, pose/velocity snapshot, hit payload, seed, backend and settings. Reset must restore the same inputs and clear old physical state; do not advertise bitwise deterministic simulation across devices.

Slow motion must report **simulation time and wall time separately**. It changes the presentation of a trial and can affect scheduling; benchmark normal speed separately. Avoid changing global physics TPS merely to slow the preview.

Keep cameras fixed relative to the test ground, not attached to a falling head/CharacterBody. Change camera framing or batch size on reset, before a trial starts; do not auto-zoom or vertically follow during impact. Keep a constant focal region and comfortable distance, with optional manual orbit only while paused.

### 8.4 First experiment sequence

1. No-hit gravity release from a known compatible pose: verify body placement, joint topology and contacts.
2. Handoff with zero new impulse from Idle/Walk; test both support legs and all representative phases.
3. Existing original Attack handoff including the visible Model lunge and live Idle/secondary pose; then upward/falling initial velocities. Fast authored arm-swing testing requires a separately authorized original Attack, not importing the private A&S reference.
4. Fixed joint/mass setup, varying Pistol/Rifle/Shotgun input structure, including centered versus off-center and symmetric versus asymmetric pellet patterns.
5. Ramp/step/wall/ledge tests, settling and pooling, then burst deaths and device profiling.
6. Only if needed, evaluate a custom proxy, a short original impact phase or physical animation. Do not start all architectures simultaneously.

## 9. Validation checklist and decision gates

Everything below is **a future acceptance test**, not a passed runtime result. Suggested numerical tolerances are initial hypotheses to agree/refine in the lab.

### Visual continuity and character identity

- [ ] Full arms/legs remain rigid; no added elbows/knees or unintended scaling/stretching.
- [ ] Original model, atlas, proportions, rig and all Action statuses remain unchanged.
- [ ] No T-pose/reset flash from Idle, either Walk support phase or Attack.
- [ ] Model lunge, skeleton world transform and root motion are preserved through capture.
- [ ] First handoff displacement/orientation error is measured per rigid piece; investigate roughly >5 mm or >1° discontinuities rather than masking them with effects.
- [ ] Front/side/three-quarter review shows readable loss of balance, limb follow-through and a plausible final silhouette.
- [ ] Pistol/Rifle/Shotgun differ in motion structure at normal speed; Shotgun is not simply the Rifle impulse multiplied.

### Physical stability and transitions

- [ ] All seven native bodies are connected as intended; no leg is accidentally an unjointed root.
- [ ] Joint anchor-position residuals **and angular swing/twist-limit violations** are logged before release; translated or out-of-limit poses have an explicit compatibility policy. Coincident anchors alone do not prove a snap-free release. Zero-added-impulse tests cover representative phases.
- [ ] First physical step does not correct a large overlap/anchor error by exploding the corpse.
- [ ] No systematic ground penetration, corner snagging, endless jitter or implausible elastic rebound on tested terrain.
- [ ] Large head mass, invisible Hips carrier and adjacent collider contacts behave consistently.
- [ ] Capsule/hitbox removal does not push the corpse, block players or cause repeated lethal events.
- [ ] Inherited root/body velocities are neither zeroed nor double-counted; angular units and impulse offsets are correct.
- [ ] Jump/falling deaths retain vertical motion; the old global Y=0 correction is absent from the lab physics path.
- [ ] A centered symmetric Shotgun pattern does not generate arbitrary yaw; a lateral hit changes torque sign correctly.
- [ ] Simulation never fights a still-running bone writer or moving CharacterBody parent.
- [ ] Interpolation off/on and non-origin/moving-parent trials are checked on the exact engine/backend. Test a low diagnostic TPS separately from performance runs.
- [ ] Settled-pose capture, stop, collision removal and pool reuse do not resurrect an animation or reset pose.

### Performance and scalable behavior

- [ ] Device targets and quality-specific budgets are agreed; 30 FPS has measured frame-time evidence.
- [ ] Active bodies/joints, contacts and retained memory stay bounded through repeated death waves.
- [ ] Cold activation, simultaneous deaths and pool exhaustion have acceptable measured p95/p99 behavior.
- [ ] A falling corpse is not frozen in midair when a timer/cap expires.
- [ ] Sleeping/parked corpses do not wake an entire crowd unnecessarily or retain AI/navigation work.
- [ ] Release performance and debug diagnostics are distinguished; thermal runs and both Android/iOS are included.
- [ ] No private source-derived Action enters lab/production exports; fallback clips have original provenance.

## 10. Recommended next steps — approval required

1. **Review this research and approve one isolated lab experiment.** Confirm target devices, initial backend policy and whether to use the current original runtime clips or separately export Pending Original V1 clips for preview.
2. **Build only the pose-handoff baseline:** native seven-body/six-joint topology on a lab wrapper, unit-scale original model, no weapons beyond a zero/small test impulse. Preserve Blender files and production scripts.
3. **Demonstrate stable handoff and ground interaction** from representative Idle/Walk/Attack/airborne states. Decide whether native anchors/carrier are adequate or a custom proxy is justified before adding more features.
4. **Develop the three weapon profiles** against the same physical baseline. Test pellet aggregation, hit-point torque, range/coverage and bounded velocities; review ordinary-speed footage.
5. **Add corpse lifecycle and stress tests**, then profile actual devices and revise the tentative Low/Medium/High budgets.
6. **Only if the measurements require it, authorize original baked fallbacks** or a more involved physical-animation controller. No existing private A&S motion should be converted into those assets.
7. **Seek a separate production-integration approval** after visual and performance acceptance. Existing WorldMap, AI, navigation, camera, player animations and original sources remain outside the lab task.

**Stop condition for this phase: this document is delivered for review. No Death Lab, new death animation, physics rig, gameplay integration or automatic implementation follows.**

### Local evidence and preservation record

Read-only inspection covered the saved Mobs library, native Zombie source/original archive, current Zombie scene and directly related animation/controller/cache scripts, runtime GLB/import settings and project configuration. Eleven monitored asset/config/script files retained identical SHA256 hashes **and modification times** before and after the audit. Blender pose sampling changed only an unsaved in-memory copy. No existing GameAssetFactory assets were saved, no Godot project/editor was launched for simulation, and no mobile performance benchmark was run.

The runtime configuration queries used temporary standalone scripts outside GameAssetFactory. Those scripts and raw audit outputs are research working files, not new gameplay or lab assets. The sole requested project deliverable is this Markdown document. No third-party resource pack or footage was copied into the project, and this research task does not commit or push reference assets.

Useful local source files:

- [Mobs Animation Library](</Users/tin/Desktop/Game Dev/GameAssetFactory/blender/animation/showcase/Mobs_Animation_Library.blend>)
- [Original-only archive](</Users/tin/Desktop/Game Dev/GameAssetFactory/blender/animation/showcase/mobs_library/originals/Mobs_Animation_Library_Original_V1.blend>)
- [Current project settings](</Users/tin/Desktop/Game Dev/GameAssetFactory/game_mobile_3d/project.godot>)
- [Zombie scene](</Users/tin/Desktop/Game Dev/GameAssetFactory/game_mobile_3d/scenes/characters/CuboidZombie.tscn>)
- [Zombie actor](</Users/tin/Desktop/Game Dev/GameAssetFactory/game_mobile_3d/scripts/cuboid_zombie.gd>)
- [Animation base](</Users/tin/Desktop/Game Dev/GameAssetFactory/game_mobile_3d/scripts/cuboid_animation.gd>)
- [Zombie secondary/Attack/death behavior](</Users/tin/Desktop/Game Dev/GameAssetFactory/game_mobile_3d/scripts/zombie_animation_secondary.gd>)
- [Existing private Attack/Hurt findings](</Users/tin/Desktop/Game Dev/GameAssetFactory/blender/animation/showcase/mobs_library/research/actions_stuff_zombie_combat_v001/FINDINGS.txt>)
