# Source evidence and research boundaries

Audited 2026-10-23 by reading the actual local ZIP JSON, following aliases/controllers and cross-checking project artifacts. Labels: **S** literal source; **O** viewed pixels; **A** project adapter; **P** original design; **U** unknown. A resource pack is presentation data, not a complete Bedrock engine implementation.

## Identity and reproducibility

Archive: `/Users/tin/Desktop/Game Dev/local_references/Actions Stuff 1.12 (resources).mcpack` — 33,884,235 bytes, 19,324 entries; SHA-256 `9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d`. Its manifest header says version **"1.1.60"**, minimum engine **"1.26.40"**, UUID `2cf066eb-1254-4b7d-affb-80fe3216b18c`. Preserve the discrepancy with the filename “1.12”; do not normalize it away.

The [machine index](evidence.json) pins whole-member hashes and exact RFC6901 pointers. `python3 scripts/animation_knowledge.py verify` rechecks these against the archive without extraction. This is a selected evidence register, not a complete source snapshot. To inspect a named fact follow its group below, then the machine pointer and alias target. Literal dot-containing keys remain single keys; RFC6901 escapes slashes in key names.

Notation: **E** = `entity/dtr.json#/minecraft:client_entity/description`; **C(x)** = `animation_controllers/616f2ff7.json#/animation_controllers/controller.animation.oreville_ans.x`; **A(x)** = `animations/f2da1071.json#/animations/animation.oreville_ans.x`. Resolve an animation alias through E/animations before assuming its target. Additional reachable definitions also occur in `animations/luf.json`, `luh.json`, `lwc.json`.

<a id="p01"></a>
## P01 — Player graph, ordered layers and clocks

**S:** E identifies `minecraft:player`, 682 aliases; conservative guard-agnostic reachability from animate/controller states reaches 663 aliases. This is potential reachability, not concurrent execution. Three referenced external vanilla clips remain unresolved: riding arms, UI look-at and sleeping. `kgklcq → lwc.xghxmf` has no bone channels but updates a variable through `anim_time_update`; discarding non-pose animations loses side effects. Pre-animation 27 → 29 → 30 order matters: speed, phase, then direction. Gait uses shared `eqhdel`; transient clips and lifetime bob use different clocks. **U:** not a full live-engine trace or subpack certification.

<a id="p02"></a>
## P02 — Direction, speed, cadence and hysteresis

**S:** E/pre_animation 27 filters speed; 29 advances phase from speed/lateral terms; 30 updates direction. C(lhbuwm) Walk→Run requires normalized speed >.7 and state time >.2; reverse uses <.6 and >.2. Ordinary fades are .22s. Four directional weight expressions can be negative; diagonal clips are mixtures, not eight authored diagonals. Recent combat/use/block context changes heading/direction handling. At normalized speed one, the phase expression yields forward 1.6Hz, side ~1.78885Hz, diagonal ~1.73567Hz. **A:** current GAF distance calibration, positive-only unnormalized weights and actual-speed Run classification are adapters; source normalized speed is not m/s. Some source coefficients are per-frame, so frame independence cannot be assumed globally.

<a id="p03"></a>
## P03 — Gait curves, opposition and seams

**S:** Eight looped length-one gait targets: `tldiyl`, `eaqhvv`, `fpushb`, `dfajpq` Walk; `fngydr`, `fcsrsv`, `pmgjno`, `qzziyu` Run. Plain key arrays coexist with analytic waist/torso/head expressions. Forward Run waist has unequal lower/upper branches; lateral Run uses a different shaped crest. These are multiple mechanisms, not one bounce formula. Ordinary gait keys are not all Catmull-Rom. `fpushb/dfajpq` left-leg position endpoints differ by .078 source units; value/velocity loop closure must not be assumed. Source Run leg scale reaches 1.07. **P:** new rigid originals can retain timing contrast while choosing connected, unit-scale poses and clean seams. That is an adaptation, not exact reconstruction.

