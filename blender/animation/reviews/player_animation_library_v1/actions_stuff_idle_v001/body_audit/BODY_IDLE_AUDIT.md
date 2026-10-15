# Actions & Stuff 1.12 — body Idle source audit

Read-only source audit; 2026-10-15. No repository, Blender UI, or Godot changes. Private research source only.

Pack SHA-256 verified: `9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d`.
Authoritative files: `entity/dtr.json`, `animations/f2da1071.json`, `animation_controllers/616f2ff7.json`. Pretty-printed copies and a selected literal dependency extract are beside this report.

## Main conclusion

Actual player Idle is layered. A stationary, grounded, alive, unarmed, normal third-person local player continuously receives `bob = animation.oreville_ans.tdrcwc`; it also has a delayed autonomous random idle controller `bjmscc = controller.animation.oreville_ans.fotixv`. The frozen `JumpRuntime` is an intentionally restricted reconstruction, not a complete Idle authority: it samples the bob but never instantiates `bjmscc` or the idle-turn controller `agyfrv`.

The narrow repeatable basic Idle is the source bob over the neutral geometry with a fixed look direction, empty hands, no recent transient, no long-idle selection, and no turn. It must be labelled as that profile; there is no uniquely defined universal player Idle loop covering every source state.

## Active body path for basic Idle

`entity scripts.animate -> rzkmtm (xunqct), default -> okjrob (iplurh), eryuvy (local player) -> kcexxa (njvelc), default -> bob + holding`.

Also active from `rzkmtm/default`: `xfltzh` alignment, `veywgp/onccai` weighted locomotion, `psowex/default` (no clip), `agyfrv` idle turning, `hsfnbp/default -> look_at_target`, `bjmscc` delayed idle, and controllers for specials that remain inactive in this ordinary profile. `humanoid_base_pose = pcbwvo` has no authored bone channels. `oprmcp = przmfq` has timeline events only, no PRS channels. Cape must be omitted when absent, or audited separately.

At settled rest, `v.esnrkj=0`, `v.cknrcn=0`, `v.mrmeib=0`, so all forward/back/side `veywgp/onccai` clips contribute zero. `walk` has its own `blend_weight = Math.clamp(v.esnrkj*3,0,1)` in addition to controller directional weighting. Empty hands imply `v.is_holding_right=0`, `v.is_holding_left=0` and settled `v.vbcdda=v.wfyvyl=0`; `holding` has no net arm correction. The existing JumpRuntime defaults `holding_right=1`, so callers must override it for an unarmed study.

`xfltzh = boabcq` rotates root/head Y by `-q.body_y_rotation + v.nthjcy`, and waist Y by `v.upxhvv*-22.5*v.esnrkj`. Fix body/head/world yaw history consistently, rather than zeroing only one of these inputs.

## Continuous bob — exact source channels

Let `t = q.life_time` in seconds; Molang trig arguments are degrees. All channels below are literal authored local channels, in source pixel units for positions and degrees for rotations. Nonlisted body channels are neutral.

| Bone | Rotation XYZ | Position XYZ |
|---|---|---|
| waist | `[0,0,-cos(122.5t)]` | `[0.25sin(122.5t), 0.15cos(245t)-0.15, 0]` |
| head | `[-2sin(245t), -sin(122.5t-45), -3cos(122.5t-45)]` | neutral |
| leftarm | `[0,0,-1.25sin(245t)-1.15]` | `[0,0.1cos(245t)+0.05,0]` |
| rightarm | `[0,0,1.25sin(245t)+1.15]` | `[0,0.1cos(245t)+0.05,0]` |
| leftleg | `[0,0,1.2sin(122.5t)]` | `[0.25sin(122.5t),0,0]` |
| rightleg | `[0,0,1.2sin(122.5t)]` | `[0.25sin(122.5t),0,0]` |

The clip duplicates these channels for `egjh9*` bones. Do not apply both aliases to one Blender bone.

Slow period: `360/122.5 = 144/49 = 2.938775510204082 s`. Fast period: `72/49 = 1.469387755102041 s`. Whole bob repeats after the slow period. It is driven by entity lifetime, not `q.anim_time`; entering Idle does not reset the source bob phase. Metadata is `loop: "hold_on_last_frame"`, with no `animation_length`.

