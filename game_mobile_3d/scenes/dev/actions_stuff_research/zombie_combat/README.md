# Source zombie combat — development only

This component is loaded only by the existing `ActionsStuffWalkRunTest` research scene. Read `docs/animation/reviews/zombie_rifle_combat_v001/README.md` at the repository root for source mappings, source-vs-gameplay adapters, controls, lifecycle, rebuild and validation.

Reuses the original CuboidZombie actor/model/feedback plus the existing unchanged ZombieDeathPhysicsLab native ragdoll/Rifle preset. Exact Mobs research Idle/Walk/Attack full evaluated clips are in `source_library.res`; source/status/hash metadata is in `profile.json`. Both Blender libraries and all source Actions are unchanged. The enabled research export guard excludes this directory from releases.

Four enemies, no automatic respawn; R resets. One handoff per lethal hit,1.20s visible physics, maximum four ragdolls/28native bodies, complete resource teardown. Existing AI attacks play the source animation with damage0 so this remains a player-animation/combat research environment. No production player-health/death redesign.
