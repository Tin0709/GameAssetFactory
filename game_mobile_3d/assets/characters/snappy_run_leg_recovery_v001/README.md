# Pending Run leg-recovery export

Separate read-only export of `Run_Snappy_LegRecovery_Test_v001`. Approved Snappy libraries and samples are unchanged. `recovery_library.res` contains only the candidate; `recovery_samples.json` records the source/Action hash, rest compatibility and120Hz poses.

Used only by the existing isolated Snappy pose writer. Approved Run remains default. B crossfades the two leg samples on the shared live phase, without changing controller speed, cadence, camera, body motion or jump physics.

**Rejected for gameplay at30FPS.** Keep this export for diagnostic A/B and human review; no production integration. See [gameplay review](../../../../docs/animation/reviews/godot_snappy_run_leg_recovery_v001/README.md).
