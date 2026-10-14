# Actions & Stuff 1.12: steady grounded forward Run layers

Read-only package/controller verification, 2026-10-14. No Blender scene, action, project asset, library or showcase was edited. Findings are confined to this directory.

The actual package `/Users/tin/Desktop/Game Dev/local_references/Actions Stuff 1.12 (resources).mcpack` hashes to `9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d`. The source aliases, controllers and clips below were re-read from that archive. `source_evidence.research_only.json` retains their precise member/JSON pointers and selected definitions. `steady_profile.research_only.json` is the machine-readable profile, including the exact bob definition.

## Canonical conditions and selection

Use regular third-person `v.tnlxsa=0`, normalized speed `v.esnrkj=1`, forward `v.cknrcn=1`, lateral `v.mrmeib=0`, grounded, alive and fully settled. Set turn `v.bdjsdw=0`, lateral reorientation `v.upxhvv=0`, waist/head yaw aligned (`v.nthjcy=q.body_y_rotation`), zero head-look input, no equipment/use/attack, no terrain offsets, no special locomotion, no spawn/hurt transient. Normalized speed 1 does **not** specify exact physical speed: `/pre_animation/27` clamps actual horizontal speed divided by 4.3, so any steady actual speed at least 4.3 produces 1.

`entity/dtr.json#/minecraft:client_entity/description/scripts/animate` invokes `rzkmtm` → `controller.animation.oreville_ans.xunqct/default`. Its `veywgp` layer selects `controller.animation.oreville_ans.lhbuwm/run`. This selection depends on speed, not sprint: Walk enters Run above .7 after .2 s dwell; Run exits below .6 after .2 s. The controller uses .22 s state crossfades. Fully settled conditions exclude that transition interval.

The Run state's raw expressions evaluate to:

| Alias | Raw weight | Steady effect |
|---|---:|---|
| `move` / `fngydr` | +1 | Main exact forward Run; clip blend weight `esnrkj` is also 1 |
| `move_right`, `move_left` | 0, 0 | No directional contribution |
| `pgnnhd` / `fcsrsv` | **−1** | Runtime handling unresolved; reconstruction explicitly assumes nonpositive directional clips inactive |
| `hxfxxu` / `ktgnrt` | 1 | Zero for `bdjsdw=0` |
| `kiggsk`, `yonenf`, `gcquxx` | 0, 0, 0 | Type-specific overlays inactive |
| `oprmcp` / `przmfq` | 1 | Marker timeline only; no pose bones |

Do not claim −1 was proved inactive. The inspected primary documentation establishes 0=off, 1=full, but does not explicitly specify negative-weight handling. It gives a boolean-gated example whose accompanying negative-range prose cannot prove how a literal signed weight is treated. The profile preserves raw −1 and the explicit inactive assumption; it does not silently subtract the backward clip or normalize four direction weights.

Pointers: `animation_controllers/616f2ff7.json#/animation_controllers/controller.animation.oreville_ans.lhbuwm/states/run`; `animations/f2da1071.json#/animations/animation.oreville_ans.fngydr`.

## Material steady layers and clocks

The main anatomy pose includes **forward Run + lifetime bob + settled sprint posture when sprint is on**. Regular empty-handed Run is not the isolated `fngydr` clip alone.

The Run clock is `v.eqhdel`, from `entity/dtr.json#/minecraft:client_entity/description/scripts/pre_animation/29`. At speed1/lateral0 its rate is exactly 1.6 cycles/s, hence .625 s/cycle. `fngydr` has animation length1, looptrue, `anim_time_update=v.eqhdel`, `blend_weight=v.esnrkj`. It preserves the source leg local Y/Z translations and Y-scale pulses, rather than reducing the legs to rotation oscillators.

Sprint on: `xunqct/default → psowex/pygoip/ptvsjb → xahrzd/ucaryc`. After 1.25 s, the held layer contributes these exact Euler vectors at weight1:

| Bone | X,Y,Z degrees |
|---|---|
| waist | +5,0,0 |
| leftarm | 0,+8,−10 |
| rightarm | 0,−8,+10 |

The same channels exist on alternate `egjh9*` skeleton names; do not apply both name sets to one body. Sprint posture's clock is seconds since entering its state, then hold on last frame; it is not the gait clock. Sprint off after settling: `psowex/default` has no animation. Immediately after release, `stop` plays `sjvffv/bxtvze` for 1.2083 s at `max(1-esnrkj,.001)=.001`; this is a transient, not a steady offset.

