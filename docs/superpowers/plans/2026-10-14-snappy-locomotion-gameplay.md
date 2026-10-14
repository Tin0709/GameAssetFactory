# Snappy Locomotion Gameplay Test

**Goal:** isolated playable A/B test of current provisional Snappy Walk, Pending Snappy Run and approved Idle, preserving production and all Blender data.
**Architecture:** extend existing expressive locomotion actor/sole pose writer and its inertial pose transition/contact hooks. One AnimationPlayer remains stopped; no new AnimationTree/layer or controller rewrite. Existing Expressive clips remain read-only A/B controls. Same capsule speeds in both styles:1.59936m/s Walk and2.5m/s Run; distance-driven stride lengths preserve appropriate cadence. Style switches blend on the persistent normalized gait phase without resetting it. Approved Idle remains normal speed.
**Spec:** the user's current milestone request and architecture commentary. Flat-ground test only; no jump, weapons, new animations or production promotion.

- [x] Write failing isolated-scene runtime tests before implementation.
- [x] Read-only120Hz source export; verify source hashes, actual Action signatures, slots, rest transforms, mesh reconstruction and physical sole-height/contact curves. Snappy Walk's common hop requires actual contact-height awareness; do not flatten it with the manifest's nominal support duty.
- [x] Add test-only visual adapter and inherited controller scene. Smooth style/Walk-Run transitions, latch support duty at receiving events, reuse single-foot Idle replant and bounded contact correction; smooth visual facing without delaying capsule input.
- [x] Add playable A/B toggle, cameras,30/60 FPS toggle, controls and deterministic no-pause review demo.
- [x] Validate physics60Hz at both30 and60 render FPS: starts, stops, reversals,90deg turns, rapid direction changes, style toggles, contacts, rigid scale, full Run target, loop and independent Idle timing.
- [x] Capture original-speed gameplay and synchronized same-control A/B videos; inspect native frames and metrics. Diagnose remaining Run-vs-Walk limitations by comparing unblended source and runtime.
- [x] Preserve all prior files, record controls/limitations and launch a separate playable window. Stop for artistic gameplay review.

Ruling: use new files in existing workspace because source reviews and imported runtime resources are local to this checkout; preserve existing scripts/scene/project settings and protect hashes instead of resetting or copying the large working tree.
Ruling: A/B shares capsule physics and travel speed. Expressive clip cadence is distance-driven at that matched speed; this is a style comparison, not an exact replay of the old pace2.25 directional/jump lab. No weapon/jump branches enter this test.

## Authorized scope update
User explicitly approves both current Snappy Blender Actions; record artistic approval without production promotion. User then requests matching the existing Expressive test speed and adding jumping. Preserve the native test/review and add a separate FastJump scene using the existing jump controller/clips, same pose writer and directional stride policy. Do not author new Actions. Validate the faster pace, airborne/landing contact ownership, interruptions, buffered jumps and both styles at30/60FPS.

## Completed review state

Both current Snappy Actions artistically approved; production promotion remains unapproved. Native72checks per30/60FPS plus FastJump41 each on rendered D3D12 Mobile. Exact measured old speed/camera matched, existing jump reused. Fresh review found GUI Space conflict; failing test reproduced it, input reservation fixes it. Added Walk-jump coverage exposed preparatory floor penetration; bounded existing35mm clearance policy applied during PREP, no guard relaxed. Source/source-review hashes protected. Movies original speed with same controls; final documentation links controls, limitations and preservation audit. Stop for user review.
