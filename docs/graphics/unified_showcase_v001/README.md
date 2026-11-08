**2026-11-08 � Terrain implementation authorized and applied:** F5/L TERRAIN now
compares Previous, source PBR, original local colored indirect and Combined.
Combined defaults ON for review. See [terrain transport guide](../../../game_mobile_3d/assets/graphics/world_map_terrain_transport_v001/README.md)
for source boundaries, guards, controls, regeneration and validation. Player
Combined and approved grass/gameplay/global light/exposure remain preserved.
This explicitly supersedes the earlier terrain-research-only note below.

# Unified playable Overworld showcase

**2026-11-08 — Recovered background gusts:** dense private WorldMap grass now
reuses the existing audited two-noise wind permutation instead of the small sine
sway. Two point/repeat samples advect separately at100× different spatial scales;
the nested easing produces travelling gusts, then the existing verified rotation
helper bends relative geometry above the captured10cm pivot pin/1cm ramp.
Captured gain0.62831855 includes native global/material multipliers; it is not
multiplied by the old .5 strength again. Wind OFF gates it exactly. Source clock,
speed, spatial scale, axis and noise are external hash-validated research inputs.
Only wind keys are consumed from the old private profile; its graphics settings
are not applied. Simulation elapsed time drives the existing interpolated clock.

L → **Grass gusts · recovered MD2 wind** restores the exact preceding sine
motion. Existing **Grass wind** disables background wind in either selection;
player contact remains independent. Missing/changed evidence falls back to the
previous motion. Prior flower-study motion, approved spread/light/palette, density,
paths, actor and mute stay. Per-card UV2 roots adapt native individual-instance
pivots to our composite. Other grass-family permutations, native world phase and
complete contact/Niagara equivalence remain unverified. No dynamic gust recoloring
was added. Native-style wind and the existing contact arc add independently.

Actual current vertex-body GPU probe with captured position/pivot/time/noise:
max displacement error0.0000003152m against the native trace. Root-pin and wind-OFF
probes return exact zero. Frozen old-mode restoration and wind-OFF time sweep are
pixel-identical.48frames per mode preserve locked framing; temporal image change
3.57→4.76 RGB codes is a motion diagnostic, not an MD2 accuracy score. Live player
contact still produces force1.0227. Four focused contracts pass; static review
found no important issues. Source files and proprietary noise remain external.

Two added vertex texture fetches, no new passes/geometry. Conservative wind bounds
reserve the original contact margin; view draws128→133 due to changed culling.
Desktop ABBA medians old .773/1.680ms vs new1.052/1.112ms show substantial background
drift: **do not infer a causal GPU cost or phone throughput**. Phone profiling is
pending. Native pivot rotation can move some tilted composite card corners below
terrain; the CPU support sweep records1,505/138,240 sampled tip corners (including
transparent corners), minimum−.177m. Roots stay pinned; no invented ground clamp
is called native behavior. Visible clipping across all terrains remains a review
boundary. Private video previews, probes and evidence:
`MD2 Research/godot_lab/world_map_unified_showcase_v001/grass_wind_v001/`.

**2026-11-08 — Outward grass spread:** existing private capture draw913 confirms
non-upright placement before WPO, although the source cards themselves are vertical.
102 reconstructed input inclinations span0.274–56.958deg, median32.884deg;
instance57 uses the native-trace-confirmed identity and measures10.746deg.
Other instances are decoded captured inputs, not individually debugger-verified.
External hash-validated angles now pitch the existing four-card patches radially.
This radial composition is an original adapter, not the recovered native
population/placement algorithm. Source cards/UVs remain untouched and unscaled.

L → **Grass spread · captured inclinations** restores exact prior upright
patches. Missing/changed private profile falls back upright. Prior grass/flower
profile is unaffected. The 8,418 cell roots, paths, density, lighting, camera,
character and mute remain. Pitched source normals are nearly UP before placement;
their tiny source deviations are retained. Motion uses those normals as the rest
direction: the existing arc delta is projected into the pitched rest frame,
avoiding the stretching caused by adding an upright arc to a tilted stem.
This remains an original wind/contact adapter, not native Niagara equivalence.

