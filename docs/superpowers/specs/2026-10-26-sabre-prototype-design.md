# Private source sabre character fidelity prototype

Implements the user's detailed 26 October request in the existing GameAssetFactory
Blender and Godot workflow. This is an internal study, not approved production art.

## Approach and constraints

The user subsequently explicitly requested the recovered Valorie skin directly,
matching the supplied image. The fidelity variant therefore preserves the original
608-vertex appearance, UVs, normals and 64px skin. Its derived Blender/GLB files and
all source-bearing renders stay in Desktop MD2 Research. Godot loads this external
GLB in memory with embedded uncompressed images; it does not extract or copy it
into GameAssetFactory. The fresh authored character/atlas remains the self-contained
fallback inside the project. The initial eleven-bone reconstructed-motion variant
is preserved as a separate study.

The user then explicitly authorized every available original MD2 component,
including the sword, with mobile optimization deferred. The preferred private
variant therefore uses the recovered 32-joint master skeleton, original player
geometry/weights, original animation channels and original Sabre mesh/UV/textures.
It preserves recovered interpolation, timestamps and scale tracks in its GLB.
Unsupported ready/strafe transitions remain clearly labelled runtime adapters.
Original skin, sword and animation data are never serialized into this project.

Keep all proprietary vertices, UVs, textures and raw animation channels in research.
No new project or replacement of grass, lighting, WorldMap or approved actors.
The opt-in mode of the same existing lab bypasses the unrelated private Fiery/old
soldier pose pipeline and uses its own AnimationPlayer.

## Milestones, in order

1. Blender character, sabre, face, rig and material: compare source bounds and
   screenshot silhouette; save an authored fallback and the private exact-skin
   fidelity variants requested by the user; prefer the full original-source bundle.
2. Complete Blender action set, showcase selector and export: Idle/Walk/Run,
   left/right strafe, Takeoff/Airborne/Landing, Ready/Enter/Exit, combat movement,
   Attack1/2/3 and individual recoveries. Use the supported medium jump attack as
   an optional alternate, clearly an inferred Sabre assignment. Verify evaluated
   skin deformation, grip, loops, source-duration errors and GLB roundtrip.
3. Existing Godot lab opt-in `--md2-sabre` mode: independent CharacterBody3D,
   imported AnimationPlayer, grounded locomotion, sprint, strafe, jump, buffered
   three-hit combo/recovery, expressions and bounded blade trails/slash events.
4. Native rendered/input-driven checks and final fidelity/provenance report.

## Evidence boundaries

The measured master is 2.003 source units high with a .508 head, .500×.750×.250
torso and rigid limbs. Source units are not proven game metres. No Sabre-named
animation or weapon-to-animation runtime assignment has been recovered; selecting
1H_Medium is an inference. Source durations are matched, while input buffering,
rate selection, movement blending, collider contacts and VFX gates are authored.
The original-source variant preserves recovered neutral appearance, skeleton and
source clips. Facial overlays, input behavior and unsupported semantic adapters
are reconstructed. The earlier retargeted study remains available separately.
No native notify times, exact engine shading, phone performance or pixel identity
will be claimed. Any held weapon scaling without a recovered equip parameter is
reported separately from the model's measured dimensions.

## Runtime interface

New files live in `scenes/dev/actions_stuff_research/md2_sabre_prototype_v001/`.
The mode owns setup/present/input/unhandled_input/release_inputs/reset and exposes
display_position. The old lab owns environment and camera. An early return in
each existing lifecycle path isolates the new actor from legacy rifle/zombie
controllers. Default saved scene flags and F5 WorldMap stay unchanged. The
source AnimationPlayer pose may receive a labelled grounded leg-direction
postprocess; raw review, attacks, jumps and weapon transforms bypass that layer.

The final source profile uses kinematically inferred effective Walk2.0/Run5.6
source units/s with normalized gait phase and braking continuity. Jump apex.4s
follows the source takeoff endpoint; height1.2 and resulting gravity15 are explicit
approximations because native jump configuration is unavailable. No additional
scene or changes to the old lab's global movement/lighting settings are needed.

Controls: WASD movement, Shift sprint, Space jump, LMB/E attacks, RMB combat-facing
strafe, Q/C facing or camera-relative aim as documented, middle drag orbit, wheel
zoom, R reset; visible buttons provide expression and action review.

## Preservation and validation

Hash the existing environment, project, lab and approved assets before changes.
The existing runtime edit is `walk_run_test.gd`; reuse the export
guard already excluding this dev subtree. No new tool or dependency installation.
The copied checkout currently has an empty .git directory and `git status` reports
not a repository; work in the explicitly requested directory and keep baseline
hashes instead of silently repairing Git or creating a separate checkout. Extend
the portable dev launcher with `--weapon sabre`; retain all old launch modes.

Test state transitions with synthetic input through the real actor, low/high dt,
buffer expiry, interruption/reset and focus loss; inspect native rendered poses,
weapon attachment, expression, trail budgets and grass/lighting preservation.
Reopen saved Blender and reimport GLB before Godot implementation begins.