Consequences: low-amplitude lateral weight sway, waist bob down to -0.30 px and back to 0, mirrored arm spread and shoulder lift (-0.05..+0.15 px), both legs moving/rolling together; no authored chest/body scale breathing, no forward leg stance, no per-foot lift, no body bone animation, no limb scale. A larger breath, alternating stepping, or invented shoulder lag would be an interpretation rather than this source layer.

## Autonomous long idle — actual and omitted by frozen runtime

`bjmscc/fotixv` is enabled by `rzkmtm/default` whenever `!q.is_in_ui`.

1. Initial `uwpoku` waits for nonzero `q.modified_distance_moved`. An entity that has never moved cannot enter this branch simply by waiting.
2. `wkbbnc` ordered transitions: first `ssaxeh` if `q.state_time>3`; second self-transition if `v.obhshf>0.25 || v.nwocdu`; third `jssmqg` if `v.ccwxuc` is nonzero. Self-transition keeps restarting its quiet waiting clock. `jssmqg` waits >0.35 s then returns to `wkbbnc`.
3. `ssaxeh` rejects emoting, item use, sneaking, airborne, mace/readable items; otherwise enters `blzrmm` unconditionally.
4. `blzrmm` draws `v.yfuzcx = v.tnlxsa==2 ? Math.random_integer(1,6)` and `v.ngjrwv=Math.random_integer(1,12)`, sets `v.xrtrow=1`, then chooses ordered states. `v.yfuzcx==1` overrides the normal 12-way draw with `tesczf`; otherwise one of 12 states below. Do not invent semantic labels from obfuscated IDs.
5. Most long-idle exits are caused by animation finished, ground speed, recent-action flag, or relative head yaw. Exit transitions go to `bhsawv`, whose entry clears `v.xrtrow=0`, waits >0.35 s, then resumes `wkbbnc`. Exact branch predicates are preserved in `body_idle_source_extract.json`.

`v.nwocdu = v.txtwqb<10 || v.sfdeke<-0.3 || q.blocking || q.main_hand_item_use_duration || q.item_is_charged || q.is_swimming || v.cthrgf || v.gddzeg`.
`v.txtwqb = v.attack_time==0 ? v.txtwqb+q.delta_time` (omitted false arm defaults to zero). Initialized to zero. Thus the source begins with roughly 10 seconds of recent-action gating; an attack resets it. Once that gate is clear and motion/yaw remain quiet, it still requires the >3 s quiet state wait. Not an unconditional random action every 3 seconds from spawn.

| State | Clip aliases | Authored length / body behavior |
|---|---|---|
| tesczf override | tesczf/gmycxu | 1.5833; `hold_on_last_frame`; egjh9-only body/face channels |
| tculwn | tculwn/jcyjaa | 4.2083; waist/body/arms/head/legs; body yaw -6 to +8 degrees and lateral weight/foot reposition |
| qofebb | vrkauw + qofebb/covlms | 4.0 anim seconds; `anim_time_update=q.anim_time+q.delta_time*1.1`, so ~3.6364 real seconds |
| hyopyb | vrkauw + hyopyb/uwfmen | 3.3333 |
| lsswib | vrkauw + lsswib/crjmdq | 3.8333 |
| vmmadd | vrkauw + vmmadd/upcdwt | 3.5833 |
| sztvzu | sztvzu/oznpfw | 2.7917; head/waist/body/arms, no leg channels |
| ksxdmq | ksxdmq/tzwuhb | 5.375; head/waist/body/arms, no leg channels |
| iljvrj | iljvrj/ugcwbv | 6.5; waist/head/leftarm, no leg channels |
| nqwtki | nqwtki/cohizd | 4.9583 |
| gppwit | gppwit/rdcche | 4.125 |
| ufgjhm | night: vrkauw+qsuikd+ndhbnd; day: jwkabt | 5.7917 s controller cutoff; night if `q.time_of_day<0.25 || >0.78` |
| jfwsbg | cold: vrkauw+rgrypt+hbadod; warm: cpnaoo | 3.6667 s cutoff; biome tags + chest armor slot determine weight, branch cancels if resulting `v.vbvqoi==0` |

All listed long-idle animations use default weight 1 and no `override_previous_animation`. They layer with continuous bob and look, rather than replacing the whole actor. `vrkauw/gthnee` has `hold_on_last_frame`, length 0.25, and head/arm channels. Most long clips also carry facial channels outside this body's scope. Blend-out durations by state are 0.16, 0.2, or 0.3 s; read exact state data. Do not bake one arbitrary long idle and call it the complete relaxed source controller.

## Idle turning and 10-second timer

