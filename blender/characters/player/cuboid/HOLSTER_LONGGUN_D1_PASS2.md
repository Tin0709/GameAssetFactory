# Holster_LongGun_V2 — D1 Pass 2

Saved in `player_cuboid_weapon_animation_dev.blend`. V2 was duplicated from V1, retaining the approved Ready → Prepare → Support release → Sweep → Over shoulder → Back align → Release → Exit story. Frames 1–18, 24 FPS, duration 17/24 = 0.708333 seconds. No Godot integration/export in this pass.

## Changes from V1

- Small initial hold on the weapon and arms lets Chest communicate intent first.
- Chest prepare key at 2.2, right-arm pull key at 3.1, weapon pull at 3.7; support side held through 4.7, visibly releasing around 5.3 and lingering through 6.2.
- Rifle accelerates into the sweep, decelerates across added shoulder guide poses at 10.5 and 11.5, then approaches the back at 13.3.
- Right arm leads the sweep at 7.7 before weapon 8.2, guides at 12.9/14.3, releases around 15.5, and recovers through 17.4/18. Left arm recovers earlier at 17.1. Exit arm poses intentionally differ slightly.
- Shoulder/guide poses on Arm.R were adjusted to reduce stock/arm overlap. This retains shoulder-driven rigid movement; no elbows, hands, IK or new bones.
- Chest overshoot peaks at 10.6, then recovery follows weapon placement rather than finishing simultaneously.
- Spine adds a delayed small response; Neck/Head remain calm with slight counterbalance, returning to zero local rotation at 18.
- Back placement overshoot at 14.8 is **1.44 cm** and approximately **1.00°**. Rifle settles to the exact V1/D0 stowed transform by 16.3, remaining secure through 18.

## Motion ranges

Sampled bone-local XYZ Euler ranges, degrees; bone axes are the existing rig axes, not global yaw/pitch.

| Bone | X | Y | Z |
|---|---:|---:|---:|
| Chest | 0.22…3.70 | −12.40…−0.30 | −0.15…0.85 |
| Spine | −0.08…0.55 | −1.30…0.12 | 0…0.15 |
| Neck | −0.40…0.05 | −0.12…1.20 | −0.25…0 |
| Head | −0.15…0 | 0…0.40 | −0.05…0 |
| Arm.L | −7.58…56.31 | −2.28…8.52 | −15.84…10.38 |
| Arm.R | −63.36…62.63 | −37.01…17.32 | −77.31…26.16 |

Chest begins at Y=−4°, so its additional sweep yaw is 8.4°. Final Chest rotation is (0.22°, −0.30°, 0.05°), with different tiny residual arm poses suitable for a locomotion blend-out.

The weapon follows the approved shoulder-side arc with coordinated lift and twist. An outboard clearance pose remains before the inward sweep. It is not a straight hand-to-back translation. Quaternion key signs remain continuous; the maximum physical carrier orientation change at 1/8-frame sampling is **3.38°**, with no sudden orientation flip detected.

## Markers

Blender timeline/action marker frames are integers. Fractional visual-event times are also stored on V2 as `event_subframes_json` for future integration reference.

| Marker | Blender frame | Visual event subframe |
|---|---:|---:|
| HOLSTER_BEGIN | 1 | 1 |
| SUPPORT_HAND_RELEASE | 5 | 5.3 |
| WEAPON_BACK_CONTACT | 15 | 14.8 |
| HOLSTER_RELEASE | 16 | 15.5 |
| HOLSTER_DONE | 18 | 18 |

## Curves and validation

- 31 curves, 300 scalar-channel key points; sparse authored poses rather than dense baking. Bezier interpolation with AUTO_CLAMPED extrema and curated timing offsets; no linear channels, noise or scale animation.
- Root, Hips, Leg.L, Leg.R: **0 keys each**. Root travel **0 m**, lower-body matrix bases remain identity in the standing preview.
- WeaponCarrier remains non-deforming and has no mesh weights. Original geometry, weights, bone lengths, hierarchy and rest matrices match the protection baseline.
- V1 curve hash unchanged: `240acd44c051a87fc00254930acf1c22f0f36af755714721d001ed0f389a5149`. All existing Idle/Run actions also match their protected hashes.
- 137 samples at 1/8-frame spacing across the full transition, including 8.0–12.0: no head-interior or deep-chest penetration found. Collision tests allow a 1 cm head boundary and 3.5 cm chest surface margin; they are not a proof of zero superficial contact.
- **Remaining limitation:** gun/right-arm intersections remain during the initial hold/pull and some guiding subframes. An arm-interior test reports 87 of 137 sampled frames with contact/intersection (2.5 cm surface margin, excluding distal 20 cm for grip contact). Initial Ready overlap comes from the preserved approved pose; the V2 shoulder/guide adjustment reduces later overlap but does not eliminate all contacts. Left proximal-arm test finds no intersections. This is ready for visual review, not a claim of completely collision-free hand/arm attachment.
- Reviewed key poses from gameplay elevated 3/4, front 3/4 and side, plus the shoulder pass at half frames. Timed repeating previews are provided at approximately 24 FPS and half speed; human playback approval remains necessary. It is a one-shot clip, so repeated preview intentionally resets from Stowed to Ready.

## Run compatibility preview

Read-only lower-body samples from `Player_Run_Blocky_V7_Final` were combined temporarily with the V2 upper body at four stride offsets (0, 4, 8, 12 frames). 140 combined samples produced no head/deep-chest collision. Gameplay renders cover holster frames 8, 11 and 15 for each stride offset. No Run keys were changed, no NLA tracks were added, and lower-body pose bases were restored before saving. This tests the filtered upper-body concept in Blender; runtime Godot layering/handoff remains untested.

## Review files and final state

- `holster_d1_v2_review/contact_sheet.png`: gameplay/front/side key-pose overview.
- `holster_d1_v2_review/preview_24fps.gif`: repeating normal-speed preview, GIF timing quantized to 10 ms.
- `holster_d1_v2_review/preview_half_speed.gif`: repeating half-speed preview.
- `holster_d1_v2_validation.json`: ranges, protection, event and layer metrics.
- `polish_holster_d1_v2.py`: reproducible V2 authoring script; edits only its own V2 action.

Connected Blender is saved with Player_Cuboid_Rig selected in Object Mode, **Holster_LongGun_V2** active, frame 1, preview range **1–18 at 24 FPS**, clean material viewport and standing lower body. Press Space over the viewport to review. Production files, Godot gameplay/D0, Run and mesh assets were not edited. No Draw, reload, recoil, pistol animation, new articulation or export was created.
