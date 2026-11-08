# Unified playable Overworld showcase

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
