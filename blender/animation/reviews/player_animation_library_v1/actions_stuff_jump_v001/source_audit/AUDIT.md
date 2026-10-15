# Actions & Stuff1.12 player Jump / Landing source audit

Archive and source-file hashes are in provenance.json. The archive is read as data. No existing repository, Blender or Godot file was modified.

Exact primary files: entity/dtr.json; animations/f2da1071.json; animation_controllers/616f2ff7.json. all_controllers.json contains all archive controllers (many belong to OTHER ENTITIES). Never choose a controller merely because it references alias `jump` or `fall`: aliases are entity-specific.

## Player source chain and layer order

scripts.animate → `rzkmtm`/xunqct (third person, nonpaperdoll, nonspectator), default (alive, unmounted, not sleeping) executes xfltzh root orientation, cape, movement offset, flkskc, veywgp locomotion, psowex sprint/stop, other conditional layers, okjrob local/remote dispatcher, then look.

okjrob/iplurh selects local `eryuvy` or remote `hgnodg`. Local ordered children: **pyhwuc/tjytvl landing → ngeixo/lfjeov jump → muiqdc/quiyxu fall → kcexxa/njvelc bob and holding → offhand**. These are simultaneous layers, not an exclusive jump→fall→landing state sequence. Top locomotion and sprint/stop run before these children. The simple implementation supports normal local type2, dry, no interactions or special settings; remote player and special roll/dive/vault/ledge/gravity variants are preserved in raw evidence only.

Exact snapshot ordering is an explicit simulation convention. Runtime has not been measured against a Bedrock VM frame trace.

## Exact principal clips

|Alias|Animation ID suffix|Length|Actual use|
|---|---|---:|---|
|jump|mykcsi|1.1667|ordinary ascent impulse|
|wxzmsp|bevrbk|1.5833|sprint jump A, ypqtmb|
|rnmred|nvxqkp|1.5833|sprint jump B, seridw|
|fall|dwzzez|3.5, hold_on_last_frame|descent additive pose|
|ydsari|xvdslp|1|LOCAL stationary landing|
|srluww|jmjgft|.75|LOCAL moving landing|
|yytrhz|lyflxw|1|REMOTE stationary landing; do not use for local|
|xahrzd|ucaryc|1.25, hold_on_last_frame|ground sprint onset/held posture|
|sjvffv|bxtvze|1.2083|sprint-stop response, also triggered on landing|
|wjmfbh|yrljkl|100, loop|fall flailing; own clock slows .5 in water|

Each target clip's full literal PRS keys, pre/post values, and interpolation modes are saved in `<alias>_animation.json`. Values are source units and Euler degrees; no retarget conversion has been applied. Eg offset duplicates egjh9* represent alternate geometry controls, not a second layer on ordinary BONES.

Normal Jump has source root scale(1.05,.95,1) at.0417 and separate L legY1.2/R legY1.25 at.125. These are actual deformations. Sprint A/B include rootposition(0,-4,0) at.0833, rootscale(1.015,.97,1.015), waistroll opposite signs, distinct head XYZ asymmetries. A/B are not exact mathematical mirrors. Preserve entire literal vectors.

Landing LOCAL moving srluww has headrotation -8 at.0625/.125, +11 at.25,+12 at.375,+3.13 at.5,0 at.625/.75; waistY-2.4 at.125/.25,-.4 at.4375,0 at.625; root scale(1.025,.95,1.025) at.1875,identity.4375/.625. At controllerweight.8 its contribution is correspondingly attenuated; source raw keys must remain distinguishable from mixed output.

LOCAL stationary ydsari: waistrotationX12 at.1667/.375,0 at.625/.875; waistposition(0,-4,1) at.125/.2917,(0,-.5,.25) at.5,zero.7083. HeadX-5 at.125,+15 at.2917/.4583,zero.625/.8333. ArmsX-20 at.2917/.4583; legrotationL(10,-10,1),R(10,10,-1) and legpositionsL(.5,0,-2),R(-.5,0,-2) at.125/.2917. Root scale(1.025,.95,1.025) at.1667,identity.3333/.5. Full keys include Catmull-Rom modes, not a hand-authored ease curve.

## Exact controller behavior in supported profile

