# Actions & Stuff directional input research v001

**Pending · research-only · Blender only · 2026-10-14.** This is a deterministic source-controller reconstruction on the existing native player rig, with explicitly identified engine adapters. It is not a claim of complete Bedrock runtime equivalence or production-ready foot planting.

## Open and review

Open `../../showcase/Animation_Showcase.blend` (from this folder, the repository file is `blender/animation/showcase/Animation_Showcase.blend`). In the 3D View press **N → Animation Library → Pending Research Sequences → Actions & Stuff Directional Input v001**. Use Play/Pause, Restart and Front / Three Quarter / Side; Return to Animation Library restores the original library scene. The standalone authoring file is `directional_input_review.blend`.

The review is **28 seconds, frames 1–840 at 30 FPS, original speed**, with a closing sample at 841. It is a one-shot sequence, not a seamless reusable locomotion loop; looping is initially off. Core directional gaits retain the source loops. Restart reproduces the same input trace. Baked playback does not execute the source Python evaluator or embedded executable text.

Videos: [three-quarter](review/three_quarter_30fps.mp4), [front](review/front_30fps.mp4), [side](review/side_30fps.mp4). Orange ground arrow is supplied input direction; blue is source-computed body facing. Highlighted W/D/S/A represents input intent, not literal keyboard queries in the pack. The pointer shows continuous gait phase. LOWEST reports the measured lower sole within 30 mm of the display floor, otherwise FLIGHT; **it is not a verified supporting-foot flag**.

| Time | Scenario |
|---|---|
| 0–0.8 s | Standing/source idle layers |
| 0.8–3.6 s | Walk W→D→S→A; key holds 0.20, 0.10, 0.05 s; recent interaction context |
| 3.6–6.4 s | Same Walk input; relaxed context, >10 s since attack |
| 6.4–8.4 s | Walk circular input, fixed head/look |
| 8.4–10.4 s | Walk input and look through a full 360° |
| 10.4–13.6 s | Walk W↔S then A↔D reversals, 0.4 s holds |
| 13.6–14.4 s | Release/source deceleration |
| 14.4–17.2 s | Run W→D→S→A; 0.20, 0.10, 0.05 s; recent context |
| 17.2–20 s | Same Run input; relaxed context |
| 20–22 s | Run circular input, fixed look |
| 22–24 s | Run input and look through 360° |
| 24–27.2 s | Run W↔S then A↔D reversals |
| 27.2–28 s | Release/source deceleration |

## What the pack actually does

Archive: `/Users/tin/Desktop/Game Dev/local_references/Actions Stuff 1.12 (resources).mcpack`. SHA256 `9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d`.

Verified files: `entity/dtr.json` (`minecraft:player`), `animations/f2da1071.json`, `animation_controllers/616f2ff7.json`. Ordinary-player chain: scripts.animate alias `rzkmtm` → controller `xunqct` → alias `veywgp` → controller `lhbuwm`. The audited profile is normal third-person grounded player type 2, excluding alternate types 3/13, air, swimming, special interactions and cape geometry.

All clip suffixes below have prefix `animation.oreville_ans.`:

| Gait | Forward | Backward | Right | Left |
|---|---|---|---|---|
| Walk | tldiyl | eaqhvv | fpushb | dfajpq |
| Run | fngydr | fcsrsv | pmgjno | qzziyu |

These are independently authored directional clips: sideways legs swing about a different axis; backward gait has distinct poses and body timing. This study evaluates all eight literal rotation, position and scale channels; it does not rotate an unrelated forward gait to imitate strafing.

With f=cknrcn and s=mrmeib, controller raw weights in F/R/L/B order are `f−.25*abs(s), s−.25*abs(s), −s−.25*abs(s), −f−.25*abs(s)`. Walk clip activation is `clamp(esnrkj*3,0,1)`; Run is `esnrkj`. Source channels are composed at their literal weights before matrix conversion. Authored Run model-Y leg scale reaches 1.07; mixed channels in this trace reach about 1.0676. No scale pulse is omitted or flattened.

Exact `pre_animation` order **27→29→30** is evaluated using the restricted Molang parser in `molang.py`. Math trig uses degrees, statement order and prior-frame variables are preserved. Unsupported syntax/profile inputs fail explicitly.

Speed variable `esnrkj` follows `clamp(horizontal_speed/4.3,0,1)` with source factor 13*dt. Common clock `eqhdel += dt*sqrt(abs(esnrkj + abs(mrmeib)*.25*min(1,esnrkj*3)))*1.6`. All directional clips read that clock; changing direction or normal Walk/Run state does **not reset it**. At steady forward settings this gives Walk 1.25 Hz and Run 1.6 Hz; lateral terms can change cadence. Jump/recovery phase overrides exist outside this grounded scope.

Walk→Run needs esnrkj>.7 and state_time>.2; reverse needs esnrkj<.6 and state_time>.2. Both states specify a .22 s outgoing linear transition. Simulation uses these thresholds and minimum dwell, rather than switching gait instantly on the displayed mode label.

Direction is derived from normalized engine movement relative to head yaw. The pack smooths forward/lateral values at 8*dt in the recent-action/backward/item-interaction branch. In the relaxed >10-second branch, forward/lateral travel can turn the body using a signed side-squared target at 6*dt and reduce strafe blending. Body yaw tracks unwrapped head yaw at 12*dt. `nthjcy` is evaluated before updating the side-turn variable, preserving its one-frame relationship. B1/B2 expose the distinction between changing travel direction and changing head/look.

