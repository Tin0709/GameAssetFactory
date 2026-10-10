# Expressive Blocky Animation — expansion guide

Research expansion: **2026-10-10, Asia/Saigon**. Scope: reusable research and future production briefs only. This extends [ANIMATION_STYLE_GUIDE.md](ANIMATION_STYLE_GUIDE.md); it does not replace it or authorize remakes, rig changes, export, runtime integration, or artistic approval of new clips.

**Preferred artistic direction:** expressive independent rigid blocks, appealing limb separation, strong silhouettes, coordinated torso response, quiet head follow-through, designed timing, convincing support and impact. Preserve soft, controlled **“nhúng nhúng”** compression during grounded preparation, absorption and recovery. Stronger landing impact still has controlled follow-through and a restrained rebound. No rubber deformation, fake knees/ankles, automatic symmetry or arbitrary airborne bounce.

## 1. How to use this knowledge base

For a future short animation request, read the relevant category brief below, inspect its named approved Action and frame ranges, then follow section 9. The brief is a starting design hypothesis, not a substitute for reviewing actual motion. Preserve character proportions, full arms/hands, textures, mesh identity, rest rig, independent Actions, original slots and existing Godot behavior.

Read alongside:

- [Style guide and original reference register](ANIMATION_STYLE_GUIDE.md): Dungeons II visual evidence, source provenance and rigid articulation principles.
- [Animation Progress](ANIMATION_PROGRESS.md), [Animation Workflow](ANIMATION_WORKFLOW.md), [Showcase README](../../blender/animation/showcase/README.md) and [Showcase manifest](../../blender/animation/showcase/animation_manifest.json): ranges, source paths, hashes, slots and review lifecycle.
- [Art Direction](../graphics/ART_DIRECTION.md) and the latest relevant records in [Graphics Research](../graphics/RESEARCH.md): selected appearance, current runtime and historical changes. Read dated follow-ups rather than assuming an older report describes the current game.

### Approval clarification received during this research

The user explicitly confirmed in this research conversation: **Jump_Landing_Impact_Test is officially approved and is the preferred landing baseline**, personally reviewed and accepted. **Jump_Landing_Test remains the preserved original softer alternative.** Use Impact for future landing, weight-transfer, compression and recovery research, alongside approved LowerBody Recovery.

At inspection, the supplied AGENTS text, Animation Progress and Workflow contained pending labels; the Impact manifest, newer Showcase records and newest Graphics Research record already described its approval. Some study README paragraphs and video captions retained delivery-time labels. This discrepancy is documented here without editing those records. The original softer alternative has no separate explicit approval established here. The newly encountered `Full_Jump_Expressive_Test` was pending, not an approved reference. The user's approval of the style does not approve every Action or a future implementation. Recheck current records in later sessions; concurrent work may supersede this snapshot.

### Evidence vocabulary and access limits

Use the existing guide's labels: **O** observed pixels; **M** measured file/data result; **D** documented statement; **P** original project proposal; **H** unverified technical explanation; **U** unknown. Approval is a separate, explicit user decision.

This expansion inspected saved pose/contact sheets, including the arm test's complete 24-frame three-quarter sheet, the sequel run/walk sheets, and the local multi-view key-pose sheets listed below. It also opened the saved Showcase in a separate background Blender process for a **read-only data audit**, without saving or changing the foreground scene. It did not conduct a new real-time video playback assessment, rerender the studies or rerun their contact/collision validation. Prior timing and numerical validation results are identified as prior evidence, not fresh measurements.

External educational articles, engine documentation and selected PDF text were accessible. Embedded demonstrations were **not visually analyzed in this expansion**; no timestamps are invented for them. The earlier guide's trailer/reel inspections remain inherited evidence with their recorded limits. Its failed continuous Dailymotion playback is still an unresolved reference gap, not proof that the current URL can never work. New category recommendations remain usable, but idle/combat/evasion/death/transition motion evidence is less complete than locomotion evidence.

## 2. Existing knowledge versus research gaps

| Area | Already established | Remaining gap / next useful evidence |
|---|---|---|
| Arm freedom | Approved Arm Motion demonstrates separated, attached shoulder swings with solid cuboids. | Weapon grips, crossed-body paths, occlusion at gameplay scale and interrupted swings. |
| Run mechanics | Approved Run has alternating support/flight, open arms, controlled torso/head and a periodic boundary. | Walk counterpart, variable speeds, starts/stops, turns, slopes and armed blending. |
| Grounded weight | Approved Recovery and Impact provide load transfer, compression, delayed upper-body response and settling. | Both receiving sides, moving impacts, varying incoming momentum and immediate exits. |
| Flight | Approved Takeoff/AirPose provide compact-to-open contrast and separate pose/presentation motion. | Arbitrary flight duration, falls from ledges, interrupted flight, controller-driven contacts. |
| Idle | Approved neutral/settle poses provide a visual anchor. | A sustained, interruptible idle; meaningful quiet versus repetitive bobbing. |
| Directional motion | Older runtime has directional/weapon functionality; this is not approval under the new style. | Expressive turn-in-place, curved travel, strafing and backward movement with stable support. |
| Combat | Articulated arms and weight transfer are reusable capabilities. | Grip-constrained swings, aim/recoil, readable events, combos and cancel windows. |
| Evasion / reactions / death | Existing studies demonstrate ingredients, not these behaviors. | Support-driven evasions; localized versus full-body impacts; stable collapse/contact topology. |
| Transitions | Separate jump-study boundaries have prior pose/velocity checks. | A systematic transition matrix across lead feet, speed, direction, weapons and interruptions. |

**Do not repeat the completed rig-feasibility experiment.** Current evidence supports creating the next small pose study with the existing rig. A specific failed pose/contact/grip test must justify any later correction. Equally, do not interpret successful running as proof that a compact roll or two-handed weapon pose is feasible.

### Approved Action anchors: inspect these concrete examples

Frame numbers are Blender frames at **30 FPS**, beginning at F1. Time at F is `(F−1)/30` seconds; playback duration includes each displayed frame interval. Sheets show selected poses, so their column spacing is not motion timing.

