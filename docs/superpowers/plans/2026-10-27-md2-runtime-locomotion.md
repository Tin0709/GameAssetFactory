# Native MD2 runtime locomotion evidence

**Goal:** Resolve actual movement/animation-state relationships and apply only justified improvements to the existing Sabre controller.

**Architecture:** Reuse the private Research library and existing lab. First pursue a bounded external read-only process snapshot based on validated public NativeLoader object/name layout; no injection, memory writes, executable changes, new loader, protection bypass or third-party execution. If ordinary read access is unavailable, stop that route. Inspect recovered reflected offsets/owners before treating values as evidence. Then record live game state using authorized UI actions and bounded sampling, compare the same measured state inputs in Godot, and change only verified relationships.

**Tech Stack:** Existing Python/ctypes/Windows read APIs, already installed MD2/approved loaders, Godot4.7.2/Blender5.2. No new software install.

**Spec:** Latest user request; speed700, Run1.25, acceleration48/deceleration42 need runtime verification. Preserve previous3fidelity fixes, original assets, accepted jump and graphics. No new scene/project/engine. Private data remains Research-only and excluded from current Git tracking before capture.

- [x] Validate a new read-only evidence route against public loader source and known reflected types.
- [x] Recover active player/component/attribute/animation owners and defaults; capture standing state and bounded input attempts. Actual moving original-game trace remains unavailable because injected gameplay inputs are not received; optional human input requested.
- [x] Independently compare units, speeds, velocity response, animation asset settings and contact/notify evidence. Final native graph normalization/weights/rates remain unresolved.
- [x] Reproduce concrete ground-response mismatches with failing tests, implement optional private-profile mapping and source-clock event hooks; label remaining adapters.
- [x] Validate30/60/120physics,27suites/1123checks,32bone/264time parity, unchanged source hashes and same native full-grass lab12frames/513states. Update existing findings. Independent code review issue fixed with failing/passing regression.

Remaining after the initial pass (human-trace limitations superseded below): human-controlled motion, stock/WASD policy,2H/Sabre layer, air/combat overrides and native support/contact/IK/audio routing. No complete native movement-equivalence claim or additional tool installation.

## Human-trace continuation

Human trials now recover actual1HMedium/Sabre owners,700cm/s normal ground response and10clean gait segments at median1.88832normalized cycles/s. The equipped1H layer uses the existing Master Idle/Walk/Run sources; input1 yields a derived2/9Walk+7/9Run blend and weighted period.52963s, independently matching native cadence. The previous pure Run1.25x clocks2.8846cycles/s and is incorrect for this observed state.

- [x] Add source-only gait composer using existing imported tracks/shared phase/private settings. Raw review, files, air/fallback/three fixes preserved; no new scene/project.
- [x] Cadence red→green;35gait checks and28suites/1158checks pass. All32bone source anchors, phase/notify/handoff, malformed optional metadata, independent264time parity, unchanged hashes, full-grass12frame/513state native study and64/64corrected face frames verified. Reviewer issues repaired and reverified.
- [x] Consolidate native Sabre UpperBody montage/composite references/early ResumeMovement/leg filters and jump data. CORRECTION: main RecoveryStart keys are stable across snapshots; prior variation confused cached EndLink. The later2026-10-27-sabre-combat-locomotion plan supersedes the historical whole-body plant/.45u policy; original queue latency remains unresolved.

Review focus: class defaults versus live instances, derived versus inherited properties, large-world double vectors versus floats, bitfield booleans, asynchronous sampling uncertainty, active modifiers and UI/menu/pause ownership. No values inferred from arbitrary byte patterns.
