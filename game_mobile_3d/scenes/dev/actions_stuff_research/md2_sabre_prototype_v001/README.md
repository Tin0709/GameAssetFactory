# Player + Sabre prototype

F6 in the existing `ActionsStuffWalkRunTest.tscn` now opens this prototype
directly. Use `game_mobile_3d/Open Sabre Editor.cmd` in the canonical
`C:\Users\ADMIN\Desktop\Dev\GameAssetFactory` checkout to select this scene.
The user chose Desktop\Dev as the main development location; prior C:\Dev work
has been consolidated here and its earlier versions preserved outside Git.
Launching the same scene with `--md2-sabre` also works.
**Return to original Rifle / Sword lab** overrides even the command-line opt-in.
Only the saved scene's Sabre entry flag changes. WorldMap, original actors,
grass and lighting are preserved. `--sword` and `--legacy-combat` retain the
old command-line experiment; its **Player + Sabre prototype** button returns here.

In the original-source profile, WASD uses normal **7 units/s** travel; Shift
selects the existing **2 units/s** slow study Walk. The authored fallback retains
WASD Walk / Shift Run. Space jumps; LMB/E holds or buffers a three-hit combo.
RMB keeps combat facing toward the mouse's ground intersection and selects
combat locomotion (declared Idle/Walk/Run aliases in the source profile).
Q/C turns; middle drag orbits; wheel zooms;
R resets; V shows the existing grass overview. F3 toggles the movement meter;
F4 resets only its measurements. F8 restores the launch camera after orbit,
zoom or overview. **Save JSON** writes aggregates and camera settings to private
Research. GUI presses are consumed before
world attacks; releases and focus loss clear held commands.

Source-profile movement follows the camera's horizontal right/forward axes,
including after orbiting; diagonals keep unit length. This follows the installed
MD2 WASD reference mod's documented input convention; vanilla click movement is
a distinct input scheme. Explicit scripted Walk/Run remains world-aligned.
Clip side names are anatomical: this
asset faces local +Z, and its left arm/leg are on local +X. Positive local-X travel
therefore selects CombatStrafeLeft; Q rotates the face toward that same left side.

The action selector exposes all 22 clips. Selecting a clip enters review, with an
optional repeating loop. Movement, jump or attack resumes gameplay immediately.
Source facial bone channels remain active. Focused/Blink add optional authored
morph overlays; Source/Neutral disables those overlays. In the authored fallback,
Auto follows combat and supplies periodic blinking.

## Appearance and file boundary

The original MD2 Valorie, original Sabre, 32-joint rig, weights and original
animation tracks are loaded directly into memory, when available, from:

`$MD2_RESEARCH_ROOT/blender/prototype_sabre/MD2_Valorie_Sabre_Source.glb`

The default research root is `C:/Users/ADMIN/Desktop/MD2 Research`. Set the
`MD2_RESEARCH_ROOT` environment variable to relocate it. The runtime uses
`GLTFDocument`, `GLTFState.HANDLE_BINARY_IMAGE_MODE_EMBED_AS_UNCOMPRESSED`, and
120Hz scene generation. It never saves, imports, caches or extracts this private
file into the game project. Its adjacent `MD2_Valorie_Sabre_Source.json` owns the
source action names, durations and alias declarations. The visible label identifies
the original private player/Sabre. A prior private skin/11-bone reconstruction is
used only if the source bundle is absent; the own-authored GLB inside `assets/` is
also selectable. Only that authored fallback is project art.

The source profile exposes 22 semantic states from 13 unique original clips.
Nine unsupported ready/strafe/combat-movement states explicitly reuse complete
original Idle/Walk/Run clips. They are labelled aliases in the selector; the source
profile bypasses the artificial readiness-transition wait. Original facial bone
channels remain active in Source mode. Focused/Blink are optional new morph overlays;
Neutral disables those overlays. The public Sabre table identifies
ABP_1HMediumAnimLayers and AM_Player_SabreCombo, supporting the selected family.
Exact montage sections/sequence assignments and identity attachment to J_R_Weapon
remain unverified adapters, rather than recovered equip data.
The prototype uses a one-unit-per-metre convention, including its 2.003-unit
model, 2.0-unit capsule and existing1m terrain blocks. The700→7 conversion uses
standard Unreal100UU/m and cm/s velocity; actual installed MD2 instance scaling
and attribute-to-movement conversion remain unverified.

## Motion and feedback limits

