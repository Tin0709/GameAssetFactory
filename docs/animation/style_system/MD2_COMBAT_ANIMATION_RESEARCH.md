# Minecraft Dungeons II combat research — Phase 2

2026-10-25. Research/design only: no game archive opened, no model/Action/scene created, no library/status/runtime changed. The result is a practical original-animation brief, **not a reconstruction of MD2 internals**. Read [frame analyses](MD2_COMBAT_FRAME_ANALYSES.md) for observations and [original melee framework](ORIGINAL_MELEE_COMBO_FRAMEWORK.md) for the proposed three-hit sword design.

**O** observed public pixels/video metadata; **E** bounded estimate/inference; **S** previously verified A&S source; **P** original GAF proposal; **U** unknown. Epic documentation describes **UE capability**, never proof that MD2 uses it.

## Evidence and scope

Phase1's [external report](</Users/tin/Documents/ChatGPT/New project/research/md2_archive_phase1_20261025/MD2_Archive_Phase1_Report.txt>) and inventory remain unchanged: RAR5,121 encrypted regular files, Unreal-like WinGDK layout, authenticity unverified. The archive fingerprint is `5d4c3c2a5062841bb853f4439587dcc312bd0e50073baeb477e789da9d631fef`. Phase2 did not retry its headers, seek passwords/keys, decrypt, decompile or execute anything from it.

Primary public routes:

| ID | Source and inspected scope | Use/limit |
|---|---|---|
| V1 | Minecraft verified channel, [official gameplay trailer](https://www.youtube.com/watch?v=vBNE3bKMpu8), notably35–60s; paused browser frame stepping and captured mediaTime | Official edited gameplay, multiple actors/effects. Cuts censor attack beginnings; some shots are cinematics/UI. |
| V2 | XboxDynasty, [first9minutes](https://www.youtube.com/watch?v=mgzk7uhAfjk), cached150–158s and220–228s; public title/channel rechecked | Continuous creator footage, two decoded60FPS clips. Publisher build identity/unmodified playback are not independently authenticated. Cache has no audio. |
| D1 | Minecraft, [gameplay systems](https://www.minecraft.net/en-us/article/minecraft-dungeons-ii-gameplay-systems),2026-08-31 | Officially describes expanded equipment, jumping/jump attacks and projectile ammo that replenishes. Does not supply combo frames, rig or state machine. |
| D2 | Xbox Wire, [gamescom hands-on](https://news.xbox.com/en-us/2026/08/26/minecraft-dungeons-ii-new-features-gamescom-2026/),2026-08-26 | Reports bow/sword/Artifact interplay and short cooldowns; qualitative design context, not measured timings. |

Search also encountered modified combat showcases and third-party asset-reference databases. They are excluded from timing/technical claims: altered stats/speed or unclear data provenance would contaminate this study. No public-video download succeeded through the browser media helper; analysis used public paused playback plus existing local public-footage caches. No new full video is stored in Git.

## Weapon coverage: do not fill missing evidence with guesses

| Requested family | Observed attack evidence | Status / original direction |
|---|---|---|
| Sword | G01/G02/G03: single straight blade, fast yellow sweep, target flash then damage number; two sequential contacts | **O** sword-shaped silhouette; exact item unknown. **P:** compact load, decisive diagonal arc, useful recovery. |
| Daggers / fast melee | Fast single-blade follow-ups are observable; no confidently identified unmodified dual-dagger sequence found | **U** dagger choreography/timing. Do not rename the sword sample “daggers.” **P:** shorter reach/compact alternating arcs after a real selected asset exists. |
| Axe | No confidently identified axe attack with readable start/contact/recovery in the reviewed sources | **U** MD2 axe timings. **S:** A&S has scoped axe variants[C02]. **P:** head-heavy load and deliberate recovery; not measured MD2 behavior. |
| Hammer / heavy | T03: square-headed melee silhouette candidate, visible arc/burst on a bridge | **E** hammer-like, exact type unconfirmed; start cut and50ms sampling. **P:** stronger preparation/brace, short release, controlled receive. |
| Ranged | T02: multiple bright projectile trails across a ledge | **O** flight; shot starts mid-flight after edit. Weapon/release/impact remain **U**. Preserve rifle's own approved cadence, ammo and grips. |
| Special skills | T01: affected silhouettes, starburst, expanding disc then particles | **O** presentation sequence; caster/skill/damage radius unknown. **P:** readable setup→brief local impact→quick decay, scaled for mobile. |

All six requested families are assessed; full measured attacks are **not** available for every family. This is the coverage boundary, not a fabricated animation catalog. Frame-based anatomy/contact/SFX fields and censored intervals are explicit in the appendix.

## What makes the observed presentation useful

**O:** In continuous melee, a new target flash precedes its new damage numeral by one decoded video frame in three inspected events. G01→G02 flashes are45frames/.75s apart. A broad blade trail and enemy response remain readable even when the actual hand-to-target intersection is obscured. These describe rendered feedback, not damage scheduling.

**E:** Large spacing contrast and a quiet return silhouette help separate attacks. Torso/hip opposition and weight transfer are plausible artistic readings, but pixel resolution, elevated camera and clothing prevent reliable bone angles, compression amplitude, foot load or support-contact measurement. A large effect is not evidence of a heavy weapon or hitstop.

**P:** Use the contrast, not copied trajectories: load a connected rigid stance, pass quickly through ambiguous silhouettes, emphasize weapon direction and receiving posture, then settle or redirect without a neutral reset. Retain gameplay responsiveness and keep effects from hiding the next readable pose. MD2's crowded multiplayer VFX is an artistic reference, not a target effects budget.

## Unreal Engine architecture: supported technologies, not MD2 findings

The following table is a capability map based on official Epic documents. These are conceptual analogies for GAF's existing Godot pipeline, not a proposal to migrate engines.

| UE technology | What the documentation supports | Practical combat use / caution |
|---|---|---|
| [Skeleton / skeletal mesh](https://dev.epicgames.com/documentation/en-us/unreal-engine/skeletons-in-unreal-engine) | Hierarchy, bone transforms, shared animation data and attachment sockets | Define actual rig/weapon frames; helper bones do not require visible joints. MD2 bone list is unavailable. |
| [Animation Sequence](https://dev.epicgames.com/documentation/en-us/unreal-engine/animation-sequences-in-unreal-engine) | Time-sampled position/rotation/scale tracks tied to a Skeleton | Author separate attacks; distinguish sample rate, play rate and game FPS. Retargeting still needs a rest-basis contract. |
| [Animation Blueprint](https://dev.epicgames.com/documentation/en-us/unreal-engine/animation-blueprints-in-unreal-engine) | Graphs blend/control bones to produce the final pose | Compose locomotion and a transient action; keep a single final writer in GAF. A video cannot identify a Blueprint. |
| [Montage / Sections / Slots](https://dev.epicgames.com/documentation/en-us/unreal-engine/animation-montage-in-unreal-engine) | Combine sequences, play named sections in runtime-selected order, route through slots/groups | Could represent attack1/2/3 and recovery. Sections alone do not implement input buffering, collision or hit-confirm rules. Slots are not automatically upper-body masks. |
| [Notify](https://dev.epicgames.com/documentation/en-us/unreal-engine/animation-notifies-in-unreal-engine) | Discrete events synchronized with sequence playback | Cue whoosh/step/trail markers. Event visibility/weight/filtering does not replace gameplay authority. |
| Notify State (same document) | Begin/update/end across a duration | Express an active blade/trail interval. Explicitly close/cancel on interruption; never leave damage enabled after an abort. |
| [Sync Groups / Markers](https://dev.epicgames.com/documentation/en-us/unreal-engine/animation-sync-groups-in-unreal-engine) | Synchronize related cycles using leader/follower roles and compatible semantic markers | Align support/phase across compatible gait transitions. A marker is not physical foot IK or a universal fix for incompatible poses. |
| [Root Motion](https://dev.epicgames.com/documentation/en-us/unreal-engine/root-motion-in-unreal-engine) | Root animation can drive character displacement when enabled; movement-driven characters are another path | Keep GAF capsule travel authoritative for v1. Do not add authored lunge displacement on top of controller travel. No MD2 root-motion mode is established. |
| [Layered animation](https://dev.epicgames.com/documentation/en-us/unreal-engine/using-layered-animations-in-unreal-engine) | Blend/add/override selected bones and descendants; upper shooting can coexist with running | Preserve legs/gait while an upper action plays. Apply both weapon hands coherently after composition; avoid double torso rotations. |
| [State machines](https://dev.epicgames.com/documentation/en-us/unreal-engine/state-machines-in-unreal-engine) and [transition rules](https://dev.epicgames.com/documentation/en-us/unreal-engine/transition-rules-in-unreal-engine) | Conditions determine transitions; blend settings and interruption behavior can be configured | Define Ready/Prepare/Active/Recover/Interrupted and explicit priority. Recovery/cancel windows are game design, not automatically supplied by a montage. |

GAF can borrow these **responsibilities** without reproducing UE classes: persistent gait phase, an action cursor, channel ownership, event intervals and controlled exits. No public technical evidence here establishes MD2's exact UE version, AnimBP/Montage use, network authority or event code.

## Combine with verified Actions & Stuff principles

Use [source evidence](SOURCE_EVIDENCE.md) and the [Bible](MOTION_STYLE_BIBLE.md), not one universal bounce curve.

| Principle | Verified A&S basis | MD2 footage observation/limit | Original GAF synthesis (**P**) |
|---|---|---|---|
| Snappy timing | S:P03 uneven plain keys plus analytic body waves | O: blade sweeps/flash change rapidly; exact action start often censored | Short decisive drive between readable poses, with different curves per weapon. |
| Anticipation / weight | S:C01–C04 context-specific attack layers; P03 asymmetric body waves | E: preparation/brace, but no reliable CoM or force measurement | Load within rigid leg reach; no mandatory input delay or rubber scale. |
| Bounce/compression | S:P05/P06 contextual receiving/landing layers | U: no defensible millimetres of MD2 compression | One motivated receive and small settle; check final soles, not timer-driven bob. |
| Rigid coordination | S:P03 source Run/Jump do contain scale exceptions | O:block silhouettes; U:internal rig topology | New originals keep full straight limbs/unit scale; distribute torso intent over the actual target controls. |
| Arc and impact | S:C09 source presentation events are not damage authority | O:target flash, trail and number can appear at different video frames | Sweep actual blade geometry; impact feedback only on confirmed hit. |
| Follow-through | S:C01 sword has three branches and minimum .3s repeat gate | O:G01/G02 successive feedback; U:input/buffer state | Design separate entry/exit velocities and a one-intent buffer; do not copy the source gate as our combo rule. |
| Smooth transitions | S:P02 shared phase/hysteresis; P05 explicit handoffs | U:no proof of MD2 blending method/cancel windows | Keep source gait phase, release unreachable anchors and cancel events explicitly. |

## Existing GAF integration audit

**A, read-only 2026-10-25:** the existing [lab scene](../../../game_mobile_3d/scenes/dev/ActionsStuffWalkRunTest.tscn) loads `walk_run_test.gd`; it chooses `rifle_visual.gd`, then inherited Jump→Walk/Run→Expressive composition. Approved `AnimationLibrary` resources are sampled into transforms. No active AnimationTree-driven melee controller was found in this lab; an AnimationTree exists as a Godot capability, not an architecture we should invent here.

[Soldier loadout](../../../game_mobile_3d/scenes/dev/actions_stuff_research/soldier_loadout_v001/loadout.gd) installs appearance by mapping Skin binds onto the existing runtime Skeleton. Its standalone10-bone Blender rig does **not** replace that Skeleton. The central [manifest](../../../blender/animation/showcase/animation_manifest.json) still targets Showcase13. Keep [rig/rest/slot constraints](RIG_CONSTRAINTS.md); do not silently merge rigs.

[rifle_visual.gd](../../../game_mobile_3d/scenes/dev/actions_stuff_research/rifle_ready_v001/rifle_visual.gd) preserves distance-derived gait, masks Aim above the lower-body pipeline, restores prior overlays, and reconciles gun/hand contacts after the base pose. [continuous_fire.gd](../../../game_mobile_3d/scenes/dev/actions_stuff_research/rifle_ready_v001/continuous_fire.gd) gates fully raised/aligned Aim,6Hz fire and fixed projectile/impact pools. [rifle_presenter.gd](../../../game_mobile_3d/scenes/dev/actions_stuff_research/rifle_ready_v001/rifle_presenter.gd) keeps render gun/hands coherent. Future melee must occupy an explicit action/weapon branch in this same ownership model, not stack a competing player on the skeleton or leave rifle constraints active on a sword.

The [Weapon Showcase manifest](../../../blender/weapons/showcase/weapon_manifest.json) currently supplies seven active ranged weapon entries, not a selected melee asset. Existing [Animation Showcase](../../../blender/animation/showcase/README.md) registration, separate Pending Actions and Blender artistic review remain the route. Existing rifle approval does not license its source-derived Aim base for commercial reuse. See [approved references](APPROVED_REFERENCES.md).

Keep current input/speeds, held-E Aim/fire, Q/C turning, .60s180° acquisition, Jump, camera, combat, death physics and production WorldMap exact. [Framework](ORIGINAL_MELEE_COMBO_FRAMEWORK.md) contains proposed event/buffer/interrupt conventions only. No runtime tests or FPS improvement are claimed by this documentation task.

## Remaining unknowns and next authoring prerequisite

Unknown: MD2 rig, keyframes, engine version, section/notify names, actual damage frames, hitstop, root-motion mode, sync groups, hitbox volumes, input buffer, cancel priority, runtime layering, audio/video offsets, source/editor files and rendering code. Public video cannot resolve these. Missing confident dagger/axe footage and only-candidate heavy identity remain explicit gaps.

Before the next Blender task, select one actual licensed/original sword and its grip/blade markers, confirm the compatible source rig, then author **one** proposed quick slash for review first. The three-hit design is a coherent brief, not authorization to make all Actions or integrate gameplay now. Verify blade clearance, support and camera readability before tuning the proposed numbers.
