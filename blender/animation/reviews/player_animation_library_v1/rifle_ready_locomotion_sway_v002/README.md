# Rifle Ready locomotion sway — Blender review, 2026-10-18

Two separate **Pending** candidates in the existing Animation Showcase:

- `Rifle_Ready_Walk_ActionsStyle_v0012` — exact name requested by the user, including `v0012`.
- `Rifle_Ready_Run_ActionsStyle_v002`.

Open `blender/animation/showcase/Animation_Showcase.blend` from the repository root. Use **N → Animation Library**, select either name, then **Play**. The approved v004 Idle and v001 Walk/Run remain independently selectable with their existing statuses. No gameplay integration is authorized by this Blender review.

## What was transferred from the liked gameplay motion

The existing `ActionsStuffWalkRunTest` was sampled read-only at60 Hz during standing, Walk, Run, a real physics jump and collision landing. The liked rifle/arm movement is predominantly Chest-led: the held assembly follows the broader upper-body motion in the current jump/landing path. There is no separately discovered rifle spring clip.

Verified source explanation in `animations/f2da1071.json`:

- Walk `animation.oreville_ans.tldiyl`: body yaw `Math.cos(q.anim_time*360+40)*9.6`.
- Run `animation.oreville_ans.fngydr`: body yaw `-Math.sin(q.anim_time*360)*24`.
- Crossbow hold `animation.oreville_ans.dubgwy`: body yaw `-this*0.8+12`, retaining20% of incoming gait yaw plus the ready twist. Its holding branch is `njvelc / ltqtzr` in `animation_controllers/616f2ff7.json`.

These candidates restore a bounded amount of that lateral character through the upper torso and complete holding assembly. The amount and overlap delays are new authored adaptations of the accepted gameplay cue; they are not claimed as additional literal source crossbow behavior. `motion_reference_audit.json` records the source distinction and measured gameplay sample.

## Comparison with approved v001

| Change | Walk v0012 | Run v002 |
| --- | --- | --- |
| Added Chest-led lateral yaw | ±3° | ±9° |
| Delay behind the existing gait rhythm | 60 ms | 40 ms |
| Existing waist roll / independent crossbow bob | Preserved | Preserved |
| Holding placement | Unchanged | Entire assembly5 mm higher for recovering-leg clearance |
| Original source gait cadence | 0.8 s | 0.625 s |
| Complete original clock recurrence | 7.2 s | 90 s |

The torso and shoulders carry the weapon together. The existing world-space head observation is compensated, keeping the gaze stable. Both arms remain straight, the original rifle-relative right grip and small living left-support trajectory are retained, and no independent floppy weapon oscillation is added. Leg curves, root/hips/spine, source leg-length pulses and body bounce retain the approved motion. The only Run seating change is5 mm, explicitly required by the native square-arm/leg clearance check.

The six `*_30fps_1x.mp4` reviews are original-speed4.8 s excerpts from front, three-quarter and side views. The `walk_comparison_30fps_1x.mp4` and `run_comparison_30fps_1x.mp4` show approved v001 on the left and the new Pending candidate on the right, with matching camera, phase, speed and30 FPS. Both approved baselines are freshly rendered from the same saved study using their unchanged Actions; raw baseline movies stay outside Git. An excerpt does not represent the complete90 s independent bob recurrence.

## Validation scope

The saved candidates passed5,834 full-loop geometry poses and86 paired source/candidate poses. Both loop poses close exactly; no new nonadjacent/rifle intersection or floor penetration was found. The preserved support excursion is about1.55mm, and both forearms retain zero elbow articulation. Lower-body world transforms and Chest bounce positions match v001 exactly in the paired audit.

`build_validation.json`, `geometry_validation.json`, `reopen_verification.json`, `gui_playback.json`, `media_validation.json`, and `preservation.json` contain the final measured checks. The geometry audit covers the entire source recurrence, both hand contacts, straight forearms, seated head, floor, nonadjacent intersections and loop poses. New upper-body loop motion is checked separately from inherited source leg subframe derivative diagnostics; approved leg wrap poses are compared exactly against v001. Those existing leg characteristics are preserved, not silently redesigned in an arm-sway refinement.

Godot files, both previously approved source Actions and all other approved data remain unchanged. These source-derived studies are **research-only / not production eligible**; an original added sway layer does not change the licensing status of the underlying research bake.

## Rebuild and file handling

`authoring/build_candidates.py` reads the current manifest for approved base hashes and runs against the unchanged approved `rifle_ready_locomotion_actionsstyle_v001.blend` source. It copies both Actions, alters only the listed upper-body properties, preserves existing Actions, and writes this separate study. `authoring/holding_sway.py` defines the bounded yaw, overlap and seating values. Registration remains selective through the existing Showcase.

The authoritative study and central Showcase are covered by the existing `*.blend` Git LFS rule. Their new versions require roughly80 MiB each before any server-side deduplication; keep them as needed source assets and avoid committing additional generated `.blend` copies. Raw gameplay samples, intermediate probes and draft backups are outside Git in the local experiment directory. No history rewrite or tracking migration is performed.