<a id="p04"></a>
## P04 — Foot effects are not foot support

**S:** A(przmfq) sets foot-effect flags at .45/.95; C(ylzimv/yztvac) gates particle effects by whole-player grounding/speed. `uvoylk → A(jvdljb)` analytically projects leg helper X/Z using a 12-unit length but forces helper Y to a grounded-dependent constant. Geometry `models/entity/464e86f4.json`, geometry index302 includes helpers `d67l7gglkl6h`, `ja89l7gglkl6h` and particle locators `obbjdm`, `hgqiud`. This demonstrates effect placement, **not per-foot floor queries/load/IK**. E/pre_animation35 predicts falling using a bounded simulated probe; it does not command player gravity. **A:** final sole anchors, reach releases and floor corrections belong to GAF.

<a id="p05"></a>
## P05 — Jump/fall/landing control

**S:** Layered paths include Landing `pyhwuc/tjytvl`, Jump `ngeixo/lfjeov`, Fall `muiqdc/quiyxu`, then bob/holding and offhand layers. Ordinary Jump starts from upward airborne conditions; no mandatory grounded anticipation state was established. Sprint chooses one of two lead branches from phase [.1,.6], fades .12s and writes phase override .05/.55 at exit for the next phase update. Recontact can retain the opposite sprint branch for .35s. Landing has moving/stationary/remote distinctions, controller weight .8, .12s outgoing fades and immediate re-jump interruption. Moving/stationary source clips last .75/1s; controller conditions own exit. Fall uses vertical/filter/state-time conditions, so layers can overlap. **P:** preserve lead/support intent without imposing clip-length flight on capsule physics.

<a id="p06"></a>
## P06 — Mixed curves and non-linear fades

**S:** Jump/Landing combine plain keys and explicit Catmull-Rom; source Jump scale can reach 1.2/1.25. Moving Landing A(jmjgft) omits arms/legs, leaving concurrent layers authoritative. C(yemteq)/dvwvti contains a sampled .4s fade table; its samples resemble cubic ease-out, but the analytic curve is an interpretation. C(tjytvl) has different .3s tables. **A:** GAF explicit duplicate-endpoint Catmull treatment and controller stepping conventions are reconstruction choices where engine behavior is unresolved. Source scale exceptions do not authorize new elastic limbs.

<a id="p07"></a>
## P07 — Turning, gaze and held equipment

**S:** E/pre_animation derives head/body-relative yaw and contextual direction/heading response. Distinct gait, torso, head, held/use and bob layers cooperate. The followed player graph does **not establish a dedicated stationary corrective-footstep Turn-in-Place Action**. **U:** Bedrock entity/body yaw behavior and external primary geometry are not fully supplied by the pack. **A:** current Q/C foot correction, sole anchors and held-E turn duration are documented Godot adaptations. Head-led weight transfer is an original design goal; do not invent a source footstep clip or confuse camera orbit with intentional facing.

<a id="c01"></a>
## C01 — Third-person sword and combo sequencing

**S:** E/animate `rzkmtm` gates third-person/non-paperdoll/non-spectator → C(xunqct), whose layers dispatch movement, held equipment, attack `ptaudk → camimd`, use `ybphcg → knoyhk` and gestures. First-person `mbpzen → pwqhcf` is separate. C(camimd) sword route `fmriac → zefcct`; grounded repeats cycle `zefcct → thdqsk → eqlzfq → zefcct` after a new attack and ≥.3s state time, with an air/riding exception. Aliases resolve to A(ykmnwz) 1.0333s, A(kmahna) 1.3333s, A(mjscqu) 1s; blends differ (.115/.075/.15s). The .3s gate is **not a maximum combo window or damage frame**.

<a id="c02"></a>
## C02 — Axe contexts