ngeixo/lfjeov default tests ordered: float special; sprint+is_jumping+phase in[.1,.6]→ypqtmb; sprint+is_jumping→seridw; airborne&&(vertical_speed>0 OR in_water)→jump. Ordinary `jump` exits on grounded OR vertical_speed<-7; outgoing fade.2. Ordinary jump has NO grounded anticipation state.

ypqtmb onentry hirjne=1; uses wxzmsp. seridw onentry hirjne=2; uses rnmred. Both outgoing fade.12. Ordered ordinary exits: alternate sprint branch if state_time>.4&&vertical_speed>1&&sprinting&&airtime<1; contact when grounded&&vertical_speed>-.3&&!is_jumping→fmzeml(A)/yutray(B); ordinary jump when state_time>.3&&airtime in[.01,.15]&&is_jumping. Onexit hirjne=0 and **gadjrq=.05(A) or .55(B)**. The next pre_animation29 consumes override into eqhdel, clears gadjrq, computes ifcvde. fmzeml forces next sprint jumpB, yutray next jumpA during.35s window, then default. These are controller rules, not matching guessed foot contacts.

pyhwuc/tjytvl default→zhbjho when airborne; captures starting height lfltum. Contact first checks optional drops>3.333 for roll/heavy variants (disabled ordinary profile); then grounded&&(esnrkj>.5 OR rvwafl)&&aliveage>1→cfpejq (srluww*.8); otherwise grounded OR dead→yytrhz (ydsari*.8). Both recover until any_animation_finished; local repeat jump hirjne/is_jumping immediately interrupts into zhbjho. Outgoing blend.12. Moving landing contains no leg/arm channels, deliberately leaving those to other active layers.

muiqdc/quiyxu default→nqtrjo when airborne&&vertical_speed<-.15. Adds fall*(.5+.5*axerqj) plus wjmfbh*axerqj. axerqj is filtered clamp(-vertical_speed*.05,0,1), gain3*dt. Ordinary exit only state_time>.5&&grounded (not immediate contact), outgoing.3. Therefore jump/fall/landing may overlap.

veywgp/lhbuwm ordinary ground run/onccai first tests hirjne or special animation flags→knxfvl(no clips), then airtime>.05→zhbjho(airborne directional clips). Ground gait hysteresis: run enters above esnrkj>.7 after.2s; walk below.6 after.2s; outgoing.22. Ordinary airborne zhbjho uses pkdlkc/hnhukj/txkksi/xvsgam at same persistent phase plus fly/qbfoza terms; outgoing.16. Sprint hirjne suppression takes precedence. knxfvl exits to airborne when no flags, otherwise run once flags clear on ground; follow source transitions even if speed is low (then source hysteresis restores walk).

psowex/pygoip default→ptvsjb when sprinting&&grounded; ptvsjb xahrzd exits stop if !sprinting, ELSE zhbjho if airborne; outgoing.1. zhbjho→stop on contact, **even still sprinting**. stop uses sjvffv*max(1-esnrkj,.001), until animation finished→default. Hence minimal stop contribution at fullspeed, stronger if stopping before landing. Preserve it rather than holding sprint endpoint forever.

## Variables and clocks

Literal pre_animation27→29→30 are reused. 27 measures supplied xyz deltas/time, smooths esnrkj toward clamp(horizontal_speed/4.3,0,1) with gain13*dt (18 when special rvwafl), resets airtime hkmncu on ground via ternary default0. 29 advances eqhdel by dt*sqrt(abs(esnrkj+abs(mrmeib)*.25*min(1,esnrkj*3)))*1.6 unless gadjrq override. ifcvde=mod(eqhdel,1). Direction smoothing and heading use previous-frame direction variables in29; 30 updates local movement projection afterward. Do not reorder them.

Ground/air directional clips have anim_time_update=eqhdel, period1. Jump, sprint-jump and landing clocks are local seconds since entry; clip lengths do not define the physical trajectory. Bob uses independent q.life_time. Rootorientation uses supplied bodyyaw and derived nthjcy. Look head relative_to.rotation='entity' needs the existing retarget transform compensation; metadata is exposed by runtime. Holding uses source `this` axis attenuation at blend_weight.5; selected steady standard right1/left0 adapter matches prior directional research, not all weapon profiles.

