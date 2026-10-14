# Read-only Snappy gameplay export

`export_snappy.py` samples current approved Snappy Walk v003/Run V1 and approved Expressive Walk/Run controls at120 Hz. Sources, Action signatures, slots/rest transforms and mesh reconstruction are checked in `export_validation.json`. `build_library.gd` creates `snappy_library.res` from `snappy_samples.json`; no Blender file is saved. Existing approved Idle and Jump runtime resources are reused unchanged.

Runtime contact profiles use actual sole-height samples to retain the Snappy Walk's shared hop. Aliases map UpperArm.L/R to runtime Arm.L/R on the existing rig. Clips are in-place, closing samples excluded from playback. No production asset references are replaced. See `docs/animation/SNAPPY_LOCOMOTION_GAMEPLAY_TEST.md`.
