# R14 Pass 2 — six-direction combat footwork

**ARTISTIC STATUS: AWAITING HUMAN REVIEW.**

Blender study only. No Godot or production migration during this pass. All pre-existing Actions (including both V1 strafes), meshes/weights, and rest rigs were checked unchanged. No IK, new bones, Root tracks, or root motion. Parent translation exists only in review scenes.

## Actions and measured feet

| Action | Duration | Lead | Plant centroid XY slip | Rigid sole-corner XY drift |
|---|---:|---|---:|---:|
| `Combat_StrafeRight_V2` | 0.333 s | Leg.R | 0.010 mm | 23.2 mm |
| `Combat_StrafeLeft_V2` | 0.333 s | Leg.L | 0.010 mm | 23.2 mm |
| `Combat_StrafeForwardRight_V1` | 0.333 s | Leg.R | 0.010 mm | 32.8 mm |
| `Combat_StrafeForwardLeft_V1` | 0.333 s | Leg.L | 0.010 mm | 32.8 mm |
| `Combat_StrafeBackwardRight_V1` | 0.333 s | Leg.R | 0.010 mm | 32.8 mm |
| `Combat_StrafeBackwardLeft_V1` | 0.333 s | Leg.L | 0.010 mm | 32.8 mm |

FPS48, frames1–16 (frame17 closes the loop), 0.867m/cycle, 3cycles/sec at2.60m/s. Left/right lead is the character’s side. Trailing leg begins0.167s later. Recovery occupies58% of the cycle; support occupies42%. Brief staggered double-flight intervals produce a small stylized shuffle-hop. Backward diagonals have separately baked lower, earlier-peaking recovery, rather than reversed forward Action playback.

Measured support-stroke implied speed: 2.60008–2.60008m/s against2.60m/s parent travel. Measurements sample evaluated sole geometry at384Hz, and separate foot-centroid locking from residual rigid-corner rocking.

Hips bounce: 13.98mm peak-to-peak, two lifts per cycle, peaks at phase0.285 and0.785; landing/unloading is staggered by half a cycle. A shallow35mm lower weight-bearing baseline reduces rigid hip seams. Forward/lateral clearance peaks55mm, backward48mm. Chest remains enemy-forward while Hips gently yaw±1.5°; maximum relative twist is1.50001° (20° limit). Approved rifle-ready arms, head lean and weapon remain a separate unchanged NLA Action, retimed for48fps.

All six share cadence and contact phases. Left-leading Actions retain their own authored phase0; transition previews offset their playback by half a cycle to preserve each physical foot’s phase. Value loop seams are zero within evaluated float precision. A 4.25m/s lab-speed scene retimes the SAME six Actions; cycle becomes0.204s, which is visibly faster and remains a study limitation.

## Review scenes

- `R14P2_00_SIX_DIRECTION_SHOWCASE`: six directions, translated parents,0.4m world grid.
- `R14P2_01_AB_SAME_GAME_SPEED`: unchanged V1 at its24fps cadence versus V2, both travelling2.6m/s.
- Individual `R14P2_*` directions: front, side, three-quarter and elevated gameplay cameras; tracking keeps the character readable as the world grid passes below.
- `R14P2_T1`–`T9`: requested direction families, shared-phase blends. Walk uses its native16@24fps cadence (32frames at48fps), with an explicit right-foot contact map; cadence changes smoothly on the same physical-foot clock during handoffs. Existing Walk is used as the forward endpoint; existing Walk played backwards is labelled as the backward baseline, with no newly authored forward/back Action.
- Native live sidebar `Combat Review`: switch showcase, A/B, individual direction, camera and transition scenes; Play/Pause.

Rendered previews sample native animation at normal clock speed; GIFs are24fps for compact review. Native Blender playback is48fps. A finite parent path resets at the end of a showcase loop; that reset is not an Action pose seam.

## Rigid-rig limitations

Single cuboid legs cannot flex knees or articulate toes/soles. Sole centroids are nearly stationary in plants, but corners rock and drift23–33mm. Maximum leg tilt is40.1°; FK hip offsets reach89.6mm. Fast cadence is needed to represent2.6m/s without inflating leg angles indefinitely. Human review should judge whether this lively shuffle cadence and seams fit the intended style.

Transition blends are phase-continuous, but feet can slip during a direction change. Existing Walk/backward comparison endpoints retain the rigid-rig limitations of the older locomotion. Numerical passes do not imply artistic approval.

## Verification

Preservation: `{'actions': True, 'mesh_and_weights': True, 'rigs': True, 'V1_file': True}`. Exactly6 new Combat_Strafe Actions. Dense numerical result: `True`. See `validation.json` and `preview_validation.json` for exact values.

## Measured transition limits

| Sequence | Entry phases | Maximum near-floor centroid excursion | Maximum near-floor foot speed |
|---|---|---:|---:|
| Right > ForwardRight > Forward | 0.000, 0.000 | 14.2 mm | 1.26 m/s |
| Left > ForwardLeft > Forward | 0.250, 0.500 | 14.2 mm | 1.25 m/s |
| Right > BackwardRight > Backward | 0.500, 0.000 | 42.3 mm | 1.67 m/s |
| Left > BackwardLeft > Backward | 0.750, 0.500 | 172.6 mm | 4.85 m/s |
| ForwardRight > BackwardRight | 0.000 | 3.0 mm | 0.86 m/s |
| ForwardLeft > BackwardLeft | 0.250 | 5.2 mm | 0.86 m/s |
| ForwardRight > BackwardRight > BackwardLeft > ForwardLeft > ForwardRight | 0.500, 0.000, 0.500, 0.000 | 23.3 mm | 2.24 m/s |
| Forward > ForwardRight > Right | 0.375, 0.000 | 197.2 mm | 5.39 m/s |
| Backward > BackwardLeft > Left | 0.000, 0.875 | 684.6 mm | 11.79 m/s |

These are conservative near-floor measurements, including landing/takeoff portions and existing Walk endpoints; they are not guaranteed planted-foot locks. Forward/backward Walk remains at its native0.667s cycle while its cadence is eased on one shared canonical clock during a strafe handoff. Turn blends retain visible sliding, and require human review before any integration.

**Transition preview distinction:** the PREVIEW_ONLY Actions bake contact-preserving FK adjustments for the six-direction family, with a45degree tilt ceiling. They are stateful study bakes, and do not prove that a simple runtime crossfade of the six raw Actions will achieve the same contact stability. The six actual Combat_Strafe Actions remain separate untouched cycles. Native Walk handoffs are excluded from the contact bake, to preserve the existing locomotion baseline. No IK/constraints were added.

Skeleton: unchanged14-bone approved cuboid rig; new bone tracks only Hips, Leg.L, Leg.R and Spine. No torso-twist clamps or runtime movement changes were introduced.