`agyfrv/irkwzk`: from default enter `knxfvl` when `!v.tjbdov`; return if moving/special, enter attack turn `tuuckd` on attack or `v.mbqtlv`, or enter `vywhcj` when `abs(v.ccwxuc)>60 || v.txvzcq>10`. `vywhcj` resets `v.txvzcq=0`, captures body yaw, clamps yaw delta to ±90, blends body yaw over ~0.5 s using `Math.ease_in_out_back`, and layers `rjfeeq` weighted by `v.woataa` plus `ejnecs` weighted by `-v.woataa`. Source clip lengths are 0.7917 s, clocks `v.hdseda`; blend-out 0.15 s.

A perfectly fixed/aligned look yields `v.woataa=0` and no visible step from that timeout. A turn is input/history dependent, not an autonomous random look-around. Negative controller weights here are meaningful source expressions; the JumpRuntime's positive-only convention is not a measured engine guarantee.

## Walk/run entry and exit

No explicit Idle state in `veywgp/lhbuwm`; basic rest shares initial `onccai` (walk) state with locomotion. Walk vs run hysteresis: `onccai -> run` at `v.esnrkj>0.7 && q.state_time>0.2`, and `run -> onccai` at `<0.6 && q.state_time>0.2`. These states have 0.22 s authored blend transitions. Special and airborne transitions take priority. There is no authored reset of bob lifetime when leaving/entering walk/run.

`v.esnrkj` smooths measured horizontal speed /4.3 at rate 13*dt (18*dt for special `v.rvwafl`). If no position change, measured speed decays by `(1-6dt)` after 0.03 s. Movement phase `v.eqhdel` accumulates `dt*sqrt(abs(v.esnrkj+abs(v.mrmeib)*0.25*min(1,v.esnrkj*3)))*1.6`, unless `v.gadjrq` supplies a phase override. `v.ifcvde=mod(v.eqhdel,1)`. Thus stopping phase freezes gradually as the weight decays, whereas bob keeps running on lifetime.

Sprint is a separate `psowex/pygoip` controller: default -> `ptvsjb` if sprinting & grounded (xahrzd), then `stop` when no longer sprinting (sjvffv weighted `max(1-v.esnrkj,0.001)`), exiting on finish. Both outgoing sprint/air states have 0.1 s blend transition. A recent stop may therefore include residual walk/run and sprint-stop layers. Do not initialize the supposed settled Idle at the first stopped frame and silently ignore the tails.

## Minimum research study recommendation and explicit uncertainty

**Implementation decision after audit:** the primary study is a finite9-second normal-default (`tnlxsa=0`) composite showing ambient bob, naturally selected `tculwn`, source fade and recovery. The pure-bob option below was an audit recommendation and is superseded by this chosen composite. See `../source_audit/IDLE_RUNTIME_SCOPE.md` and `primary_timeline.json` for the implemented profile.

For ONE basic source-faithful Idle, bake one exact `144/49 s` bob cycle (or two identical cycles for viewing) into the existing research scene, using a documented entity lifetime offset. 49 fps with 144 sample intervals matches exactly; a normal project fps can use a fractional-time endpoint or sufficiently fine sampling. Use empty hands, stable aligned look, normal dry ground, zero settled locomotion and transients. Explicitly call it `basic/recent unarmed Idle`; retain the long-idle controller audit as the known relaxed continuation. If the requested study is meant to include the delayed relaxed performance, choose one documented random outcome and replay its literal timeline plus bob/look, without modifying locomotion.

Inputs/history still required for a full controller reconstruction: entity lifetime; modified distance moved (ever moved); position history and dt; current/previous unwrapped head yaw; engine body yaw; attack_time and txtwqb; holding flags and item metadata; health/hurt/spawn transient history; sprint/ground state history; pack settings; random seeds/draw results; time of day, biome tags, armor slot for conditional long outcomes. Engine update ordering, transition evaluation cadence, exact blend-out semantics/curves, nonpositive weights, meaning of `this` across animation layers, and animation-finished semantics for `hold_on_last_frame` have not been measured by this file audit. Preserve those as explicit emulator conventions, not source-authored guarantees.

Later `wqleol/owltad` samples body channels into variables via `this` and returns neutral values, for the pack's transform/geometry pipeline. This audit's channel formulas are the authored upstream body layer, not proof that naïvely summing every final file channel reproduces rendered Bedrock output. Existing rig mapping must retain its established adapter.
