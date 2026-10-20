# Actions & Stuff stationary turning — source audit and dev integration

2026-10-20. Implemented in the **existing** `res://scenes/dev/ActionsStuffWalkRunTest.tscn`. Gameplay awaits user play feedback; no new Blender Action, candidate, scene or project. Existing approved Actions remain byte-identical.

## What the pack actually does

Primary source: local **Actions Stuff1.12 (resources).mcpack**, SHA256 `9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d`. Inspected ZIP members directly, followed the entity aliases/controller references, and checked other reachable yaw/leg definitions. No video was used as truth.

| Evidence | Verified behavior |
| --- | --- |
| `entity/dtr.json`, `scripts.animate` → `rzkmtm` | Third-person, non-paperdoll, non-spectator entry. `rzkmtm` resolves to `controller.animation.oreville_ans.xunqct`. This is a direct animate entry; spear sound controllers `rzytgh/bqtrpv` are unrelated. |
| `animation_controllers/616f2ff7.json`, `xunqct.default` → `agyfrv` | Ordered after ordinary movement/sprint and before item/head layers; gated outside UI/paperdoll. `agyfrv` resolves to **`controller.animation.oreville_ans.irkwzk`**. |
| `irkwzk`: default → `knxfvl` → `vywhcj` | Stationary: turn when `abs(v.ccwxuc)>60`, or idle timer exceeds10s. Capture shortest signed difference, clamp each corrective turn to±90°. Source body yaw is `v.nthjcy`. |
| `vywhcj` | `v.hdseda` advances; body yaw uses `Math.ease_in_out_back(...,clamp(hdseda*2,0,1))`, reaches the target in0.5s with overshoot. Weighted layers: `rjfeeq:v.woataa`, `ejnecs:-v.woataa`. Finish after0.7917s, interrupt on movement, or chain after0.5s if remaining gap>60°. Outgoing blend0.15s. |
| `animations/f2da1071.json`, `rjfeeq` → **`animation.oreville_ans.eyrmmr`**, `ejnecs` → **`animation.oreville_ans.eaqdwo`** | Two real non-looping0.7917s corrective clips. Local clock is `v.hdseda`; small per-degree PRS values receive the signed controller magnitude. Leading leg lifts first, opposite leg follows. Retain numeric timestamps, pre/post values and Catmull-Rom, not a synthesized walk loop. |
| Same clips | Waist dip/roll and head reactions accompany opposite leg corrections. For example, leading lift key0.0833 has positionY0.015; leading yaw key0.1667 is±0.5. They are coefficients, not final90°-turn amplitudes. At our source-unit scale0.05625m, a90° turn's lift channel alone peaks75.94mm. Actual floor-clearance is affected by rotation/contact constraints. |
| `dtr` pre-animation27 →29 →30 | Speed/idle age, unwrapped `q.head_y_rotation(0)`, head-minus-body `ccwxuc`, gait/direction filters. Moving body follows unwrapped look at12×dt; standing body is updated by `irkwzk`. Look yaw is clamped/smoothed near±90°. No gait reset on ordinary heading changes. |
| Root layer `xfltzh` → `boabcq`; `look_at_target` → `cndmcx` | Source cancels `q.body_y_rotation` against authored `nthjcy`; head uses entity-relative look. Pack animation layers and Bedrock rotation queries cooperate. Engine mouse/body/query behavior itself is absent from the resource pack. |
| `ybphcg` → `knoyhk.gjhnog` → `mhyyzj` / `jawwtn` | Charged crossbow hold layers head/body difference across waist and arms (half-yaw terms, pitch compensation). This branch **does not set `mbqtlv`**, so ordinary corrective footwork remains available. |
| `irkwzk.tuuckd` | Attack/`mbqtlv` shortcut: full wrapped turn, cubic-out0.333s heading response,0.5s state, no corrective clips. `mbqtlv` is set by bow, water-trident and generic long-use branches; it is not a universal crossbow-aim flag. Automatic rifle shots are not misrepresented as Bedrock melee `attack_time`. |

**Conclusion:** There are dedicated additive left/right corrective animation clips driven by a stationary-turn controller, combined with Bedrock look/rotation queries and other layers. There is no single universal standalone Turn-in-Place Action, and this is not solely a rigid Bedrock body rotation. The earlier directional study omitted `agyfrv`; its old “no dedicated turn” conclusion was incomplete. No foot-contact memory/IK solver was found in these resource definitions.

Exact compact excerpts: [source_evidence.json](../../../../game_mobile_3d/scenes/dev/actions_stuff_research/turn_in_place_v001/source_evidence.json). Compiled runtime subset is43KB; readable evidence59KB. No full pack/index is committed. Rebuild both with Python3, from repo root:

```sh
python3 game_mobile_3d/scenes/dev/actions_stuff_research/turn_in_place_v001/extract_source.py "/path/to/Actions Stuff 1.12 (resources).mcpack"
```

The extractor verifies the pack hash and reuses the existing audited Molang parser. It preserves both original source clips; duplicated alternate-geometry bone names are excluded from the current normal rig profile.

## Godot reconstruction and declared adaptations

