# MD2 Sabre movement correction

> Execute inline with systematic debugging, test-driven development and final verification. User requests an implementation in the existing lab, not another project or a design approval round.

**Goal:** Correct the playable source-profile pace from the public player movement table; measure physical travel and gait, without editing approved source assets.

**Architecture:** Existing actor owns capsule travel and source animation sampling. Separate the gameplay speed from measured source stride reference speeds. Mode supplies camera-relative human input and an optional compact measurement overlay. A small RefCounted meter collects actual displacements; no source assets enter Git.

**Tech:** Existing Godot4.7.2 project, original external private GLB, GDScript, installed Python for source audits.

**Spec:** User's latest request in this chat; preserve original character/Sabre/rig/actions, grass, terrain, lighting and existing scene. No video calibration. Public raw-table values have community-extracted provenance, not verified local1.1.3 runtime provenance.

## Evidence and decisions

- Public MCFUN original JSON identifies DT_PlayerDefinition#0: MovementSpeed700, multiplier1, JumpCoyoteTime.155. DT_MobType1Definition#0/#1/#2:300/400/500. Store raw JSON only in ignored Research/source_snapshot/public_tables. No copied raw table in the public project.
- Unreal actor velocity is cm/s; use the conventional100UU per metre/one Godot world unit. Effective MD2 attribute-to-controller conversion and runtime scale remain unverified.7units/s is a declared table-derived baseline, not a claimed measured native velocity.
- Human WASD defaults to normal Run; Shift provides the existing2-unit slow Walk as an accessibility/study adapter. Scripted requested_run keeps its existing explicit semantic contract. Authored fallback and legacy mode retain their controls.
- Gameplay gait clock follows actual distance divided by existing source-kinematic stride length. At7units/s, Run's existing5.6-unit/s stance fit implies1.25 playback. This is a disclosed distance/cadence adapter, not a recovered MD2 play-rate formula. Raw review remains1x; attacks/jumps remain independently timed.
- Source Run is asymmetric. Do not falsify perfect foot locking or translate/stretch approved legs to hide that uncertainty. Measure world sole movement during low-foot candidate contacts; distinguish it from confirmed slip/load. Preserve direction/phase adapters.
- Preserve current acceleration48/deceleration42, turning12rad/s, attack travel.22, jump height1.2/gravity15 and camera. They remain adapters because native values were not obtained. Add recovered-table.155coyote window without deriving physics from pose duration.
- UE4SS experimental3.0.1-1183 was explicitly approved, downloaded/hash verified and attempted. It crashed before Lua init; added proxy rolled back, original winmm unchanged. No runtime values or protection bypass. Do not let inspector compatibility block the playable correction.
- Public Sabre row confirms1HMedium layer/combo montage and per-variant attack-speed data; it does not establish movement blend/root-motion notify parameters. Do not invent those or change approved attack timing in this movement correction.

## Task1 — Physical pace, input and gait

- [x] Add real-actor tests proving ordinary human input reaches7, Shift2, diagonal same speed, actual distance, camera-relative directions, gait advances by travel/stride and raw review stays1x; watch pre-fix assertions fail.
- [x] Implement the minimal source-profile changes in actor.gd and mode.gd. Keep explicit scripted walk/run and independent attack/jump clocks.
- [x] Test coyote acceptance/rejection and one jump per press. Preserve original jump trajectory until actual native values can be read.
- [x] Update prior fixtures only where their documented superseded speed/control assumptions change; keep their underlying regression coverage.

## Task2 — Inspectable movement measurements

- [x] Test actual path/net distance, wall blocking, response95 and stop distance; do not integrate requested velocity as travelled distance.
- [x] Add bounded movement_meter.gd and native-sole snapshots; reset without moving the actor.
- [x] Add toggle/reset/save controls to existing CanvasLayer, compact bottom-right overlay. No new scene, resource/project settings or environment edits.
- [x] Save aggregate measurement results under private Research, not proprietary poses or resources in project/Git.

## Verification

## Task3 — User-reported motion softness, double image and stepping

- [x] Diagnose actual viewport scaling/AA and the source-specific presentation route. Preserve physical speed and original pose clocks.
- [x] Test full-resolution source display separately from lighting/shadow tiers; expose a reversible toggle, keep original A/B/tier semantics.
- [x] Test render-fraction interpolation for original32-bone skin, rigid Sabre and camera together; rendering must not write authoritative skeleton/capsule/markers/events. Exact endpoints including weapon scale and reset/teleport history.
- [x] Keep ribbon/particles on the same display time, preserving physical VFX sampling/events/pool limits.
- [x] Validate30/60Hz fractional render samples and native Mobile/D3D12 pixels. No TAA/motion blur/sharpening added. Standard one-physics-tick display delay is disclosed.

## Final verification

## Task4 — Subsequent user combat and camera steering

- [x] Verify source Sabre AttackSpeedMultiplier1.2/1.2/1.0 in gameplay, preserving raw review1x and wall-time input buffering. Recoveries stay1x because their rate relationship is not established.
- [x] Align private sample envelope targets and VFX windows with the configured motion rate, retaining source audio pitch.
- [x] Apply the public HeavyJumpAttack GravityMultiplier2 only to source aerial attacks until physical landing. Ordinary jump remains the disclosed ballistic adapter. Test actual apex-to-floor travel at30/60Hz.
- [x] Audit camera projection, direction, framing, damping and jump behavior; expose inspectable current values and a reproducible baseline reset. Do not substitute co-op4000 arm length for unverified solo configuration or calibrate native constants from video.
- [x] Native same-scene combat/camera validation, source preservation hashes, final regression and independent review.

- [x] Meaningful Godot checks30/60Hz, existing Sabre suites, physics contact/phase/combo/audio regressions; all automated runs use Dummy audio.
- [x] Native Mobile/D3D12 run of this same scene, inspect the overlay and controls. Runtime frames verify this lab, never estimate original MD2 values from pixels.
- [x] Rehash original source GLB/showcase; audit diff for only controller/debug/tests/docs changes. No manual stage/commit while checkpoint manager is active.
- [x] Final independent review if available, fix substantive findings, rerun affected checks. Document remaining runtime/foot-contact/attack-root-motion uncertainties in existing module README.

## Verified outcome

2026-10-26: 857 checks across16 suites passed, plus same-scene native Mobile/D3D12 movement8frames, combat/camera8frames and virtual144Hz/60physics display continuity. Independent review P2 event-clock issue fixed and re-reviewed with no remaining P1/P2. Original GLB/showcase hashes unchanged; project/scene/environment files unchanged from task base. Both approved UE4SS starts failed before Lua and were rolled back. Native solo camera, ordinary jump and effective movement formulas remain unresolved; this completes the scoped playable fixes and audit, not a claim of exact engine equivalence.
