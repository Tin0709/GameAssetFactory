# Player lighting in the existing main WorldMap

F5 runs `game_mobile_3d/scenes/WorldMap.tscn` with the existing private primary
player. The default Combined mode now includes original map-derived local RGB
incoming light, a broad rough-specular proxy, and selective skin softening.
No character, Sabre, animation, controller, camera, grass, terrain, fog or global
sky asset/preset was rebuilt or retuned. Test audio remains off.

In **L → PLAYER MATERIAL**, the three additional checkboxes compare:

- **Player · local colored indirect:** replaces engine diffuse ambient on the
  player with the original six-direction field. It does not stack a second
  ambient term. Crown visibility still applies independently.
- **Player · broad rough reflection:** original low-frequency incident-field/F0
  proxy. Global environment reflections remain unchanged, avoiding terrain and
  foliage changes. This is not recovered MD2 reflection radiance or a sharp
  cubemap/reflection-probe solution.
- **Player · masked skin softness:** external, hash-verified source MRES alpha
  identifies selected Valorie skin; only those texels get an original normalized
  diffuse-wrap response. Width .15 is an authored policy, not recovered native
  scatter radius. Eyes/mouth/clothes retain the source mask decisions. This does
  not implement the native screen-space SSS diffusion/history filter.

Disable all three to restore the preceding approved Combined player treatment.
The existing material selector still isolates original/neutral/cloud/roughness/
self-light modes; new effects are restricted to Combined. B retains the full
graphics baseline. Night, non-Mobile/vertex shading, incompatible map recipes,
changed terrain transforms and out-of-volume samples keep the preceding path.

## Data and source boundary

Recovered source evidence identified per-texel model1/5 selection from MRES alpha
and profile1, verified selective recombination and incident diffuse/specular
contributions. It motivated the separation of terms; it does not establish
numerical equivalence of this original volume or skin wrap with MD2.

The original map field is at
`game_mobile_3d/assets/graphics/world_map_actor_light_v001/field.res`. Incoming rays
use only the existing GAF solid grid and averaged authored face colors. Runtime
samples three heights, interpolates six directions, scales sky and bounced sun
separately, and submits changed uniforms. There are no per-frame physics rays.
Coarse empty-corner interpolation, static terrain, low-frequency directionality
and the lack of dynamic occluders are explicit limitations.

Source skin/ORM/emission/UVs remain unchanged. Metallic reads the correctly
repacked ORM B channel. MRES alpha is loaded into a transient R8 texture only
from the private research folder, with exact RGBA identity and Valorie material
guards. No proprietary source texture/mask/clip/code is saved in project assets,
Git or release exports. Missing/mismatched mask disables only the skin response.

## Validation checkpoint

- Original Python integration/terrain tests: 11 passed.
- Native Mobile player-field contracts: 39; original player-material contracts:
  63; showcase25clips; terrain response4790/terrain1959; grass light and mist pass.
- Headless and Compatibility: 9 field/fallback contracts each.
- Complete production shader on synthetic authored HDR inputs:20cases,
  max absolute error5.96e-5. Direct skin-wrap GPU ratio .8696289 versus independent
  normalized formula .8695652. This tests our implementation, not native MD2 parity.
- Three fixed-camera locations:18images, exact full-frame off/on/off restores.
- Real existing-controller movement/jump/reversal/combo routes at render caps
  30/60/120 with physics60: no trajectory error beyond repeat-control noise;
  maximum .1305mm at30Hz also occurs in the control. Speed parameter7m/s retained.
- Shared desktop Mobile/D3D12/RTX4070TiSUPER samples: same86draws in the held
  close view. GPU clocks drifted across ABBA (.36–1.13ms medians), so no causal
  incremental GPU-cost claim. Forced three-height CPU refresh roughly82–103us
  before the final metadata guard; not phone timing. No handset certification.

Private images, measurements, before snapshots and exact reproducer scripts:
`MD2 Research/godot_lab/world_map_unified_showcase_v001/player_light_integration_v001/`.
The original authoring export was refreshed to include recipe identity; numeric
sky/sun/valid payloads remained byte-identical. Fresh review found normalization
and stale-albedo gates; both are corrected and covered by fallback tests.

The result is ready for visual review, not a declaration of native SSS/Lumen
recovery, MD2-quality acceptance or mobile-device performance approval.

Final-code six-block interleave (64 warm/96 samples each) observed GPU medians
.364–.365ms off / .368ms on,86draws in every block. Forced full CPU refresh
medians80.5–96.5us including final metadata checks. This is a shared desktop
observation, not an isolated causal estimate or phone performance certification.
