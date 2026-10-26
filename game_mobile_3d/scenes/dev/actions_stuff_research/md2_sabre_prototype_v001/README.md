# Player + Sabre prototype

F6 in the existing `ActionsStuffWalkRunTest.tscn` now opens this prototype
directly. Use `C:\Dev\GameAssetFactory\Open Sabre Editor.cmd` to select the
correct project and scene; the older Desktop\Dev checkout is separate.
Launching the same scene with `--md2-sabre` also works.
**Return to original Rifle / Sword lab** overrides even the command-line opt-in.
Only the saved scene's Sabre entry flag changes. WorldMap, original actors,
grass and lighting are preserved. `--sword` and `--legacy-combat` retain the
old command-line experiment; its **Player + Sabre prototype** button returns here.

WASD walks, Shift runs, Space jumps, LMB/E holds or buffers a three-hit combo.
RMB keeps combat facing toward the mouse's ground intersection and enables the
authored combat movement clips. Q/C turns; middle drag orbits; wheel zooms;
R resets; V shows the existing grass overview. GUI presses are consumed before
world attacks; releases and focus loss clear held commands.

Movement keys remain aligned to world X/Z. Clip side names are anatomical: this
asset faces local +Z, and its left arm/leg are on local +X. Positive local-X travel
therefore selects CombatStrafeLeft; Q rotates the face toward that same left side.

The action selector exposes all 22 clips. Selecting a clip enters review, with an
optional repeating loop. Movement, jump or attack resumes gameplay immediately.
Face Auto follows combat, Neutral/Focused override it, and Blink tests the same
independent morph controller used by the simulation's periodic blink.

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
Neutral disables those overlays. The native Sabre-to-animation assignment and
identity attachment to J_R_Weapon remain adapters, rather than recovered equip data.
The source's units have not been proven to be game metres; the prototype treats
the 2.003-unit model and 2.0-unit capsule consistently in its local world.

## Motion and feedback limits

AnimationPlayer supplies the raw source pose. An optional grounded locomotion
direction adapter then redirects only the two legs; raw review, attacks and jumps
bypass it. Its world-yaw smoothing preserves the travel plane during body turns,
and a small leg-local height correction preserves each original evaluated sole
minimum. Hips, spine, arms and the weapon remain unchanged. The face controller
owns only its two optional morph scalars. Original source weapon scale/shear is retained,
including the compressed blade during the finisher. Source clip durations are preserved; the 220ms input buffer,
40ms clip blend, movement rates, collider behavior and VFX windows are authored
adapters. The controller advances an event clock with exact clip-end overshoot
and samples animation/markers in steps no longer than 1/120s within physics ticks.
The original source profile uses effective Walk2.0/Run5.6 units/s from a kinematic
stance fit, without the lab's1.2 multiplier. These are not recovered game settings.
Run's asymmetric stance paths prevent perfect bilateral foot locking. Gameplay
cadence follows actual speed during acceleration/braking and is1x at nominal
cruise; raw review remains1x. Gaits persist through braking before Idle, and
locomotion switches retain normalized cycle phase with an80ms blend.
Estimated jump height remains1.2 units; gravity15 and launch6 align the physical
apex with the source Takeoff's.4-second endpoint. This is a timing adapter, not
recovered native physics; actual floor collision owns landing.
No claim of matching the original game engine's interpolation is made.

Attacks retain the authored full-body pose and reduce grounded travel to 22%.
There is no lower-body movement blend or perfect foot lock during moving attacks.
Jumping cancels a grounded combo; an attack requested in the air selects AirAttack.
Each accepted attack emits one `impact_ready` signal at its authored fast-motion
gate for future targets. There are no targets, damage, fake impact flashes or
whiff hitstop in this mode. Ribbon points follow exported SabreBladeBase/Tip nodes;
the ribbon holds at most 28 samples and particles use a fixed pool of 48. Original
Sabre OGG samples are decoded from Research into a bounded four-voice prototype
mix; sample triggering/layering does not reconstruct the original Wwise graph.

Source metallic maps are retained. An optional actor-only ReflectionProbe captures
the local world/sky: receive mask2, capture mask1, ambient override disabled.
It leaves the lab Environment and grass unchanged. The probe recenters in coarse
12-unit steps; use Refresh after changing lighting. Native A/B verification found
39,848 changed actor pixels and exactly zero difference in a frozen grass region.

## Verification

Run `tests/test_state.gd`, `tests/test_runtime.gd`, `tests/test_mode_switch.gd`,
`tests/test_review.gd`, `tests/test_facing.gd`, `tests/test_source_profile.gd`,
`tests/test_motion_calibration.gd`, `tests/test_locomotion_direction.gd`, and `tests/test_private_loading.gd`
with Godot `--headless --path <existing-project>
--script res://scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/tests/<name>`.
The latter verifies neutral morphs, the original alpha atlas, embedded textures,
and zero new project filenames caused by the private runtime load.

`tests/capture_native.gd` uses a no-focus offscreen native viewport and actual
Input actions. Use Mobile/D3D12 on this machine. Numeric reports go to
`.validation/md2_sabre_prototype_v001/`; any private rendered frames/movie belong
under `Research/reports/prototype_sabre/godot_native/source_v003/`, outside the game project.
Earlier source_v002 and11-bone captures remain preserved. A native engine-shutdown
warning reports seven Texture RIDs; there are no recorded gameplay/script failures.
The original research export guard excludes this entire development subtree.
