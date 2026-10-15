# Player Idle head, lookaround, and face source audit

Read-only audit of `/Users/tin/Desktop/Game Dev/local_references/Actions Stuff 1.12 (resources).mcpack`. No repository file, Blender data, Blender UI, or Godot file was changed. This report and its evidence are confined to this audit directory. Source identifiers are obfuscated; conclusions use the player entity's actual alias graph, not similarly named aliases on other entities.

## Decision for the single Idle study

Use ordinary **player profile `v.tnlxsa=0`**, alive, third person, dry, standing, unarmed, with zero caller head queries. Reproduce the literal controller-selected autonomous idle and the continuing body layers. A seeded ordinary random draw can reproducibly select `tculwn` without replacing the source chooser. A nine-second study can show eligible stillness, its 4.2083-second gesture, its source exit fade, and ambient recovery. Declare the prior-history initialization required to make this controller eligible. Do not fabricate a blinking head or claim the fixed existing character renders source facial animation.

This is deliberately a new Pending Blender study only. The accepted Godot baseline uses profile 2 and remains unchanged.

## Important profile correction

`entity/dtr.json` is `minecraft:player`. Its pre-animation[44] starts `v.tnlxsa=0`. Local player morph setting `oreville_ans:pntihm`, option `cvqsjl`, sets it to 2. `manifest.json` defaults that setting to `default`. `texts/en_US.lang` identifies the options as:

- `default`: **Disabled: Default Character Model**.
- `cvqsjl`: **Rana: Frog Girl**.

The prior JumpRuntime constructor's hardcoded `v.tnlxsa=2` is therefore a Rana morph profile, not the ordinary default player. Its neutral body channels can be reused carefully; this profile must not silently carry into the primary PlayerIdle study. `tculwn`'s head, waist, body, arms and legs have byte-equivalent parsed channel records between normal and `egjh9` names, verified in `audit_checks.json`. Rana-specific `tesczf` and `iodvus` are additional behaviors, not ordinary player idle evidence.

## Three different sources of head movement

1. **Autonomous authored attention gesture:** `bjmscc` → `controller.animation.oreville_ans.fotixv`, including `tculwn` → `animation.oreville_ans.jcyjaa`. This has actual yaw/roll keys even with caller head queries fixed at zero.
2. **Player/query-driven gaze:** `look_at_target` → `animation.oreville_ans.cndmcx`, continuously active through `hsfnbp` in ordinary standing idle. Its normal and `egjh9` head tracks explicitly set `relative_to.rotation="entity"`, with `rotation=[q.target_x_rotation,v.wyuvst,0]`. This is not an autonomous lookaround clip.
3. **Small periodic ambient motion:** `bob` → `animation.oreville_ans.tdrcwc`, driven by `q.life_time`; this keeps head/waist/arms/legs moving but is not the randomized attention gesture.

### Query yaw history and head reference

Player pre-animation[29], under `!q.is_in_ui&&!v.is_paperdoll&&(v.wtlyok?1:!v.is_first_person)`, performs:

```
v.hgztwc=q.head_y_rotation(0);
v.jjzail=v.hgztwc-v.jrptkt;
v.qfzzuw=v.jjzail+(v.jjzail<-180?360:v.jjzail>180?-360:0);
v.vyjyhz=v.vyjyhz+v.qfzzuw;
v.jrptkt=v.hgztwc;
v.ccwxuc=v.vyjyhz-v.nthjcy;
v.tnswmo=Math.min_angle(v.ccwxuc);
Math.abs(v.tnswmo)>90
  ? {v.wyuvst=Math.lerp(v.wyuvst,Math.clamp(v.tnswmo,-90,90),0.05);}
  : {v.wyuvst=v.tnswmo;};
```

The same script smooths moving-player yaw response with `v.bdjsdw += ((v.sfdeke>0?Math.clamp(q.yaw_speed,-48,48))-v.bdjsdw)*(5*q.delta_time)`. `v.tjbdov=v.esnrkj>0.1||v.cthrgf||v.gddzeg` controls movement/body-follow logic; while moving, `v.ufojdf += (v.vyjyhz-v.ufojdf)*(12*q.delta_time)` and `v.nthjcy=v.ufojdf+v.upxhvv*90`.

`hsfnbp` → `controller.animation.oreville_ans.ooprql` default enters with `v.htpchf=1` and applies `look_at_target` for `v.tnlxsa!=13`. Its exits concern gliding or `v.yngszr||v.dxlndb`; none applies to the proposed ordinary idle. Thus the study's composed head must preserve the active **entity-relative** head reference. Treating the final head orientation as a simple child of the torso would double-add torso yaw/roll. The existing JumpRetarget explicitly cancels pure root/waist/body ancestor rotation for entity-relative head while preserving source translation and inherited scale. Its documented limitation for shear under nonuniform rotated ancestors remains.