Validation: source mesh hashes and bundle unchanged; static card edge error
<0.00000024m, inclination error<0.00000018rad; support/contact bounds pass.
Actual GPU shared-helper test4,896cases preserves theoretical arc chord length
within0.00000057m and keeps tips above ground. That test verifies the independent
helper, not complete native wind equivalence. Same-camera upright restoration is
pixel-identical; actual player force remains1.0227. Native Mobile shows spread,
wind/contact and lighting together. Same close view93draws both modes; ordinary
view127→128 from changed culling bounds, with unchanged96batches/card counts.
No added texture lookup/render pass; small vertex projection cost and alpha
overdraw still require phone profiling. Private evidence/scripts/images:
`MD2 Research/godot_lab/world_map_unified_showcase_v001/grass_splay_v001/`.

**2026-11-08 — Grass light response:** default private Mobile WorldMap now uses
the hash-validated captured Day grass normal weight1, applied after interpolation
in world space. Source evidence: private `godot_lab/grass_normal_response_v001/`
(PS835/913); the buffer remains external. This is the verified normal consumer,
not recovery of the entire native foliage lighting algorithm.

Original mobile equivalents add real alpha-tested grass shadows, the existing
ground's directional cloud attenuation, and bounded warm tip transmission using
the existing GAF foliage helper (.1248 original policy, not an MD2 constant).
Direct transmission shares shadow/cloud attenuation; no emissive or ambient lift.
Existing palette, textures, source scale, density, wind/contact deformation,
paths, character, audio mute and scene remain unchanged. Native Lumen/indirect
lighting and complete native two-sided scattering are not reproduced.

Press L → **Grass lighting · MD2 study** for an exact old-shader/shadow-OFF
comparison. B baseline also suspends the new path. Unsupported renderers or
forced vertex shading retain the old response. The private captured parameter
must validate; absent/changed data falls back safely. Flowers keep their old shader.

Validation: native Mobile/D3D12 contract and planting regression pass; independent
static review found no important issues. Frozen same-camera OFF restoration is
pixel-identical; transmission ON/OFF without sunlight is pixel-identical. Grass
ROI luminance p90–p10 increases14.55→41.17 (contrast diagnostic, not MD2 error).
Actual player passage produces force1.0227; a controlled force .9081 decays to
.00328 after4s with the new light path enabled. Native static spawn draws85→127;
current capped desktop motion interval16.66ms. Extra alpha-shadow draws require
phone measurement; neither handset FPS nor full MD2 visual equivalence is claimed.
Private screenshots, scripts and receipts:
`MD2 Research/godot_lab/world_map_unified_showcase_v001/grass_light_match_v001/`.

**Current grass-only density review:** flowers are temporarily hidden. All8,418
supported grass blocks in the100m playable boundary have one patch root; actual
dirt-path and stone blocks remain unplanted. The optional shader ground-kind mask
also clips overhanging blades away from dirt/stone, preserving readable paths.
There is no noise-density omission, empty spawn circle or cell-fit downscaling in
this review. Trees, root-soil speckles and audio remain off.

Each transient private patch assembles three original MD2 Medium cards and one
Short card at **native1x scale**, with rotated root offsets. Medium heights are
read from the source meshes (approx0.671/0.941/0.926m), against the recovered
player body height2.003417m. Root uniqueness remains one patch per block;
canopies may overlap naturally and are no longer clipped to individual cells.
This crossed-card assembly and distribution are original review adapters, not
an exact recovered MD2 patch mesh or native population density. UVs, alpha atlas,
normals and motion channels are preserved. Generated private meshes stay in RAM.

L: **Dense grass only · native card scale** switches between this review and the
previous4,642grass/flower study, preserved unchanged. G still toggles planting;
wind/contact controls work in either profile. Immutable material wind strengths
are retained across profile switches, including switching while wind is off.
Both profiles, terrain coverage, source scale, no dirt roots, mutable wind
regression, grounded Idle, mute and cliff contact pass validation.