- Reuse the existing Molang VM, generic controller execution and source Catmull sampler. Run the literal `irkwzk` state records with the relevant pre29 head-unwrap relationship; leave the actual locomotion/gait runtime authoritative. Substep at60Hz for30/60Hz callers. Moving/airborne intent interrupts immediately and fades corrective layers over the source0.15s; movement velocity is never delayed.
- Godot supplies intentional look separately from actual body yaw. **Q/C** slew the standing look left/right at135°/s; look acquisition is bounded at6rad/s. These are input/query adapters, not source keyboard settings. Existing auto-aim supplies look while a live target is selected. Manual turning works in Ready or Aim without a selected auto-target. WASD remains authoritative for travel; RMB drag remains camera orbit and does not directly turn the player.
- Apply the source waist/head/leg deltas to the existing approved rifle Idle/gait family. The source's independent legs remain compensated against waist motion in the native hierarchy. Preserve existing contact anchors and rigid leg solver; release the leading foot first and the trailing foot second, using windows around the authored lifts. This ground-contact policy is our adaptation, not source IK. Once turn keys settle, retain the approved Idle's lateral-foot release; a residual look angle must not pin its weight shift. Ignore zero-amplitude timeout clips for foot eligibility, preventing artificial walking every10s.
- Godot's Visual node carries the authored body heading, replacing Bedrock's root cancellation. Ready uses head-led yaw and half-yaw torso/shoulder response. Preserve the approved straight arms, lowered shoulder fit, rifle/right attachment, left support and base7° lean. Independently applying the source turn's arm offsets would break the approved rifle grip; carry both arms and rifle coherently through the existing torso/aim frame instead. Source head/waist accents remain additive; no new arm/recoil animation is authored.
- Keep existing auto-aim alignment/fire gating, actual muzzle rays and recoil order. At rest within the source60° head/body zone, allow the common aiming frame a75° **3D** cone, reserving15° for native rifle offset, vertical pitch and close-range parallax. The previous60° total cone could permanently starve firing at a57° target. Moving/airborne acquisition retains its60° bound and previous facing. This additional cone allowance is a rifle adapter, not an Actions & Stuff rule.
- Source easing names/timing and overshoot intent are retained. [Microsoft documents Back/Cubic easing semantics](https://learn.microsoft.com/en-us/minecraft/creator/reference/content/molangreference/examples/molangconcepts/mathfunctions?view=minecraft-bedrock-stable), but publishes no Back coefficient or closed-engine rotation implementation. The VM uses standard Back coefficient1.70158×1.525 and cubic-out math. Positive-only, unnormalized clip contribution follows the existing research convention. Exact engine coefficient, negative-weight implementation and query evaluation order cannot be certified from the pack alone; do not claim frame-identical Bedrock playback.

A gradual90° look request can trigger its step as soon as the gap exceeds60°, then leave a smaller head/body difference. Our bounded-look tests produce about63° body correction for a90° request and153° for180°; the remaining angle is purposeful upper-body look, not a failed target. Instant source-controller180° tests chain two90° steps. No gait clock reset, generic walking-in-place, new scene or new Blender Action is introduced.

## Checks and review

`test_turn_source.gd`: small25°, left/right90°,180°, alternating turns, literal dwell/step chaining, movement interruption and stationary gait continuity at30/60Hz.

`test_turn_gameplay.gd`: exact source lift/yaw keys and curved interpolation,12s zero-turn idle, small/head-led turns, left/right/180° footwork, rapid alternation, Ready/Aim, immediate Walk/Run, Q/C release/focus/orbit separation, actual close-range firing and hand/foot contacts at30/60Hz. Planted turn contacts drift below0.0001mm; grip/support error below0.001mm. Free-foot motion is intentionally quick in the source clips; it is not constrained as a planted foot.

Existing continuous-fire30/60, automatic target/LOS/death/approaching encounter30/60 and camera30/60 regressions pass. Infinite6Hz fire,2.70/~7.55m/s, approved animation1× and jump/camera parameters remain. Native Metal Mobile captures at30/60FPS exercise manual turns, Aim, auto-target combat/recoil, Run and Jump/Landing with source footsteps. Numeric reports are saved alongside this README.

The combined native move/jump/stop sequence has one8.64mm replant adjustment from the inherited140mm contact-safety cap; foot yaw stays within0.02° per planted sample. The isolated turn tests have no such slip. Do not remove that protective cap or claim perfect all-terrain contact. Flat research floor only; no phone performance certification. Native physics timing measures desktop auto-aim/player/fire work between priority−2 and+2, excluding the later zombie pass and rendering; it is not total mobile frame time.

Run checks with Godot4.7.2, e.g.:

```sh
Godot --headless --path game_mobile_3d --audio-driver Dummy --script res://scenes/dev/actions_stuff_research/tests/test_turn_gameplay.gd -- --silent-review 30
Godot --headless --path game_mobile_3d --audio-driver Dummy --script res://scenes/dev/actions_stuff_research/tests/test_turn_gameplay.gd -- --silent-review 60
```

For native capture, use `turn_in_place_v001/capture_review.gd` with `--fixed-fps 30` or60, `--write-movie /outside-git/review.avi`, `--audio-driver Dummy`, user args `-- /outside-git 30 --silent-review` (or60). Raw AVI/PNG sequences stay outside Git; compact reports and selected stills stay here. User gameplay launches normally with audio.

**Preservation:** see `preservation.json`. Approved Blender sources/Showcases, all animation libraries/profiles, weapon model, movement/physics settings, camera, original zombie death-physics implementation and WorldMap remain exact. Only existing research rifle visual, scene input/HUD and Molang math adapter are modified; new turn code/data/tests are under the already export-excluded research root. No Git history/tracking/LFS changes or manual push.
