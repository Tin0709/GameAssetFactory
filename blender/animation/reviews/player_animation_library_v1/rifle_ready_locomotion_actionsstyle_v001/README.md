# Rifle Ready locomotion ActionsStyle v001 — Blender research review

Two NEW Pending candidates in the existing Animation Showcase:
- `Rifle_Ready_Walk_ActionsStyle_v001`
- `Rifle_Ready_Run_ActionsStyle_v001`

`Rifle_Ready_Idle_ActionsStyle_v004` was artistically approved by the user on2026-10-17. Its approved Action and source file are preserved exactly. Approval is recorded in the central manifest; the original source-folder Pending delivery records remain historical evidence.

## Source verified this build

Primary reference: the existing local Actions & Stuff1.12 mcpack, SHA256 `9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d`. The pack is read directly on every build. Large extracted payloads/probes stay outside Git in the local experiment cache.

- `entity/dtr.json`: ordinary player0, alive/local/dry/grounded, mainhand uncharged crossbow, empty offhand, no attack/use, neutral caller look.
- `animation_controllers/616f2ff7.json`: `xunqct/rzkmtm` layered graph; `lhbuwm/veywgp` forward Walk/Run; `iplurh/okjrob` local holding controller; `njvelc/kcexxa.ltqtzr` crossbow hold. The latter stays active during BOTH gaits; there is no fabricated separately named crossbow-running clip.
- `animations/f2da1071.json`: `tldiyl/walk`, `fngydr/move`, settled sprint `ucaryc/xahrzd`, crossbow bob `rrvlnm/mshwsb`, crossbow hold `dubgwy/tcucxa`, source head `cndmcx/look_at_target`, root heading `boabcq/xfltzh`, turn bank `ktgnrt/hxfxxu`, foot-event timeline `przmfq/oprmcp`.

Crossbow hold cancels accumulated arm pitch/yaw through literal same-axis `this`; it keeps asymmetric residual roll and upstream vertical shoulder motion. Body yaw retains20% of the gait yaw plus12degrees ready twist. Settled sprint changes the asymmetric arm roll. Waist/shoulder/head bob retains its own400/200/100degree-per-second clocks. Autonomous idle attention is inactive during sustained movement; no invented look-around is added to these locomotion clips. Cape/helper surfaces have no corresponding native geometry and are not fabricated.

The ordinary source controller uses speed thresholds .7/.6, .2s dwell and .22s fades. These Actions are steady gait states, not baked transition cinematics. Virtual forward queries are2.62451171875blocks/s for Walk (normalized .6103515625, phase1.25cycles/s) and5.59blocks/s for Run (normalized1, phase1.6cycles/s). These are source sampling conditions, not changes to Godot travel speeds.

## Exact source behavior and native adaptation

Both use the approved v004 actual Rifle Stylized V2, right grip matrix, lowered ready family, joined head/torso anchor, straight forearms, and tiny inherited support-pressure motion. Right arm drives the rifle as a rigid attachment. Left palm has only restrained inherited breathing release/tangent motion (maximum about1.55mm from the approved relative anchor), and the whole straight support arm follows the closest reachable shoulder socket. No elbow/knee, mesh/rest-rig/proportion change or floppy weapon layer.

Literal source leg rotations, horizontal translation, source phase/key locations/interpolation and Run leg-length pulse (1..1.07) remain. Source scales keep cuboid shape but change leg length; do not describe them as fixed-size rigid legs. Constant source crossbow angles/rightitem offset are calibrated to v004 rifle contacts rather than forcing a short crossbow's attachment onto our longer rifle.

Explicit native geometry adapters:
- Walk holding assembly seats2mm lower. The left straight support is projected toward a socket target4mm outside the native shoulder center to clear moving head corners; the actual palm/grip stay fixed relative to the rifle.
- Run holding assembly rotates24degrees upward about the shoulder line, seats30mm lower and24mm right, then projects the left straight arm toward the same4mm-outset native socket target. Both in-hand contacts remain stable. This is a native rifle clearance adaptation, NOT behavior claimed to exist in the pack. It keeps the long rifle/arms out of the recovering legs; the gun is visibly higher during Run than Idle/Walk.
- Run gait-only waist vertical excursion is60% of source amplitude; independent crossbow lifetime bob and all gait clocks remain unchanged. This prevents native torso/holding compression intersecting the high source recovery. Maximum vertical adjustment is69.75mm. No leg recovery path was redesigned to make room.
- The broad native square head remains seated at the torso top; torso-relative pitch/roll is bounded to4degrees, with relative yaw retained. This differs from literal entity-relative source head tilt and prevents shoulder clipping. Largest tilt correction is reported in the build evidence.
- Per-sole vertical correction only prevents our square boots penetrating the floor (Walk≤43.83mm, Run≤36.30mm). Source leg angles/horizontal paths/scale are retained. No physical foot lock, guaranteed no sliding, Godot transition or mobile-performance claim is implied by this in-place Blender study.

## Timing and playback

240Hz evaluated PRS plus original source gait breakpoints; keyed LINEAR bake, no generic running formula or smoothing replacement. Ordinary source controller warmup establishes steady motion before capture. The fast steady continuation is compared with a separately advancing full graph; measured maximum channel difference is below5e-10 over the audited3.6s span.

Walk: core stride .8s; full natural composite loop7.2s, F1–216, closing217 excluded.
Run: core stride .625s; full natural composite loop90s, F1–2700, closing2701 excluded. The long period is the exact recurrence of the source gait and independent crossbow bob (144strides/25bob periods); it avoids forcing a bob reset every stride. Do not arbitrarily shorten the composite before gameplay layering.

Adjacent torso/leg solid seating follows the source root-leg/waist hierarchy: measured maximum about182.2mm Walk and194.1mm Run. This is a source-style overlapping pelvis/leg visual adapter, not a physical anatomy/contact certification. Head/chest and right-shoulder seating remain within the approved v00430/55mm bounds; other nonadjacent/rifle intersections are rejected.

Three review views use original speed30FPS. Each7.2s Run movie is a continuous excerpt, not the full90s composite loop. Side-by-side comparisons label Idle Approved and both locomotion clips Pending. Movies use the same actor/materials/cameras and actual weapon, not video-derived fitting.

## Review and preservation

Open the EXISTING `blender/animation/showcase/Animation_Showcase.blend`, N sidebar → Animation Library. Select the new Rifle Ready Walk or Run; playback loops its registered range. Approved v004 remains directly selectable, and all archived entries remain recoverable through Show Archived.

See `source_build_validation.json`, `geometry_validation.json`, `registration.json`, `reopen_verification.json`, `media_validation.json` and `preservation.json` for measured evidence. The shared authoring study `.blend` is a source file, not another Showcase. Original approved Actions/native assets and the existing Godot project remain unchanged.

These source-derived adaptations are research-only and not eligible for commercial production. No Godot integration in this task: first review these TWO Pending Blender candidates, then integrate explicitly approved behavior into the existing player/weapon dev flow without another project or test scene.