Native Mobile/D3D12 review:96batches/33,672cards, observed87draws in the spawn view,
60FPS-capped desktop interval16.66ms. This is not mobile-device throughput.
Wind, actual movement contact and continuous4s recovery were captured privately in
`MD2 Research/godot_lab/world_map_unified_showcase_v001/dense_native_grass_v001/`.

**Current planting — grass and flowers only:** WorldMap now displays4,642 private
MD2 reference instances:3,821 grass assets and821 flowers (pink256, yellow184,
white210, purple171). There are3,460 carpet-grass cells plus smaller clumps and
flower pockets. One asset per integer XZ block, on supported grass terrain only;
the dirt paths and spawn clearance stay open. Original meshes/textures load from
the existing Research bundle, without extraction or copied assets in res://.

The original placement adapter fits/recenters each mesh inside its cell with
bounded jitter, rotation and scale. Animated tips also stay within that cell's
0.48m half-extent. Rendering uses105 spatial MultiMesh batches,8 species and a
shared interaction field. G now toggles ONLY these grass/flower batches; L offers
independent wind/contact toggles. Trees, old schematic vegetation, brown root
speckles and default audio remain off. Existing player, camera and graphics stay.

Motion reuses the private lab's wind/grass/flower deformation and underdamped
recovery, with an optional receiver-height callback for this stepped map. Plants
on a3m higher cliff do not receive a player's lower-level contact. Existing field
memory recovers instead of being masked off instantly. This is an original
terrain/placement adapter; source wind parameters are evidence-backed but complete
native Niagara/Jump physics equivalence is NOT claimed.

Validation: actual map cell uniqueness, transformed mesh bounds, support heights,
four flower colors, distinct UI controls, grounded Idle/mute and cliff contact
pass. Legacy flat-field29 checks and the complete showcase contract pass. Native
Mobile/D3D12 shows wind and force-driven motion, recovery without teleport reset,
and active contact during actual movement. Same-camera bare/planted and motion
images plus numeric results are private in
`MD2 Research/godot_lab/world_map_unified_showcase_v001/grass_flowers_cells_v001/`.
Desktop capped timing is not a handset performance certification.

**Latest test defaults:** all project test audio starts muted via the default
Master bus. L can explicitly enable it for a review. Hidden vegetation now also
removes its root-soil/contact flags and oak IDs from the live ground field while
preserving terrain height/kind/path-edge channels; G restores the exact planted
field. Startup fix: the first physical ground contact now clears the transient
JumpAirborne state, which previously persisted despite floor=true/velocity=0.
Only that initialization branch changed in the source controller; clips, normal
jump physics, combat and approved animation data remain unchanged.

**Follow-up user change:** trees, schematic foliage, grass and flowers are absent
from the playable map by default. Their trunk collisions, canopy/contact shading
and oak-root shading are disabled too. Terrain/grass blocks, character, combat,
lighting and source assets are preserved. G can restore the saved vegetation for
comparison; explicit original-player diagnostic mode retains the old planting.

2026-11-08. User-authorized integration after the closed graphics checkpoint;
not a declaration of MD2-quality completion or a restart of broad research.

## Open and play

Open `game_mobile_3d/project.godot` in Godot4.7.2, press **F5**.
The main scene remains `res://scenes/WorldMap.tscn`. `Open World Map.cmd` also
starts it. Restart an existing play session to load changes. F6 runs the selected
scene and can open an older lab.

The user selected **A&S / MD2 + Sabre as the primary player going forward**.
The editor loads its existing private model, rig, motion, runtime profiles and
audio transiently from `MD2_RESEARCH_ROOT`, defaulting to
`C:/Users/ADMIN/Desktop/MD2 Research`. These remain reference-test assets, not
new original production assets. Missing data gives an explicit warning and
disables the placeholder's gameplay. Exports cannot load this editor-only adapter.
No release build is claimed; private assets stay outside Git and releases.