Additional layers are retained: root/waist yaw `boabcq`, entity-relative head targeting `cndmcx`, Run bank `ktgnrt`, independent lifetime bob `tdrcwc`, settled sprint layer `ucaryc`, and ordered right-hand holding attenuation `dpjhxl`. Lifetime bob uses 122.5/245 degree frequencies independently of gait phase. This review uses the previously declared settled sprint endpoint and right-hand holding profile; it does not investigate sprint-onset transients or weapon changes.

There is **no foot-lock, IK, plant memory, contact-preserving pivot, dedicated turn-in-place/180° reversal Action** in this audited ordinary-ground path. Step timeline flags at .45/.95 are event flags, not ground constraints. Directional curves, shared phase, smoothed weights and body coordination explain the verified pack behavior. Extreme stationary input spam remains a stress test; this research does not silently add a new foot-placement algorithm to make the source appear more capable.

## Explicit adapters and limitations

1. **Engine inputs:** keyboard-to-velocity, collision/friction, mouse/head/body yaw dynamics, query timing and exact closed-engine evaluation are not present in resource JSON. The harness supplies deterministic virtual position deltas and movement vectors at 60 Hz; output is reviewed at 30 FPS. Nominal query speeds: Walk 2.62451 blocks/s, Run 5.59 blocks/s. Display root XY stays exactly fixed while queries move virtually. Therefore this is stationary footwork research, not a measured world-space sliding test or a Minecraft physics implementation.
2. **Negative weights:** source weights can be negative. This study uses `max(0,raw)` without normalization, matching the existing declared source study adapter. Negative-weight semantics have not been measured in Bedrock. Exact query_yaw_speed units are also unspecified by the official query page; the harness supplies head-yaw derivative in degrees/s. Those choices are assumptions, not source facts.
3. **Contexts:** the two key-spam sections explicitly seed recent versus relaxed attackless-timer context; this does not restart the gait clock. The take starts after 12 seconds of idle warmup. Input+look circle reaches 360°; the actual source body heading follows with source delay.
4. **Native transforms:** existing 1.8 m appearance, 13-bone rest rig and 64 mesh vertices are preserved. Source legs remain independent of waist motion through native parent compensation; straight arms/legs have neutral ForeArm transforms. Full composite uses explicit source Rz·Ry·Rx conversion (Blender XYZ), entity-relative head and full applicable layers. The approved isolated Walk study used ZYX, parent-relative head and omitted bob/controller layers; it is left unchanged. Thus the new full Walk composite intentionally differs from that isolated simplified profile, without overwriting it.
5. **Native height presentation:** raw source transforms on our proportions can put a sole 136.8 mm below the original ground. Lowering the entire ground made idle visibly float. The separate presentation parent therefore applies a **phase-independent directional/strength height envelope**, calibrated from source curves across 16 angles, 7 magnitudes and 241 phases per clip, with one constant 5.30055 mm padding. Offset range in this take is **7.51–150.33 mm**. It changes absolute body height as direction/activation changes; relative bone bounce and the complete pose Action are unchanged. No per-frame foot clamp, IK or planted-foot constraint is used. The raw pose study is retained in the local staging archive; this is a native-rig adaptation, not a foot solver found in the pack.
6. **Unrepaired source details:** the .078-model-unit lateral Walk endpoint mismatch remains as authored. Independent lifetime bob means the full composite is not a short exact repeating loop. Other player types, attacks, water, terrain, items and jump transitions remain outside this review.

## Validation and preservation

15 controller/channel tests pass, including statement order, phase continuity, threshold/dwell/crossfade, backward/side distinction, literal keys, degree atan, source seam and scale preservation. Accepted forward Run profile comparison covers 15,183 channel components with zero error. Independent native evaluation checks all 1,681 half-frame samples: matrix error ≤5.96e−7; pose Action exactly matches the raw source study; ForeArm basis identity. Display root XY=0; minimum sole clearance 0.500083 mm; idle clearance about 5.30–6.30 mm. These geometry checks establish no floor penetration at sampled frames, not proven foot locking, perfect silhouette, or no inter-limb overlap.

The same central Showcase now has a separate Pending research sequence; its previous 37 entries and Action signatures remain unchanged. Separate rig/scene/cameras/parent/HUD avoid changing the original review scene. Save/reopen, Action/slot validation, sequence open/return, three camera/HUD controls and no-autoplay are checked. Approved Walk/Run source files, weapon Showcase and all protected Godot files are preserved. No Godot integration or production asset promotion is included.

Audits: `audit/controller_findings.txt`, `audit/clip_findings.txt`, exact source excerpts, timeline, deterministic trace, height calibration, native reopen and preservation results. `source_payload.json` and source-derived reconstruction are private **research-only**, outside the Godot project; they are not commercial production assets.

Primary semantic references: [animation format](https://learn.microsoft.com/en-us/minecraft/creator/reference/content/visualreference/actor_animation.v1.8.0?view=minecraft-bedrock-stable), [animation controllers](https://learn.microsoft.com/en-us/minecraft/creator/documents/animations/animationcontroller?view=minecraft-bedrock-stable), [query_yaw_speed](https://learn.microsoft.com/en-us/minecraft/creator/reference/content/molangreference/examples/molangconcepts/queryfunctions/query_yaw_speed?view=minecraft-bedrock-stable). These document format/query semantics, not hidden Bedrock foot placement or negative-weight behavior.
