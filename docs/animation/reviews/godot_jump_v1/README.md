# Expressive jump gameplay test — Pending

Open `game_mobile_3d/scenes/dev/ExpressiveLocomotionTest.tscn` in Godot and press **F6 (Run Current Scene)**. This updates the existing isolated review scene. F5 still runs the unchanged production WorldMap.

**Space jumps. WASD/arrows move. Shift runs.** Walk/Run default to the requested **1.5× travel and gait**, with **Idle at normal 1× speed**. Jump timing is driven separately by physics. R resets, 1/2/3 select front/three-quarter/side, F9 plays the demo, L starts a 6 m fall test, and E toggles the existing rifle carry layer. The raised platform beside the origin provides an early-landing/ledge test. Onscreen movement/RUN/JUMP buttons are available for touch review; this remains a test HUD.

[Original-speed gameplay review](gameplay_1x.mp4): 504 frames, 16.8 seconds, 30 FPS, actual Godot Mobile/D3D12 rendering. Includes standing, walking, running and repeated jumps, recovery, front/three-quarter/side views and a 6 m fall. Engine time scale is 1; the recording is not retimed. [Pose overview](gameplay_poses.jpg).

## Physics and animation phases

The existing Pending `Full_Jump_Expressive_v2_Test` is sampled read-only into one non-looping native Animation. Its 93-frame study is **not played on a fixed full-jump timer**. The same runtime model, rest rig, coordinate conventions, locomotion clock and upper-body layer architecture are reused.

| Phase | Runtime behavior |
|---|---|
| Ground preparation | Source F7–19 over 0.20 s; skip the quiet ready hold, retain the soft receiving dip. Horizontal movement remains live. |
| Takeoff / ascent | Actual impulse starts AIR; vertical velocity develops F19–33. Default physical height 1.2 m, gravity 18 m/s². |
| Air / descent | Source air pose develops toward F41.5, then F45 as predicted contact approaches. A 45 source-frames/s cap prevents squeezing the whole gesture into a short flight. |
| Unprepared fall | Enter the lowered-arm F43 approach directly, settle toward F44/F45; no repeated takeoff or artificial midair bounce. Long falls remain AIR until collision. |
| Actual contact | Collision starts LAND/F46. Left lead receives first, right follows after 25 ms. |
| Impact / rebound | F51 compression at 0.10 s after contact; F55 at 0.22 s, F67 at 0.42 s. Preserve the stronger V2 absorption and one controlled rebound. |
| Moving recovery | Legs release toward the still-running gait over 0.08–0.32 s; torso over 0.14–0.54 s; upper gesture over 0.18–0.65 s. No gait clock reset. |
| Stationary recovery | Replant feet individually after 0.40 s; settle toward normal Idle by 0.85 s. |

Capsule translation is the only large vertical jump trajectory. The Blender-only 0.72 m preview elevation was not exported. Small authored hip/body compression remains pose motion. Repeated presses have a 140 ms buffer; a buffered landing receives at least 100 ms of impact before the next preparation. No double jump or forced flight timer is introduced.

Both moving legs retain gait influence in flight. Preparation retains more moving gait than the stationary pose, so live travel does not drag two frozen legs. Landing keeps the current distance-driven phase rather than restarting LEFT=0. Existing normalized support phases remain LEFT=0 / RIGHT=0.5. Pose/velocity residuals smooth event changes; foot anchors are bounded at the existing 14 cm safety radius. Landing prioritizes vertical sole clearance within that radius and releases excess horizontal anchoring. Actual supported height takes precedence over the center ray at ledges.

## Evaluation

The open raised arms, asymmetric airborne legs and restrained head preserve the expressive blocky silhouette. The compact dip feels connected to the approved lower-body softness. Impact reads strongly in the torso before the legs rejoin movement; continuing Run does not wait for the full upper-body recovery. Stationary landings retain the deeper absorption and controlled rebound. The face/materials and rigid full arms remain intact.

The hardest cases are rapid repeat/early contact and ledge interruptions. They deliberately truncate parts of the large airborne gesture to preserve responsive collision-driven motion. These still have fast arm changes and should be reviewed in gameplay; a numerical bound is not artistic approval. An early platform touchdown can occur before the largest air silhouette develops, which is preferable to ignoring the physical contact.

## Verification and remaining limits

**77 checks pass at 30 render FPS and 77 at 60 render FPS, with 60 Hz physics.** The separate old locomotion regression passes 41 checks. Fresh processes reload the saved scene/resources. Coverage includes stationary/Walk/Run, both receiving phases, repeated and buffered jumps, 0.22 m short jumps, a 0.7 m raised platform, running off that platform during recovery, a 36 m fall lasting beyond the source duration, airborne input, moving landings, rigidity, contact clearance and rifle mask/socket availability.

Default measured peak is 1.198–1.201 m; sampled flight is 0.717–0.733 s. Short jumps land in 0.30 s. Ground penetration stays below 0.001 mm in this test. Stationary impact contact centers stay below 0.01 m/s. Source-to-runtime rigid vertex reconstruction error is below 0.001 mm; scale error remains below 0.000001. Details: [30 FPS](runtime30.json), [60 FPS](runtime60.json), [export validation](export_validation.json).

The existing sharp-turn foot-sliding limitation remains. Bounded anchors also release during difficult moving landings; maximum residual is about **8.0 cm at 30 FPS / 7.2 cm at 60 FPS** across this stress suite. This is not a claim of zero foot sliding. A rigid boot can rock on corners because there is no ankle. Per-foot terrain normals, slopes, narrow/moving platforms and full directional locomotion are not certified. The simple platform verifies contact events, not general terrain adaptation. Fall impacts currently use the controlled V2 absorption, without severity scaling.

The optional existing rifle layer and socket pass smoke checks and still exclude hips/legs. Full firing, draw/holster, strafing and combat interruption remain unverified. No phone benchmark was performed; offline RTX movie timings are not a mobile 30 FPS measurement. Artistically approved Idle/Walk/Run and Pending Jump V2 are not promoted to production by these checks.

## Preservation and reproducibility

All Blender sources, Actions, the existing Animation Showcase, production player/controllers/weapons, project settings and WorldMap remain byte-identical. Only the isolated test files and documentation/manifest gameplay metadata change. Jump V2 remains **Pending** in the same Showcase; no new Blender Action or duplicate entry was created. Backups/concurrency checkpoint: `.validation/expressive_jump_v1/backup/` and `baseline.json`. See [preservation audit](preservation_validation.json).

Native export/build instructions: [jump asset README](../../../../game_mobile_3d/assets/characters/expressive_jump_v1/README.md). Automated test command from `game_mobile_3d`: `Godot --headless --audio-driver Dummy --fixed-fps 30 --script res://tests/validate_expressive_jump.gd` (repeat at 60). Automated audio is process-only muted; manual F6 uses normal audio. Keep this lab Pending until explicit user review; do not replace production animations.