| Control | Behavior |
|---|---|
| WASD | Normal source-controller run,7m/s |
| Shift + WASD | Slow Walk, preserving the source lab convention |
| Space | Jump; existing repeated-jump/flip behavior retained |
| LMB / E | Held Sabre combo; airborne downward attack |
| RMB | Combat-ready strafe and mouse ground aim |
| Q / C | Combat-ready turn |
| R | Authored spawn reset, clearing input/audio/trail history |
| L | Compact options, hidden by default |
| B | Original / combined graphics, same player and map |
| T / Shift+T | Next time preset / toggle time cycle |
| V / Shift+G | Existing overview / visit existing grove |

L offers time buttons, cycle, local exposure, private audio and experimental
terrain-cache controls. Existing F-key graphics comparisons remain available;
the updated list is in `HUD/Help`. No duplicate lab UI/environment is installed.

## Combined graphics defaults

Existing Day composition and balanced finish, sunlight/soft shadows, atmosphere,
direct cloud shading, foliage transmission, root soil, canopy contact, leaf
sampling, grass/path verge and ground/plant variation are combined with the
existing directional ambient fill, actor crown visibility and guarded static
ground-reflected sunlight. Support guards remain active.

Bounded local exposure is active on supported devices with scene-only original
art strength **0.12**, versus standalone review0.23. Gain clamps/shader math are
unchanged. B and re-enabling F7 retain this profile. Unsupported devices fall back.
F12 terrain-sky cache is **off by default** because prior cross-run image closure
is unresolved. It remains opt-in.

Default12:00, paused. The existing independently authored GAF hourly palette is
applied relative to this exact Day anchor. This is **not a recovered MD2 cycle**.
Non-Day direction/fill suspend static Day caches; noon and baseline restore their
proper state, including after overview or graphics hotkey changes.

## Architecture and preservation

`scripts/world_map_showcase.gd` selects the primary before child ready callbacks,
owns options/time and coordinates Environment edits. Its palette is export-safe
original GAF data. The existing geometry, placement, camera and scene are retained.

Editor-only `world_map_actor.gd` extends the unchanged Sabre Actor and reuses its
Effects, ReferenceAudio and RenderPresenter. The presenter owns displayed bones,
face groups, weapon and root; camera/vegetation/actor lighting read that same root.
Physical-root interpolation stays off to avoid double smoothing. The adapter
bridges the existing map reset/jump/collider API and routes combat inputs.
Old pistol Combat/SpawnDirector services are removed **at runtime before ready**,
because they require an incompatible Pistol API. Their source scenes are preserved.
This provides sword whiffs/effects; no new enemy combat is introduced.

`world_map_audio.gd` reuses the private meadow audio engine with map surface queries.
Only the audio manifest section is loaded, not another meadow. Wind, birds/nature,
contact footsteps/rustle and Sabre samples are active. Sample identity is verified;
native event graphs, mixing/attenuation and ordinary dirt mapping remain adapters.
No fake impact on an empty hit.

`GAF_SHOWCASE_PLAYER=original` explicitly restores the previous player, services,
UI and defaults for diagnostics. It is not a silent primary fallback. Existing
export guard excludes the private dev tree; production scripts have no static
dependency on it. No private GLB/audio/source key arrays are saved into res://.

## Validation

- Actual-primary contract passes headless and Forward Mobile/D3D12: external
  rig32/hybrid/25 semantic states, speed, presenter, hidden HUD, reset history,
  Day/Night/overview and baseline restoration, bounded exposure recreation.
- Real input route at render caps30/60/120, physics60: run, jump, air attack,
  full held combos, release/recovery and direction changes. Zero failures;
 21 accepted strikes including3 air attacks. Peak run7m/s.
- Short desktop route wall-frame means33.37/16.67/8.33ms,308–311draws, RTX4070TiSUPER,
 1280×720/Mobile D3D12/MSAA2x. Capped diagnostics are **not handset throughput,
  sustained performance, isolated GPU cost or30/60/120physics certification**.