| ID / Action | Source and directly inspected frames | O: visible characteristic | Transferable lesson / limit |
|---|---|---|---|
| A1 — `Expressive_Arm_Motion_Test`, approved | [Study](../../blender/animation/reviews/player_animation_library_v1/expressive_arm_motion_test/README.md); [front/three-quarter poses](../../blender/animation/reviews/player_animation_library_v1/expressive_arm_motion_test/three_pose_review.jpg), F1,7,14; [complete three-quarter sheet](../../blender/animation/reviews/player_animation_library_v1/expressive_arm_motion_test/three_quarter_all_frames.jpg), F1–24 | F7 opens a different arm silhouette from F14; hands remain joined to solid arm blocks. The lower body stays nearly stationary. F19–24 narrow toward the neutral outline. | Use shoulder spread and torso relation to make arcs readable. This is an arm capability reference, not whole-body locomotion or a seamless idle. |
| A2 — `Run_Expressive_Test`, approved | [Study](../../blender/animation/reviews/player_animation_library_v1/run_expressive_test/README.md); [three-view sheet](../../blender/animation/reviews/player_animation_library_v1/run_expressive_test/run_pose_sheet.jpg), F1,4,7,8,10,13,16,17 | Side F8/F17 show extended leg splits and visible ground clearance; F4/F13 are narrower passing arrangements. Front arms stay outside the torso outline; the face remains comparatively level. | Alternate contact/pass/release/flight, not just a faster walk. Side-view arm overlap is a projection limit. Preserve F19 closing key but play F1–18. |
| A3 — `LowerBody_Recovery_Test`, approved | [Study](../../blender/animation/reviews/player_animation_library_v1/lowerbody_recovery_test/README.md); [three-view sheet](../../blender/animation/reviews/player_animation_library_v1/lowerbody_recovery_test/recovery_pose_sheet.jpg), F1,7,10,13,18,22,33,42 | F7 shifts laterally; F18 is lowered and pitched; F22 remains inclined while later F33/F42 return upright. | Grounded softness is a load/receive/recover sequence. Whole-leg hip overlap substitutes for anatomical folding, with visible limits. |
| A4 — `Jump_Takeoff_Test`, approved | [Study](../../blender/animation/reviews/player_animation_library_v1/jump_takeoff_test/README.md); [three-view sheet](../../blender/animation/reviews/player_animation_library_v1/jump_takeoff_test/takeoff_pose_sheet.jpg), F1,7,9,14,17,19,20,24 | F14 is compact with arms back; F17 lengthens the assembly; F24 exposes raised arms and a leg split. | Contrast preparation and release. Prior validation labels F19 last support/F20 first integer airborne sample; this is not a newly measured physics trajectory. |
| A5 — `Jump_AirPose_Test`, approved | [Study](../../blender/animation/reviews/player_animation_library_v1/jump_airpose_test/README.md); [three-view sheet](../../blender/animation/reviews/player_animation_library_v1/jump_airpose_test/air_pose_sheet.jpg), F1,4,7,9,13,16,19,22 | Leg split opens toward F9/F13; the arms change height and direction unequally; the late pose still has separated limbs. Side projection hides some paired-arm separation. | Continue purposeful angular overlap in flight. The final sample is not a universal held air pose or a validated arbitrary-duration loop. |
| A6 — `Jump_Landing_Impact_Test`, approved preferred landing | [Study](../../blender/animation/reviews/player_animation_library_v1/jump_landing_impact_test/README.md); [three-view sheet](../../blender/animation/reviews/player_animation_library_v1/jump_landing_impact_test/impact_pose_sheet.jpg), F1,6,9,10,14,18,26,30,42,52,56 | F14 is distinctly compressed; F18 retains a pitched upper body; F30 is more upright; F42–56 progressively quiet the silhouette. Arms counterbalance rather than simply mirror. | Fast receiving action, delayed upper-body response, small rebound and slower recovery are the landing anchor. Exact amplitude is specific to this test. |

**D, prior authored/measured details:** A2 uses 18 playback frames/0.600 s, with 34% support per leg and 32% total flight. Its right-arm outward range was 13.3–36.4°, head yaw excursion 4°, and leg split 102.6°. The older sprint had a *larger* split (112.1°) and a faster cycle: the improvement was articulation/control, not maximum amplitude. A6 has first/second support F9/F10, lowest hips F14 (120 mm below ready), one 12 mm overshoot at F30, and settles through F56. The softer alternative reaches its low at F16 after F9/F11 contacts. See linked studies for definitions and validation scope. These numbers are benchmarks for comparison, **not universal targets or Dungeons II measurements**.

**M, fresh data audit:** saved Showcase opened with Blender **5.2.2 LTS**, one 13-bone armature and zero pose-bone constraints. A1 has 20 F-curves; A2–A6 each have 87, each with one original slot. A2's data range is F1–19. This confirms stored structure, not rendered quality or export behavior. A1's sparse tracks make full-pose reset especially important; assigning only an Action name is insufficient.

## 3. General principles for this visual style

All prescriptions in sections 3–9 are **P**, informed by the evidence register and approved examples. They are not claims about Mojang's internal rig or automatic artistic approval.

1. **Give each motion a cause.** Establish intention, driving force, receiving support and recovery. The viewer should be able to tell which foot carries the body and why the chest/arms change direction. Gilbert's body-mechanics discussion emphasizes consistent forces and intentional decisions [E1].
2. **Compress the assembly, preserve the blocks.** Create compact/open contrast with joint rotations, approved local pose offsets and torso inclination. Do not scale, shear or soften cuboids. Grounded hip lowering needs a support solution and an acceptable hip seam. In air, change articulation rather than add a second vertical bounce.
3. **Design negative space at meaningful moments.** Check arm/torso wedges, hand/head clearance and leg separation in front, three-quarter, side and gameplay views. Arms need not remain equally spread throughout; compact passing poses make the wide moments meaningful. Avoid permanent scarecrow posture.
4. **Coordinate rather than oscillate.** Hip/chest counter-rotation supports the step, strike or receiving force. The head may lead an intentional look and lag an inertial response; neither “head always last” nor identical delayed sine waves is a rule. Stable gaze is the default.
5. **Use timing contrast.** Separate preparation, commitment, transfer, recoil and settling. Smooth interpolation alone cannot supply weight. Fast spacing during release and close spacing around a readable extreme should be purposeful. Keep hard impacts crisp without introducing accidental positional pops.
6. **Overlap according to cause and strength.** The receiving mass reacts before trailing parts settle; amount of follow-through should fit the initiating motion [E2]. Our block arms can overlap through shoulder/chest orientation without floppy elbow bends. Quiet phases need genuinely low velocity, not endless noise.
7. **Keep asymmetry functional.** Lead/trail support, grip and gaze explain unequal poses. A balanced periodic leg rhythm can coexist with different arm arcs, as A2 shows. Random phase offsets are not a cure for stiffness and can destroy contact timing.
8. **Track useful landmarks.** Inspect wrist/hand corners, shoulder junctions, boot support corners, pelvis center and head center in world and screen space. Parent rotation already generates arcs; editing local channels independently can kink the final path. Judge the evaluated path, not the appearance of an individual F-curve.
9. **Responsiveness belongs in the design.** Preparation must fit the input/telegraph budget. Enemy warning, player response, damage window and decorative follow-through serve different purposes. Professional game-animation guidance explicitly distinguishes audience clarity from excessive input delay [E3, E4].
10. **Separate style, gameplay and presentation.** A beautiful preview trajectory, floor offset or slow-motion replay must not become duplicate runtime travel. Sound, trails and camera shake may clarify an already readable action; they cannot validate its mechanics.

### A support model future sessions can reuse

Mark each interval as left support, right support, both, flight or an intentional body/hand contact. For a rigid boot, distinguish the stationary **lowest corner/edge** from the rest of the sole rocking around it. Do not claim a flat, immobile sole while rotating the entire leg.

