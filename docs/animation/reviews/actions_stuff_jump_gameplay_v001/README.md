# Approved Jump / Landing in the existing research game

The user artistically approved **Actions & Stuff Jump / Landing v001** on 2026-10-15. It is now integrated directly into `res://scenes/dev/ActionsStuffWalkRunTest.tscn` in the existing `game_mobile_3d` project. No new scene/project or Blender revision. Blender study files and their embedded historical Pending metadata remain byte-for-byte preserved; this document records the subsequent explicit approval.

Open that scene and press **F6**. **WASD** moves, **Shift** runs, **Space** jumps from standing/walking/running, **R** resets. Right-drag/wheel retain existing orbit/zoom. F5 still opens WorldMap. Normal user launches retain audio.

[Actual gameplay at original speed, 30 FPS](gameplay_30fps.mp4) · [60 FPS](gameplay_60fps.mp4). Both native Metal/Mobile captures use real input actions and normal 60Hz capsule physics, with four launches/four collision landings over 11.33 seconds. These are internal checks, not another approval stage.

## Motion and event bridge

`source_jump_runtime.gd` runs the frozen approved source programs in order pre27→29→30, locomotion `veywgp`, sprint `psowex`, local landing `pyhwuc`, jump `ngeixo`, fall `muiqdc`, bob/holding/look. `jump_program.json` contains the actual approved clips/controllers, not generic jump curves. Ordinary Jump, gait-dependent Sprint Jump A/B, moving/stationary local Landing, Fall and outgoing source fades retain their authored clocks, translations, rotations and scale. The approved reconstruction's declared positive-only unnormalized mixing, uniform Catmull interpolation, linear outgoing fades and outgoing clocks are retained; these are declared evaluator conventions, not proof of undocumented Bedrock internals.

`source_jump_sampler.gd` preserves full native local PRS, including root squash, asymmetric ordinary-Jump leg stretch (sampled maximum 1.248485), head translations and entity-relative head compensation. The old ground sampler's 1.106 leg safety bound is not applied to Jump targets. The new scene-local visual bridge retains the established single pose writer and inertial pose handoff. All source layers, including the 1.2083-second sprint-stop clip and its outgoing fade, finish before returning to the old ground target path.

`source_jump_actor.gd` extends the existing capsule actor. Space is edge-triggered; held Space does not auto-repeat. Existing planar controls, acceleration 32, deceleration 28, Walk 1.8m/s and Run 5.031m/s stay unchanged in air and on ground. Godot owns height/gravity/contact: gravity18m/s², nominal1.2m jump, impulse sqrt(2*g*h). Standard 60Hz integration peaks around1.256m (30Hz stress integration around1.311m). No Blender parent trajectory, fixed15-second playback or1m/.6s preview arc is imported.

Real grounded status, body Y, vertical speed and accepted takeoff feed source queries. `q.is_jumping` is the accepted launch-tick adapter; actual collision supplies `q.is_on_ground` and triggers local Landing. Early/late contact follows physics rather than forcing a clip endpoint. Incoming impact velocity is retained for diagnostics; it is not substituted into the source grounded query. Source .05/.55 sprint phase overrides synchronize the old gait clock; stopping, switching gait and R do not reset it. R cancels air controllers and rebases vertical history without inventing landing.

The existing calibrated planar source query, 4.5rad/s turn-to-travel response, camera size5.1 and native height envelope remain. Ground contact eligibility evaluates once after choosing final poses. Airborne feet have no planted anchors, ground IK or yaw lock. A rigid foot can reach this native floor slightly before its capsule: a bounded140mm vertical leg translation prevents floor penetration without firing Landing early or changing capsule/body height. This is a disclosed scene-owned contact adapter, not a source feature. Ordinary ground contact correction remains unchanged. This flat-floor research scene does not certify terrain/weapon/mobile-device behavior.

Both source and future samplers retain the unarmed holding flags0/0. This preserves the recent Walk/Run arm correction; old source reference defaults and all source Blender Actions remain unchanged.

## Validation and preservation

- Literal parity: 2,160 source controller/native PRS samples plus326 exact-key/interpolation probes; all29 visual aliases, ordinary/sprint branches, landing/fall, timeline events and .05/.55 overrides covered. Max variable error1.07e-13, native position0.371µm, basis4.78e-7.
- Actual collisions at30/60Hz: standing, walking, running, midair reversal, stop in air, held launch, raised-floor contact, Space input and reset. Full scene tests additionally verify landing states on actual contact, unplanted air feet, full scales, floor clearance and return to locomotion. Maximum sampled leg step is below28° at30Hz/below15° at60Hz in the five transition trials.
- Existing ground arm, sampler, interruption, facing, continuity, gait/contact and directional suites pass. Independent review caught and verified fixes for vertical reset history, duplicate contact evaluation and premature sprint-stop handoff.
- Baseline hashes protect2,508 existing files. Only the intended scene factory and research README change among that baseline; all Blender sources/Showcases, ground evaluators, WorldMap, production character assets, project settings and export guard remain exact. Backups and complete logs are in `/Users/tin/Documents/ChatGPT/New project/experiments/actions_stuff_jump_gameplay_v001/`.

The enabled existing research export guard excludes this scene and the entire `scenes/dev/actions_stuff_research/` subtree, including every new script/data/fixture. These proprietary source-derived reconstructions stay private research and are not commercial production animations. Approval does not change licensing or production scope.