`xfltzh` → `animation.oreville_ans.boabcq` supplies root and head yaw `-q.body_y_rotation+v.nthjcy`; its waist yaw is `v.upxhvv*-22.5*v.esnrkj`. Keep this authored layer and distinguish it from visual/world heading adapters.

### Source composition order matters

`rzkmtm` → `controller.animation.oreville_ans.xunqct/default` orders the relevant entries as:

`xfltzh`, cape, movement offset, `flkskc`, locomotion controller, `psowex`, `agyfrv`, other interaction controllers, `hsfnbp`, swim, **`bjmscc`**, other item/body controllers.

The full exact list is in `selected_player_head_face_source.json`. `hsfnbp` gaze is therefore before autonomous `bjmscc` attention keys. The latter is an additive authored contribution to the already composed head. Do not reorder layers based on their descriptive names, particularly clips containing `this`.

## Autonomous idle eligibility and selection

`bjmscc=fotixv` starts in `uwpoku`, waiting for nonzero **`q.modified_distance_moved`**. It does not autonomously leave that state for a newly spawned never-moved entity. After entering `wkbbnc`, transition order is:

1. `ssaxeh` when `q.state_time>3`.
2. Self-reset `wkbbnc` when `v.obhshf>0.25||v.nwocdu`.
3. `jssmqg` when `v.ccwxuc` is nonzero; this waits `q.state_time>0.35` before returning to `wkbbnc`.

`ssaxeh` returns to `wkbbnc` for emoting, main-hand use, sneak, airborne, mace, or readable item; otherwise it enters `blzrmm`. `blzrmm` executes:

```
v.yfuzcx=v.tnlxsa==2?Math.random_integer(1,6);
v.ngjrwv=Math.random_integer(1,12);
v.xrtrow=1;
```

The Rana-only `tesczf` branch has priority when `v.yfuzcx==1`. Ordinary profile 0 selects the twelve branches from `v.ngjrwv`. `tculwn` is selected by `v.ngjrwv==1`.

`tculwn` plays its literal 4.2083-second clip and exits to `bhsawv` on `q.is_emoting||q.any_animation_finished||q.ground_speed||v.nwocdu||v.ccwxuc`; its source `blend_transition` is **0.2 seconds**. `bhsawv` clears `v.xrtrow=0`, then returns to `wkbbnc` after **0.35 seconds**. Other branches have their own completion/interrupt conditions and 0.16/0.2/0.3-second fades; preserve them if the evaluator includes the complete source controller even though this single study displays one seeded branch.

`v.nwocdu` is not simply "moving": pre-animation[29] sets `v.txtwqb=v.attack_time==0?v.txtwqb+q.delta_time` and sets the flag for `v.txtwqb<10`, reverse travel `<-0.3`, blocking, main-hand use, charged item, swim, crawl/fly flags. A faithful stillness scenario must declare eligible prior movement/attack-free history, rather than silently skipping the controller's startup gate or claiming a guaranteed idle exactly three seconds after spawning.

### `tculwn` head and supporting body motion

All times below are clip-local seconds. Catmull-Rom is explicitly authored on the intermediate records; the full pre/post values are in the evidence JSON.

Head rotation `(pitch,yaw,roll)`:

| Time | Source degrees |
|---:|---|
| 0 / 0.125 | (0,0,0) |
| 0.25 | (0,-30,-5) |
| 0.4583 | (0,-32,0) |
| 0.6667 | (0,-22.75,0) |
| 0.9167 | (0,40,5) |
| 1.1667 | (0,40,2) |
| 1.4583 | (0,30,-3) |
| 1.875 | (0,30,0) |
| 2.5833 | (0,30,-6) |
| 3.0 | (0,0,5) |
| 3.375 | (0,0,-2) |
| 3.75 / 4.1667 | (0,0,0) |

This particular gesture is primarily sideways yaw plus tilt. It does **not** author an up/down head pitch sweep. Do not add one to satisfy an imagined idle pattern.

The body responds after the head: body yaw is 0 at .1667, -6° at .2917/.75, +8° at1.25, +6° from1.5417 through2.625, then0 at3.0. The source waist rolls and shifts: x-position reaches -1 source unit at1.0833, holds through2.2083 and returns0 at2.5417; roll reaches -3° at1.3333 through2.5. Body vertical position has distinct dips/rebounds, e.g. -.5 at.8333, +.07 at1.0, -.6 at1.1667, -.75 at2.375, then returns. Keep these source features rather than imposing new breath curves.

