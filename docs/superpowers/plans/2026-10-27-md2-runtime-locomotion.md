# Native MD2 runtime locomotion evidence

**Goal:** Resolve actual movement/animation-state relationships and apply only justified improvements to the existing Sabre controller.

**Architecture:** Reuse the private Research library and existing lab. First pursue a bounded external read-only process snapshot based on validated public NativeLoader object/name layout; no injection, memory writes, executable changes, new loader, protection bypass or third-party execution. If ordinary read access is unavailable, stop that route. Inspect recovered reflected offsets/owners before treating values as evidence. Then record live game state using authorized UI actions and bounded sampling, compare the same measured state inputs in Godot, and change only verified relationships.

**Tech Stack:** Existing Python/ctypes/Windows read APIs, already installed MD2/approved loaders, Godot4.7.2/Blender5.2. No new software install.

**Spec:** Latest user request; speed700, Run1.25, acceleration48/deceleration42 need runtime verification. Preserve previous3fidelity fixes, original assets, accepted jump and graphics. No new scene/project/engine. Private data remains Research-only and excluded from current Git tracking before capture.

- [ ] Validate a new read-only evidence route against public loader source and known reflected types.
- [ ] Recover active player/component/attribute/animation owners and defaults; capture controlled start/stop/turn/jump/combat samples where accessible.
- [ ] Independently compare units, speeds, velocity response, animation rates/ratios and contact/notify evidence.
- [ ] Reproduce concrete controller mismatches with failing tests, implement justified repairs and label unknowns.
- [ ] Validate30/60/120physics behaviors, all Sabre regressions, raw pose parity and native existing-lab gameplay. Update the existing findings with new evidence and limits.

Review focus: class defaults versus live instances, derived versus inherited properties, large-world double vectors versus floats, bitfield booleans, asynchronous sampling uncertainty, active modifiers and UI/menu/pause ownership. No values inferred from arbitrary byte patterns.