AnimationPlayer supplies the raw source pose. An optional grounded locomotion
direction adapter then redirects only the two legs; raw review, attacks and jumps
bypass it. Its world-yaw smoothing preserves the travel plane during body turns,
and a small leg-local height correction preserves each original evaluated sole
minimum. This direction helper leaves hips and the upper body alone. A separate
reversible **Stable body/head** adapter now retains25% of the original spine/head
orientation oscillation around each source Walk/Run cycle mean. It caches96
samples per clip in memory, restores source locals before each evaluation and
fades over100ms at gait entry/idle. Head orientation is solved in skeleton space
so reducing spine sway does not double the original compensating head nod.
Leg/root/hip poses and local arm/weapon tracks remain intact; arms and Sabre
inherit the steadier torso. Neck attachment position and source scale/shear
are preserved. Air/combat/raw review bypass it. These weights are an explicit
gameplay reconstruction, not recovered MD2 animation-graph values.
The face controller
owns only its two optional morph scalars. Original source weapon scale/shear is retained,
including the compressed blade during the finisher. Source clip durations are preserved; the 220ms input buffer,
40ms clip blend, movement rates, collider behavior and VFX windows are authored
adapters. The controller advances an event clock with exact clip-end overshoot
and samples animation/markers in steps no longer than 1/120s within physics ticks.
The original source profile now uses table-derived normal Run7, without the
lab's1.2 multiplier. Slow Walk2 is a study adapter. Its **stride references remain
Walk2.0/Run5.6**, derived from the earlier stance fit, not native speed settings.
Cadence follows actual post-collision travel divided by these references: Run7
produces1.25× gameplay sampling, not an arbitrary aesthetic multiplier or a
recovered MD2 play-rate formula. Raw review and ordinary jump clips remain1×. Gameplay
Sabre attacks use their public per-variant rates1.2/1.2/1; recoveries stay1×
because their native montage-rate relationship is not established.
Blocked travel produces zero gait advance. Run's asymmetric stance paths still
prevent a claim of perfect bilateral foot locking. Gaits persist through braking before Idle, and
locomotion switches retain normalized cycle phase with an80ms blend.
Public-table JumpCoyoteTime.155 permits one jump after a recent ledge departure;
takeoff consumes it, so it cannot grant a second airborne jump. Estimated jump
height remains1.2 units. Following the user's slow-jump feedback, the source
profile uses a declared.25s apex-time adapter: gravity=2h/t²=38.4, launch9.6.
The earlier15/6 adapter took about.817s per jump; the new native60Hz capsule
trace takes.517s with the same1.200827-unit measured apex. At30/60/120Hz,
flight is.533/.517/.508s, including discrete floor-contact detection.
These are lab approximations, not recovered MD2 gravity/launch constants.

Source takeoff stays1x but transitions to the original airborne loop at the
physical apex or ceiling collision, rather than waiting for its full.4s clip.
Actual floor contact starts landing. Stationary landing retains its full.3s;
with movement input it releases after a declared.05s contact interval into the
existing gait/blend. This prevents a.3s static landing pose sliding across the
ground while the capsule already travels7u/s. Source clips, raw review1x,
ordinary movement speed and fallback jump remain unchanged.
At the unchanged7u/s travel speed, shorter flight also shortens horizontal jump
range; native MD2 jump distance and air-control parameters remain unverified.
No claim of matching the original game engine's interpolation is made.

## Direct movement evidence and measurement

Public original-JSON records identify DT_PlayerDefinition#0: MovementSpeed700,
multiplier1, coyote.155; DT_MobType1Definition#0/#1/#2:
Zombie300/Skeleton400/Creeper500. These are verified in a **community-extracted
public mirror**, whose precise build is unspecified here. They are not verified
effective values from installed1.1.3. Full raw records/hashes stay in ignored
MD2 Research/source_snapshot/public_tables/, never in this public project.