Timeline: wxzmsp at0 sets sxqiqn=1; rnmred at0 sets ywlneb=1; both at1.5 clear hirjne. Ordinary jump at0 can set both footstep flags if supplied xyz changed>.5 from saved location. Gait oprmcp .45/.95 sets footstep flags. They are event data, not extra pose channels; runtime does not spawn particles/sounds. Loop timeline rearming is not independently verified.

## Absent / unknown behavior and proposed traces

Resource contains no authored physical world jump arc, launch impulse, standard gravity, exact grounded-contact instant, or fixed complete jump duration. pre_animation35 includes a20Hz predictive block/water probe (gravity-.08 per tick, velocity*.98), used for special fall choices; it does not implement actual engine movement. Existing controller thresholds can be exact while supplied physics remains a declared presentation trace.

Recommended exact source phase reconstructions: six independent raw source Actions (jump,wxzmsp,rnmred,fall,ydsari,srluww), each preserving all source PRS; plus a controller-composed study showing (1) stationary ordinary→stationary land, (2) walking ordinary→moving land, (3) sprintA at phase.25→moving land→Run, (4) sprintB at phase.75→moving land→Run, (5) stop during sprintair→stationary land with sprintstop, (6) repeated held sprint contact to verify alternating branch and .05/.55 overrides. Warm aliveage>1 and real virtual locomotion before each jump. Record all supplied queries. A physical preview height must be separate presentation data and labeled an assumption.

Unknown engine implementation details explicitly recorded by evaluator: uniform cardinal Catmull-Rom(.5 tension), duplicated endpoint tangent controls, nonpositive weights inactive without normalization, linear controller fades, one ordered transition per controller per sample, outgoing clocks continue through fades. These are reconstruction conventions, not claims of measured Bedrock internals. Dense240Hz sampling and exact authored breakpoint retention reduce bake error without proving those conventions match the proprietary engine.


## Primary Blockbench interpolation verification

Pinned primary source: [timeline_animators.js, lines544–555](https://github.com/JannisX11/blockbench/blob/7c92e27d237e365110030d73e92c5d1605f0d311/js/animations/timeline_animators.js#L544), [keyframe.js, getCatmullromLerp](https://github.com/JannisX11/blockbench/blob/7c92e27d237e365110030d73e92c5d1605f0d311/js/animations/keyframe.js#L227), [Bedrock importer](https://github.com/JannisX11/blockbench/blob/7c92e27d237e365110030d73e92c5d1605f0d311/js/formats/bedrock/bedrock_animation.js#L207). The importer collapses identical pre/post to one datapoint; every one of150 paired keys in the selected transient/stop clips is identical. Blockbench interpolates Catmull when either boundary key has that mode, adds adjacent point controls, evaluates THREE.SplineCurve with normalized segment alpha, and duplicates missing endpoint controls. The key timestamps do NOT introduce nonuniform tangent weighting. Exact keys are pre-side in Blockbench, but all paired keys here have equal pre/post.

An independent Node program executes those inspected primary interpolation method bodies, against4575 interior samples from six principal source clips. Maximum component error versus JumpChannels=1.4210854715202004e-14. See blockbench_parity.json and verify_blockbench_reference.js. Thus this sampler is verified against Blockbench preview for this payload; it remains unmeasured against the Bedrock engine. The earlier Catmull convention disclaimer is narrowed accordingly.

Caller `q.is_jumping` is an engine query, not established here as a physical Space-key hold flag. The scenario harness may supply it while held, but that mapping MUST be labeled an engine-input adapter. Likewise a0.6s preview airtime, any root height/world XYZ arc, and supplied vertical speed are prescribed presentation queries, not reconstructed physics or source clip duration. The query dictionary contains callables after normalization; serialize only ordinary query values or replace callables with recorded XYZ/head samples.

Local controller stepping convention: advance current/outgoing clocks and due timelines; evaluate one ordered transition; execute old on_exit then new on_entry and timestamp0 events; sample new state at0; compose in source parent layer order. Existing source phase programs run before controllers. Therefore gadjrq written by jump on_exit is consumed on the NEXT pre_animation29. No separate Bedrock VM trace is available to certify same-frame initialization/transition ordering; preserve this uncertainty in delivery.
