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

Remaining: human-controlled MD2 motion sample; stock versus installed WASD input policy; current2HMedium versus Sabre-specific layer; air/world-gravity and combat effect overrides; native support/contact/IK and audio/surface routing. No claim of complete native movement equivalence. No further tool installation or loader change was needed.

## Human-trace continuation

Human trials now recover actual1HMedium/Sabre owners,700cm/s normal ground response and10clean gait segments at median1.88832normalized cycles/s. The equipped1H layer uses the existing Master Idle/Walk/Run sources; input1 yields a derived2/9Walk+7/9Run blend and weighted period.52963s, independently matching native cadence. The previous pure Run1.25x clocks2.8846cycles/s and is incorrect for this observed state.

- [ ] Add a small source-only gait composer using existing imported tracks, shared phase and recovered private sample settings. Leave raw review, source files, airborne timing, fallback and the three prior pose fixes intact. Use the existing final pose pipeline; no scene/engine/project replacement.
- [ ] Prove failing cadence first, exact all-bone anchor sampling, phase/notify/transition semantics and private-profile fallback. Validate complete regressions and actual full-grass viewport, then review changes.
- [ ] Consolidate live combat montage/ResumeMovement/slot and jump evidence. Do not substitute unresolved composite/slot behavior with an unverified full combat rewrite.

Review focus: class defaults versus live instances, derived versus inherited properties, large-world double vectors versus floats, bitfield booleans, asynchronous sampling uncertainty, active modifiers and UI/menu/pause ownership. No values inferred from arbitrary byte patterns.
