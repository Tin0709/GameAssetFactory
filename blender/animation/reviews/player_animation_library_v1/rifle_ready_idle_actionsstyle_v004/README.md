# Rifle Ready Idle ActionsStyle v004

**Pending Blender review.** Exactly one separate candidate, based on the user's artistically approved `Rifle_Ready_Idle_ActionsStyle_v003`. Its source file and all Action curves remain unchanged. v003 approval is recorded in the main manifest; v004 is not approved. Research-only/nonproduction; no Godot integration.

Open the existing `blender/animation/showcase/Animation_Showcase.blend`, use the Animation Library sidebar and select `Rifle_Ready_Idle_ActionsStyle_v004`. The actual Rifle Stylized V2 is shown. v003 remains independently selectable as Approved; older entries remain available through Show Archived. Space plays/pauses. F1–324 at30FPS gives10.8seconds; closing key325 is excluded from playback.

## Change versus v003

| Property | v003 approved base | v004 Pending |
|---|---|---|
| Overall holding set | Original height | Arms and rifle lowered18mm in world vertical, same alert angles |
| Right grip/rifle alignment | Stable rigid relationship | Retained; rifle orientation and motion unchanged apart from constant drop |
| Left support | Palm locked relative to rifle | Tiny pressure release and overlap; actual relative palm offset up to1.79mm |
| Left shoulder | Source constrained support | Up to2.44mm new movement and±0.15° whole straight-arm rotation |
| Head/body/legs | Source-derived v003 | Identical curves and evaluated world transforms |
| Cadence, pauses, loop |10.8seconds, source timing | Identical; no stretch or key-time edit |

The new support additive is independently authored, not claimed to exist in the original pack. It follows the inherited source waist/idle bob clock (400°/s,0.9s) and shoulder/head rhythm (200°/s,1.8s). Pressure release0.4–1.6mm has a75ms overlap;±0.8mm tangent travel has100ms overlap;±0.15° whole-arm shoulder rotation has125ms overlap. These offsets make the support side breathe with the existing idle without adding new torso/head motion or another rhythm. There is no elbow articulation, forearm bend, scale pulse or loose weapon following. Both arms remain straight. The rifle stays controlled by the right hand.

Directions are measured from the actual rifle body and magazine surfaces toward the support palm. The final micro-motion needs no collision clipping at any of the2,593 build samples. Whole-arm rotation pivots near the support palm so shoulder life does not cause a large hand arc. At30FPS the largest new palm-offset step is0.158mm; this is deliberately subtle rather than an exaggerated reanimation.

## Review

- `comparison_v003_left_v004_right_30fps.mp4`: same camera/time, v003 left and v004 right,10.8s at original speed.
- `rifle_ready_idle_three_quarter_30fps_1x.mp4`, `rifle_ready_idle_front_30fps_1x.mp4`, `rifle_ready_idle_side_30fps_1x.mp4`: original-speed views.
- `build_validation.json`, `refinement_validation.json`, `motion_validation.json`: exact changes, independent base comparison, geometry/loop checks.

## Preservation and limits

All unaffected F-curves are copied verbatim, including original key times/interpolation/modifiers. The constant arm-set drop requires new local translations for both upper arms and the rifle carrier; only the left upper arm gets the small additional rotation. Forearm local channels remain untouched. Independent649-pose comparison verifies head/body/root/legs unchanged,18mm right-arm/rifle drop and identical orientation. Geometry checks cover rigid weights, straight elbows, actual rifle meshes, feet, adjacent seating and loop pose/velocity boundaries.

The inherited source reconstruction and its documented adapters remain research-only: asymmetric crossbow hold layers, seeded attention gesture, calibrated rifle grip, head clearance, sole correction and source foot movement are preserved. See the unchanged v003 `REFERENCE.md` for exact source files/controllers and adaptation limits. This refinement does not independently license the underlying source-derived motion or certify gameplay transitions.

All earlier Actions, native rig/mesh/material/texture data and prior study folders are preserved. Backups before the change, including unsaved native session data, are outside the repository under the v004 experiment directory. The existing Godot game and research scene are not modified.

Final validation:83native Actions (82earlier exact),48Action registrations plus2research sequences,15focused entries/35archived. Native save/reopen and two GUI playback wraps pass. All2,032protected Godot and previous rifle study files are byte-exact. Four review videos decode1,296frames at30FPS with continuous timestamps. Both Blender files use existing Git LFS tracking; source10.87MiB and current Showcase33.92MiB. No tracking migration or history rewrite.
