# Grassland v4 — broad blades and reference palette

ARTISTIC STATUS: AWAITING HUMAN REVIEW. The actual default `Grassland.tscn` now uses the v4 Blender exports and scene-local presentation. The approved v3 Blender source, GLBs, atlas and original shader remain available through A/B. The shared `Gameplay.tres`, 40×40 layout, collision, production player, camera, movement, combat and numeric weapon controls remain intact.

## Review controls

Run `scripts/launch_grassland.ps1` for the updated actual game, or `scripts/launch_grassland_lookdev.ps1` for the peaceful material review. Both use Godot 4.7.2 Mobile/D3D12 on this workstation. The main scene selection remains Grassland.

- **F1:** previous v3 geometry, atlas, materials, lighting palette and original motion, with fog disabled.
- **F2:** new v4 geometry and presentation; starts selected.
- **Tab:** compare at the same camera/player position without resetting motion history.
- **F3:** player-shadow blur .30/.50. Grass never casts shadows in either setting. This is a minor appearance control, not a phone quality tier.
- **WASD / Shift / R:** existing move, sprint and reset. **1/2/3:** existing pistol/rifle/shotgun controls.
- **F7:** the actual game's existing optional combat review remains functional. The dedicated LookDev scene blocks both F7 and `--combat-review` from spawning an enemy.
- **F4, LookDev only:** show/hide the eight-cell, 4×2 bare-dirt sample at the cleared center. Previous v3 always hides it. The actual game remains all grass.

## Blender assets and integration

`blender/environment/studies/grass_block_reference_v4/grass_block_reference_v4.blend` is editable and includes the broad grass, thicker green cap and bare dirt block. The v4 grass has **36 flat rectangular blades**, **288 authored vertices / 216 triangles**, heights **.2821–.4795 m** and widths **.12035–.19923 m**. Every tip retains its base width; there are no needle tips. The four rings remain **0/.22/.65/1**, with quadratic red bend mask, green normalized height, and imported UV2 roots. Generated grass LODs are disabled so decimation cannot destroy the blade silhouette or masks.

The actual map imports `grass_patch_v4.glb`, `grass_dirt_block_v4.glb` and `environment_atlas_v4.png`. Grass cap depths change from **.125/.1875/.25 m** to **.14375/.215625/.2875 m**: exactly **15% thicker**, while block dimensions and collision remain 1 m tall. The comparison swaps actual previous/new block chunk geometry as well as their atlases. The distribution stays at **400 seeded patches**, with no per-grass colliders.

`dirt_block_v4.glb` is a separate **1 m cube / 12 triangles**, with warm ochre top pixels and deeper brown-gold sides. LookDev instances eight actual GLBs and removes exactly their eight underlying grass tops, so every one of the 1600 map cells is rendered once at Y=1. There are no additional colliders, shifted surfaces, holes or coplanar overlap. Soil material sampling preserves the authored dirt UV tile.

## Palette, light and motion

The two user references guide original authored meadow/dirt swatches, broad grass shape and lighting; no protected graphics or level content are copied. The new 128² atlas supplies integrated meadow greens, cooler deep blade greens and softer sunlit greens. Terrain samples its meadow pixels in an irregular world order, removing repeated diagonal stamps. Gentle broad color fields link leaves to the ground; the dirt sample supplies the requested ochre contrast.

The scene-local warm sun uses **rotation −48°/−42°**, **energy 1.10**, color **(1,.94,.82)**. Cool ambient fill uses **(.63,.75,.84)** at **.52 energy**. Two-sided matte blade shading keeps both faces readable. No SSAO, SSIL, SDFGI, SSR, glow or volumetric fog is enabled.

The user's latest steering **defers fog entirely**. Fog is disabled in both actual-game and LookDev appearances, including previous v3 and both F3 settings. There is no active atmosphere clock, dynamic tint/density update or F5 binding/HUD control. The previous appearance uses a local environment copy with fog disabled; shared `Gameplay.tres` stays untouched. The removed experiment is retained separately for a future authorized revisit.

**No grass casts shadows in any A/B or F3 mode.** The prior baked `root_shade` grass-cluster map and generator are removed. Player meshes retain sun shadows, with bias **.025**, normal bias **.45** and opacity **.78**. A small player-only contact ellipse remains. Grass may receive the player's real shadow. The stored sun shadow distance stays 29 m; it is not claimed as an optimization for this orthographic camera.

