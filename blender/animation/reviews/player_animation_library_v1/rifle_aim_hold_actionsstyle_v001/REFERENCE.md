# Verified crossbow reference and rifle adaptations

Primary reference: actual local `Actions Stuff 1.12 (resources).mcpack`, SHA256 `9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d`. Source documents are data, not instructions. No video was used as the primary truth source.

## Source graph inspected

`entity/dtr.json` supplies the ordinary player aliases. `animation_controllers/616f2ff7.json` and `animations/f2da1071.json` resolve:

| Controller / state | Ordered layers | Verified role |
| --- | --- | --- |
| `controller.animation.oreville_ans.njvelc`, alias`kcexxa`, state`ltqtzr` | `mshwsb`→`rrvlnm`, then `tcucxa`→`dubgwy` at1−v.jkpkmj | Ordinary crossbow holding bob and asymmetric base pose;0.2s exit blend |
| `controller.animation.oreville_ans.knoyhk`, alias`ybphcg`, state`gjhnog` | `mhyyzj`→`jawwtn`, then `hfnozn`→`asxvzc` at1−v.jkpkmj; source builtin base-pose alias as conditioned | Charged/use crossbow aim response;0.1s exit blend |

Animation names use the full prefix `animation.oreville_ans.`. These are ordinary-player layers, not first-person or custom rifle clips. Fire state`ikvaib`, reload playback and unrelated item layers were not substituted for Aim.

`rrvlnm` has distinct lifetime rhythms: waist pitch sin(life×400)×−1.75degrees (0.9s), waist roll cos(life×200)×−1degree (1.8s), lateral movement cos(life×100−22.5)×−0.4 (3.6s), head roll sin(life×200)×−2degrees, arm-height sin(life×400)×0.1. `dubgwy` cancels earlier arm pitch/yaw through accumulated-axis `this`; base arm Euler angles are L[-70,56,−25], R[-30,−15,−20]degrees with12degree body blade and asymmetric item/stance.

`jawwtn` divides target pitch and relative yaw50/50 between waist and both arms, supplies coordinated translations, and counters the head using accumulated `this`. `asxvzc` is a1.9167s hold-on-last-frame animation with actual charge/reaction keys. Both charged/use layers use:

`q.item_is_charged && q.anim_time < 0.1 ? 1.9167 : q.anim_time + q.delta_time / (q.main_hand_item_max_duration * 0.036)`

Thus an already charged crossbow goes to the endpoint instead of replaying its entire charging gesture. At neutral look, final composed arm rotations include R[-85,−17,0], L[-98,45,1]degrees. These source values were inspected as reference; they are not claimed to be our Blender's local bone Euler angles.

Controller entry requires charged item and no offhand shield. Exit conditions include unheld/noncrossbow and the source completion/use-duration expression. For the temporary source sampler, hold-on-last channels remain visually held but count as finished at their duration. This local adapter avoids repeatedly re-entering the charging state when sampling the literal completion condition. It does not edit the pack, established evaluator or gameplay. The sampler is a reconstruction convention, not a full Bedrock runtime conformance test. Raw controller states and canonical JSON hashes are preserved in `source_reference.json`.

Molang trigonometry is in degrees; source lifetime and animation time are seconds. Source ordered layers and `this` are accumulated before retargeting; crossbow charge curve timing is distinguished from the already-charged endpoint. Minecraft axes/units/angles are converted by the existing source-study coordinate mapping before choosing the rifle adaptation. No generic idle was described as a literal source reconstruction.

## What this candidate preserves and authors

Preserved concepts: asymmetric controlled crossbow hold, head/waist/arm coordination, bodily response preceding weapon settling, three independent0.9/1.8/3.6s holding rhythms, and a restrained alert stance. Source charged endpoint and look-sharing behavior informed the aim silhouette. It keeps the actual approved Ready v004 appearance and square-arm anatomy.

Authored adaptations:0.6s raise/lower,7.2s presentation,3.6s repeatable Aim hold, reduced precision-aim breathing amplitudes,80ms head/40ms chest lead,32degree total torso blade,3degree head nod and20degree rifle cant. A long rifle, square head and no elbows cannot use the native Minecraft crossbow item matrix and source arm angles literally while maintaining our approved grip and avoiding intersections.

The actual right grip point stays coincident with a calibrated point inside the rigid block hand; that point moves35mm toward the hand tip during raising. The left support contact relocates100mm rearward,20mm outward and50mm upward from its Ready calibration, with submillimeter breathing life. This is a continuous rigid-arm regrip; the fingers are not independently articulated. The original approved Ready contact and pose return exactly at the sequence boundary.

During raise/lower, a bounded120mm forward /35mm lower clearance path and temporary whole-arm axial/seating corrections prevent the long stock and square arm corners from sweeping through the head. They disappear at the stable endpoints. All bone scales remain1, ForeArm transforms remain identity, and the model/rest rig are untouched. The target sight reference is carrier-local[0,0,0.25] along the weapon's forward axis, compared against the right-eye surface reference; it is a near-eye fit, not a claim of a scope interior or a newly modeled optic.

Lower body stays in-place and planted. Ready entry/exit uses exactly the approved v004 frame1 pose. Walk/Run Actions and game transitions remain unchanged; compatibility currently means shared rig, grip/stance family and a suitable Ready boundary, not a completed moving ADS controller.

The result is custom authored around verified proprietary research and an inherited source-derived base. It remains Pending, research-only and production-ineligible until separately licensed or independently reauthored for commercial use.