- [DefaultPlayer raw](https://mcfun.cc/minecraft-dungeons-2/database/definitions/defaultplayer-2cbbcea71a/data/)
- [Zombie](https://mcfun.cc/minecraft-dungeons-2/database/mobs/zombie-47cbff6de3/data/), [Skeleton](https://mcfun.cc/minecraft-dungeons-2/database/mobs/skeleton-c189203437/data/), [Creeper](https://mcfun.cc/minecraft-dungeons-2/database/mobs/creeper-aaa99ff3f3/data/)
- [Sabre raw](https://mcfun.cc/minecraft-dungeons-2/database/definitions/sabre-aaf238329c/data/)
- [Epic: actor velocity in cm/s](https://dev.epicgames.com/documentation/en-us/unreal-engine/BlueprintAPI/Transformation/GetVelocity)

The player row routes MovementSpeedMultiplier through CT_AttributeAdjustments
row MovementSpeedMultiplier. Curve keys/interpolation, gear/status stacking and
effective active-player values are not recovered locally. Base1 is the chosen
bare prototype profile; no unsupported boost curve is invented. Sabre's table
contains per-variant AttackSpeedMultiplier1.2/1.2/1 and montage references, but
no attacker travel/root-motion settings. Its knockback control-disable fields
belong to hit-target knockback, not an attacker lock. Gameplay now applies those
three attack rates without rewriting source keys: Attack1.433333/1.2=.361111s,
Attack2.4/1.2=.333333s, Attack3.666667/1=.666667s. The220ms input buffer remains
wall time, and source VFX gates map through each clip's rate. The exact montage
sections and effective runtime attack-speed composition are still unverified.

Acceleration48, braking42, turn cap12rad/s, grounded attack input anchor, ballistic jump and
camera remain disclosed lab adapters. The public player's heavy-jump-attack
GravityMultiplier2 is applied only after an airborne source attack, until actual
floor contact, including if its pose clip finishes during a long fall. It is not
applied to ordinary jumping. Activation height-limit semantics, launch-velocity
handoff, source montage physics and landing notify alignment remain unresolved.
With the new1.2-unit/38.4-gravity adapter, apex-to-floor travel measured from the
first nonascending physics tick is.267/.250s normally and.167/.167s for the
aerial attack at30/60Hz. The twofold gravity factor is public-table data; the
base trajectory and ability handoff remain reconstructed. These are prototype
measurements, not recovered MD2 flight times.
The faster gravity would otherwise land before the established aerial slash
and sound. AirAttack therefore uses a declared physics-cadence adapter
sqrt(38.4/15)=1.6x, applied identically to pose, combo clock, VFX window and audio
landmark (original audio pitch remains1). Its source time at real contact is
.266667s, inside the existing[.19,.38] blade-motion window; the reconstructed
audio landmark is.158875 wall seconds, within8ms of the tested.166667 contact.
This rate is NOT recovered MD2 data. Raw AirAttack review remains1x; grounded
Sabre rates remain the verified1.2/1.2/1. This avoids moving only the effect while
leaving the sword pose behind the physical landing.
Native blending/root-motion/attack movement remain unresolved.

A second, pinned public extraction snapshot corroborates the player row:
[IronKinoko raw tables at630e72c](https://github.com/IronKinoko/Minecraft_Dungeons_II_DATA/tree/630e72c2f12e4d343f791a0101f4ecf7adc37a15/data/raw).
DT_JumpDefinition has three variants with Delay0; this is not a height/gravity
configuration. DT_GameBalanceDefinition Active/SecondPass contains co-op arm4000,
max zoom500, start/end radii500/1600 and interpolation speed5. Those co-op values
do not establish this solo player's view or projection, so the existing camera
is preserved. TypeAttributeModifiers is empty in these two rows; that is not
proof that equipment, effects or other runtime modifiers are absent.

Approved UE4SS3.0.1-1183 crashed before Lua initialized, both with the existing
Native Loader and in a controlled isolated attempt. Its added dwmapi.dll was
removed, existing Native Loader winmm.dll restored with the same hash, and zero
runtime values were obtained. No console unlock or protection bypass was used.

The meter computes planar path/net distance and speed from actual position
differences, actual advanced gait cycles, response95 and braking distance/time.
Reset suppresses acceleration until two velocity samples exist. Sole diagnostics
use original rest-bottom centroids in final world space, low-foot geometry and
backward movement relative to travel. Rolling and stance/load remain unresolved:
this is candidate sole motion, not proof of slip or foot locking. Exports contain
aggregates/settings only, never source poses or mesh data.

tests/test_movement_source.gd checks30/60Hz distance, normal/slow input, diagonals,
camera directions, coyote edges, blocked gait and raw1× review.
tests/test_movement_meter.gd checks path/net/blocked measurement semantics.
tests/capture_movement.gd renders this same lab on native Mobile/D3D12 and writes
private images/measurements, including two cadence rules at the same7-unit speed.
It measures OUR implementation; it does not infer MD2 parameters from video.

Source attacks retain the complete full-body pose and anchor grounded input
travel immediately, including pre-attack momentum. Previously the22% input
adapter slid3.346u/2s despite zero root translation in the exported combat clips;
the new native held-combo trace adds0u. Held/buffered combos retain their feet;
an unheld, unqueued recovery yields to movement. Original animated steps inside
the attack remain; no claim of perfect IK or native runtime lunges is made.
Authored fallback retains its earlier22% travel. Jumping bypasses the source
ground anchor, including a simultaneous Run+attack+jump, without lowering its
launch travel speed.
Jumping cancels a grounded combo; an attack requested in the air selects AirAttack.
Each accepted attack emits one `impact_ready` signal at its authored fast-motion
gate for future targets. There are no targets, damage, fake impact flashes or
whiff hitstop in this mode. Ribbon points follow exported SabreBladeBase/Tip nodes;
the ribbon holds at most 28 samples and particles use a fixed pool of 48. Original
Sabre OGG samples are decoded from Research into a bounded four-voice prototype
mix; sample triggering/layering does not reconstruct the original Wwise graph.
Scheduling retains exact accepted-event times even when a faster combo section
starts inside a physics tick. Audio shares the actor's timeline across mute,
reset and review, without changing original sample pitch. Envelope landmarks are
our reconstruction; two variants would need a negative start delay at1.2×, so
the start clamps to the accepted event and leaves up to14ms peak mismatch.
Physics-tick dispatch and device latency also remain; no sample-accurate native
event/mixer match is claimed.

## Motion clarity and camera audit

Source mode uses100% render resolution by default instead of Medium's85%
bilinear upscale. **Native pixels100%** is reversible and follows the selected
lighting tier/Original A/B scale when off; grass, lights and shadows stay intact.
TAA, screen-space AA and motion blur were not enabled in the measured viewport.

The source32-joint skin, rigid Sabre, ribbon, particles and camera now share a
render-fraction presentation timeline. It uploads interpolated poses only to
RenderingServer, leaving physical skeleton/capsule/markers/event clocks intact.
**Smooth display** disables it for comparison. Standard interpolation adds up
to one physics tick of display delay; it does not add a temporal image trail.
Bounded histories retain just-expired VFX through that display delay. Exact
endpoints preserve original weapon scale. Native virtual144Hz/60physics samples
show0 held display frames versus84 held physical samples in144 observations.
This is a continuity probe, not a performance benchmark or phone result. Run
`capture_presentation.gd` with `--fixed-fps 144`; assuming144 while running the
ordinary120 cap gives invalid
speed normalization. The failed ordinary-cap diagnostic is retained in Research.

The camera meter reports the actual camera basis, including V overview, plus
projection, span, arm distance, viewport and disclosed damping adapters. At
launch it remains orthographic14.5, azimuth37.815°, elevation22.918°, arm20.139u,
horizontal response12/vertical8. Ordinary jump anchorY span is<.0004u at30/60Hz.
F8 restores that recorded launch framing; it does not claim a recovered MD2 view.
The solo projection/FOV/rotation/zoom and speed-sensitive controller formula
remain unknown. Co-op arm4000 is insufficient evidence to replace these values.

Source metallic maps are retained. An optional actor-only ReflectionProbe captures
the local world/sky: receive mask2, capture mask1, ambient override disabled.
It leaves the lab Environment and grass unchanged. The probe recenters in coarse
12-unit steps; use Refresh after changing lighting. Native A/B verification found
39,848 changed actor pixels and exactly zero difference in a frozen grass region.

## Verification

Run all `tests/test_*.gd`, including source-combat timing, camera audit,
presentation and effect-history checks; the earlier core suites are
`tests/test_state.gd`, `tests/test_runtime.gd`, `tests/test_mode_switch.gd`,
`tests/test_review.gd`, `tests/test_facing.gd`, `tests/test_source_profile.gd`,
`tests/test_motion_calibration.gd`, `tests/test_locomotion_direction.gd`, and `tests/test_private_loading.gd`
with Godot `--headless --path <existing-project>
--script res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/tests/<name>`.
The latter verifies neutral morphs, the original alpha atlas, embedded textures,
and zero new project filenames caused by the private runtime load.

`test_jump_responsiveness.gd` checks actual collisions at30/60/120Hz, unchanged
height, held-jump/no repeat, apex/falling pose, ceiling collision, stationary
landing, moving landing release and raw source playback. `capture_jump.gd`
records every physical pose via the existing signal so image-capture waits
cannot miss the apex. Its before/after parameter trials use the SAME existing
lab, camera and grass; private frames/trace stay in Research/movement_measurements/jump.

`tests/capture_native.gd` uses a no-focus offscreen native viewport and actual
Input actions. Use Mobile/D3D12 on this machine. Numeric reports go to
`.validation/md2_sabre_prototype_v001/`; any private rendered frames/movie belong
under `Research/reports/prototype_sabre/godot_native/source_v003/`, outside the game project.
Earlier source_v002 and11-bone captures remain preserved. A native engine-shutdown
warning reports seven Texture RIDs; there are no recorded gameplay/script failures.
The original research export guard excludes this entire development subtree.
