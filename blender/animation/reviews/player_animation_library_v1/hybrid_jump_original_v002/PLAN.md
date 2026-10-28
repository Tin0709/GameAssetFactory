# Jump v002: soften contact and add overlapping body/head follow-through

User rejects v001's stop-start landing and insufficient A&S-like body/head bounce. Author a separate Pending revision, preserving v001, every old Action, references and Godot.

Confirmed cause: v001's per-segment quintic ease forces zero velocity at every knot in every channel. Its45mm compression finishes in55ms, then reverses twice within300ms, while global head attitude stays deliberately restrained. Direct A&S local Landing instead has a longer overlapping body/head response and Catmull interpolation; its0.75–1s authored durations are not physics flight times.

- Capture existing115Action signatures/76entries/6reviews and736Godot file hashes, save immutable backup.
- Keep original takeoff/airborne and the exact same0.52s flight arc in the comparison. Author only new Landing + full context, avoiding redundant unchanged phase Actions. New original0.72s recovery,~62mm compression, lower torso lean, head nod delayed behind mass, smaller second settle.
- Use C1 Hermite curves with continuing tangents at non-extremal keys; extrema reverse naturally. Measure body/head phase lag, speed/acceleration and pose continuity, not just endpoints.
- Show v001 vs v002 in one normal-time A/B review inside the existing Showcase. Same cameras/character/trajectory/contact time. Fixed feet, unit scale, no knees/elbows or copied reference keys. The existing preview root collision impulse remains disclosed; do not attribute all world-space contact velocity to pose curves.
- Inspect actual motion, foot contacts and rigid geometry. Append two Pending pose Actions/two presentation carriers, preserving old metadata. Save/reopen/select and open A/B playback; no Godot integration.