There are no separate source shoulder bones in this gesture. The actual whole-arm channels are its shoulder response: left arm roll -4° at1.2083–2.25, returns at2.7083, a -2° residual at3.0417; right arm roll2° at.875,0 at1.125,6° at1.375,5° at1.7083–2.1667,8° at2.5417, then small settling keys to0 at3.625. Both arms have rotation only in this clip, with no authored arm translation. Body/waist hierarchy also carries them. Inventing a shoulder drop or forearm bend would not reconstruct this clip.

`agyfrv=irkwzk` separately handles standing body alignment: the `vywhcj` branch triggers for `abs(v.ccwxuc)>60||v.txvzcq>10`, clamps the turn to±90°, plays `rjfeeq` weighted by turn and `ejnecs` weighted by its negative, and updates `v.nthjcy=Math.ease_in_out_back(v.martvv,v.martvv+v.woataa,clamp(v.hdseda*2,0,1))`. This is gaze/body realignment, not the randomized lookaround. Zero query yaw isolates the actual autonomous gesture without inventing camera input.

## Ambient source motion

`bob=tdrcwc` uses degrees inside Molang trigonometry. With `L=q.life_time`:

- Waist rotation `(0,0,-cos(122.5L))`; position `(.25sin(122.5L), .15cos(245L)-.15, 0)`.
- Head rotation `(-2sin(245L), -sin(122.5L-45), -3cos(122.5L-45))`.
- Left arm roll `-1.25sin(245L)-1.15`; right roll `1.25sin(245L)+1.15`; both arm vertical offsets `.1cos(245L)+.05`.
- Both legs roll `1.2sin(122.5L)` and x-position `.25sin(122.5L)`.

The slow period is 360/122.5 = **2.9387755102 seconds**, the double-frequency period **1.4693877551 seconds**. A nine-second presentation is a finite study; it is not mathematically a seamless source loop. `holding=dpjhxl` has blend_weight.5 and `-this*v.vbcdda`/`-this*v.wfyvyl` arm pitch correction; use the unarmed flags0/0 so it contributes no held-item arm suppression.

## Facial support: real source behavior, unsupported by the native study rig

### Conditions and actual player blink

`entity/dtr.json` pre-animation[23] is exactly:

```
v.kdqvtc=!v.is_first_person&&!v.map_face_icon
 &&(!q.is_persona_or_premium_skin||v.tnlxsa>=2)
 &&q.is_alive&&q.is_pack_setting_enabled('oreville_ans:wzqdjp');
```

The setting defaults **true**, translated as **Enable Expressions**. `ppzqvo` is invoked under `v.kdqvtc&&!q.is_spectator&&!v.xrtrow`; therefore the ordinary ambient blink controller is suppressed while an autonomous idle owns `v.xrtrow=1`. Additional special `bypidi` requires `v.tnlxsa==2` and is excluded from ordinary profile0.

`ppzqvo` → `controller.animation.oreville_ans.rnxhgi` chooses a wait `Math.random(1.25,4.25)`. For `q.any(v.tnlxsa,0,1,5,9)` it transitions to `njqykr`, plays `bvlbek`, and returns on `q.any_animation_finished`. `bvlbek` → `animation.oreville_ans.joxcyv` declares `loop:true`, `animation_length:.15` and sets both `hmhadkd67l_92f5d6` and `hmhadkja89l_92f5d6` scale to `(0,0,0)`. Other morph branches play `drqjht=yasxuh`, .7917 seconds, using many explicit face bones.

**Completion caution:** the literal `.15` blink clip declares looping while its controller uses `any_animation_finished`. This audit does not claim measured Bedrock engine behavior for that combination. The existing JumpRuntime excludes looped clips from its completion list, so reusing that rule for this blink would latch the blink state forever. Preserve the source data and disclose any future emulator convention; there is no need to solve or fake this visual behavior in the fixed-rig idle study.

The player's separately declared `blink=controller.animation.persona.blink` is not defined in this pack and is **not reachable** from `scripts.animate` through the player's controller alias graph (663 reachable aliases inspected). Other entity controllers with an alias named `blink` do not establish player behavior. Do not use the absent persona controller as source timing evidence.

### Facial keys during the autonomous gesture

`tculwn` itself has facial driver channels; it has **no `timeline` events**. Two eye-driver bones use scale keys at .0417→0, .1667→1, .6667→0, .7917→1,2.75→0,2.875→0. Their position keys shift the positive/negative eye drivers oppositely during each glance. Eyebrow-driver keys (`6q63jgok_92f5d6` and `6q63jgokja89l_92f5d6`) move vertically .5 source units during the corresponding side looks. The `4q4dghk_92f5d6` driver shifts x +1 then -1 then0. These are actual per-bone PRS curves, not independent random expression names, texture flipbook frames, or newly invented smile/frown poses.

