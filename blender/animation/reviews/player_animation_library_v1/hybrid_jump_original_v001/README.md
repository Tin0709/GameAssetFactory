# Original Jump — MD2 foundation + A&S bounce, Pending

Run **Open Original Jump Review.cmd** to open the EXISTING `blender/animation/showcase/Animation_Showcase.blend` with its repository panel and play **Original Jump — MD2 foundation + A&S bounce**. Space pauses; use Front / Side / Three-quarter to inspect. All earlier Idle, Walk/Run, hybrid Run and reference Actions remain available with their original statuses. New request authorizes Jump creation; it does not promote the Pending Walk/Run or authorize Godot integration.

| New original Pending Action | Pose duration | Playback frames at60FPS |
|---|---:|---:|
|`Jump_Takeoff_MD2_AS_Original_v001_PENDING`|0.40s|1–25, finite|
|`Jump_Airborne_MD2_AS_Original_v001_PENDING`|0.80s|1–48, closing49|
|`Jump_Landing_MD2_AS_Original_v001_PENDING`|0.30s|1–19, finite|
|`PREVIEW_ONLY_Jump_MD2_AS_Context_Original_v001_PENDING`|2.00s take|1–120, closing121|

Select phases individually in the same Animation Library. The context is an inspection take, not another production jump candidate. It has0.4s of quiet pose before launch and a settled hold after landing; the lead-in is not an input delay. World elevation is on the separately identified presentation Empty, never baked into Root or the reusable phase Actions.

## Construction

**Source-backed foundation:** existing private MD2 extraction records `Player_Jump`0.40s and `Player_Jump_Land`0.30s, with separate airborne loops. The current accepted lab separates jump physics from skeletal playback. Existing direct A&S source research establishes local Jump/Landing clocks, early airborne compression, lead-side variation, separate fall/landing layers and diminishing/nonlinear recovery. New source scale exceptions are deliberately not adopted.

**Original design:** all curves come from `motion.py` and `build_original.py`, not copied MD2/A&S key arrays. Strong early arm release and an asymmetric straight-leg silhouette; restrained head attitude; arms fan away from the face. Land on fixed flat soles, compress the mass45mm over55ms, recover most height by130ms, add a smaller12mm settling dip, finish at300ms. New head pitch stays within4.5°. The existing13-bone rest rig, original mesh/texture and rigid weights are reused; ForeArm helpers remain identity, all scales one, no knees/elbows added.

The45mm compression is rigid leg-origin compensation at the hidden hip junction. Legs retain their lengths; body/leg overlap substitutes for an articulated crouch. The existing head/chest junction also overlaps under lean. These are inspectable voxel-rig choices requiring artistic review, not claims of recovered native IK.

**Original preview adapter:**0.52s flight,0.25s to a1.20m apex, then a0.27s descent. This continues the accepted lab's approximate snappy arc. The private runtime analysis contains~0.52s flights, but capsule height/terrain/read timing make its recorded vertical extent unsuitable for claiming this is exact native physics. No game physics or Godot controller changed. Isolated airborne poses can extend below Root, so their library preview uses a declared−40mm floor; full context uses the actual zero-height ground and its separate arc.

## Inspection evidence

`measurements.json`:2,001 evaluated samples per saved Action, actual rigid sole vertices,30/60/120Hz output samples, zero sampled grounded/context penetration, zero grounded sole velocity in this stationary take, unit scales, identity ForeArms, zero Root travel. Takeoff→Airborne and Landing→settled pose errors zero. Airborne/context pose loops close. These are stationary flat-ground results, not validation of moving jumps, terrain or engine integration. Pose continuity does not prove all derivative/blending behavior in a future controller.

Independent saved-source SAT checks at1,001 subframes per Action found no arm/head, arm/torso, arm-to-arm or leg-to-leg intersections above1mm; expected connected head/chest overlap remains. Rendered Front / Side / Three-quarter frames and `Jump_MD2_AS_Original_Pending.gif` show actual authored motion. GIF samples30Hz over2s; codec merges identical holds while preserving total timing.

`hybrid_jump_authoring.blend` contains only these four new original pose Actions. Central installation/reopen and GUI playback evidence are beside it. Backups/signature baselines/logs/regenerable frames stay outside Git in `.validation/animation_showcase/hybrid_jump_original_v001`. Proprietary research excerpts stay in MD2 Research. **Pending human artistic approval; no Godot integration.**
