# Private Forest phase grading comparison

Existing F5 WorldMap → L → **Air · private Forest phase LUTs (experimental)**. OFF by default. Compare at7/12/16.5/18.5/22hours using existing controls; original rendering, audio-off, player, Sabre, vegetation and camera remain.

The adapter samples eight actual captured typed32³ Forest LUTs, packed privately into eight slabs of a32×32×256 texture. It uses independently written logarithmic input mapping and display-to-linear output, fused into the existing compositor writeback. A second artistic grade/tone curve and the old Canvas vignette are suspended only while the comparison owns the environment. They restore on OFF/B/F7/HDR fallback, missing source, unsupported pipeline and scene exit. Resources become ready before environment ownership changes; this is designed to avoid a one-frame double grade. Explicit frame-by-frame resize/HDR transition coverage remains open. A failed optional shader rebuilds the approved exposure path and retains the exact failure reason.

The profile, LUTs and native parameters remain SHA-pinned outside the project/Git; missing source or a distributable runtime disables the option. Production scripts contain original implementation only. Eight LUTs consume1,048,576bytes plus64bytes of parameters after first use; released on OFF; the actual original APPLY shader is rebuilt, rather than keeping a conditional experimental shader. No new full-screen pass, scene or project. Existing6custom raster stages remain.

## Evidence and limits

Private evidence: `MD2 Research/godot_lab/world_map_unified_showcase_v001/forest_grade_transfer_v001`.

-77actual GPU HDR swatches across8anchors and3intermediate/evening phases match an independent CPU trilinear sampler within.07818/255 display codes; existing3/255 gate unchanged. This validates the transfer, not cross-engine light units or full MD2 reproduction.
-30locked screenshots cover meadow and a real cliff at7/12/16.5/18.5/22h. All10OFF restores are bit-identical after rebuilding the actual original shader. The previous cached-shader approach failed2views (two half components each/max.00024414linear), preserved under before_original_off_pipeline. No tolerance was relaxed. First teleport captures were invalid as a second location because the source presenter history was not reset; preserved separately, corrected by resetting it in the research runner only. Camera remains the approved orthographic configuration.
-Native/spatial/showcase26clips and actual gameplay30/60/120 render caps pass. Optional shader fault and missing-profile fallback pass.
-Direct RenderingDevice timestamp brackets measure all6effect stages. Five-phase shared desktop ABBA/720p medians about.046–.047ms OFF/.057–.058ms ON, unchanged draws within each pair. Driver4.7.2 returns nanoseconds despite XML saying microseconds; raw timestamps and version-pinned implementation are saved. No handset/FPS/thermal claim.

Clock anchors, smoothstep interpolation and afternoon/evening mirroring follow our existing original phase-air policy; they are NOT recovered native MD2 hours or native LUT-generation/blending rules. Input radiometry remains unity gain as an explicit experiment; source local exposure/bloom is NOT reproduced. Pre-LUT vignette/noise/AA are not part of this isolated transfer. Morning/twilight/late-night currently become materially darker, so this option has NOT replaced the approved default. Do not compensate with an invented brightness factor. Next: close same-input exposure/bloom and input-unit contracts, then re-evaluate phase readability before any promotion.

Review: an independent read-only code review identified retained experimental APPLY onOFF; its corrective lifecycle review found no further important issue. The fresh strict10-view image gate passed after restoration. Debug toggles rebuild shaders/resources and can have first-use compilation cost; warm GPU timings do not measure this hitch.

Timestamp unit evidence: [version-pinned D3D12 conversion](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/d3d12/rendering_device_driver_d3d12.cpp).
