# Weapon handling

Labels: **S** verified pack source; **O** observed pixels; **A** project adapter; **P** original proposal; **U** unknown. A source mechanism provides a reference ingredient, not approval to copy its performance. Use [rig constraints](RIG_CONSTRAINTS.md), [approved references](APPROVED_REFERENCES.md) and the [authoring workflow](AUTHORING_WORKFLOW.md).

## Source scope

**S:** player third-person attacks run through `dtr → xunqct → camimd`; `pwqhcf` is first-person. Riding, offhand use and item tags select different variants. Resolve the complete path before sampling. [Sword/scope](SOURCE_EVIDENCE.md#c01), [held layers](SOURCE_EVIDENCE.md#c06). **U:** a source crossbow pose does not establish a compatible rifle grip or exact final world-space hand angle.

## Fit the selected weapon

**A:** documented Rifle Stylized V2 dimensions are **1.200 × .093 × .3618 m**; Sand Block V1 is **1.205 × .119 × .4298 m** (length/width/height). These are historical asset measurements, not a fresh native audit. Read the [V2 attachment contract](../../../blender/weapons/rifle_stylized_v2/godot_integration/README.md) or [Sand Block guide](../../../blender/weapons/rifle_sand_block_v1/README.md). Keep their distinct geometry, muzzle, sights and source markers; no scaling individual axes to hide a bad fit.

**A/P:** retain RightHandGrip, LeftHandGuide, Muzzle, AimReference, RecoilPivot and HolsterAttach. Evaluate both palms and the weapon together through the entire clip. The longer barrel changes obstacle clearance even when grip markers agree. Literal source crossbow placement missed the previous rifle support point by **244.4 mm**; moving only the support arm would change the declared reconstruction. [Crossbow evidence](SOURCE_EVIDENCE.md#c06).

**U/P:** this audit establishes no selected GAF sword/axe/spear/hammer dimensions or grip layout. Measure the actual asset, pivot, blade/head endpoint, hand spacing and swept volume before authoring. Use a shared rigid holding frame for two hands; preserve full straight arms. Change the original pose to fit the asset, with the adapter disclosed; never alter approved geometry or invent elbows.

## Give each weapon a readable character

Every personality below is **P**, informed by the linked **S** mechanism.

| Weapon | Use | Avoid |
|---|---|---|
| Sword — precise, flowing | Distinct directional silhouettes and torso-led follow-through; source has three grounded attack variants. [C01](SOURCE_EVIDENCE.md#c01) | Treating each slash as a mirrored arm swing or source minimum re-entry delay as a damage window. |
| Axe — committed, head-heavy | Clear loading, fast release and longer settling; source separates grounded, airborne and offhand/riding variants. [C02](SOURCE_EVIDENCE.md#c02) | Same recovery for every context; losing the planted support during a large shoulder arc. |
| Spear — directed, braced | Readable point alignment, retractable reach and stable grip; distinguish jab from sustained use. [C04](SOURCE_EVIDENCE.md#c04) | Sliding hands, telescoping shafts, or assuming a thrust sound means contact. |
| Hammer — deliberate, weighty | Original head-led arcs and receiving compression; verified mace falling/recovery is an analogy. [C03](SOURCE_EVIDENCE.md#c03) | Calling a custom hammer/slam a literal pack action. |
| Rifle — coordinated, alert | Both arms and rifle share a coherent brace, with controlled aim/recoil. [C06](SOURCE_EVIDENCE.md#c06) | Independent arm sway breaking support; transferring crossbow clocks into automatic-fire cadence. |
| Shield — protective | Preserve blocking visibility, item clearance and free-hand ownership. [C06](SOURCE_EVIDENCE.md#c06) | Claiming source blocking supplies timed parry, invulnerability or riposte. |

**P:** review normal-speed front/side/gameplay pixels, muzzle/edge clearance and moving contacts. Label inspected pixels **O** and state their scope; numerical marker equality alone does not certify surface contact.