**S:** C(camimd) axe route `qwqond`; grounded dxdudb branches repeat `kkyulq → A(ufbmwj)` (1.6667s), attack clock×1.2, repeat gate .375s. Air branches use `mvkirz → A(wzpxjr)` (.7917s hold); offhand/riding differs again. An `attack_time>.4` condition is normalized attack progress, not documented .4-second blade contact. **P:** heavier original load/recovery must be designed around the selected axe, not inferred universally from clip length.

<a id="c03"></a>
## C03 — Mace as heavy-weapon analogy

**S:** Mace item/tag selects distinct standing/falling states, including 1.4583/.8333s clips, .3s repeat gate, falling 1.6667s hold and weighted recovery. Source fall queries change the branch. **U:** no exact custom hammer, radial shockwave, camera shake or ground-slam damage system is established. Use this as a scoped heavy-weapon analogy; original hammer silhouette, impact and balance remain **P**.

<a id="c04"></a>
## C04 — Spear jab and sustained use

**S:** C(knoyhk)/kuyjab layers spear hold and C(cqkhdi) jabs. Jab entry uses early attack progress or cooldown ratio; repeat gating uses cooldown query/4. A(epthqa) standing and A(rqzbns) moving/air clips are nominally2s with clock multipliers1.15/1.65, so duration is not cooldown. Sustained-use nookvi adds progress-driven clips; E/animate `pjoyta → rqzpao` advances tier-dependent progress. **U:** these are not our stamina, damage, reach or invulnerability rules.

<a id="c05"></a>
## C05 — Player Hurt and death

**S:** E/animate `hgymxj → ismckx`; render-controller hurt color writes a flag, E/pre31 latches/clears it. Third-person hurt selects A(gavocc), a1s full-body reaction; first-person uses A(twrhbq) arm motion. Retrigger guard is state_time>.49; tint fades over .5s. Player death channels use death_ticks/frame_alpha and root-pivot roll. This proves a skeletal **player Hurt**, and does **not** prove a player ragdoll. Preserve source context rather than extending the zombie absence finding to all entities.

<a id="c06"></a>
## C06 — Crossbow, bow, shield and handling layers

**S:** Held crossbow routes through `okjrob → iplurh/eryuvy → kcexxa → njvelc/ltqtzr`, including bob/hold weighting. Use C(knoyhk)/gjhnog drives charging clips (1.9167s hold; charge-dependent clock). Finished and no longer charged selects ikvaib/dtfqyg → A(pomlkz), .875s release and .15s fade. Bow has different charge/release clips. Shield blocking selects distinct main/offhand held1s clips with .25s blend; first-person has separate .24/.1 blends. **A:** automatic rifle6Hz, reversible .24s Aim and custom1/6s recoil are GAF choices, not crossbow RPM. No timed perfect parry/riposte is established.

<a id="c07"></a>
## C07 — Zombie attack and hurt-color scope

**S:** `entity/dup.json` zombie attack C(aioksj) is triggered by attack_time>0, selects A(craixf) and runs in ordinary seconds (.75s) until any_animation_finished. **P interpretation:** visual arm reach around .2083–.25s is geometry-dependent, not a verified source contact or gameplay hit frame. **S:** Its traced graph has hurt-color → pre30 flag → C(nwwoke) armor sounds, with **no mapped skeletal zombie Hurt**. **A:** our bounded directional upper-body hit impulse is original; existing native ZombieDeathPhysics owns lethal physics. Do not rebuild it or claim hurt-color proves a skeletal flinch.

<a id="c08"></a>
## C08 — Other mob reactions and death

**S:** Breeze `entity/duk.json` maps Hurt A(batero), .5s, C(xjrxen) health-change trigger. Warden `dwe.json` maps A(iuyrdp), .5s through C(unxrpk) on health decrease; its attack/roar/sonic-boom context is separate. Vindicator `dwf.json` and Pillager `dto.json` have distinct attack/death graph examples, not native ragdolls. These counterexamples limit the zombie conclusion. **P:** use their reaction/recovery contrast as a reference after auditing the actual target rig/behavior; no cross-species automatic retarget assumption.

<a id="c09"></a>
## C09 — Event authority and unverified actions