- Existing hybrid transitions431, combat handoffs97, foot placement281, jump
  timing48 and private loading14 checks pass. Stale loading count corrected to
  include the already-existing optional JumpFlip state; controller core unchanged.
- Legacy main map7094checks/394rays passes in explicit original-player mode.
  This is geometry/legacy coverage, separate from actual-primary tests.
- Same-framing original/combined/no-local-exposure/restored/night/options images
  captured and visually inspected. Local exposure built without error, approx
 3.69MB targets at720p. Artistic quality remains subject to user review.

Raw measurements, screenshots, scripts and logs remain private at
`MD2 Research/godot_lab/world_map_unified_showcase_v001/`.
No phone benchmark, native-cycle/Lumen parity, terrain-cache closure, new artistic
approval or production eligibility is claimed. Next: review the unified F5
experience, then profile devices and target specific remaining visual gaps.
# Player material comparisons — 2026-11-08

**User approval follow-up:** Combined is now the persistent player default,
including clouds and the two validated Day skin terms. Original/neutral and every
independent comparison remain available. Night/source/renderer guards are unchanged.

F5 still opens the existing WorldMap. **L → PLAYER MATERIAL** selects Original,
Neutral, Cloud only, recovered Valorie Roughness only, recovered
view-facing Self-light only, or Combined (approved default). Original restores actual previous
surface overrides; B remains the whole-map baseline. F3 also gates player direct
cloud shading. The scrollable options panel fits 720p. Audio remains OFF.

The focused factory `world_map_player_material.gd` and `world_map_player_pbr`
shader now preserve all three current private surfaces: opaque Sabre, alpha-cutout
body/face, original nearest atlas, separate metal/rough channel selection and
emission. Unsupported flags/features/materials or renderers restore the source.
Godot owns ambient, fog, shadows and the no-cloud direct BRDF. Existing canopy
visibility retains its own control across every comparison mode. The old original
GAF actor keeps its previous path. No rig, motion, grass or environment asset changed.

Recovered parameters are loaded from a hash-validated **external** PIX buffer;
Valorie identification checks atlas and ORM pixels/channels, not duplicate names.
The Day roughness transform and cubic N·V self-light are independently authored
equivalents of recovered operations. They now default ON after user approval, suspend outside verified
Day/source conditions, and never apply to Sabre. Source emission is retained;
this is not a complete native emissive/SSS/indirect-light reconstruction.

Validation: 63 native Mobile material/state checks, 12 headless fallback checks
and 29 legacy actor-fill checks; existing primary-showcase,
grass lighting and wind checks pass. Locked original↔neutral and restore images
have **0 changed pixels**; no-sun cloud comparison also has 0. The custom direct
cloud path is not bitexact: a unity-field diagnostic has p95 4/max7 RGB byte
differences among changed pixels. It avoids the older actor helper's artificial
GGX clipping; grass/terrain helpers are unchanged. Shader precision/compilation
closure remains open. Comparisons include whole final-image effects of grading
and exposure, not registered MD2 error scores.

Private reproducible inputs, screenshots, tests and timing:
`MD2 Research/godot_lab/world_map_unified_showcase_v001/player_light_audit_v001/adapter_v001/`.
Desktop ABBA viewport samples showed 133 draws in every mode and approximately
0.361–0.364ms GPU on RTX4070TiSUPER/Mobile D3D12. These are shared-workstation
observations, not isolated causal cost or handset performance certification.
Human artistic review and phone measurements remain pending.

## Terrain investigation follow-up

The approved player now defaults to Combined. Terrain remains unchanged while
private material/light A/B studies at three existing map views investigate PBR
input preservation and position-dependent colored indirect lighting. See private
`player_light_audit_v001/adapter_v001` for the prior adapter checkpoint and
`terrain_light_audit_v001/README.md` beside it for new source-backed findings,
math counterfactuals, cutaway-aware screenshots and exact restore checks.
No new capture, extraction or production terrain feature is introduced.