All audited twelve-branch idle clip definitions and conditional companion clips lack timeline events. Randomization belongs to the controller's selection; facial keys belong to the chosen gesture. The evidence preserves both independently.

### Render/geometry/material/texture trace

The player includes `controller.render.oreville_ans.vmmipy` under `v.kdqvtc&&!q.is_spectator`. It uses:

- `Geometry.pfsswq` → `geometry.oreville_ans.tbsoux` in `models/entity/464e95f8.json`: **88 bones**, 64×64 UV layout, separate head-front planar face/mask parts and abstract driver bones.
- `textures=[v.tnlxsa>=2?Texture.transparent:Texture.default]`.
- `Texture.default=textures/entity/steve`: this actual PNG is not in the pack, so the base game/user skin provides it.
- `Texture.transparent=textures/oreville/ans/bge.png`: present, transparent asset, rather than a blink frame atlas.
- `Material.default=entity_alphatest`.

The `fyennh=holadk`, `xoqtsu=zwpjfo`, and `dpoyzc=ljrhsi` animations are also gated by `v.kdqvtc&&!q.is_spectator`. They transfer the abstract face-driver values through variables into render geometry: for example `fyennh` evaluates `v.pdgwcc=this<0.8;return this` on one eye-driver scale Y, `v.kjvidh` on the other, and `v.neogsx` on the face mask. `xoqtsu` stores eye/eyebrow offsets and visibility state. `dpoyzc` applies these to actual face-part positions/scales with camera-distance offsets; e.g. `3dafc72467mdd.scale = v.neogsx||(v.kjvidh&&v.pdgwcc)`. This is geometry/visibility behavior, not a simple material image switch.

The main normal third-person renderer uses `Geometry.default=geometry.humanoid.custom` and `Texture.default`, neither geometry nor Steve texture being supplied here. The Rana profile2 instead selects `Geometry.ryhgyw=geometry.oreville_ans.fhtczz` in `models/entity/464ef792.json` (28 bones) and `Texture.ryhgyw=textures/oreville/ans/nbs.png`; its source includes extra hat/eye pieces. This distinction is why pack face support does not imply the existing Blender body has that support.

### Exact native limitation and adapter boundary

The measured repository bridge contract contains exactly these13 bones: `Root,Hips,Spine,Chest,Neck,Head,UpperArm.L,ForeArm.L,UpperArm.R,ForeArm.R,WeaponCarrier,Leg.L,Leg.R`. `Head` is a single rigid cuboid. No eyelid, eye, eyebrow, mouth, face mask, or source driver bones exist. The immutable SourceChannels evaluator only samples eight body names: root/waist/body/head/arms/legs; all source facial channels are outside its sampling set. JumpRetarget maps only those body channels into the13-bone rig. `rig_limitation_evidence.json` records the contract path, names, signature and Head proxy.

Consequently the authorized single Idle study can preserve actual body/head/arm/leg motion and record omitted facial curves, but **cannot visibly reproduce source blink/expression geometry with the unchanged rig, mesh, UVs, texture and materials**. A whole-head squash, fake head nod, new eye overlay, material blink toggle or painted atlas substitute would be a new behavior/asset adapter, not literal source parity. Keep the existing face appearance and document the limitation. A separate future face adapter would need an explicitly designed native facial representation, source curve mapping, texture/skin compatibility and independent review; it is outside this study.

## Evidence and verification scope

- `selected_player_head_face_source.json`: exact selected player aliases, controllers, full clips, pre-animation scripts, geometry, render controllers, material definitions, settings and source pack SHA256.
- `player_entity_pretty.json`: complete parsed player entity.
- `audit_checks.json`: graph reachability, absent persona blink, source body duplicate equality, idle lengths/loop/timeline metadata and source paths.
- `player_controller_edges.json`: resolved player-specific reachable controller edges.
- `rig_limitation_evidence.json`: actual13-bone contract and eight-channel evaluator boundary.
- `build_audit_evidence.py`: reproducible local read-only extraction/check script.
- `source_index.json`: root pack animation/controller/render/geometry index used for this audit.

These checks establish source support and adapter boundaries, not measured Minecraft runtime engine semantics or final Blender playback correctness. No claim is made that existing JumpRuntime exactly reproduces blink loop completion or every special controller branch. No repository/Godot/Blender mutation occurred.