**S:** A(adutle) timeline .25 sets a sound-route flag; C(ybkmlx) checks `q.ticks_since_last_kinetic_weapon_hit` for material feedback. These expose presentation events/engine hit observation, **not server hitbox or damage authority**. Official [animation-controller documentation](https://learn.microsoft.com/en-us/minecraft/creator/documents/animations/animationcontroller?view=minecraft-bedrock-stable) distinguishes resource-pack animation state logic. Player spin, dash strike, custom hammer, radial slam and timed parry were not established in the traced routes. This is scoped **U**, not a claim that no pack/entity/context contains any analogous move. Future originals must state input, contact, damage, cancel and travel ownership explicitly.

## Visual references and limits

**O, official:** Minecraft's [Dungeons II gameplay trailer article](https://www.minecraft.net/en-us/article/minecraft-dungeons-ii-gameplay-trailer) identifies the official [94s trailer](https://www.youtube.com/watch?v=vBNE3bKMpu8). Existing cached metadata records 2026-08-20, Minecraft channel; retained 4s-spaced contact sheet was inspected. Shots around36–48s show separated actors/weapons, large directional arcs and concentrated effect bursts readable at an elevated gameplay camera. Cuts/VFX obscure precise anticipation and contact; no engine implementation or measured attack duration is inferred.

**O, third-party:** [XboxDynasty gameplay](https://www.youtube.com/watch?v=mgzk7uhAfjk), cached title “Minecraft Dungeons II | Das sind die ersten 9 Minuten”, upload2026-09-28. Existing 1280×720/60FPS cached segments150–158s and220–228s were inspected at10samples/s, including wide travel/encounter context and a bright directional strike/effect near220–221s. Silhouette/effect contrast can inspire original readability. Small actor pixels, obscuration, uncalibrated original playback and possible footage edits prevent exact limb/impact/physics claims. These observations are **not A&S source evidence**.

Local research cache: `.validation/md2_grass_wind_v001/research_visual/`; it is optional/untracked and may disappear. No new media was downloaded or added to Git. Hashes below identify the retained local clips; source URLs/time ranges remain the durable route.

- `gameplay_t150_158_research.mp4`: SHA-256 `26c377bce6a0baa81d7ddb6edad7afd6edb821fd22fe1e160ceb6bc47d2ea03c`.
- `gameplay_t220_228_research.mp4`: SHA-256 `bf95610f20f07a6d270c62db69eb74eed5b61e8c98c66cdfabe93b91c93f7556`.

Older A&S walk/run/jump videos under [style references](../references/style_research_2026_10_10/media_manifest.json) remain useful visual preferences. Modded base-Minecraft clips must not be relabeled verified Dungeons II footage. GIF delay/sample rate is not engine FPS or a reliable source-contact clock.

## Earlier records and project adaptations

Use [player deep research](../ACTIONS_AND_STUFF_PLAYER_DEEP_RESEARCH.md), [local audit](../research/actions_and_stuff_deep_2026_10_14/LOCAL_AUDIT.md), [current Workflow](../ANIMATION_WORKFLOW.md), [Rig](RIG_CONSTRAINTS.md), [Godot](GODOT_INTEGRATION.md) and [Approved References](APPROVED_REFERENCES.md). Older claims are scoped to their dated inspection; direct routes above expand their combat/Hurt coverage. Do not overwrite approved source curves or repair library status drift during research. Remaining uncertainties are listed in [Gaps](GAPS_AND_DEMOS.md).


## 2026-10-25 public combat extension

[MD2 Phase2](MD2_COMBAT_ANIMATION_RESEARCH.md) adds public paused-browser observations and decoded cached gameplay with frame-zero/PTS conventions, images and uncertainty. See [frame analyses](MD2_COMBAT_FRAME_ANALYSES.md) for the distinction between visible feedback and internal damage timing. Existing A&S source pins remain unchanged; unofficial MD2 archive encryption/authenticity limitations remain intact.
