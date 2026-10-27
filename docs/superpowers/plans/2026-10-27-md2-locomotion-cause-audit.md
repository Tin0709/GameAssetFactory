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

- [ ] 1. Generate private matched-time Blender/Godot/source pose measurements; hash originals before/after.
- [ ] 2. Audit accessible movement fields, animation-state relationships, units and root motion without repeating extraction.
- [ ] 3. Record controlled physical and animation traces, prove hypotheses, and add failing regression tests for concrete errors.
- [ ] 4. Apply minimal justified repairs in the existing controller; retain approved motion and existing controls.
- [ ] 5. Run affected/full Sabre suites and native existing-lab gameplay captures; inspect results and update existing library guidance with cause, limits and next recoverable evidence.

No manual commit/push is needed for this audit. Respect concurrent checkpoint-manager changes.
