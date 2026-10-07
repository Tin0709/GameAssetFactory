# E2 — Armed Run Ready, Pass 1

Created **LongGunReady_Run_V1** in `player_cuboid_weapon_animation_dev.blend`.
E1 remains unchanged as the Idle Ready candidate. No Godot integration or V2.

## Action and composition

- Frames **1–17**, with 17 duplicating 1; play unique frames 1–16.
- Base authoring: **24 FPS**, 0.667-second cycle. At **1.60 cadence**: 0.417 seconds.
- Animated bones: **Spine, Chest, Arm.R, Arm.L, WeaponCarrier, Neck, Head**.
- Root, Hips, Leg.L and Leg.R: **0 keys each**. No scale tracks.
- Required phase contract: Run and Ready Run use the same source frame. Body
  basis is Run basis multiplied by Ready correction for Spine/Chest/Neck/Head;
  arms and carrier use the authored Ready poses. Run alone owns the lower body.

Run was inspected at Contact 1/9, Down 3/11, Passing 5/13 and Up 7/15. Both halves
retain their existing slight asymmetry. Source hips fall to approximately
0.633 m at Down and rise to approximately 0.713 m at Up. The new motion is derived
from that cycle, rather than an independent breathing oscillator.

## Motion strategy

| Part | Blocking strategy |
| --- | --- |
| Spine | Absorbs roughly one third of transmitted vertical motion and some angular variation around the cycle's average athletic lean. Maximum correction from current composed Hold is about 13 mm / 0.54°. |
| Chest | Retains controlled stride energy and forward intent, including Contact/Down absorption and Passing/Up recovery. Keeps about 58% of baseline angular variation; it remains visibly mobile in the sampled poses. |
| Arm.R | Rear/trigger control follows the coordinated rifle correction, compensating for the torso moving underneath it. No free Run arm swing. |
| Arm.L | Keeps its distinct forward support pose and local shoulder response. It shares the weapon correction but is not a mirrored copy of Arm.R. |
| WeaponCarrier | Partial vertical/rotational compensation, retaining motion instead of fixing the rifle in world space. A 0.22 source-frame response lag (about 5.7 ms at 1.60 cadence) preserves a small delayed response. |
| Neck / Head | Neck absorbs the remaining transmitted motion; Head keeps a calmer orientation and reduced vertical excursion. No scanning or independent oscillation. |

The arms and rifle share a rigid correction at authored samples, preserving
their relative grip relationships. Local shoulder translations are part of the
blocking; no bone lengths, scale, mesh or skinning were changed.

## A/B/C measurements

Peak-to-peak world-space vertical excursion, sampled in the Blender composition
over 6.67 seconds at quarter-playback-frame intervals:

| Variant | Hips | Chest | Carrier / grip | Rifle muzzle | Head |
| --- | ---: | ---: | ---: | ---: | ---: |
| A — Run + Hold V2 | 81.3 mm | 82.1 mm | 104.7 mm | 144.5 mm | 78.7 mm |
| B — Run + Ready Loop V1 | 81.3 mm | 82.2 mm | 108.6 mm | 155.4 mm | 80.0 mm |
| C — Run + Ready Run V1 | 81.3 mm | **55.7 mm** | **29.3 mm** | **44.0 mm** | **17.3 mm** |

C reduces carrier bob about **72%** versus A. The rifle muzzle also travels less
vertically than Chest, so the improvement is not limited to the carrier pivot.
Angular range across a stride is approximately Chest **4.76°**, rifle **2.88°**,
Head **1.07°**; A's corresponding values were 8.20°, 8.20°, 3.55°.
These measurements support the stability hierarchy, not artistic approval.

## Rendered comparison and concerns

`E2_Run_ABC_Detail` and `E2_Run_ABC_GameplayScale` are saved in the development file.
A is left, B center, C right. Space plays at 24 FPS; the previews already sample
Run and C at 1.60 cadence. The 160-frame preview covers 16 Run cycles and five
independent E1 cycles. `PREVIEW_ONLY_*` Actions are baked comparison playback;
they must not be exported. **The actual Ready Run Action has no lower-body keys.**

The gameplay-scale scene matches the current elevated camera orientation and
14.5-unit orthographic vertical span at 1280×720. It is a Blender composition,
not a recording of the game renderer or gameplay controller. Detail lighting
varies slightly across the three characters because they share studio lights.

Inspected Contact/Down/Passing/Up renders preserve the rifle silhouette, clear
head, and distinct supporting arms. C's rifle dip/rise is visibly smaller across
the inspected poses than A or B. Chest still moves beneath it. The difference is
larger than E1's near-subpixel addition at gameplay scale.

Remaining artistic concerns for **normal-speed visual approval**:

- Compensation is deliberately meaningful; judge whether the weapon still feels
  carried and weighted rather than too steady over repeated strides.
- This rigid stylized rig uses small shoulder/neck translations. Inspect them in
  motion for sliding or a telescoping impression, especially in close views.
- The short, phase-locked cycle repeats every 0.417 seconds. Existing left/right
  asymmetry is retained, but long-playback naturalness remains an artistic judgment.

Normal-time animated comparisons are in `ready_run_e2_review`. GIF timing
alternates 40/50 ms frames to approximate 24 FPS. No additional slow-motion pass
or unapproved animation version was produced.

## Clipping, transitions and validation

- No weapon/inset-head or deep-chest intersections in the sampled A/B/C poses.
  Inspected rendered phases show no major face, torso or arm/rifle clipping.
  Existing minor grip overlap remains acceptable; exhaustive all-view collision
  freedom is not claimed.
- Arm/weapon relative-transform matrix error stays below 0.000046 through
  interpolation. This is not a penetration-depth measurement.
- Compared with Run + the approved Hold endpoint over the stride, C differs by
  at most 2.80° in arm/rifle orientation and about 44 mm at an arm origin. This
  supports broad Draw/Holster compatibility for blocking, with no catastrophic
  pose mismatch found. It does **not** remove the need for transition blending
  or approve arbitrary-phase runtime transitions.
- Cycle pose mismatch: **0**; endpoint curve-slope mismatch below **5.1e−8**.
- Shared-phase comparisons at offsets 0/4/8/12 pass. Lower-body composition error
  is at most **1.2e−7**. Saved preview poses match the source composition within
  **1.2e−7**.
- All **19 pre-existing Actions** match protection fingerprints, including E1,
  Hold V2, Run V7, Draw V3, Holster V3 and Player_Idle. Original mesh/weights,
  rest matrices, bone lengths and hierarchy are unchanged. Production Godot files
  are unchanged. A pre-E2 development-file backup is retained.

See `ready_run_e2_validation.json` for measured evidence. Stopped after Pass 1;
the next decision is visual approval of C against A/B at normal speed.
