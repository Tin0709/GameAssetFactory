# Terrain corner receiver correction

> Execute inline with superpowers:executing-plans; preserve the existing scene and approved graphics owners.

**Goal:** Remove false dark block corners before considering artistic shadow softness tuning.

**Spec:** User requests softer MD2-like corner shading. Native event1753 separates spatial incident light from material/colored visibility; it does not validate our current bake or prescribe a universal ambient lift. Diagnostic captures isolate contact, direct shadow and sky-only response. Of56993 current unique receivers,9138 normal-offset origins lie inside adjacent solid cells. Correct this numerical boundary error using scene geometry, without inventing native coefficients.

**Architecture:** Original offline integrator resolves blocked receiver origins to the nearest empty tangential neighbourhood, retaining the existing1cm normal epsilon. Reuse all source geometry/colors and rebake only original GAF radiance. No runtime passes, new scenes, shadow/global exposure/actor/vegetation changes. Preserve the preceding cache privately and in Git history.

**Tech:** Existing Python/NumPy integrator, compressed Godot resource, Mobile/D3D12 comparison scripts.

- [x] Reproduce the receiver boundary failure with an independent near-interior regression; verify valid open receivers remain unchanged and enclosed inputs fail closed.
- [x] Implement bounded geometry-aware receiver correction; record repaired/unresolved counts and preserve original cache.
- [x] Rebake and compare locked cliff/west/meadow before/after/restore, including sky-only. Check pixels and cache guards; only accept if the actual corner shading improves.
- [x] Validate no new draws/streams, gameplay and mobile-path contracts. Review the scoped change, save findings, commit/push and open the playable scene with FPS.

Remaining physical diffuse transport, native Lumen filtering/short-range AO and handset cost stay explicitly unverified. If this fix is insufficient, diagnose the remaining contribution separately instead of stacking arbitrary blur/brightness.

## Execution ledger

- RED near-interior integration mismatch reproduced, then7Python tests pass. Bounded origin correction repairs10107snapped unique receivers;120942valid vertex instances remain bitexact.
- Authoring exporter failed on its incorrect identity-only check; fixed to validate actual original chunk translations/identity basis. Fresh export byte-identical geometry/colors, explicit metadata identity proof; reused the completed bake rather than repeat work. Original cache preserved privately.
- Native1958/headless1946 contracts and fresh review pass. Three single-session cache-swap restores exact0; meadow6pixels/max1byte.128repaired-point convergence p95sky.003005/sun.001657.
- First comparison helper used float surface strings and failed; rejected outputs retained. Valid evidence uses matched_compare.gd. Short timing drift retained; justified512-frame warm repeat gives ~.45ms/133draws for both, shareddesktop limits.
- Actual60Hz movement/jump/combo feature residual.130486mm equals repeated-control residual; no controller change. UI clarifies F12 replacement; actual on/off ownership and FPS review pass. Final commit/sync receipt lives privately with the evidence.