Bob is weight1 via `xunqct/default → okjrob/iplurh/eryuvy` (local) or `hgnodg` (remote) `→ kcexxa/njvelc/default → bob/tdrcwc`. It is driven by `L=q.life_time`, with degree trigonometry:

| Bone | Exact bob contribution |
|---|---|
| waist | RZ=−cos(122.5L); PX=.25 sin(122.5L); PY=.15 cos(245L)−.15 |
| head | RX=−2 sin(245L); RY=−sin(122.5L−45); RZ=−3 cos(122.5L−45) |
| leftarm | RZ=−1.25 sin(245L)−1.15; PY=.1 cos(245L)+.05 |
| rightarm | RZ=+1.25 sin(245L)+1.15; PY=.1 cos(245L)+.05 |
| both legs | RZ=1.2 sin(122.5L); PX=.25 sin(122.5L) |

Unlisted bob channels are zero or absent, scales are absent. Bob's first-harmonic period is `144/49 ≈ 2.9387755102 s`. The exact joint recurrence with the .625 s Run period is **720 s**, comprising 1152 Run cycles and 245 bob cycles. Four Run cycles (2.5 s) advance bob306.25°, so cannot make the combined pose a seamless short loop.

Requested study initialization is run phase0, lifetime origin0, already-settled sprint, six continuous seconds at30FPS/180 visible frames. Lifetime origin0 is an explicit arbitrary bob phase; no recording phase has been identified. At t=6, core Run has completed9.6 cycles and bob's first harmonic735° (15° mod360). Do not force the take endpoint to the initial pose. A t=6 closing evaluation lies beyond the 180 samples t=0…179/30.

## Neutral layers and head basis caveat

`humanoid_base_pose/pcbwvo` contains only `loop=hold_on_last_frame`, with no bones. `move.arms` and `move.legs` are empty loop definitions despite their .001 entity weights. `controller.player_movement.offset/yemteq/default` has no animation for `trznwu=gynlia=tkterv=0`. Type-specific geometry offsets `btwfwj/isrdju` and `pxfdpb/ooczsv` are gated off for regular `tnlxsa=0`. The `.5`-weighted `holding/dpjhxl` adds arm X `-this*v.vbcdda`/`-this*v.wfyvyl`; both variables settle to0 with empty hands. `xfltzh/boabcq` contributes zero under aligned yaw and `upxhvv=0`. `hxfxxu/ktgnrt` contributes zero with `bdjsdw=0`. Thus no nonzero neutral base-pose or terrain offset was found in these conditions.

**Zero head-look input is not proven equivalent to disabling the look layer.** `hsfnbp/ooprql/default` still invokes `look_at_target/cndmcx`, whose head has `relative_to.rotation=entity` and numeric rotation `[q.target_x_rotation,v.wyuvst,0]`. The input can be zero while the entity-relative basis cancels inherited parent rotation. Blockbench's [Bedrock importer](https://github.com/JannisX11/blockbench/blob/master/js/formats/bedrock/bedrock_animation.js#L260) marks this global rotation; its [preview animator](https://github.com/JannisX11/blockbench/blob/master/js/animations/timeline_animators.js#L383) compensates parent world rotation. This is corroborating authoring-preview behavior, not a verified current Bedrock multi-layer runtime result. A reconstruction omitting that basis must label the head-orientation mismatch; candidate behavior is inherited head origin with parent-rotation compensation so cumulative head orientation is entity-relative.

## Accumulate channels before transforming; Euler naming correction

Microsoft's [Animations Overview](https://learn.microsoft.com/en-us/minecraft/creator/documents/animations/animationsoverview?view=minecraft-bedrock-stable) specifies resetting the geometry pose each frame, adding per-axis animation channels, then building the transform. Accumulate Run+bob+sprint rotations into a single source Euler vector **before** converting to a matrix; multiplying separate Run and sprint rotation matrices is not equivalent.

