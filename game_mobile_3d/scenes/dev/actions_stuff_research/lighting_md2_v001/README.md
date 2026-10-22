# GAF_MD2_Lighting_v001 — development visual review

Original mobile lighting, installed only by `md2_lighting_enabled=true` in the EXISTING `ActionsStuffWalkRunTest.tscn`. Default Noon/Medium, automatic time paused. Shader ZIP stays external and no GLSL was copied. [Research/evidence](../../../../../docs/graphics/MD2_LIGHTING_AND_GRAPHICS_RESEARCH.md).

Top-right controls:07:00Morning,12:00Noon,16:30Afternoon,18:30Dusk,22:00Night; full24hslider; Auto/Pause; cycle speed; Original A/B; Low/Medium/High; independent Fog/Glow. **L**folds controls. Existing25%HUDand WASD/Shift/Space/E/R/Q/C/V/rightmouse/wheel remain. Input release is caught before GUI so dragging onto this panel cannot leave aim/orbit stuck.

## Reuse and removal

`lighting.gd` is a Node owning one nativeEnvironment/Sky while borrowing an existingWorldEnvironment and DirectionalLight3D under its scene. `setup(scene:Node3D,foliage:Node=null)` snapshots those resources and viewport. Foliage adapter expects the existing shared materials array; omitted for other scenes. `set_time(hour,snap=false)` seeks smoothly (modulo24); `advance(delta)` is frame-rate independent; `set_quality(index0..2)`, `set_original(bool)`, `set_fog`, `set_glow`, `release`.

Runtime state is independently authored. One reused palette dictionary, no per-frame nodes or grass transform changes. Paused stable lighting skips expensive apply work. The UI metrics update4Hz. Realtime shadow size/filter APIs are GLOBAL: this devlab assumes one owner and restores known ProjectSettingsinitialization onOriginal/exit, including16-bit depth. They have no getter for an unrelated owner's runtime overrides. Add arbitration before production concurrency.

Original A/B restores the exact priorEnvironment reference, sunproperties, viewport mode/scale, known global atlas/filter/depth and grass fragment grade0; same owned evaluation props remain for fair comparison. `release` additionally disables/hides the UI and guards setters; removal frees owned assets. Disabling the scene flag removes this entire system. No saved project-default changes.

## Budgets

| Tier | 3Dscale | Shadow atlas/depth | PCF | Splits/range | Glow |
|---|---:|---|---|---|---|
|Low|.75|1024/16bit|VeryLow|Orthogonal24m|Off|
|Medium|.85|2048/16bit|Low|2/32m|Subtle|
|High|1|2048/32bit|Medium|2/38m|Subtle|

All use native depth/height fog, a small incremental procedural background, explicit ambient and one shadowed key. No PCSS, SSAO, SSR, SSIL, GI, volumetrics or extra local dynamic lights. Grass/flowers do not cast shadows; selected existing actor/zombie/props/trees do. No decorative translucent shafts are justified in this flat field. UI stays full resolution.

Metrics distinguish renderCPU, engineprocess/physics, framepace, visible primitives/draws and shadow primitives/draws. GPUzero meansN/A. Two-cascade shadow draw counter currently reports0despite visible shadows on testedMetal; widget showsN/A. This is not a zero-cost claim. Desktop30/60checks do not establish Android/iOSperformance.

## Internal evidence

`tests/test_md2_lighting.gd`:20behavior contracts; missing-controller and reviewfindingRED→GREEN logs. Existing Fire30/60, Strafe, camera, grass regressions. Native captures/profile scripts instantiate the SAMEexisting scene through a temporary runtime viewport, never save another scene. Screenshots/PNGmovie readbacks are excluded from profile samples. Video is300nativeframes/10seconds at30FPS; time-of-day seeks are accelerated preview, actor/grass animation remains1×.

Preserve all approved sourceActions/skin/weapon/zombiephysics. Only the authorized lab/scene plus an optional fragment foliagegrade change among prior game files; `vertex()` body stays exact. Runtime content remains in the existing release-excluded research root. Keep this final result Pending until user review.

Latest2026-10-22user policy: all tall/short grass has castingOFFand receivingdisabled (`shadows_disabled` in sharedshader). Other caster settings remain. Wind/contactvertexcode unchanged. Original A/Bretains this latest grasspolicy. NativeMobilecompile/render and32batch/0castercheck pass; measured FPSgain is not established by cappeddesktopCPUtimings. See lightingresearchfollow-up.
