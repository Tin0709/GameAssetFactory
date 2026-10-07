# R14 — Combat strafing V1

**ARTISTIC STATUS: AWAITING HUMAN REVIEW.**

Saved study: `C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/player/cuboid/player_combat_strafe_r14_v1_study.blend`

Actions: `Combat_StrafeRight_V1` and `Combat_StrafeLeft_V1`.

## Motion

Both cycles last 20 frames at 24 FPS (0.833 seconds). Frame 21 closes the curve; a single-cycle playback range is 1–20. Bezier handles and cyclic extrapolation maintain matching seam pose and velocity.

| Phase | Frames | Right strafe | Left strafe |
|---|---|---|---|
| Step outward | 1–8 | Right foot lifts, advances and plants | Left foot lifts, advances and plants |
| Transfer support | 8–11 | Both feet grounded | Both feet grounded |
| Close stance | 11–18 | Left foot follows | Right foot follows |
| Settle / repeat | 18–21 | Both grounded; recover | Both grounded; recover |

The trailing foot begins 10 frames (0.417 seconds) after the leading foot. Swing duration is 7 frames (0.292 seconds). There are no simultaneous flight samples in either loop. The legs remain separated without crossing; the minimum horizontal sole gap is about 59 mm.

Hips rise and settle through a 14 mm vertical range (0.678–0.692 m height), with ±10 mm lateral weight movement and a small 0.9–1.7° directional lean. Peak foot clearance is 41 mm. The preview parents advance 160 mm per cycle, or 0.192 m/s; the Actions contain no Root motion or scale tracks.

## Connected torso and 20° limit

Hips yaw is eased within ±2°. A delayed Spine counterrotation follows the stepping rhythm. Chest, Head, arms and WeaponCarrier retain the approved ready Action; their resulting movement inherits the small lower-body and Spine response. Resulting chest yaw remains within ±0.959° of forward.

| Evaluated case | Maximum absolute Chest/Hips relative horizontal yaw |
|---|---:|
| Combat Strafe Right | 1.299647° |
| Combat Strafe Left | 1.299647° |
| Right → Stop → Left → Right | 1.299746° |

Measurements sample evaluated matrices every 1/8 frame, including between keys and across all continuous-sequence blends. This is dense numerical validation, not a mathematical proof over every real-valued instant. The large margin below 20° is intentional; no abrupt 20° clamp is used. Leg swing angles are not treated as torso twist.

The continuous sequence runs 268 frames (11.17 seconds). It brakes the gait clock and world travel together, settles to neutral, steps left, then brakes through double support and eases into right. The finite sequence does not promise a seamless end-to-start path loop.

## Contact and preservation checks

- Lowest foot point: 2.867 mm above ground in either loop; 2.736 mm during the continuous sequence. No sampled penetration.
- Planted sole travel-axis range: below 0.08 mm. Forward/back drift reaches 13.6 mm from the rigid-leg yaw. Three-dimensional sole-center drift reaches 16.7 mm as the block soles rock.
- Matching loop values: zero error; finite-difference derivative mismatch below 0.000008 channel units/frame.
- No arm, weapon, Chest, Head, Root, or scale channels in the new study Actions. Spine rotation is the only intentional upper balance layer; it replaces the ready layer's neutral Spine rotation while retaining its breathing translation.
- All 228 pre-existing Actions, 445 mesh objects' geometry/weights, and 198 rig rest signatures match the pre-study snapshot.
- Existing source files and tracked production files were not edited. No Godot integration or export was performed.
- All 14 videos fully decoded at 24 FPS: twelve 80-frame A/B/C clips and two 268-frame continuous clips.

## Review setup

Open `index.html` for synchronized A/B/C videos with elevated gameplay, front three-quarter, front and side selectors. A uses the unchanged existing Walk lower Action at its original 16-frame cadence, travelling sideways. B/C use the new shuffles. All use the same rifle-ready upper pose and preview speed.

Native Blender opens on `R14_00_ABC_COMPARISON`; Space starts 24 FPS playback. Individual scenes are `R14_A_EXISTING_WALK_SIDEWAYS`, `R14_B_STRAFE_RIGHT`, `R14_C_STRAFE_LEFT`, and `R14_D_RIGHT_STOP_LEFT_RIGHT`. The latter includes labelled stop/reversal markers. Individual scenes each have four named cameras. The orange fixed enemy marker appears in the elevated rendered view and is hidden in the other rendered views to avoid occluding the character.

Rendered contact sheets, camera stills and ordered reversal samples were visually inspected. Full clips are supplied for the user's motion judgement; technical checks and still inspection are separate from artistic approval.

## Rig limitations

The latest compatible rig has single rigid Leg.L/Leg.R bones and no knees or foot articulation. Small FK translations, up to 36.7 mm, keep block soles clear while allowing the slight bounce; they can produce minor hip seam changes. This is an explicit study compromise. No new bones, IK, mesh edits, weights, backward strafe or automatic additional versions were introduced.

The original unsaved session was preserved as `pre_r14_session_recovery.blend` before authoring.
