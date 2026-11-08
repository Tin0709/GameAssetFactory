# Forest phase atmosphere integration

2026-11-08, user-authorized. Existing F5 `game_mobile_3d/scenes/WorldMap.tscn`; no new scene, assets or controller. Review pending, not an assertion of native MD2 rendering equivalence.

## Default and comparison

Private Mobile showcase defaults to **Air · measured night / dawn / day** and **Air · exposure-shaped soft light**. Open L to disable either independently. H toggles fog; T changes phase; Shift+T previews the original GAF clock. B retains the original graphics baseline. Audio stays muted.

The preceding atmosphere is restored by disabling both new Air options. Existing spatial-mist, captured-color and shadowed-scatter comparisons remain. UI is sharp and is drawn after the scene effect.

## Evidence transfer

`world_map_phase_air.gd` validates eight anchors derived from nine PIX captures using an external, SHA-pinned editor-only profile. Duplicate final Day data are not added as an extra time sample. Source data and capture assets stay under Research `godot_lab/world_map_unified_showcase_v001/phase_atmosphere_integration_v001`; no LUT/bytecode/texture/raw proprietary constants are embedded in production. Missing/invalid data retain the previous mist behavior.

The shared 3D medium keeps grass, player, terrain and cutaway on the same integration path. Source primary+sky scatter is blended in linear space and normalized to the approved incident-light luminance. Extinction uses measured density ratios relative to the captured Day coefficient; existing local density normalization and world ground origin remain original adapters. Height falloff converts base-2/cm to natural exponential/m with `100*ln(2)`. The recovered 3600cm ray start becomes36m, not a player-centered clear sphere. No captured absolute world altitude is copied into a different map.

Capture timestamps do not identify game hours. Placement of anchors on our clock, smoothstep interpolation and mirrored evening transition are ORIGINAL GAF choices. Frame01 is a night-like captured state, not a proven native Night endpoint. The density normalization, world-space banks and source-light energy mapping are not recovered MD2 fog-generation algorithms.

## Original Mobile light-spread implementation

The existing resolved-color local-exposure compositor now optionally builds a quarter-resolution color source shaped by the local log-luminance meter, followed by two separable five-sample broad/narrow filters. Its final application adds a bounded .16 light-spread contribution. This is an original approximation motivated by verified native local-exposure-before-bloom ordering. It does not copy native DXIL or reproduce the native pyramid, HDR range, highlight/shadow formula or final LUT exactly.

The old Environment glow is suspended only while the replacement compositor is active, has rendered and reports no error. Off/failure restores the old glow. Existing F7 owns compositor lifetime; shared PRE_OPAQUE mist coexists. When the new light-spread option is off, the three additional raster passes are skipped. Three quarter-resolution packed color targets add approximately0.66MiB at1280x720; lower rendering resolution reduces this cost. Existing packed resolved-color restriction and unsupported-renderer fallback remain.

## Validation scope

Private integration folder contains same-camera Day/Morning/Night previous / measured-fog / combined / previous-restore screenshots, shader initialization logs, exact image restoration measurements, native profile/clock/fallback checks, spatial-mist contracts and30/60/120 gameplay routes. Read the final private README/results before treating any checks as passed.

Desktop viewport counters do not establish the complete cost of direct RD compositor raster work. Real-phone GPU timings, thermal behavior and visual approval remain pending. Do not report a flat viewport timing as zero effect cost. This pass preserves the approved source assets, animations,7m/s controller, grass placement/wind/contact, terrain lighting and camera.
