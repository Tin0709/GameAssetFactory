**2026-10-22 — Current scene performance mode:** The existing lab now opts into an adjustable 0–50 batch, default20, and removes lighting review props. See `../performance_lab_v001/README.md`. The original four-actor encounter below remains the opt-out fixture; source visuals, AI and death physics remain unchanged. Both modes cap performance-mode active corpses at4 via the new admission subclass.

# Source zombie combat — development only

This component is loaded only by the existing `ActionsStuffWalkRunTest` research scene. Read `docs/animation/reviews/zombie_rifle_combat_v001/README.md` at the repository root for source mappings, source-vs-gameplay adapters, controls, lifecycle, rebuild and validation.

Reuses the original CuboidZombie actor/model/feedback plus the existing unchanged ZombieDeathPhysicsLab native ragdoll/Rifle preset. Exact Mobs research Idle/Walk/Attack full evaluated clips are in `source_library.res`; source/status/hash metadata is in `profile.json`. Both Blender libraries and all source Actions are unchanged. The enabled research export guard excludes this directory from releases.

Four enemies, no automatic respawn; R resets. One handoff per lethal hit,1.20s visible physics, maximum four ragdolls/28native bodies, complete resource teardown. Existing AI attacks play the source animation with damage0 so this remains a player-animation/combat research environment. No production player-health/death redesign.

## Live bullet feedback (2026-10-21)

Surviving hits now add an original bounded directional upper-body impulse after source sampling,65ms existing flash and restrained capped knockback; feet/gait and AI remain active. This is an explicit gameplay adaptation: the audited zombie pack has hurt color/armor-sound logic but no mapped skeletal Hurt clip. Four prewarmed existing number labels per actor replace per-hit nodes; existing projectile impact/audio pools remain. Lethal hits retain the last displayed pose and the existing native death lifecycle. Full evidence, limits and30/60/native checks: `docs/animation/reviews/zombie_hit_feedback_v001/README.md` at repository root. Player/Combat Strafe and approved assets are unchanged; awaits user review.
