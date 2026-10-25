# Combat animation design

Labels: **S** verified source; **O** observed pixels; **A** project adapter; **P** original proposal; **U** unknown. Use for future authorized work. Preserve [rig constraints](RIG_CONSTRAINTS.md), [weapon contracts](WEAPON_HANDLING.md) and [approval boundaries](APPROVED_REFERENCES.md).

## Give contact one authority

**S:** `variable.attack_time` is engine swing progress. Source animation seconds, controller state time, cooldown seconds and presentation-event timestamps are different clocks. Spear swing sounds follow a timeline variable; hit sounds react to `ticks_since_last_kinetic_weapon_hit`. Neither schedules damage. [C09](SOURCE_EVIDENCE.md#c09).

**P:** specify original anticipation, active contact, follow-through and recovery. Gameplay owns collision, damage, range, targets, invulnerability, costs and interruption; animation/effects display the decision. Author contact against actual weapon/target geometry, not an undocumented source damage frame. Never transplant complete proprietary curves into original production motion.

**O → P:** the inspected Dungeons II footage emphasizes readable directional silhouettes and concentrated effect bursts at gameplay distance. Use these as artistic references; cuts, obscuration and small actor pixels do not establish exact contact timing or engine mechanics. See [video provenance and limits](SOURCE_EVIDENCE.md#visual-references-and-limits).

For the researched public footage and a detailed **original** three-hit sword brief, use [MD2 Phase2](MD2_COMBAT_ANIMATION_RESEARCH.md), its [frame analyses](MD2_COMBAT_FRAME_ANALYSES.md) and the [melee framework](ORIGINAL_MELEE_COMBO_FRAMEWORK.md). Unverified weapon identity and censored timing remain explicit; this is not an MD2 asset reconstruction.

## Action families

All new choreography, timings and gameplay contracts remain **P** until implemented and reviewed.

| Family | Use | Avoid |
|---|---|---|
| Ready / recovery | **S:** held-item and item-use layers are distinct. **P:** define a stable entry stance, attention direction, weapon clearance and a recoverable exit velocity. [C06](SOURCE_EVIDENCE.md#c06) | Resetting every attack to neutral; treating an approved rifle Ready as universal melee posture. |
| Sword / axe / spear attack | **S:** distinct grounded/contextual variants and spear jab/use exist. **P:** show reach, loading and return through whole rigid limbs, torso and support. [C01](SOURCE_EVIDENCE.md#c01), [C02](SOURCE_EVIDENCE.md#c02), [C04](SOURCE_EVIDENCE.md#c04) | One swing for every weapon; stretching limbs or separating hands from a two-hand shaft. |
| Combos | **S:** grounded sword states chain with new attacks after ≥.3 s; axe uses other gates. **P:** specify original input buffering, maximum continuation window, branch choice, cancel rules and recovery. [C01](SOURCE_EVIDENCE.md#c01), [C02](SOURCE_EVIDENCE.md#c02) | Calling a minimum state-time test a complete combo system or hit-confirm rule. |
| Spin attack | **U:** no dedicated player spin established in audited paths. **P:** design readable loading, a continuous rotation path, support change and controlled stopping; validate swept weapon volume. [C09](SOURCE_EVIDENCE.md#c09) | Claiming literal source choreography; conflicting animation yaw and controller facing. |
| Dash / dash strike | **S:** verified dash examples belong to camel/nautilus. **P:** movement owns travel; animation explains launch, brace and braking, including blocked travel. [C09](SOURCE_EVIDENCE.md#c09) | Retargeting a mob dash as proven player behavior; baking duplicate world travel. |
| Jump attack | **S:** axe has airborne variants; mace responds to falling context. **P:** define launch, air ownership, attack interruption and actual landing response. [C02](SOURCE_EVIDENCE.md#c02), [C03](SOURCE_EVIDENCE.md#c03) | Midair ground compression, invented knees, or a fixed landing pose before floor contact. |
| Hammer / slam | **S:** mace falling and recovery provide an analogy. **P:** make original heavy preparation, descending silhouette, receiving compression and rebound; gameplay decides contact/radius. [C03](SOURCE_EVIDENCE.md#c03) | Assuming the source provides a custom hammer, radial damage, shockwave or camera shake. |
| Block / parry | **S:** shield branches follow `q.blocking`. **P:** distinguish held defense from a separately specified timed parry, success reaction and optional riposte. [C06](SOURCE_EVIDENCE.md#c06) | Inferring perfect-block timing, stun or invulnerability from a shield pose. |
| Hurt / hit response | **S:** player Hurt exists; audited zombie has color/sound without skeletal Hurt; other mobs differ. **P:** choose directional response, retrigger policy and upper/lower-body ownership. [C05](SOURCE_EVIDENCE.md#c05), [C07](SOURCE_EVIDENCE.md#c07), [C08](SOURCE_EVIDENCE.md#c08) | Fabricating a zombie source clip or making every hit restart locomotion. |
| Knockback / death | **P/A:** gameplay/physics owns displacement and impulse; animation explains local recoil or yields to the declared death system. **S:** player procedural root death and mob-specific death clips are separate evidence. [C05](SOURCE_EVIDENCE.md#c05), [C08](SOURCE_EVIDENCE.md#c08) | Deriving knockback strength from a torso angle; running competing pose and ragdoll writers. |
| Special ability | **P:** name its purpose, preparation, targeting, travel, contact, cost, cancellation and recovery before posing. **U:** generic labels do not establish a source equivalent. [C09](SOURCE_EVIDENCE.md#c09) | Adding unverified damage/VFX rules because a reference looks powerful. |

## Prove the assembled behavior

**P:** test miss/hit, travel, blocked reach, interruption and repeat input. Preserve support or release/replant it. Verify final composed contacts at relevant frame rates. Record inspected normal-speed gameplay as **O**; label Blender-only evidence. Follow the [workflow](AUTHORING_WORKFLOW.md) for Pending registration and preservation. Technical correctness, artistic approval and production eligibility remain separate.