For support point `s(t) = actor_position(t) + actor_rotation(t) × local_support(t)`, a planted contact should remain nearly stationary in world space. Evaluate the full expression: actor rotation also moves an offset foot. In straight in-place locomotion at constant orientation, the backward local support velocity should approximately cancel forward controller velocity. At a turn or during acceleration, a nominal run-speed correction alone is insufficient.

Use the hips/torso as a *visual mass proxy*, not a measured center of mass. A static supported pose should read balanced over support; a moving body can pass outside that area while momentum and the next receiving step explain it. Avoid forcing every dynamic pose into a static balance rule.

## 4. Reusable category design briefs

Each brief identifies the smallest useful next study. Proposed Action names are examples, not created assets. No durations below should be taken as approved gameplay timing. Begin with readable phases, then choose timing against intended speed, input response and reference evidence.

### 4.1 Idle and subtle character movement

**Implementation record (2026-10-10, pending):** [Idle_Expressive_Test](../../blender/animation/reviews/player_animation_library_v1/idle_expressive_test/README.md) applies this brief as a 3.2-second seamless loop: quiet load shifts, fixed full soles, rigid torso rotations and staggered arm/head response. Original Idle and all jump studies stay preserved. Only explicit user review can approve it; future character Actions, including experiments, must register Pending in the existing central Showcase before delivery.

**Purpose / anchors:** alert, comfortable readiness; A1 F1/F24, A3 F33–48 and A6 F42–56. These are neutral/settle anchors, not evidence of a complete idle cycle. E5 supports studying performed idle behavior, but its avatar findings do not establish our amplitude or personality.

**Mechanics and poses:** establish a slightly unequal relaxed load with both boots supported. Suggest breathing through tiny chest/shoulder rotations and a small relative head adjustment; never inflate the torso. Distinguish a quiet base loop from occasional intentional look/weight-shift one-shots. A real replant must first unload that leg.

**Timing, arcs and coordination:** use slow, unevenly spaced changes with quiet dwell, restrained shoulder/arm lag and stable gaze. Arms describe small shoulder-centered arcs; hips should not bob at running frequency. Breathing, gaze and load change need not peak together. If adding variation later, use authored compatible variants rather than uncontrolled random motion.

**Robotic pitfalls:** every bone on the same sine, symmetrical hand pendulums, perpetual knee-like bobbing, a freeze at the loop seam or large gestures repeating predictably. Over-animation can be less believable than restraint.

**Reusable brief:** “Create one separate unarmed ready-idle test with supported feet, rigid breathing suggestion and subtle unequal arm response; inspect A1 neutral and A6 settle. No new joints, scaling or ambient gesture system. Review several native-speed loops plus interruption into a start.”

**Pass / research gate:** boots stay supported, head is readable at gameplay size, repeat seam is unobtrusive, interrupting at different loop phases does not snap or delay input. Still needed: an inspectable uninterrupted 10–20 s II idle/reference performance with pre/post movement, not a single neutral screenshot.

### 4.2 Walk and run locomotion

**Purpose / anchors:** purposeful walk and energetic run sharing the approved articulation language. A2 is the run reference; sequel sheets G1/G2 below provide visible contrast. Do not remake approved Run merely to increase amplitude.

**Mechanics and poses:** walk uses alternating contacts with a readable transfer/double-support opportunity; run includes genuine release/flight and quicker recovery. Design contact, receiving/down, passing and release poses for each side. Hip height follows support and clearance; chest counter-turn balances the gait, arms oppose the corresponding legs while retaining lateral freedom, head stays comparatively quiet.

**Timing, arcs and coordination:** the planted boot travels backward relative to the actor at the intended speed, then lifts and returns through a shaped recovery arc. Whole-leg clearance comes from the existing pose-offset convention, with hip overlap inspected. Arm reversal can lag the step slightly; it must not pull both shoulders backward together. Match both pose and velocity across the loop seam.

**Robotic pitfalls:** speeding up walk without flight, equal spacing throughout support/recovery, flat hip motion, all-body mirrored extremes, unsupported foot sliding and a neutral reset every cycle. Excessive torso twist or head bounce undermines the face and weapon stability.

**Reusable brief:** “Create one expressive walk test complementary to A2, at a stated nominal travel speed. Preserve open attached shoulders, clear receiving/passing poses and solid legs. Compare identical views against approved Run; do not overwrite it.”

**Pass / research gate:** inspect at least three repeats and both lead feet; walk/run remain distinguishable without labels. Measure planted support drift at nominal speed, floor clearance and seam continuity. A2's prior 2.9001 m/s diagnostic speed is specific to that study; controller speed changes require new testing. Slopes, step climbing and armed variants remain separate validations.

### 4.3 Starting, stopping, acceleration and deceleration

**Purpose / anchors:** make locomotion feel intentional before and after its loop. A3 supplies transfer/recovery; A2 supplies destination gait; A6 supplies controlled receiving response, scaled to the event rather than copied wholesale. E6 documents why start/move/turn/stop clips and contact information matter.

**Mechanics and poses:** starting moves load toward a support leg, then projects the body into travel and releases the other leg. Stopping places a receiving step to absorb existing travel, while chest/arms continue briefly. Braking from speed is not reverse playback of acceleration. Include quiet ready, committed push/brake, first/last receiving contact and gait/idle handoff.

**Timing, arcs and coordination:** build lean and stride with speed; unwind torso/head after support catches the body. Let arms enter or leave the gait through compatible arcs rather than switching immediately to full amplitude. A short input tap may require an abbreviated start, not a complete cycle followed by a complete stop.

**Robotic pitfalls:** legs run at full speed while the capsule is stationary, long pre-action crouches after input, abrupt velocity changes hidden by long crossfades, synchronized stopping of all parts or recovery steps that slide backward.

**Reusable brief:** “Test one forward start and one stop with a specified lead/support foot and speed envelope, in separate Actions. Use A3 transfer and A2 gait phase. Show actor travel externally for diagnosis and state who would own runtime velocity.”

**Pass / research gate:** release input early, hold it, reverse it and stop from each support phase; no planted-foot teleport or extra idle step. Measure time from input to visible commitment, not merely clip length. Obtain continuous starts/stops before choosing production anticipation and braking distances.

### 4.4 Directional movement, turning and strafing

**Purpose / anchors:** change travel direction while preserving deliberate support and readable facing. A3's lateral transfer is a starting ingredient; it does not prove turning. Existing R15 strafe behavior is a compatibility baseline, not the new artistic standard.

**Mechanics and poses:** separate turn-in-place, curved forward travel and aim-facing strafe. For a planted turn, unload one leg, rotate/replant it, then transfer and bring the other through. In curved travel, step placement and body lean support the turn. In strafe, the pelvis carries lateral travel while chest/head maintain the target within a reasonable twist range. Backward travel needs its own recovery/visibility logic.

