# Minecraft Dungeons II lighting & graphics research — GAF MD2 v001

2026-10-22 · Integrated **dev visual review**, not production or phone acceptance.

## Result and scope

The reusable original `GAF_MD2_Lighting_v001` is running in **the existing** `res://scenes/dev/ActionsStuffWalkRunTest.tscn`, Godot4.7.2.stable.official.ed1daf0bf / Mobile. No new project or gameplay scene. It provides five artistic times, continuous24h sampling, smooth preset changes, automatic preview/pause/speed, Original A/B, Low/Medium/High, independent fog/glow controls, and compact measured render statistics. Noon/Medium starts paused. **L** folds the top-right panel; all previous controls and the25%legacyHUD remain.

[Same-camera comparison](reviews/md2_lighting_v001/comparison.png) · [Native controls](reviews/md2_lighting_v001/06_controls.png) · [Full field/sky](reviews/md2_lighting_v001/07_overview.png) · [10-second transition preview](reviews/md2_lighting_v001/day_transition.mp4) · [Raw performance](reviews/md2_lighting_v001/performance.json).

The camera, actor/weapon/zombie source code/assets and grass vertex motion remain authoritative. A small linked arrangement of existing stone/dirt/grass blocks, flowers and two trees supplies shaded material comparisons, without remaking assets. It belongs to the opt-in module. Original A/B uses the SAME arrangement and exact pose/camera/wind phase; it restores the original lighting and foliage fragment response rather than changing scene content.

## 1. Genuine MD2 visual observations

All three requested official pages were accessible and inspected:

- [Minecraft gameplay trailer article](https://www.minecraft.net/en-us/article/minecraft-dungeons-ii-gameplay-trailer).
- [Xbox Wire September28: interconnected world](https://news.xbox.com/en-us/2026/09/28/how-minecraft-dungeons-iis-interconnected-world-makes-every-journey-an-adventure/).
- [Xbox Wire June10: demo details](https://news.xbox.com/en-us/2026/06/10/minecraft-dungeons-2-arpg-details-demo-xbox-games-showcase-2026/).

**Observed pixels, not renderer claims:**

| Actual image/shot | Visible evidence | Original adaptation |
|---|---|---|
|[First-Ambush_01_4K](https://xboxwire.thesourcemediaassets.com/sites/2/2026/09/MCD2_Creator-Toolkit_Screenshot_First-Ambush_01_4K-b8393fbfc0915a250b36-1024x576.jpg)|Pale warm daylight; coherent shadows generally toward image lower-left; shade retains green/material identity. Ground and tufts share a palette. Broad paths/value regions remain readable around small combatants.|Tune one warm key and cool fill before effects; keep grass grounded and highlights controlled.|
|[Rainy06](https://xboxwire.thesourcemediaassets.com/sites/2/2026/09/06-8da4bf74d4fcce760202-1024x576.jpg), [icy08](https://xboxwire.thesourcemediaassets.com/sites/2/2026/09/08-c15f2f780e34664b2437-1024x576.jpg)|Outdoor color varies by region/weather: darker muted green versus cool blue. There is no universal MD2green.|Separate time/palette data from scene geometry; do not globally wash every material orange/blue.|
|[Wellspring_01](https://xboxwire.thesourcemediaassets.com/sites/2/2026/09/Wellspring_01-612f97f7c9c9453ba0a5-1024x576.jpg)|Warm pastel terrain, green vegetation; broad pale diagonal shafts; softer violet recesses. These are spatial features, not equally present in the meadow shot.|Restrained distance haze; shafts only with a plausible occluder and measurable benefit.|
|[Official Minecraft trailer](https://www.youtube.com/watch?v=vBNE3bKMpu8), paused0:40and0:55|Blue dungeon/Sift surroundings support warm lamp/attack accents. Glow is selective; small figures retain contrast.|Keep ordinary grass non-emissive and glow restrained around existing bright combat effects.|
|[Enchantsmith close-up](https://xboxwire.thesourcemediaassets.com/sites/2/2026/09/MCD2_Creator-Toolkit_Screenshot_Enchantsmith_01_4K-9492893c7b5d3acb0fed-1024x576.jpg)|Warm exposed faces and cool shaded stall regions; coherent foliage green.|Secondary close-up evidence only; judge final work at approved gameplay distance.|

**Unknown:** exact MD2renderer/engine algorithms, GI implementation, shadow filter, fog integration, exposure numbers, volumetric method and day/night cycle. Neither screenshots nor the separate Java shader establish them. Our07:00/12:00/16:30/18:30/22:00are artistic preview presets, not verified MD2times. No source-derived numeric setting is presented as an MD2fact.

## 2. Actual Complementary/Euphoria package inspection

Read-only local archive: `/Users/tin/Desktop/Game Dev/local_references/Comp5.10d2EuphoriaPatches_1.11.0-dev1.zip`;680entries; SHA256 `fa2dd9b6e26189fe04a18fbab63242410ef12effed60d33cc35cc6e0d0b19000`.

Internal markers identify Complementary **r5.10** and Euphoria Patches **1.11.0** (`Made for Complementary Shaders r5.10.txt:1`, `shaders/lib/misc/myFile.glsl:1–2`, `InformationEuphoriaPatches.md:10–12`). The filename's `d2`/`dev1` suffixes are not independently proven by these markers. This is Minecraft Java reference code, **not confirmed MD2source**.

Libraries were followed through actual callers: `world0/gbuffers_terrain.fsh:1–7` → `program/gbuffers_terrain.glsl:11,175–176,502–505` → `DoLighting`. Deferred fog/clouds use `program/deferred1.glsl:217–245,488,623–624`; shafts use `program/composite1.glsl:99–106,303–309`; bloom/tonemap use composite4/5. These depend on MinecraftG-buffers, material masks, lightmaps, shadow textures, matrices, dimension macros andTAA. An isolated GLSLfile is not a reusable standalone effect.

| Archive evidence (one-based lines) | Verified technique and cost | Lesson, not transplanted code |
|---|---|---|
|`lib/colors/lightAndAmbientColors.glsl:8–30,48–87`; `lib/common.glsl:913–916`|Separate direct/ambient noon,sunset,night palettes; positive-sine noon factor; squared visibility night/day blending; rain blend. Shaft palette uses different weighting.|Original independent key/fill/sky tracks with smooth temporal weights.|
|`lib/lighting/mainLighting.glsl:761,790–825,845–870`|Diffuse combines direct,ambient,block/minimum light,AO,emission; GGXhighlights separate.|Readability comes from balanced components, not exposure alone.|
|`lib/lighting/shadowSampling.glsl:44–92,135–140`; `mainLighting.glsl:382–395`; `common.glsl:577–589`|Basic four comparisons versus five-tap colored filter; higherTAApaths use paired radial samples. Quality2/3/4/5uses2/4/8/16iterations (4/8/16/32SampleShadowcalls), some paths double.1024/2048/4096maps vary with settings.|Shadow work scales by sample count, casters, range and map size; these are source operation counts, not device timings.|
|`lib/colors/skyColors.glsl:49–67`; `lib/atmospherics/sky.glsl:47–75,86–132`|Artistic up/middle/down bands, elevation gradient, sun-facing horizon tint/glare; one passage explicitly labels fake scattering.|A lightweight gradient/palette is a valid original art tool; no need to replicate a physical atmosphere.|
|`lib/atmospherics/fog/mainFog.glsl:101–117,124–190,192–208`|Analytic distance exponential plus altitude/weather/day color; separate border/cave handling.|Use native depth/height fog with modest local opacity; avoid copying its dimension-specific formula.|
|`lib/atmospherics/volumetricLight/volumetricLight.glsl:98–151,208–261,293–320`|Shadow-sampled shaft raymarch, base near counts6/10/15/30with conditional increases and cheaper far samples.|Desktop shafts can have substantial sampling cost; not a mandatory Mobile feature.|
|`lib/atmospherics/clouds/mainClouds.glsl:1–47,49–115,138–179`; `reimaginedClouds.glsl:51–81,89–145,195–214`|Dispatches Reimagined/Unbound clouds; slab/depth/distance and higher-quality lighting work.|No cloud shader port; small lab does not need this additional rendering subsystem.|
|`lib/shaderSettings/tonemaps.glsl:4`; `lib/colors/tonemaps.glsl:29–82,121–156`|Default modifiedLottes with dark lift, highlight white treatment and dark desaturation;ACESoptional.|Preserve bright texture detail and readable dark clothing using native tonemap/fill.|
|`lib/shaderSettings/bloom.glsl:4–11`; `program/composite4.glsl:25,35–55,70–80`; `composite5.glsl:54–90,318–339`|Default.12; weighted7×7blur at seven scales; mixes scene toward blur before tonemap. No explicit bright-pass threshold in this inspected path.|Do not assume every bloom implementation is threshold-only; our restrained nativeHDRglow is an original choice.|
|`shaders.properties:2–14,249–253`|POTATO→COMPLEMENTARYquality profiles vary shadows/clouds/shafts/reflections; separate aesthetic presets can selectACES/saturation/bloom; quality−1disables shadow passes.|Keep art presets and performance tiers separate. Definitions do not prove a profile was active.|

## 3. Licenses and reuse restrictions

Read both included licenses. `ComplementaryLicense.txt:9–13,38–82,86–93` (CLA1.7) permits ordinary gameplay/content creation but excludes modification/redistribution from Normal Usage; modified distribution has retained-license, credit, name, visual-difference, exclusive-license and human-written-contribution conditions, with uncovered uses reserved. `EuphoriaPatchesLicense.txt:20–22,26–48,52–58` (v1.1) adds patch-based modified distribution, credit/naming conditions and a waiver of large visual differences. It references CLA1.6 while this bundle contains1.7; that mismatch is recorded, not resolved here.

These observations are **not permission or legal clearance for a commercial Godotport**. No proprietaryGLSL, lookup asset or shader texture was copied, translated or distributed into the game. The original ZIP remains outside the project in local_references. Runtime uses independently authored GDScript/native Godotfeatures and our existing assets. Obtain explicit appropriate permission before any future source/asset reuse outside granted terms.

## 4. Actual GodotMobile capabilities

Project remains `renderer/rendering_method="mobile"`,1280×720canvas_items, original1024directional atlas/16-bit depth/filter1(VeryLow). The installed binary is4.7.2. Read [renderer comparison](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html), [environment/postprocessing](https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html), [lighting/shadows](https://docs.godotengine.org/en/4.7/tutorials/3d/lights_and_shadows.html), and [resolution scaling](https://docs.godotengine.org/en/4.7/tutorials/3d/resolution_scaling.html).

Supported tools used: one DirectionalLight3D, native filtered shadows, ProceduralSkyMaterial, explicit colored ambient, native depth/height fog, Filmic/exposure/color adjustments and optional glow. No SSAO/SSR/SSIL/SDFGI/VoxelGI/volumetric fog requested. PCSS/light_angular_distance is Forward+only; ours stays0. Shadow softness uses `shadow_blur` plus PCFquality. Bilinear viewport3Dscale is portable; no assumed FSRavailability.

## 5. Implemented original architecture

[Module folder](../../game_mobile_3d/scenes/dev/actions_stuff_research/lighting_md2_v001/):

- `palette.gd`: nine time keys including matching midnight endpoints; separate original direct,fill,sky,horizon,ground,fog,exposure and saturation tracks. Smoothstep interpolation, modulo24; finite fallback. Runtime reuses a state dictionary.
- `lighting.gd`: owns the custom Environment/Sky; borrows the existing WorldEnvironment/key and optional grass material references; snapshots original resource/sun/viewport and known global shadow initialization. `setup(scene,foliage=null)`, `set_time`, `set_quality`, `set_original`, `release`.
- `preview_ui.gd`: compact/collapsible UI and no InputMapedits; only Lnew. Buttons/sliders avoid keyboard focus. Right-mouse release is now cleared in the lab's existing `_input` even if UI consumes the event; E/Q/C protections remain.
- `metrics.gd`:4HzUIreadout of measured render CPU/GPU and visible/shadow statistics, no readbacks.
- `review_props.gd`: existing asset links and simple static contacts; owned by the opt-in module. No source mesh/material edits.

Set `md2_lighting_enabled=false` on the SAMEscene to remove the module; script defaultfalse preserves older fixtures. `Original A/B` restores exact original Environment, key parameters, viewport scale/mode, shadow size/filter/**16-bit setting**, and grass fragment grade0. Shutdown also restores when the borrowed WorldEnvironment was removed first. Released setters do nothing and UI retires, preventing stale controls reapplying changes.

Directional atlas/filter APIs are GLOBAL and have no getters. This lab assumes exclusive ownership of those overrides, restores the known ProjectSettingsinitialization, and never saves ProjectSettings. Another concurrent runtime owner requires an explicit arbitration service before production adoption.

## 6. Day/night art presets

| Phase | Key / fill design | Key elevation | Key / ambient energy | Exposure |
|---|---|---:|---:|---:|
|07:00Morning|Warm pale sunlight; cool, readable canopy shade.|19°|1.18 / .42|.98|
|12:00Noon|Neutral warm key, balanced blue-gray fill; main comparison reference.|58°|1.35 / .34|.96|
|16:30Afternoon|Golden key, cooler fill; longer shadow and restrained orange.|24°|1.12 / .39|.98|
|18:30Dusk|Fading peach key and lifted cool fill; silhouettes remain readable.|8°|.40 / .44|1.05|
|22:00Night|Stylized cool moon-equivalent key and blue ambient; dark but navigable.|40°|.30 / .45|1.08|

Intermediate dawn/night keys avoid abrupt changes. The low-energy evening key becomes a moon-equivalent fill; this is an artistic direction path, not an astronomical model. Preset clicks/slider seek quickly through a smooth response; automatic time starts paused, default24hours/5minutes, adjustable. No frame-rate-dependent lerp or exposure auto-adaptation. First native dark captures were inspected; night/dusk fill was deliberately raised because the charcoal player shirt initially lost too much detail.

## 7. Shadows, atmosphere and foliage

One dominant directional shadow, no new local realtime lights and no tiny-grass/flower shadow casting. Selected character/zombie/block/tree casters remain. Orthogonal/2-split close ranges avoid four-cascade cost; blur1.25, opacity.82 and restrained bias are authored starting values, not universal presets. Compare feet/block bases while moving; PCFsoftness is not PCSScontact hardening.

Native depth fog starts10m, ends50–70mdepending on time, max opacity.10–.25; weak height density.015. It is intentionally subtle across the small30×30field. Sky gradients remain visible in overview/at the field edge; the normal isometric camera usually looks at ground. No fake sky claim is made from a ground-only screenshot.

An original fragment-only grass grade darkens the lowest blade region gently and changes up-normal blend.56→.54. `lighting_grade=0` restores the previous exact formula. Atlas/nearest sampling, roots, UV2/COLOR, all vertex deformation, time clocks, bounds, spring/grid, population and32regional buffers are preserved. This is root shading, **not screen-spaceAO, GI, or simulated vegetation transmission**. Native oriented diffuse plus warm/cool illumination supplies a low-cost foliage response.

No translucent shaft planes were added to the empty clearing: Wellspring-style beams need meaningful occlusion/depth, and extra planes would add overdraw without a demonstrated benefit here. Future optional short beams under genuine canopy openings should be bounded/faded and tested for intersection/sorting. No claim of true volumetric scattering.

## 8. Grading, glow and materials

Filmic, white1.8, exposure.96–1.10, contrast1.04 and saturation.93–.98form the original grade. No copiedLUT. Colored key/fill does most of the work. Ordinary grass/dirt stay matte; no metallic reinterpretation or emissive grass. Medium/Highallow a low-intensity native glow withHDRthreshold1.25and bloom0; Lowdisables it. Existing rifle/impact bright effects can respond; no new dynamic light is attached per shot.

LightmapGIwas considered but not baked: this devfield is interactive and time-varying, and grassUV2contains immutable bend roots. Never overwrite it for lightmaps. Reflection probes/sky reflections add little to this mostly matte lab; explicit ambient avoids radiance recapture costs. Sky uses incremental64radiance as a modest background gradient. More advanced static-light baking/probes belong to a fixed representative level and separate measurement.

## 9. Mobile-first quality tiers

| Tier | 3Dscale | Atlas/depth | Filter | Shadow/range | Glow |
|---|---:|---|---|---|---|
|Low|.75 (56%pixels)|1024/16bit|VeryLow|Orthogonal/24m|Off|
|Medium(default)|.85 (72%pixels)|2048/16bit|Low|2splits/32m|Subtle|
|High|1.0|2048/32bit|Medium|2splits/38m|Subtle|

UI remains full resolution. Same geometry/motion/combat across tiers; no shader recompilation or per-blade CPU updates. Atmosphere remains analytic native fog, no separate decorative transparencies/clouds. All tiers retain the same small procedural background; lower3Dresolution and fewer shadow samples/cascades provide the main low-tier saving. Target30FPSbudget33.3ms;60FPS16.7mswhere actual device evidence supports it. No device-independent High60promise.

## 10. Initial native performance

Actual existing scene, Metal/Mobile, AppleM2Prodesktop,1280×720,60FPScap;300measured frames/tier after45warm-upframes. Eaim/fire, walking/running/jump, live zombie hit/death, grass wind/contact all active. No screenshot/movie readbacks inside samples. One deliberate Rreset midway creates a known encounter-reconstruction spike; it is reported rather than hidden.

| Tier | Framepace median/p95ms | RenderCPU median/p95ms | Engineprocess median/p95ms | Enginephysics median/p95ms | Visible draws median–max | Visible prims median | Shadow prims median | Peak corpses |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
|Low|16.690 / 17.594|0.075 / 0.092|2.579 / 53.361|9.721 / 571.807|57–63|77040|21986|2|
|Medium|16.678 / 17.571|0.083 / 0.097|2.923 / 55.690|8.280 / 14.899|57–63|76924|21986|2|
|High|16.682 / 17.477|0.084 / 0.098|3.266 / 53.504|8.147 / 13.226|57–63|76924|21986|2|

GPUmeasurement returns0on this testedMetalpath and is **N/A**, not0ms/free. Lowreports19median shadow draws; two-splitMedium/Highreturn0draws despite nonzero shadow primitives and visible shadows, so their shadow draw counters are alsoN/A. Visible object medians are57; visible primitive counts may include instanced triangles, and shadow primitives may repeat geometry across cascades. All pools had0misses; peak grass active cells remain local (~100). Each tier reached the approved~7.55m/srun speed.

RenderCPU comes from `viewport_get_measured_render_time_cpu`; it excludes script/other engine CPU. Frame setupCPUis logged separately. `Performance.TIME_PROCESS/TIME_PHYSICS_PROCESS` are engine monitor durations, not GPU/active utilization; do not sum them blindly. Framepace includes the60FPScap. Median/p95do not imply zero hitches: the deliberate encounter reset produces maxima around64ms; that reset behavior is existing combat setup and was not redesigned by this lighting task.

Controlled frozen-poseMediumprobes collect75frames each after12warm-upframes: full, shadows off, glow off. RenderCPUmedians are approximately.683/.527/.694msrespectively; whole-frame pace remains capped. Shadow removal changes shadow primitives22258→0. The ~.156msrenderCPUdifference is a bounded desktop submission estimate, not isolatedGPUshadow cost. Glow delta is within/noisier than measurement variation; no positive GPU/postcost is invented. Native per-pass GPUcost remains unavailable here.

RealAndroid/iOSvalidation is **pending**. Sustained heat, bandwidth, alpha overdraw, shadow atlas pressure and device-specific shader/Metal/Vulkandrivers require representative phones. Favor stable30FPSwith headroom; reduce3Dscale before worsening gameplay responsiveness. The dominant budget may remain grass fill or existing ragdoll CPU rather than this controller.

## 11. Verification and source conservation

20lighting contracts now cover integration, midnight/negative wrap, night fill,30/60transition parity, quality bounds, exact Original/release, borrowed-environment removal, and stale-control safety. A genuine missing-controller RED preceded implementation. Fresh review found stale controls after release and RMB-up over GUI; both had failing reproductions before their fixes.

Existing RifleFire30/60, CombatStrafe, camera-comfort and29grass contracts are run internally; actual native profiling exercises new lighting with live combat. Exact file/SHAaudit covers all pre-existing Blender/game files. Approved .blendActions, Soldier/weapon meshes, character/rifle/zombie scripts, projectdefaults and WorldMap remain untouched. Only the authorized lab script, scene opt-in and grass fragment shader change among pre-existing game files; the grass `vertex()` body is byte-identical. New runtime material remains inside the existing release-excluded research root.

Native stills freeze world/pose/camera/wind phase; Original restores its original1.0render scale, while the new Medium preview uses.85. This compares the complete default look and quality setup, not a claim of identical render budget; both A/Bstates use the same props. The short movie uses30FPSfixed simulation,300actual rendered frames/10.00simulated seconds, no retiming of actor/grass motion. Time-of-day preset seeking is intentionally accelerated preview, not a realtime10secondphysical day. Screenshot/movie timings are excluded from performance claims.

## 12. Known limits and next work

- This is an original MD2-inspired lighting study, not full visual parity with its richer authored environments or verified internal renderer.
- Flat30×30terrain cannot demonstrate distant landscape depth, interior transitions or complex heights. Fog is kept subtle instead of hiding missing geometry.
- No true vegetation transmission, GI, SSAO, contact-hardeningPCSS, volumetrics or cloud system. Root darkening is an approximation.
- Shadow/global restoration assumes one owner; arbitrate before streamed worlds or simultaneous preview modules.
- GPU/pass timing and representative phone sustained performance remain unestablished.
- Future priorities: representative fixed level/canopy openings; on-deviceGPUcapture and thermal runs; compare scale/MSAA/shadowtiers; static terrain AO/lightmapprobe plan without touching bendUV2; localized emissive practicals only where authored; optional bounded shafts with measured benefit.

Stop at this integrated **visual review**. Do not promote native libraries/Actions or productionWorldMap based on this desktop result.

## Follow-up — grass shadows disabled,2026-10-22

Latest user requests no shadows on either tall or short grass. All32grassMultiMeshbatches already had shadowcastingOFF. The shared grass shader now also uses native `shadows_disabled`, removing shadow reception for both families. Directional/ambient diffuse, rootgrade, texture colors and all vertexwind/contact logic remain unchanged; one render-mode token is the only code change. Character/zombie/tree/terrain shadow settings stay intact. Original A/Bnow compares lighting while retaining this latest grass shadow policy; the earlier fivephase media above predates this optimization.

[Current native image](reviews/md2_lighting_v001/grass_no_shadows/after.png) · [Before](reviews/md2_lighting_v001/grass_no_shadows/before.png) · [Native check](reviews/md2_lighting_v001/grass_no_shadows/result.json). ActualMobilecompile/render passed,32grassbatches/0casters, unchangedvertexbody. Paired60sampledesktopchecks stayed near60FPScap; renderCPUmedian.747→.653ms, but this is not GPUtime and is insufficient to claim a large FPSgain. MetalGPUtiming remains unavailable. No shadowcasterpass reduction is attributed to this change because grasscasting was already disabled.

## Follow-up — green grass-root blend, 2026-10-22

The user observes dark wedges rising from each grass base and requests continuity with the green terrain. Inspection of the actual atlases finds the tall grass median green already equals the terrain median (84,130,52 sRGB); the extra 0.82 material multiplier and side-facing diffuse response deepen the visible root band. This is separate from shadow maps, which remain disabled for grass.

The dev shader removes that multiplier, samples the existing ground-top atlas at each fixed root, and blends root albedo and upward lighting normal back into the leaf material over normalized height 0.02–0.62. Terrain UV mapping was verified from its exported top-face vertices: UV=(local X+0.5, local Z+0.5), and the current unit-block grid therefore repeats at `fract(world_root.xz)`. This contract is specific to the flat research field. Color sampling is per vertex, using one shared existing texture; no additional per-fragment sample, image, emission or global lighting adjustment. Cream seed tips and the upper leaf material remain.

This supersedes the earlier root-darkening description and exact Original-formula restoration claim: Original A/B now retains both the current green-root blend and no-grass-shadow policy. It still compares lighting. All deformation statements, geometry/UV/COLOR, roots, wind/contact clocks, populations and buffers remain exact; the vertex stage adds only a shading color sample.

[Before at 14:48](reviews/md2_lighting_v001/grass_root_blend/before_14.8.png) · [After at 14:48](reviews/md2_lighting_v001/grass_root_blend/after_14.8.png) · [Close-up](reviews/md2_lighting_v001/grass_root_blend/after_close.png) · [After at dusk](reviews/md2_lighting_v001/grass_root_blend/after_18.5.png). These native Mobile images freeze pose, camera and wind phase within each pair. They show the visible dark root band reduced while retaining leaf/seed definition.

Native compile/render logs contain no errors. The audit confirms 1,317 clumps, 32 batches, zero grass shadow casters, receiving disabled and two family materials sharing the actual top texture. All 29 grass contracts pass. SHA audit of 9,038 pre-existing Blender/game files permits only the grass shader and field texture binding changes; approved actor/combat/animation assets, WorldMap and project defaults are exact. This is a visual correction, with no measured phone-performance or FPS-gain claim.

## Follow-up — foliage lighting matches the terrain across the day, 2026-10-22

A further user screenshot at 16:36 shows that the base-only blend still leaves dark upper-blade wedges. The supplied MD2 frame is the visual target for continuous ground/foliage color. The earlier mixed face/up normal still lets blade yaw and bending drive directional brightness above the root blend. This effect becomes conspicuous under the authored low afternoon key.

The original dev adaptation now assigns a world-up fragment lighting normal to the whole blade and uses Burley diffuse, matching the actual terrain top's default diffuse mode (native audit reports mode 0). Thus changing leaf orientation no longer changes its direct diffuse brightness. The original root color sample and fade, leaf/cream seed textures, cutouts and every vertex deformation statement remain. There is no emission, extra light, altered sun/ambient palette or constant-brightness override: day/night light color and energy still apply. This is our material technique, not a claim about MD2's undocumented renderer.

Original A/B retains the latest foliage policy in both modes; its legacy `lighting_grade` input is retained for controller compatibility. Grass still neither casts nor receives shadows per the user policy. Terrain and actor shadow settings are unchanged.

[16:36 before](reviews/md2_lighting_v001/grass_daylight_match/before_16.6.png) · [16:36 after](reviews/md2_lighting_v001/grass_daylight_match/after_16.6.png) · [Six-time comparison](reviews/md2_lighting_v001/grass_daylight_match/daylight_comparison.png) · [Close-up](reviews/md2_lighting_v001/grass_daylight_match/after_close.png). Native Metal/Mobile captures use the actual existing scene and freeze pose/camera/wind within each pair. Reviewed 07:00, 12:00, 16:00, 16:36, 18:30 and 22:00; the dark face-dependent wedges are removed. Native compile/render log is clean. All 29 grass and 20 lighting contracts pass. SHA audit of 9,038 pre-existing Blender/game files changes only the grass shader; its complete vertex body is byte-identical. No new scene/project, source asset or gameplay changes, and no phone-performance or FPS-gain claim.
