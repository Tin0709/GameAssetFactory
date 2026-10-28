# Original Hybrid Run v001 — three Pending variants

Review target: existing `blender/animation/showcase/Animation_Showcase.blend`, sequence **Original Hybrid Run — V1 / V2 / V3 synchronized**. The three original Actions are individually selectable there. This folder contains ONE authoring study, not separate per-animation showcases. All versions are Pending. No Godot implementation or existing approved motion was replaced.

| Action | Hip bounce peak-to-peak | Torso yaw peak-to-peak | Head pitch peak amplitude |
|---|---:|---:|---:|
| Run_Hybrid_V1_Subtle_Bounce_Original_v001 |25mm |8degrees |0.6degrees |
| Run_Hybrid_V2_Balanced_Bounce_Original_v001 |45mm |14degrees |1.0degrees |
| Run_Hybrid_V3_Expressive_Bounce_Original_v001 |65mm |20degrees |1.5degrees |

All use1.888Hz full gait cycles and7m/s virtual contact travel.32frame intervals per cycle; FPS60/fps_base0.9931144067796611 gives60.416effective frames/s. Four cycles playF1–128; F129 is the duplicate closing pose, excluded from playback. Duration2.118644s. Do not relabel as60fps/fps_base1 or change to16frames/30fps. All three are phase-synchronized; the same rest rig, mesh/materials, lighting, camera and support schedule allow meaningful A/B/C comparison. Front,3/4and Side cameras retain left-to-right variant order.

## What was designed originally
`motion.py` and `build_original.py` load no reference animation data. Independent curves create asymmetric load/release spacing, different torso/head/arm phase offsets, opposite straight-arm swing and snappy rigid-leg recovery. Original prototype phase origin=.25. Right support centers at Action phase.25; left at.75, opposite by half a cycle. Each original rolling support window occupies.16cycle (~84.75ms), with heel/toe edge transfer. This is an original short-contact design, NOT a recovered MD2 foot-contact mask. Only the verified cadence and virtual movement speed are preserved as numerical reference foundations. Native absolute contacts remain unavailable; artistic/source-derived approval is not inferred.

Source-JSON research motivated principles, not keys or proprietary procedural code. No native scale/stretch channel was copied. All bones remain scale1; technical ForeArm helpers remain identity, so whole arms/legs remain straight. Hips carry controlled load/weight shifts and upper layers counterrotate gaze. Legs rotate as rigid blocks and use connected upward pivot recovery inside the waist (maximum ~130/135/140mm in V1/V2/V3). This preserves geometry rather than bending a knee or stretching a limb; the tuck/silhouette needs human review. Root/object Action travel is zero. Stage-row offsets are static comparison layout only.

## Measurements and interpretation
`measurements.json` is evaluated from the saved keyed rig, not just generator equations:1025subframe samples over one cycle per variant, with virtual7m/s forward travel. Sample the same actual bottom edge while it is the intended rolling support; do not compare a heel-to-toe edge switch as if it were one physical material point. Current rolling-contact3D speed RMS is~0.019m/s and max~0.020m/s; measured floor penetration0mm, scale deviation0. Dense1/16frame linear baking reduces between-key contact-height ripple. No runtime IK or terrain clamp masks these measurements.

Head measurements are evaluated world orientation relative to neutral rest: maximum pitch0.6/1/1.5degrees; yaw0.27/0.45/0.675and roll0.24/0.4/0.6. Hip amplitudes and body yaw are actual evaluated values. Scene synchronization is not proof of future Godot blends: movement compatibility here means exact cycle timing, root-in-place and phase/contact feasibility under calibrated travel. Start/stop, turn, jump/land and combat integration remain future work and must not replace approved controllers before review.

## Preservation and review
Original central file, registry, UI code and initial sampling draft are preserved under ignored `.validation/animation_showcase/hybrid_run_original_v001/`. The installer compares all101old Action fingerprints and the native rest signature; previous66entries/statuses remain unchanged.3new Pending registrations and one comparison scene are added. The comparison uses3copies of the original rig/mesh with synchronized Action bindings; no source asset is introduced. One static Empty presentation Action is stage metadata, not a fourth character animation.

UI startup now tolerates an older installed addon lacking the archive property, then uses the existing repository panel; no global auto-run preference or addon installation is changed. Original-motion comparison gets its own accurate panel label; existing source-research sequence labels remain intact.

Use N → Animation Library → comparison, Play/Pause, Restart, Front/3/4/Side. Return to Animation Library to select V1/V2/V3 individually or an earlier approved reference. All new Actions remain Pending until the user selects/approves a foundation. Authoring study: `hybrid_run_authoring.blend`. No GLB export, Godot code change or production promotion in this milestone.