**Timing, arcs and coordination:** an intentional look may lead, then shoulders/hips follow as support permits. Do not rotate both feet under a planted body without accounting for their contact arcs. Shape inside/outside arm paths; keep the weapon-facing side more stable if armed. A rapid reversal should include a receiving/braking decision.

**Robotic pitfalls:** spinning the actor around two glued soles, applying forward run unchanged sideways, crossed boots clipping, mirrored poses that reverse a weapon grip, and torso twist that accumulates independently of feet.

**Reusable brief:** “Test one 90° turn-in-place and then one lateral step/strafe direction, separately. Declare facing, travel vector, support foot and exit phase. Preserve A1 shoulder freedom and A3 grounded transfer; no automated eight-direction batch.”

**Pass / research gate:** inspect front/side and actual gameplay direction conventions; test both turn signs, diagonal interpolation, reversal and zero-speed facing changes later. Track world contact drift during rotation. Acquire continuous II turning/aim-strafe footage before claiming a sequel-specific directional style.

### 4.5 Melee and ranged weapon animations

**Purpose / anchors:** readable, forceful action with coherent hands and useful gameplay events. A1 supplies arm arcs, A3/A6 support/receiving response. E3 supports readable anticipation; E7 emphasizes weapon-dependent timing and responsiveness. No inspected source establishes II's exact hit frames or grip solver.

**Mechanics and poses:** for melee, define guard → preparation → commitment/contact → follow-through → recovery. Support and hips initiate a believable weight transfer, chest/shoulder carry the swing, the free arm counterbalances, and the head retains target awareness. Track weapon-tip arcs and grip continuity, not just hand position. A heavy sweep, short jab and miss need different momentum/recovery.

For ranged weapons, distinguish raise/aim, fire or release, recoil and return. A bow needs a feasible two-hand separation/draw pose; a pistol needs stable muzzle direction with recoil transmitted into the arm/shoulder. A two-hand grip removes some independent arm freedom: express asymmetry through torso, shoulders and timing without letting hands leave the prop. Do not add a long anticipation to every triggered shot.

**Timing, arcs and coordination:** name the exact gameplay release/contact event, intended active interval and earliest cancel/recovery exit. Keep strike spacing decisive; avoid a pause just before contact caused by automatic easing. Preserve continued motion on a miss; a hit response is a separate design choice. Recoil returns with controlled damping rather than repeated mechanical oscillation.

**Robotic pitfalls:** swinging only an arm from a frozen torso, uniform weapon speed, rigidly synchronized free arm, sliding grips, excessive head recoil, and forcing a whole-body swing into an upper-body blend mask.

**Reusable brief:** “Choose one weapon and one attack or ranged-fire test. Establish prop/grip compatibility with three key poses first; preserve rigid arms. Then author anticipation, active event, follow-through and recover, with support annotated. Compare unarmed mechanics and armed grip views.”

**Pass / research gate:** grip and muzzle/blade trajectory remain coherent; attack direction/commitment reads at gameplay size without VFX; foot support, hand/head clearance and cancel boundary hold up. Weapon geometry, actual gameplay timing and inspected attack/recoil references are prerequisites for final values. Do not rebuild elbows to solve a speculative grip.

### 4.6 Dodging, rolling and evasive movement

**Purpose / anchors:** a committed displacement with convincing launch and recovery; A3 transfer, A4 push and A6 receiving action. A roll is a distinct contact problem, not merely a rotated dodge. E8 explains why interpolation can spoil roll intermediates even when keys look plausible.

**Mechanics and poses:** begin with a side-step or short evasive hop: load the pushing side, project away, clear/replant the free foot, receive and recover. Torso leans with intent; arms counterbalance without detaching; gaze remains useful. A roll would require planned hand/shoulder/back/foot contacts and sufficient head/limb clearance through the entire rotation.

**Timing, arcs and coordination:** brief readable preparation, fast travel commitment and controlled receiving recovery. Angular pose change and externally owned displacement must agree. For a roll, rotational spacing and body clearance determine the arc; blending upright endpoints through a compressed middle is insufficient. Invulnerability timing is a gameplay contract, not something inferred from the pose.

**Robotic pitfalls:** sideways skating with running legs, rotation about the origin that drives the head into the ground, elbows/knees invented for a tuck, and a springy second launch after landing. A visually rigid rectangular body cannot achieve every human rolling pose.

**Reusable brief:** “Prove one lateral evade first with explicit support/release/receive phases. Preserve A6 controlled recovery. Treat a roll as a later three-pose plus intermediate-clearance feasibility study on the existing rigid rig; report limitations before proposing changes.”

**Pass / research gate:** direction reads immediately, travel/pose agree, ground and body contacts are plausible, recovery can exit without snapping. A true compact roll remains **U** for this rig. Obtain continuous side/three-quarter roll footage and a contact breakdown before authoring production rolling motion.

### 4.7 Hit reactions, stagger and knockback

**Purpose / anchors:** communicate where force arrives and whether balance is retained. A6's receiving/overlap phases and A3's replant/recovery are useful; neither is an approved damage reaction. E9 documents the need for context and interruption policies in a professional reaction system.

**Mechanics and poses:** distinguish a local flinch, balance-breaking stagger and translated knockback. For a chest hit, chest/shoulder may react before the hips catch the mass; a lower-body hit changes support first. Larger loss of balance needs a receiving step, not unlimited torso bend. Head response follows the force without a large disconnected whip.

**Timing, arcs and coordination:** an unexpected impact should not anticipate itself before the hit. Establish pre-hit motion, sharp receiving change, delayed arm/head response and a slower recovery. A deliberate brace is a separate prepared state. Knockback world travel belongs to the controller/physics contract; the pose should react to that travel rather than duplicate it.

**Robotic pitfalls:** identical whole-body recoil for every direction, every part peaking simultaneously, full reset to neutral between repeated hits, huge additive rotations, or a planted foot being dragged without a replant. Do not just play the landing clip backward.

**Reusable brief:** “Create one light directional chest reaction, then a separate heavier stagger only after review. Define incoming direction, current support, hit moment, recovery step and interruption policy. Reference A6 for momentum reception, not for a copied damage performance.”

**Pass / research gate:** impact direction and severity read without particles; support either stays credible or visibly changes; repeated-hit/death interruption cannot produce a pose pop or unbounded additive twist. Inspect local light/heavy and front/side references before designing a large reaction set.

### 4.8 Death and falling animations

**Purpose / anchors:** clear loss of control and a settled end state. Use A5 for airborne articulation discipline and A6 for impact sequencing only; recovery in a living landing must not be carried unchanged into death.

**Mechanics and poses:** distinguish fatal collapse, airborne falling and nonfatal knockdown/get-up. Death progresses from force/loss of support to fall, first body contact, subsequent mass settling and rest. Plan which hip, shoulder, hand or torso surface receives first. Keep the head and rigid boot/arm volumes out of the floor. A ledge fall begins because support disappears; it does not add an anticipatory jump.

