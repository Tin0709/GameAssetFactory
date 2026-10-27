# MD2 locomotion discrepancy investigation

**Goal:** Locate the discrepancy between recovered Blender skeletal motion and the existing playable Sabre lab using independent pose and movement measurements; correct demonstrated implementation errors.

**Architecture:** Keep the existing source loader, CharacterBody3D, animations, source adapters and lab. Trace source → Blender → Godot raw playback → composed gameplay pose → physical travel. Changes require a failing behavioral reproduction. Native values not recovered remain unknown.

**Tech Stack:** Existing Blender 5.2, Godot 4.7.2, Python/NumPy, accessible local caches and public extracted tables. No new dependencies or scene.

**Spec:** User request of 2026-10-27 in this chat; investigation and repairs are authorized. Preserve accepted jump, character/Sabre/face, graphics and environment. No video calibration, encryption bypass, or proprietary source data in Git.

## Review focus

- Raw playback parity at off-key times and endpoints, including tiny facial scales and nonuniform weapon scales.
- Start/stop/reversal and Walk↔Run at 30/60/120 Hz; distinguish input, actual travel, cycle rate and transition clocks.
- Combat planting/interleaving, airborne interruption, focus/reset and raw review remain intact.
- Contact measurements are geometric candidates, not proof of native foot locks.
- Public table speed/units, native defaults, source schema and reconstructed behavior must remain separate.

## Tasks

- [x] 1. Generate private matched-time Blender/Godot/source pose measurements; hash originals before/after.
- [x] 2. Audit accessible movement fields, animation-state relationships, units and root motion without repeating extraction.
- [x] 3. Record controlled physical and animation traces, prove hypotheses, and add failing regression tests for concrete errors.
- [x] 4. Apply minimal justified repairs in the existing controller; retain approved motion and existing controls.
- [x] 5. Run affected/full Sabre suites and native existing-lab gameplay captures; inspect results and update existing library guidance with cause, limits and next recoverable evidence.

## Findings and rulings

- Fixed3proved defects: wall-time/source-time coupling, stale omitted constant PRS channels, and cached leg heading after reset. Red regressions preserved privately; new17/14/6behavioral checks pass.
- Matched264times/32bones/13unique clips: maximum Godot/source matrix-element discrepancy.040674→.00001067 after resetting omitted channels. All13source root translation channels are constant; this does not disprove runtime root-motion sources/notifies.
- Ruling: preserve7u/s,1.25Run rate,48/42acceleration/braking, accepted jump and existing combat travel adapters. No recovered formula justifies another numerical retune. Continue labeling those adapters.
- Ruling: keep source arrays and all associated working capture JSON ignored in Research Git, removing accidental current-index tracking while preserving local files/history as authorized. Public tables remain in ignored source_snapshot. No proprietary asset transferred into GAF.
- Additional28movement effect definitions verify configurable speed/friction/rotation/jump/air-control surfaces. Player movement-multiplier adjustment curve is referenced, but its keys and SetByCaller run magnitude remain absent.
- Native verification uses existing full100×100grass lab,32bones/13clips, real physical callbacks and silent fixed60fps AVI. Offline timings are not device-performance evidence. Face probe64corrected Walk/Run frames retain both eyes. Known7TextureRID shutdown warning persists.
- Final review found no remaining P1/P2 in the handoff/reset changes. Source recovery and current architecture still cannot establish exact MD2 gameplay fidelity; see private findings for prioritized unknowns and Godot route.

No manual commit/push is needed for this audit. Respect concurrent checkpoint-manager changes.
