# Reconstruction conventions and limits

Private source-derived research. The registered Action is not a commercial animation or a complete Bedrock emulator.

## Verified source and profile

Archive: `/Users/tin/Desktop/Game Dev/local_references/Actions Stuff 1.12 (resources).mcpack`. Its hash matches the earlier Walking research. The displayed pack name is Actions & Stuff 1.12; its manifest declares version 1.1.60. Neither fact identifies the version used to record `Running.mp4`.

The study uses these literal source contributions, in source layer order:

1. `animation.oreville_ans.fngydr`: all Run head/waist/body/arm/leg position, rotation and scale channels, full weight.
2. `animation.oreville_ans.ucaryc`: held grounded sprint state after settling. Source end values add waist X +5°, left arm Y +8°/Z −10°, right arm Y −8°/Z +10°. Its Catmull-Rom entry transient is not played or approximated in this settled study.
3. `animation.oreville_ans.tdrcwc`: lifetime bob evaluated from its own `q.life_time`, including waist/head/arms/legs.
4. Generic holding `dpjhxl`: blend weight .5 and `-this*holding_flag` reduce the held arm's accumulated X rotation. Under settled normal-tier right holding, right arm X is half its pre-holding value; Y/Z and position are unchanged.
5. `look_at_target/cndmcx`: zero target-look input with entity-relative rotation semantics. The closest native-rig equivalent cancels parent orientation for Head while retaining the body-transformed head pivot.

Runtime conditions are declared, not recovered from the recording: regular body type 0, grounded, sprinting, full normalized speed, forward weight 1/lateral 0, movement boost tier `undfyr=0`, neutral head look/turn/terrain/attack/item-use, settled generic main/right holding and empty offhand. Ground speed 5.59 is compatible with normal sprint tier. Screen-left item-bearing arm is treated as the standard unmirrored right hand; the recording does not authenticate its handedness or exact item. No item prop geometry was added to the existing character.

The ordinary Walk/Run controller uses smoothed speed, .7/.6 hysteresis, .2 s dwell and .22 s crossfade. This study starts in steady Run; transitions are documented, not fabricated into an already-running clip. At the declared forward state, the source cumulative clock formula reduces to `v.eqhdel = 1.6*t + phase_origin`. The clip's own speed blend weight is 1. Raw directional expressions include a backward weight of −1; nonpositive directional contributions are assumed inactive. Primary documentation did not establish all version-specific negative-weight behavior. Other directional mixtures are not claimed to be reproduced.

Full exact evidence: [steady-layer memo](controller_research/STEADY_RUN_LAYERS.md), [controller profile](controller_research/steady_profile.research_only.json), [held-item audit](controller_research/held_item_profiles.research_only.json), [archive pointers](controller_research/source_evidence.research_only.json).

## Timing and interpolation

Molang trigonometry is evaluated in degrees. Numeric Run vectors are linearly interpolated at their actual source phases; original breakpoints are retained before dense samples. Source scale holds its endpoint value outside its keyed interval. Sprint is read only after its held endpoint; no generic smooth curve replaces its transient.

The Run phase clock is 1.6 cycles/s; lifetime bob remains 122.5°/s and its second harmonic 245°/s. Both study origins are explicitly set to zero; the recording's lifetime phase is unknown. Run alone repeats after .625 s, but the complete composite's exact common recurrence is 720 s. The Action therefore contains a continuous six-second take rather than a falsely seamless short loop. It has an evaluated endpoint sample at F181; playback F1–180 displays six seconds at 30 FPS without replacing that endpoint with the opening pose.

Dense native curves use linear interpolation with 2,996 samples, retaining 232 exact source breakpoint times across the take. This is a numerical bake of evaluated source transforms, not a smoothing pass. Saved-source sampling bounds its approximation; it does not prove all possible intermediate times or independently validate the closed-source game engine.

## Coordinates, channels and rig adaptation

Channels are summed per local axis before constructing a transform, consistent with [Microsoft's animation documentation](https://learn.microsoft.com/en-us/minecraft/creator/documents/animations/animationsoverview?view=minecraft-bedrock-stable). Bedrock-to-Blockbench signs are rotation `(-rx,-ry,rz)` and position `(-x,y,z)`; Blockbench-to-native mapping is `(-x,z,y)`, yielding native translation `(raw_x,raw_z,raw_y)`.

Rotation uses explicit column-vector matrices `Rz(rz) @ Ry(-ry) @ Rx(-rx)` with coordinate conjugation. Three.js's intrinsic `ZYX` name corresponds here to Blender's `XYZ` product. An independent quaternion test verifies the product. The accepted Walking builder used Blender's `ZYX` name; its file and Action are intentionally preserved. This study corrects the naming mismatch instead of silently carrying it into the new reconstruction. Source code evidence is linked in the controller memo.

Transforms use the established Blockbench-style pivot convention: translated pivot, rotation and local scale about that pivot. Native scale axes are permuted consistently; the source Y stretch appears on native Leg bone Y. Rest/parent inverses preserve desired source-leg world transforms even though native legs are parented under Hips and source helper anatomy places them under root. ForeArm helpers remain identity, keeping each full arm straight.

The existing 1.8 m character determines a model-unit fit of about 56.25 mm. Shoulder virtual pivots are two model units below the native top caps, as in Walking. Native proportions/shoulder inset are retained rather than reshaping the model into Minecraft's body. Helper geometry supports standard anatomy pivots, but the primary `geometry.humanoid.custom` and cape geometry are absent; exact original bind geometry cannot be verified. Cape and alternate body-type/helper surfaces have no corresponding mesh/bones and are explicitly excluded. Particle marker helpers are not substituted for feet.

Source `relative_to.rotation=entity` is not assumed a no-op when look input is zero. Head is kept at the parent-transformed pivot with entity-relative summed source orientation. This is a representable native equivalent; the precise order of all Bedrock runtime operations and externally supplied look/holding flags remains an inference, not a claim of engine-equivalent evaluation.

## Ground and source scaling

The source's 1.07 leg-length pulse is preserved. A strict viewer exception applies only to this verified source provenance, research-only/non-production entry, Leg.L/R Y scale in [1,1.070002], linear keys and no modifiers. Existing animation restrictions remain unchanged. Source stretch preserves straight cuboid shape, while changing its length; it should not be described as fixed-size rigid motion.

The floor is a single display alignment at −.0336740687 m, computed from the native six-second geometry probe with .4 mm padding. The motion itself is unchanged: no foot locks, per-frame floor lifting or support correction. Source .45/.95 particle flags schedule effects and project locator Y to ground; they do not measure physical contact. Native sole clearance is therefore a geometry result of this retarget, not recovered Minecraft support/flight/slip.

## Recorded reference and visual comparison

Fresh decoding verifies 349 samples, 250×380, exact `i/30` timestamps and the original video hash. The primary continuous window is zero-based F30–97, 68 samples, with no duplicate/near-duplicate samples. It shows roughly four recorded strides. Camera yaw, perspective and held-item asymmetry limit calibration.

The observed recurrence is approximately 17 frames, versus canonical forward 18.75 frames. This difference can reflect unidentified movement/controller/capture conditions or pack versions; none is established. Main videos retain both clocks and let phase drift remain visible. The separately labeled diagnostic changes only forward phase rate to `30/17`, preserving source channel shapes and native lifetime bob; it creates no Action and does not change the registered faithful bake.

[Reference memo and provenance](video_research/VIDEO_COMPARISON_MEMO.md). No per-frame size matching, camera-motion fitting, subframe contact estimate or version-difference claim was made.