**Timing, arcs and coordination:** gravity-driven travel accelerates until contact; limbs lag the rotating mass, then settle in contact order. A heavy impact can have a small residual adjustment, but not A6's purposeful recovery to ready. The terminal pose needs broad enough support to look stable and must remain quiet. Fall duration and terrain collision cannot be inferred from a fixed preview clip.

**Robotic pitfalls:** a uniform-speed hinged plank fall, all parts hitting simultaneously, recurrent idle breathing after death, floor penetration hidden by camera, uncontrolled repeated bounce, or blending the corpse back to standing at clip end.

**Reusable brief:** “Test one simple directional collapse from a declared support pose into a stable terminal pose. Keep contact/travel presentation separate and inspect intermediate block clearance. Do not add ragdoll, get-up, gore, dismemberment or runtime collision changes.”

**Pass / research gate:** initial cause, loss of support and final death state read distinctly from stagger; all contact surfaces are plausible in three views; holding the end does not drift. Later inspect slopes/walls, moving entry and airborne death separately. Ragdoll cost/behavior and compact folded poses remain unproven for this rig/mobile target.

### 4.9 Transitions and blending

**Purpose / anchors:** retain the approved motion quality across state changes. A2's seam and the documented A4→A5/A5→A6 boundaries are concrete starting cases, not proof of universal blending.

**Mechanics and poses:** choose transitions with compatible support, travel, facing, grip and body momentum. The visible blend is its own pose sequence and needs inspection. Two valid endpoint poses can average into an invalid floating or intersecting pose. Preserve a receiving step when moving into idle; preserve gait phase when resuming movement.

**Timing, arcs and coordination:** compare position and angular/linear velocity at the handoff. A long blend can erase anticipation/contact; a very short blend can snap. Use different transition policies for cyclic locomotion, one-shot attack and high-priority interruption. Head/arm overlap should continue through the handoff, not restart from a generic neutral. For additive layers, declare the reference pose and inspect the combined result at maximum weight; an absolute chest rotation cannot simply be treated as a recoil delta. A mask through the torso must still coordinate the shoulder/grip chain with the supporting hips.

**Robotic pitfalls:** restarting cycles on every input update, mismatched left/right support, simultaneous independent skeleton writers, missing channels inheriting stale poses, blending world travel twice or stretching a contact phase to fit a fixed generic fade.

**Reusable brief:** “Test exactly one source→destination pair, at named support phases, with entry/exit speed and event policy. Render the actual intermediate blend at native timing in the same camera. Preserve both source Actions and bind/reset their original slots correctly.”

**Pass / research gate:** validate both lead feet, multiple entry times and interruption; no contact drift, grip break, residual stale pose or event duplication. A1 is a particularly useful reset stress case. Runtime claims require the actual Godot controller and in-game recording; Blender-only blending remains a study.

## 5. Rigging and Blender implementation considerations

### Preserve the existing articulated assembly

The original arm study and fresh Showcase audit support the current rig as the first choice. Keep the established shoulder inset/rest pivots and independent shoulder controls. Bone names containing `ForeArm` are not permission to introduce an exposed bending elbow; the approved full-arm treatment remains the visual standard. Similarly, `Leg.L/R` are whole rigid legs, not hidden knee/ankle chains.

The reviewed studies use rigid weighting and pose offsets to preserve dimensions. Leg retraction into the hip changes **exposed** length without changing cuboid geometry. This is a stylized overlap convention, not anatomical compression. A3 previously reached approximately 149 mm maximum leg-local translation magnitude; A6 about 140 mm. Those are combined local translations, not universal safe vertical allowances. Inspect the seam and full segment, especially at greater pitch, lateral steps or deep impacts.

Use the existing FK articulation and minimal local translations first. If a pose fails, identify the actual cause: pivot, travel/pose mismatch, contact solver, silhouette, grip geometry, arc or interpolation. Try a different pose/support/timing before changing the rig. Future corrective controls must be isolated, baked to compatible tracks and tested against approved Actions; they are not authorized by this document.

### Author and preserve Actions deliberately

- Back up source files and any unsaved work before future mutations. Work in a separate saved study with a unique Action name/version; never edit an approved Action in place.
- Preserve bone hierarchy/rest matrices, object transforms, rotation modes, mesh/UV/material/texture data and rigid weights. Unit scale throughout; no scale keys for squash or reach.
- Keep the Action **and its original Blender 5.2 slot** bound. Local audit found `OBEAM_Player_Rig` for A1, `OBLB_Test_Rig` for A3 and `OBRUN_Test_Rig` for the other listed studies. A slot identifier need not match the current Showcase object name.
- Match the library's supported one-object slot/layer/strip/channelbag contract. Do not flatten or bulk-import legacy libraries. Preserve Action users and never silently overwrite duplicate names.
- Reset the full pose before isolated review of a partial Action. Full-body locomotion and deliberately masked upper-body animation require different channel ownership; do not accidentally key rest values into a layer that should preserve the base gait.
- Inspect evaluated curves between keys. Quaternion sign continuity/normalization, Euler wrapping and automatic Bezier overshoot can each cause different problems. Use aligned/controlled handles where contact or crisp impact requires them; do not make every key linear or every reversal equally soft.
- Separate exportable pose from preview actor travel, floor lowering, cameras and review holds. Record which tracks own local grounded compression. Do not export a review parent or NLA combination as an unnoticed production trajectory.
- For cyclic playback of P frames, retain the matching P+1 closing key and periodic tangent, but do not render/export an extra displayed closing frame. One-shots need a declared ending/exit policy; looping them in a viewer does not make them seamless.