Wind remains **3×**, player splay **1.85×** and influence **.90 m**. The continuous movement tracker, eight-segment limit, soft cancellation and **.8 s recovery** remain unchanged. Combined bend is capped at **min(.18 m, half the vertex's rest height)**, preventing shorter leaves from folding flat. Roots stay fixed and vertical arc shortening avoids stretching. New culling margin is .22 m. GPU readback measured peak tip wind **.0152 → .0472 m**, walking bend **.0472 → .0848 m**, and capped combined bend **.1801 m** on a .36 m test blade.

## Verification and captures

Focused tests recorded missing-v4 and missing-soil failures before integration. Final runtime checks pass: **929 v4 imported geometry/A-B/F3/combat/no-fog checks**, **2979 terrain/controller checks**, **308 motion checks**, **434 review checks**, **434 review checks with `--combat-review`**, **1927 soil replacement/A-B/F4 checks**, **21 preserved shader GPU checks**, and **11 v4 shader GPU checks**. The existing animation-test-enemy validation also passes. Tests exercise actual imported vertices, masks, cap depths, rendered chunk assignment, continuous motion, controllers and input dispatch; shader movement is measured on the actual GPU vertex computation.

The active capture harness writes **31 actual no-fog Godot PNGs** to `.validation/grassland_v4`: paired previous/mobile/player-detail standing, walking, sprinting, boundary, broad-tip detail, passage splay, wind phases and soil views. Comparison triplets freeze simulation only across each pair. Capture FPS/HUD readback is excluded from performance evidence.

The earlier **31 presentation captures** are preserved in `.validation/deferred_fog/prior_presentation`. The **six fog PNGs**, experimental runtime snapshots/tests/logs and fog profile are preserved separately in `.validation/deferred_fog`; these do not describe the active game. Archived fog tests expect the removed experiment and are excluded from active validation. Active v4 checks explicitly exercise all appearances/quality settings with fog disabled and verify that F5 cannot turn it back on. Normal/flag review contracts, soil replacement and both shader suites pass after removal.

Import completed successfully but this sandboxed Windows editor emits its existing safe-save settings warning. Final runtime, capture and profile logs contain no script/shader errors. Runtime validation uses workspace-local APPDATA and absolute forward-slash log paths.

## Warm desktop measurements

The initial three serial processes measured the **actual Grassland game before the changing-fog follow-up**, one appearance each, at **1280×720**, Godot **4.7.2 Mobile/D3D12**, RTX **4070 Ti SUPER**, VSync disabled and no FPS cap. Each had a three-second startup warmup, movement/overview warmups and three real-time three-second sampling windows. No screenshot readbacks or Blender renders overlapped; the user's static Blender asset-review window was open. The following table preserves those initial comparisons.

| Median | Previous v3 | V4 mobile | V4 player detail |
| --- | ---: | ---: | ---: |
| Idle CPU process, ms | 1.389 | 1.390 | 1.595 |
| Idle measured render GPU, ms | .168 | .144 | .142 |
| Idle draw calls | 41 | 41 | 41 |
| Sprint CPU process, ms | 1.594 | 1.523 | 1.567 |
| Sprint measured render GPU, ms | .179 | .154 | .146 |
| Full-map CPU process, ms | 2.337 | 1.555 | 1.609 |
| Full-map measured render GPU, ms | .131 | .120 | .116 |
| Full-map draw calls | 48 | 48 | 48 |
| Full-map primitives, including player shadows | 134,120 | 102,914 | 102,950 |

The smaller authored patch reduces the grass geometry count, while both v4 appearances avoid any grass shadow pass. Fragment shading/world pixel sampling costs more than the previous plain material; A/B retains additional cached previous meshes for immediate comparison. The optional LookDev dirt sample adds eight block draws and is excluded from this actual-game profile. There is no extra root texture.

Fog is deferred, so **no new warm GPU run was required for its removal**. The table above reuses the clearly labeled pre-atmosphere measurements; they used the earlier static .0025-density fog pipeline and are historical baseline readings, not a measured no-fog result. The later changing-fog profile remains archived at `.validation/deferred_fog/v4_profile_mobile.json` for future experiments.

These are indicative desktop readings, not phone performance claims. CPU process monitoring refreshes once per second; noise is visible in sprint p95 **7.174/7.375/7.023 ms** and player-detail idle p95 **23.374 ms**. Raw initial means, medians and p95 remain in `.validation/v4_profile_current.json`, `v4_profile_mobile_before_atmosphere.json`, and `v4_profile_high.json`; the deferred changing-fog rerun is archived separately. Android/iOS thermal, GPU, memory and battery testing remains pending. The flat map still lacks the references' elevations, architecture and composition; this pass changes the requested assets and presentation. Human art approval remains pending.
