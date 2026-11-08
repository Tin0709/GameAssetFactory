# WorldMap colored terrain transport

**Corner correction,2026-11-08:** Normal-offset rays at concave grid endpoints
could enter neighbouring blocks. The baker now retains already-empty origins
exactly and resolves blocked ones within the existing1cm tangent neighbourhood;
unresolved enclosed receivers fail closed. The current cache repairs10107 unique
receivers (13864 vertex instances);120942 other instances retain bitexact sky/sun
data. This corrects false corner darkness without changing global exposure,
direct shadow filtering, source geometry, shaders or runtime stream size. It is
an original integration-boundary fix, not native MD2 Lumen/PCSS recovery. F12 is
labelled explicitly as a legacy sky-only replacement, not an additional effect.

Original GAF data, derived exclusively from the existing authored map/atlases.
`transport.res` is a compressed approximately1.1MB Resource, not MD2 reference
data. It covers598 surfaces/134,806 generated vertices/56,993 unique receivers.
Two RGB float streams add3,235,344 bytes of vertex attribute payload; cache CPU
arrays and transient mesh construction have additional memory overhead.

The offline256-ray integrator traces the original solid half-cell grid. It
separates visible directional sky and one diffuse sunlight bounce from average
authored surface colors. A bounded geometric-series sky-bounce reserve is an
original approximation. Source MD2 evidence motivates linear material channels,
dielectric response and separate spatial incoming light; this is **not Lumen**,
native radiance generation, or native MD2 preset data.

Runtime requires the calibrated Day context, exact map/material recipe/geometry
identity, unchanged world transforms, a matching sun direction and the original
ambient owner. Unsupported context restores the preceding recipe. Transform
notifications validate moved/restored chunks without per-frame ray tracing.
All rows/payload/profile values validate before atomic mesh replacement. Source
positions/normals/UVs/colors/indices/collisions remain unchanged; CUSTOM1/2 are
transient render data. Existing CUSTOM0 terrain visibility remains available.

F5 opens WorldMap; L → TERRAIN offers Previous / PBR only / Local indirect only /
Combined. Combined is the new default for review. B restores the original whole
look. Shift+F1 gates reflected sunlight while retaining local sky. F3/F11/F8,
optional F12 and non-Day contexts can suspend the new field. Old mineral bounce
and visibility do not stack with it. The approved player/grass owners and global
light/exposure settings are preserved.

## Regenerate with existing tools

Work from the GameAssetFactory checkout. Use the installed Godot console as
`<godot>`. Choose new scratch directories; the exporter/baker refuse reuse.
Set `GAF_SHOWCASE_PLAYER=original` for authoring, then clear it before normal play.

1. `<godot> --rendering-method mobile --rendering-driver d3d12 --path game_mobile_3d --audio-driver Dummy --script res://tools/export_world_map_terrain_light.gd -- <scratch-export>`
2. `py -3 -m scripts.graphics.terrain_irradiance --source <scratch-export> --output <scratch-bake> --rays 256`
3. `<godot> --headless --path game_mobile_3d --script res://tools/pack_world_map_terrain_light.gd -- <scratch-bake>`

The baker requires identity chunk bases and original grid-aligned translations;
restore the grid before rebaking a transformed scene. Regenerate after authored material/layout changes.
Export uses actual scene material colors/recipe and exact solid half cells, with
low-frequency face averages. Trees, moving vegetation, fine source textures,
dynamic emitters and cloud variation at secondary hit points are not traced.
Cutaway walls remain physical occluders, consistent with their retained shadow
casters. Native indirect specular/reflection transport remains separate work.

## Validation and limits

Native Mobile1812 checks (Compatibility/headless1800 each), 5 analytic/independent-ray
Python tests and7 HDR cases
pass. HDR response/channel/emission tests have maximum absolute error9.77e-5.
A128-receiver256→1024-ray comparison gives p95 skyRGB.00322 and unit-sunRGB.00193.
Three locked Previous/Combined/restore sets have exact0pixel restore error.
Against original checkpoint shader code, small residuals remain (1–64 pixels,
max20RGB byte; whole-image mean error≤.000062 byte); no cross-version bitexact
claim is made. Correct Lambert flags are used in this comparison.

Actual movement/jump/held combos at physics60/render caps30/60/120 show no added
trajectory error: the30Hz feature and repeat-control residual are both.1305mm;
60/120 are exact. Source run parameter remains7m/s. Existing player63, grass light/wind, legacy
bounce17/terrain-sky535 and full-map7094 checks/394rays also pass. Desktop RTX4070TiSUPER/Mobile
D3D12 ABBA viewport medians were approximately.365–.366ms Previous and.304–.305ms
local lighting,133draws in every mode. These are shared-workstation observations,
not isolated causal cost, sustained FPS or phone certification. Artistic review
and target-device memory/performance acceptance remain open.

Detailed screenshots, input identities, controls, HDR/convergence results and
logs stay in private `MD2 Research/godot_lab/world_map_unified_showcase_v001/terrain_spatial_light_v001/`.