The [Blender developer notes on slotted Actions](https://developer.blender.org/docs/release_notes/4.4/animation_rigging/) explain that an assigned Action without an assigned slot may not animate a data-block. Local 5.2 data and the established registration workflow are the implementation authority here; inaccessible manual/export pages were not treated as successfully read documentation.

## 6. Transition contracts, Godot compatibility and mobile

### Current runtime inspection, not an integration change

Read-only inspection found `project.godot` declaring **4.7 / Mobile**, with `WorldMap.tscn` as main. `world_map.gd` selects `CuboidPlayerJumpGifV004.tscn`; its visual script inherits V003, which inherits `player_combat_strafe_r15.gd`, then the weapon integration stack. Current code already has sampled poses, per-bone jump weights, gait phase, weapon/contact responsibilities and distinct moving takeoff/landing blends. This is not evidence that an AnimationTree conversion is needed or authorized. Preserve its single final pose-writer arrangement during any separately requested integration.

The [Godot 4.7 AnimationTree documentation](https://docs.godotengine.org/en/4.7/tutorials/animation/animation_tree.html) documents blend spaces and cyclic synchronization modes, and explains defaults for missing tracks. These are available concepts to evaluate against the installed engine, not a plan to replace the current sampler. Normalized time alone cannot align feet unless the authored logical phases also correspond. A missing bone transform track uses bone-rest behavior in the documented system; do not assume it reproduces the Showcase's explicit pose reset or the custom runtime sampler.

### Record this contract before each new clip

| Field | Required decision / evidence |
|---|---|
| Identity | Unique Action/version, source hash, slot, rest-rig signature, approval status. |
| Time | FPS/fps_base, playback range, closing key, loop/one-shot, event frame and seconds. |
| Entry / exit | Source/destination pose, lead foot, support state, local/root velocity, facing, weapon/grip. |
| Motion ownership | Controller/physics travel versus local hip compression; exact preview-only transforms. |
| Contact | Support intervals, anchor type, floor reference, clearance and drift measurements. |
| Layering | Bone/property ownership, full pose or additive/masked intent, reference pose and reset behavior. |
| Gameplay events | Damage/release/contact/cancel windows; one owner for event dispatch and interruption rules. |
| Compatibility | Export track paths, axes, units, rest pose, scale, clips retained and post-import timing. |

### Minimum future transition matrix

| Pair / condition | Specific failure to expose |
|---|---|
| Idle→start→walk/run→stop→idle | Input latency, support drift, frozen anticipation, sliding settle. |
| Walk↔run, both lead feet and multiple phases | Phase inversion, artificial flight in walk, foot-speed mismatch. |
| Forward↔strafe/backward/turn, both directions | Planted-foot rotation, crossed limbs, torso/aim overtwist. |
| Gait↔attack/aim/fire, stationary and moving | Grip break, masked hips fighting support, duplicate events. |
| Attack/dodge→hit; hit→death; repeated hits | Cancel priority, restarting frozen poses, uncontrolled additive accumulation. |
| Takeoff→air→landing→idle/gait | Duplicated boundary frame, incoming velocity discontinuity, double trajectory, resumed gait phase. |
| Reset/respawn and Action switching | Stale transforms from partial tracks, incorrect slot or preview-floor carryover. |

Do not infer priority rules from clip names. A proposed starting policy is death overriding ordinary recovery, while hit, attack and dodge cancellation are decided by gameplay. CRYENGINE's documented reaction priorities [E9] demonstrate the need for an explicit policy; they are not rules to transplant unchanged into Godot.

### Practical mobile requirements

Target **30 FPS** remains a user requirement; minimum phone is unspecified. That is roughly 33.3 ms for the *entire frame*, not a skeleton budget. No desktop validation establishes phone performance.

Prefer the current small rigid rig and reusable baked transform clips before considering runtime IK, ragdolls or a large motion database. This is a cost-conscious proposal, not a measured comparison. Bound active layers and independent writers; later profile animation CPU, skinning/draw cost, clip memory and worst-case simultaneous characters on the target device. Do not quote a safe bone count or memory budget without measurement.

At export/import, verify FPS, names, slot selection, interpolation, looping and events; sample contacts after any key reduction/compression. Small numerical pose changes can shift a rigid boot corner visibly. Judge readability at actual gameplay camera size and motion sampled near 30 FPS, while retaining interpolation for render timing. Automated Godot tests use process-local Dummy audio; user playtests keep normal audio. This research ran no Godot tests and makes no new runtime/phone claim.

## 7. Reference sources and evidence ledger

Access/review date: 2026-10-10. Reuse original source manifests and contact sheets rather than copying proprietary keyframes or importing reference assets into the game. A contact sheet proves shown poses, not full-speed feel or a hidden rig technique.

### Dungeons II: retained primary stylistic reference

| ID | Source / exact locator | Evidence used in this expansion |
|---|---|---|
| G1 | [II hero run GIF](<https://minecraft.wiki/w/File:Player_Master_Run_(Dungeons_II).gif>); [saved complete sheet](references/style_research_2026_10_10/run_cycle.jpg) | **O, re-inspected:** f02–f03 at 0.080–0.130 s have a broad opposing leg arrangement; f06 at 0.250 s is narrower; f09–f10 at 0.380–0.420 s open the opposite stride. Straight-edged blocks stay recognizable. This isolated render has no visible floor proving exact support timing. |
| G2 | [II hero walk GIF](<https://minecraft.wiki/w/File:Player_Master_Walk_(Dungeons_II).gif>); [saved complete sheet](references/style_research_2026_10_10/walk_cycle.jpg) | **O, re-inspected:** f06–f08 at 0.250–0.330 s and f19–f21 at 0.790–0.880 s show opposite open strides with lower arm presentation than the run extremes; f13–f14 at 0.540–0.580 s narrow toward passing. Do not infer world foot speed from a fixed isolated render. |
| G3 | [II hero jump](<https://minecraft.wiki/w/File:Player_Jump_(Dungeons_II).gif>) and [jump-land](<https://minecraft.wiki/w/File:Player_Jump_Land_(Dungeons_II).gif>) | **Inherited O/M**, already analyzed in the style guide; not a new visual pass here. Keep its compact/open and receiving lessons, frame-delay records and provenance limitations. |
| G4 | [Official II trailer](https://www.youtube.com/watch?v=vBNE3bKMpu8) and [official article](https://www.minecraft.net/en-us/article/minecraft-dungeons-ii-gameplay-trailer) | **Inherited selective inspection:** saved trailer samples 00:28.719099, 00:38.719100, 00:48.719100. No new continuous input/transition analysis. The article supplies official context, not disclosed rig internals. |
| G5 | [Supplied extended walkthrough](https://www.dailymotion.com/video/xbfhi7u) | Earlier player failure documented in the style guide. **No new motion observations or timestamps** attributed to this recording. |

The [existing frame-delay/hash register](references/style_research_2026_10_10/wiki_cycles.json) measures G1 as 14 frames/0.580 s and G2 as 27/1.120 s. They are GIF presentation frames with unequal delays, not native engine frames. Comparing their duration does not establish controller speed or responsiveness.

### Dungeons I: secondary professional reference, not sequel implementation evidence

The original guide already covers Rich Stubbs' [Technical Animation Showreel 2025](https://richstubbs96.artstation.com/projects/2BGWqB), [Jungle Awakens](https://richstubbs96.artstation.com/projects/eaY94Y), [Howling Peaks](https://richstubbs96.artstation.com/projects/OoLXJg) and [Echoing Void](https://richstubbs96.artstation.com/projects/oA3yBw). Use its actual access register and saved samples. For example, its technical sample at **00:11.557841** and Howling Peaks attack sample at **00:25.360962** are inherited selective references, not newly watched sequences in this expansion. Boss/DLC rigs from I and unrelated personal rig demonstrations cannot establish the II hero's controls. The [community Blender render instructions](<https://minecraft.wiki/w/Help:Isometric_renders_%28Minecraft_Dungeons%29>) describe a reconstruction/render workflow, not the original studio's complete animation pipeline.

### Broader professional and technical sources

| ID | Primary source and accessed locator | Documented contribution / limits |
|---|---|---|
| E1 | Wayne Gilbert, [Body Mechanics Breakdown](https://www.animationmentor.com/blog/animation-tips-tricks-what-makes-or-breaks-a-good-body-mechanics-shot/), introductory mechanics discussion, 2014 article | **D, text read:** forces, intentions, anticipatory weight shifts and deliberate ordering of movement. Embedded motion not inspected. Applied here as causal design questions, not source-specific pose timing. |
| E2 | Drew Adams, [Follow-through and Overlapping Action](https://www.animationmentor.com/blog/follow-through-and-overlapping-action-the-12-basic-principles-of-animation/), “How To Practice,” 2017 | **D, text read:** trailing response and proportionality to the driving action. Pendulum reasoning helps distinguish response from arbitrary wobble; living limbs/head can also act intentionally. No embedded-video timestamps claimed. |
| E3 | Chris Hurtt, [Anticipation](https://www.animationmentor.com/blog/anticipation-the-12-basic-principles-of-animation/), “Why” and “How to master,” 2017 | **D, text read:** preparation can be subtle and communicates upcoming action; always moving in the opposite direction produces formulaic results. Game telegraphs are discussed. No visual breakdown of the embedded cartoons performed. |
| E4 | Justin Owens discussion in [Animation Mentor Tips & Tricks](https://content.animationmentor.com/pdfs/AnimationMentor_TipsTricks_EveryAnimator.pdf), PDF pages **16–18** (zero-based 15–17) | **D, selected PDF text read:** game responsiveness constrains anticipation, and motion must work across camera angles. PDF screenshot retrieval failed for a selected page; no illustrated sequence is claimed analyzed or reproduced. |
| E5 | Atxa Landa et al., [Evaluating Idle Animation Believability: a User Perspective](https://arxiv.org/abs/2509.05023), abstract | **D, abstract only:** the authors report acted and genuine idle motion were perceived similarly, while handmade and recorded motion differed. This supports considering performed reference; it does not prove a universal preference or transfer to cuboid mobile characters. Dataset videos were not inspected or imported. |
| E6 | [Animation-Driven Locomotion, GDC 2012 slides](https://media.gdcvault.com/gdc2012/slides/Summit_AI/Anguelov_Bobby_AnimationDrivenLocomotion.pdf), PDF pages **34–40, 49** (zero-based 33–39,48) | **D, selected text read:** start/move/turn/stop coverage, contact/passing annotations and residual sliding under motion planning. A highly specific navigation approach; not a recommendation to copy its clip counts, IK solution or architecture. Screenshot requests were not used as motion evidence. |
| E7 | [Animation Mentor: Dynamic Action & Combat](https://www.animationmentor.com/animation-program/game-animation-dynamic-action-combat/), overview/course description | **D, course text only:** combat and responsiveness are taught together, with weapon-dependent action. A curriculum description is weaker evidence than an inspected animator breakdown; no course video/reel analyzed. |
| E8 | David Rosen, Wolfire, [Angular and linear keyframe blending](https://www.wolfire.com/blog/2010/04/Angular-and-linear-keyframe-blending/), 2010 roll example, numbered keyframes 1–2 in author's discussion | **D, text read:** the author describes poor intermediate hand paths with linear blending and improved roll interpolation through hierarchical local rotation, while noting more complex cases combine approaches. Embedded images were not visually inspected here; no independently observed frames claimed. This is Overgrowth, not either Dungeons game. |
| E9 | Crytek, [Hit and Death Reactions System](https://www.cryengine.com/docs/static/engines/cryengine-5/categories/23756813/pages/23306580), “Overview,” “Some rules,” example data | **D, documentation read:** reactions depend on context and have explicit interruption/end policies. Its ragdoll and interruption rules are engine/game-specific; they do not mandate ragdoll or identical priorities for our project. |
| E10 | Natasha Krinsky tutorial summary, [Building a Standout Gameplay Animation Demo Reel](https://www.animationmentor.com/blog/tutorial-build-standout-gameplay-animation-demo-reel/), “Adding Character to Cycles,” 2026 | **D, article read:** movement can express intent/personality, and selected game examples are presented from several angles. Linked video was not watched. Use as a reminder to choose a performance intention, not merely a mechanical checklist. |
| E11 | [Godot 4.7 AnimationTree](https://docs.godotengine.org/en/4.7/tutorials/animation/animation_tree.html), synchronization and better-blending sections; [Blender slotted Action release notes](https://developer.blender.org/docs/release_notes/4.4/animation_rigging/) | **D, engine documentation/search-accessed release note:** distinguish timing/phase, missing-track defaults and slot assignment. Read alongside our actual runtime and fresh saved-file audit; no automatic migration. |

Additional attempts: David Rosen's large GDC 2014 PDF failed retrieval due to size; the GDC 2024 *A Second Shot* notes failed retrieval; Blender manual/export pages returned errors. Their search snippets were not promoted into inspected demonstrations. This research does not claim to have reconstructed Dungeons II's IK, shoulder translation, blend trees, motion capture, physics or rig hierarchy (**U/H**, not verified facts).

### Targeted reference acquisition for unresolved categories

If remote playback is unavailable in a future category task, request a local MP4/GIF or ordered PNG sequence with FPS/delays, original URL, exact source start time and game/build provenance. Prefer native-speed uncut footage, full body and visible ground, with at least a second before/after the action. No need to collect hours of unrelated footage.

| Needed clip | Useful minimum coverage / question it answers |
|---|---|
| Idle→move→idle | 10–20 s quiet idle plus departures/returns; separates base motion from occasional gestures. |
| Start/stop/turn | Several short starts, stops from walk/run, 90°/180° turns and both leads; exposes support and response timing. |
| Aim/strafe/fire | Sideways and backward travel while facing a target, then fire/recover; tests torso/hip/grip coordination. |
| Melee / ranged | One complete attack each, hit and miss if available, repeated fire/reload separately; identifies telegraph, active event and recovery. |
| Dodge / roll | Full preparation through recovery, side/three-quarter with floor; reveals actual contact and head clearance. |
| Hit / death / fall | Light/heavy impacts from known direction and a complete collapse or ledge fall; distinguishes reactive force, support loss and settling. |
| Transitions | Continuous rapid direction changes and interrupted actions; isolated GIFs cannot establish runtime policies. |

For each acquired reference log source time, decoded frame index/time, visible support, pose event, observation and uncertainty separately. Analyze original principles; never transfer proprietary character geometry, skeletons or keyframes into the commercial game.

## 8. Reusable quality checklist

Use **pass / revise / not applicable / not yet tested**, with evidence and exact frame ranges. A numerical score cannot override a failed support/compatibility gate or user judgment.

### Pose and performance

- [ ] Intent/action reads in silhouette at gameplay scale; lead/trail and open/compact contrast are clear.
- [ ] Arms remain attached and independently useful; wide motion does not become permanent spread.
- [ ] Cuboid dimensions, straight edges, proportions, full hands and texture identity remain unchanged.
- [ ] Support and weight transfer explain hip/chest motion; hip overlap is acceptable in all review views.
- [ ] Torso counter-response helps the action; head remains readable and does not mechanically copy torso motion.
- [ ] Asymmetry has a reason; quiet moments are quiet; grounded softness is controlled.

### Motion and contact

- [ ] Native-speed viewing precedes slow-motion diagnosis; contact sheets retain frame/time labels.
- [ ] Preparation, commitment, impact and recovery have deliberately different spacing.
- [ ] Hand/weapon/boot/head paths have coherent arcs; interpolation does not kink or overshoot unexpectedly.
- [ ] Lowest sole/body support is measured; intentional rocking is distinguished from sliding.
- [ ] No floor penetration, visibly detached joints or distracting nonadjacent intersections between keys.
- [ ] Compression does not require scaling, hidden fake joints or excessive hip burial.
- [ ] Impact has appropriate sharpness, delayed response and controlled settling; no midair ground bounce.
- [ ] Repeats and shared boundaries preserve pose and motion without extra held closing frames.

### Technical and contextual checks

- [ ] Source hashes/backups, rig signature, old Actions, slots, rotation modes and appearance preserved.
- [ ] Full-pose reset, Action switching, save/reopen and playback range verified for the actual current library.
- [ ] Evaluate actual blended poses, both leads, mirrored travel directions, grip variants and interruptions relevant to scope.
- [ ] Root/controller/preview travel has one declared owner; grounded offsets do not duplicate physics.
- [ ] Weapon/contact events occur once and agree with active/cancel windows.
- [ ] Front, three-quarter, side and gameplay camera compare the same timing/pose/stage; label holds and speed changes.
- [ ] Report contact drift in mm, clearance in mm, boundary position/velocity error with sample interval, and the measurement frame of reference. Historical sub-millimeter study results are comparison data, not fresh validation or universal tolerances.
- [ ] If integration is requested later: inspect imported timing, live Godot pixels and an in-game clip. Headless/import success alone does not pass visual quality.
- [ ] If mobile readiness is claimed later: profile the named target phone at representative load. Otherwise label performance untested.
- [ ] Explicit user approval refers to the exact reviewed version; technical success and pending registration never substitute for approval.

## 9. Future creation workflow and knowledge capture

**Research relevant references → inspect approved examples → design key poses → implement a separate Action → render comparison → evaluate → refine → request user approval → retain the approved version in Animation Showcase.**

The established library workflow allows compatible tests to be registered **pending** for review *before* approval. This reconciles the requested artistic sequence with the existing viewer process: author/refine in the separate study, register pending when needed for review, then only after explicit approval promote that exact entry and refresh/save. If review occurs outside Showcase, register it pending first and record the received approval explicitly. This research makes no registrations or status edits.

1. **Scope one behavior.** State intended feeling, entry/exit, weapon, support, travel ownership and success criteria. Read the relevant brief and actual current runtime; do not infer authorization for neighboring clips.
2. **Inspect only relevant references.** Use the named approved Action plus available external evidence. Record exact frames/times and unknowns. Avoid repeating all Dungeons research.
3. **Design 3–6 decisive poses and support phases.** Confirm silhouettes, grip and rigid-leg feasibility before polish. For difficult rolls/deep compression, resolve geometry first.
4. **Back up, author separately, preserve compatibility.** Keep approved sources immutable. Select timing/spacing to express the event; do not copy an approved Action's amplitudes indiscriminately.
5. **Render the comparison at original timing.** Same camera, character, lighting and floor; front/three-quarter/side plus gameplay-scale view where relevant. Show several loops or full one-shot with labeled endpoint holds. Preserve a baseline.
6. **Evaluate cause before cosmetics.** Correct support/travel and key poses, then timing/arcs, then torso/head overlap and small clearance. Record a short list of frame-specific issues and change one meaningful group per pass. Do not add noise to hide stiffness.
7. **Verify the saved result.** Slot/reset, geometry, contacts, loop/boundary and preservation checks appropriate to the change; use the current library manifest rather than an obsolete verifier expecting fewer entries.
8. **Request approval with concrete evidence.** State improvements, remaining limitations and Blender-only/runtime scope. Keep all undecided versions pending. On approval, update the exact manifest/status through the established workflow in a separately authorized creation task.
9. **Enrich the knowledge base.** Add a compact evaluation to that study, link it from Progress and the relevant category, and record what was learned. Preserve old evidence and supersede outdated conclusions explicitly rather than rewriting history.

### Reusable future-task brief

```text
Behavior/version:
Intent and gameplay context:
Approved anchors (Action, source, exact frames):
External evidence (URL, source time/decoded frames, access limits):
Entry → support/force phases → exit:
Key poses and camera/weapon constraints:
Timing/events/loop boundary:
Pose versus controller/preview travel ownership:
Allowed scope and protected files/Actions:
Review views, comparisons and technical measurements:
Unresolved risks and approval status:
```

### Record after each approval

Keep Action/source/slot/hash, exact approval/date/scope, tested camera/weapon/support conditions, three strongest frames, original-speed media, measured contact/continuity results, limitations, and one or two reusable lessons. For example: “A6: earlier second support and delayed chest settling clarify weight” is useful; “all future landings must dip 120 mm” is an unjustified generalization.

## 10. Recommended production order

This is a proposed sequence, **not authorization to start it**. Complete and review one behavior at a time; use its transitions as part of that behavior rather than postponing all blending until the end.

1. **Ready idle and expressive walk.** Establish the quiet baseline and a walk complementary to approved Run. These expose support and amplitude differences early.
2. **Forward start/stop into walk, then run.** Close the highest-frequency transition gaps; test both leads and short input taps before expanding directions.
3. **Turn-in-place, curved movement, then strafe/backward.** Prove one direction first; retain support and later add aim-facing constraints.
4. **One weapon-ready/grip study, one melee attack and one ranged-fire study.** Choose actual game weapons; resolve rigid-arm feasibility and event timing before combos/reloads.
5. **Light hit reaction, then stagger.** Reuse A6 receiving principles while establishing force direction, support and interruption priorities.
6. **Lateral evade, then a separate roll feasibility decision.** Evasion can reuse established start/receive mechanics; rolling introduces more severe rigid-body contact limitations.
7. **One death collapse and a distinct falling study.** Establish terminal states and multi-surface contacts after reaction mechanics are reliable; keep ragdoll optional and unproven.
8. **Broader transition/variant coverage, then separately requested runtime/mobile validation.** Add combos, directions, weapons and terrain only as gameplay demands. Existing approved jump components remain references; the pending full-jump study is not promoted or remade by this plan.

The immediate knowledge gain is a reusable way to design motion around **support, force, pose contrast and transition contracts**. The remaining research gap is targeted continuous motion evidence for new behaviors, not another broad survey of block-character rigging.

## 11. Documentation-task verification scope

This task wrote only this new guide in the repository. The original style guide and existing status records were not edited. The saved-file Blender audit used background mode with auto-execution disabled and no save operation; no foreground Action/pose selection was changed.

A before/after hash check covered 368 selected files: the style guide, manifest-listed study sources, Showcase and Godot scripts/scenes/project configuration. At verification, **367 matched**, while `Animation_Showcase.blend` had changed independently during the task. That change was left untouched; this report does not claim global workspace immutability or restore concurrent work. The guide's local links and all nine category sections were checked. These documentation checks do not validate a new animation, export or runtime behavior.