The documented X-then-Y-then-Z rotations mean the column-vector matrix `Rz @ Ry @ Rx`. Blockbench [ModelFormat](https://github.com/JannisX11/blockbench/blob/master/js/io/format.ts#L692) defaults to Three.js `ZYX`; [Bedrock format](https://github.com/JannisX11/blockbench/blob/master/js/formats/bedrock/bedrock.js#L1489) does not override it. The [Three.js matrix formulas](https://github.com/mrdoob/three.js/blob/dev/src/math/Matrix4.js#L376) give `Rz @ Ry @ Rx` for that intrinsic-order label. [Blender's matrix implementation](https://github.com/blender/blender/blob/main/source/blender/blenlib/intern/math_rotation_c.cc#L1617), with orderXYZ, gives the equivalent column-vector matrix. Thus Three.jsZYX and BlenderXYZ correspond here; copying the label is incorrect. Blockbench's [animation import signs](https://github.com/JannisX11/blockbench/blob/master/js/formats/bedrock/bedrock_animation.js#L178) invert source rotationX/Y and positionX.

For the proposed display-coordinate conversion, use explicit `Rz(rz) @ Ry(-ry) @ Rx(-rx)` after source channel accumulation, then `C @ R @ C^-1` for target coordinates. It corresponds to Blender `Euler((-rx,-ry,rz),'XYZ')`, with radians. Parent reports prior accepted Walk used BlenderZYX; the new Run study should document this convention correction while leaving that accepted Walk untouched. Actual target rest-bone basis and pivot compensation remain the parent implementation's responsibility.

## Geometry and omitted native-rig features

The regular renderer in `render_controllers/464e7f72.json#/render_controllers/controller.render.player.third_person` selects `Array.epvbkc[v.tnlxsa]`, where index0 is `Geometry.default`. Entity binding is `geometry.humanoid.custom`; neither that geometry nor `geometry.cape` is defined anywhere in the archive's model geometries. Exact primary skeleton parents, pivots, bind transforms, skin/proportions and cape shape are therefore external fallback data. Entity regular scale is .9375. Do not describe a fallback reconstruction as the pack's extracted main rig.

Corroborating package anatomy hierarchy is retained in evidence:

- `models/entity/464e86f4.json#/minecraft:geometry/68` (`geometry.oreville_ans.jbttdv`): root[0,0,0]→waist4ghq[0,12,0]→body4ghq[0,24,0]→left/rightarm4ghq[±5,22,0]. These are attachment helpers.
- `models/entity/464ef792.json#/minecraft:geometry/336` (`geometry.oreville_ans.jujuvq`): alternate egjh9root→waist→body→head/arms, with egjh9legs parented to root. Its central humanoid pivots are waist[0,12,0], body/head[0,24,0], arms[±5,22,0], legs[±2,12,0]. This supports the usual hierarchy assumption, but is an alternate model, not primary geometry proof.
- `models/entity/464e86f4.json#/minecraft:geometry/302` (`geometry.oreville_ans.yshdar`): foot effect locator helpers are children of independent helper6d6e6flk; they are not leg children. They place particle locators, not anatomical contact constraints.

Cape is missing from the native13-bone rig: core Run cape RX=`5 sin(720phi)`, RY=`24 sin(360phi+10)`. Runtime cape/vuslkn adds RX=`-5+kbshhs`; for straight grounded speed≥4.3 and a cape, settled `kbshhs=-7 min(actual_speed,10)`, ealvck0. Runtime pitch ranges[−75,−35.1]° and total including Run is bounded[−80,−30.1]°, while core yaw is±24°. Cape Y position reads an armor-neck locator offset, unknown without runtime geometry. No exact surface/silhouette error bound is possible without the cape mesh; omission has no feedback channel into main anatomy in these definitions.

Alternate egjh9* bones, *4ghq attachment bones and effect helpers should be omitted as absent surfaces/helpers, not merged as additional layers onto the native anatomy. `wqleol/owltad` records cumulative channel `this` into variables and returns neutral primary transforms; `gzxwdv/uivqbf` copies them to *4ghq helpers. Rigid source arms/legs have no elbow/knee/ankle channels in Run; adding such bends changes the source motion. Geometry/proportions, relative head basis, signed weights, attachment surfaces and full engine evaluation behavior remain explicit fidelity limits.

## Head basis study recommendation and exact order

`xunqct/default/animations` applies xfltzh at index0, normal veywgp/Run at4, sprint psowex at7, okjrob at11 and look hsfnbp at13. Within okjrob local/remote states, kcexxa is at3; its default plays bob at0. Therefore the material order is **Run → settled sprint → bob → entity-relative head basis**. The entity animate recorder wqleol and helper-copy gzxwdv are later. Treating numeric-zero look as a guaranteed no-op would ignore that basis flag.

Best supported study handling: inherit the body-transformed Headpivot position, cancel inherited parent rotation, and apply the accumulated literal source head Run+bob rotation relative to a neutral entity basis. This compensation is not an invented head counter-twist. It is supported by the Blockbench primary importer/preview paths; exact current Bedrock multi-animation composition remains unvalidated, so preserve that limitation in the study metadata.

## Held golden/Totem-like item audit

`held_item_profiles.research_only.json` retains exact general holding paths and optional diagnostics. The recording's item and physical hand remain unidentified. Screen-left alone does not establish main/right or off/left, especially while camera azimuth changes. The canonical main profile above is explicitly empty-handed; it must not be called the exact item-bearing recording pose.

No third-person Totem-specific pose branch was found. The two `totem_of_undying` controller states (`wducfe` and `zjeawg`) contain equip sounds/transitions only, with no animation. A simple nonweapon Totem follows the general carrying paths: main/right enters `kcexxa/njvelc/ssulqn`; off/left enters `wjfipe/dpcxlx/ssulqn`. `v.is_holding_right/left` have no assignments anywhere in the pack's JSON, so are external flags that the study must explicitly set.

The exact tail of `pre_animation/29` updates the modifiers:

- Right held: `v.vbcdda=lerp(v.vbcdda,!v.fxllpr&&!v.hhsumy&&v.undfyr==0,0.2)`; right empty: multiply by `1-9*delta_time`.
- Left held: `v.wfyvyl=lerp(v.wfyvyl,!v.hhsumy,0.2)`; left empty: multiply by `1-9*delta_time`.

Both held transitions converge per frame with factor.8; no delta_time multiplies the held lerp coefficient. Canonical grounded no-special-motion and `undfyr=0` give settled1 for the held arm,0 for the other. Source movement tier `undfyr` is not a weapon flag: `/pre_animation/40` derives it from `q.ground_speed/(sneaking?.3:sprinting?1.3:1)`, subtracts4.316406, divides.864258, rounds and clamps below at0, then waits.5s stable. Set undfyr0 explicitly: normalizedspeed1 alone does not imply0. At boosted undfyr≠0, main/right target becomes0, while off/left remains1. Groundspeed4.3 without sprint or5.59 with sprint is compatible with the normal tier.

The `holding/dpjhxl` layer, after bob, has blend_weight.5 and controllerweight1. Its arm X increment is `-.5*this*vbcdda` (right) or `-.5*this*wfyvyl` (left). Therefore it **attenuates the existing accumulated arm X**, instead of adding a new static pitch:

| Profile at normal movement tier | Right Run RX | Left Run RX |
|---|---|---|
| empty hands | −55 sin(360phi+10) | +55 sin(360phi+10) |
| main/right generic Totem | **−27.5** sin(360phi+10) | +55 sin(360phi+10) |
| off/left generic Totem | −55 sin(360phi+10) | **+27.5** sin(360phi+10) |
| both generic items | −27.5 sin(360phi+10) | +27.5 sin(360phi+10) |

Sprint contributes armX0 and bob contributes armX0, so these exact X formulas apply with sprint on or off. Holding leaves the source arm Y/Z and positions unchanged. For settled sprint S and lifetimeL, rightarm Y=`18 sin(360phi)-8S`, Z=`1.25 sin(245L)+1.15+10S`; leftarm Y=`18 sin(360phi)+8S`, Z=`-1.25 sin(245L)-1.15-10S`. Both arm Y positions remain `-.5 cos(720phi)+.1 cos(245L)+.05`.

`fzimtw/utlfik` (main) and `xhexyy/pyhjiu` (off) are.3s equip transients: arm rotation returns0 and itemscale1. They do not add a persistent arm pitch. Other special raised-hand clips require hold_up/other flags and should not be silently activated for Totem.

For video compatibility, preserve the empty-hand study's label and compare main/right-held versus off/left-held variants using these source multipliers, with all body clocks, bobphase, sprint and head-basis handling unchanged. This is a material source-supported difference capable of explaining asymmetric arm arcs; it does not confirm item or hand identity. No invented held-arm offset is warranted.
