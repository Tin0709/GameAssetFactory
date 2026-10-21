# Zombie Hit Feedback Implementation Plan

> Execute natively in this session; user already authorizes implementation and immediate gameplay review. No delegation or extra approval gate.

**Goal:** Make every rifle bullet readable while keeping zombies responsive.
**Architecture:** Retain the existing source pose sampler, damage contract and native Lab death graph. Add a bounded, analytic upper-body impulse after living pose sampling; prewarm the existing UI assets in the dev adapter.
**Tech Stack:** Godot 4.7.2 / GDScript, native Skeleton3D/PhysicalBone3D, existing shared materials/audio/impact pools.
**Spec:** User's Zombie Hit Reaction & Combat Feedback request in this chat; source findings and implementation evidence in `docs/animation/reviews/zombie_hit_feedback_v001/README.md`.

## Constraints

Same `ActionsStuffWalkRunTest.tscn`, no new scene/project/Action. Preserve player/Combat Strafe source files, 6Hz infinite fire, 2.70/~7.55m/s, camera/jump/turn controls, WorldMap and approved Blender assets. Retain native death impulse240/48N·s, gravity18 and cleanup1.20s. Research/dev only.

## Review Focus

- World-space side/front/back impacts when the zombie itself rotates.
- Repeated6Hz and same-tick bursts must remain bounded without restarting recovery.
- Feet/gait must remain source-authored while the upper body reacts.
- A lethal hit during recovery must retain the last pose and trigger one native death.
- Feedback and physics resources must stay bounded across hits, cleanup and reset.

## Task 1 — Live hit layer and bounded feedback

Files: modify `game_mobile_3d/scenes/dev/actions_stuff_research/zombie_combat/source_visual.gd` and `physics_zombie.gd`; create sibling `hit_feedback.gd`; test `tests/test_zombie_hit_feedback.gd` in the same research directory.
Interfaces: existing `take_damage(int, Vector3)->bool`, `flash_hit(float)`, `hit_impulse(Vector3)`, `_process(float)` and native `ragdoll.sample/begin/release` remain compatible.

- [x] Inspect Mobs library, direct pack entity/render/controllers, current damage and native Lab implementation.
- [x] Write behavioral regression; run RED and confirm missing directional motion, unbounded burst knockback and per-hit number nodes.
- [x] Add post-source world-space damped impulse, cap7deg/12mm, quick recovery; preserve hips/legs/clocks.
- [x] Use65ms existing flash, existing impact/audio pools, four prewarmed number slots per zombie; bounded1.6m/s nonlethal knockback.
- [x] Run GREEN at30/60 and existing death/fire/autoaim/Combat Strafe checks.
- [ ] Inspect native30/60 gameplay captures, record file preservation, then open the same scene with ordinary audio for user review.

No manual commit or Git history/tracking changes: existing workspace auto-sync owns persistence.
