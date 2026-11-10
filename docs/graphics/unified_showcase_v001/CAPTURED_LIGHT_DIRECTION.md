# Primary-light direction comparison — paused checkpoint

Existing WorldMap, F5. L opens options; **Light - captured primary direction (Noon anchored)** switches this candidate (currently ON). OFF restores previous direction; the approved Noon is unchanged. No new scene, geometry, fog, intensity or material tuning.

Original cross-engine helper uses an external, hash-pinned, editor-only reference profile; proprietary reference values remain outside the repository. It normalizes source directions, aligns azimuth relative to approved Noon and preserves the source-relative horizontal ground cosine by scaling the vertical component. It reconstructs a unit direction. This is an independent adapter, not copied native shader code. Source angular finite-light behavior is not implemented here.

Capture ordering, clock placement, interpolation, evening mirror and handoff are original assumptions. Different reference/approved Noon elevations mean side-normal lighting cannot simultaneously match the native image. No native 24-hour trajectory or complete radiometry claim.

51 original-fixture checks,62 existing direct-key checks,48 rendered Lambert faces and actual30/60/120 render gameplay passed. Two Noon comparisons unchanged. Initial strict42image restore gate failed on sparse components; raw failure retained, unchanged-controls also show sparse nondeterminism. Desktop shadow coverage changes with direction; morning viewport median increased .251ms in this run. Not a phone benchmark.

User paused before executing prepared runtime integration context/proof/B/stage tests and broader regressions. Full default acceptance remains pending; do not claim complete validation. Read Research CURRENT_GRAPHICS_CHECKPOINT.txt before resuming. All preceding approved assets/controller/graphics preserved; source-order experiment remains OFF.
