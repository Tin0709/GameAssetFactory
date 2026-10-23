# Action-to-action transitions

**S** source verified; **A** project adaptation; **P** original design; **U** unknown. These rules connect expressive poses to responsive gameplay; no single blend duration solves every boundary.

## Verified mechanisms

**S:** Ground locomotion shares `eqhdel`, speed hysteresis and contextual directional weights; the source is not eight clips restarted on input edges. Ordinary ground fades are .22s, while other states use sampled non-linear fade tables. Pre-animation order is significant. [P01–P03](SOURCE_EVIDENCE.md#p02)

**S:** Sprint jump selects one of two phases, advances local event clocks and reseeds shared gait to .05/.55 at handoff. Landing can coexist with other motion and be interrupted by a new jump; moving Landing omits arms/legs. [P05/P06](SOURCE_EVIDENCE.md#p05) These mechanisms support phase-aware transitions; they do not establish a universal foot-contact solver.

**S:** Third-person sword states cycle through three branches with a .3s minimum repeat gate, different .075–.15s fades and an air/riding exception. [C01](SOURCE_EVIDENCE.md#c01) This establishes presentation sequencing, not input buffering, hit confirms or gameplay cancel windows. Source weapon-ready/use/release layers also have independent clocks and contexts. [C06](SOURCE_EVIDENCE.md#c06)

## Author an explicit contract

For each new action record the following **P** design decisions before keying:

| Boundary | Required contract |
|---|---|
| Idle/Walk/Run → action | Current pose/velocity, support side, intended facing, grip and persistent gait clock. Prefer compatible support; release an unreachable anchor before replanting. |
| Wind-up → contact | Named original event time/range, blade or muzzle geometry, target reach and damage-system ownership. Cosmetic source events are not hit authority. |
| Contact → recovery | Preserve velocity intent, reduce amplitude deliberately and end in a usable guard/stance. A missed strike still has recovery. |
| Attack → next combo link | Allowed input time, buffer expiry, hit/miss behavior, entry pose/velocity and lower-body ownership. Do not equate clip end with input permission. |
| Attack → locomotion/block/hurt/jump | Explicit interrupt policy, pose handoff, event cancellation and physical travel owner. No invisible damage after a canceled strike. |
| Aim/fire repeat → Aim | Restore prior overlays before evaluating base, apply each event delta once, retain gun/hand coherence; no cumulative offsets. |
| Stop/reverse → next step | Hold reachable contact or release intentionally; do not restart gait, queue obligatory extra foot exchanges or rotate a locked sole indefinitely. |

**A:** Existing rifle distance-calibrated phase, tiny-tap contact retention, .14s speed-derived Run blend, .24s Aim and .60s held-E 180° turn belong to the accepted lab architecture. Preserve them unless the task requests changes. Source Walk normalized speed would otherwise keep Run above its literal exit threshold. [Godot](GODOT_INTEGRATION.md)

Evaluate the **final composed pose**, including weapon and presentation interpolation. Pose continuity and velocity continuity are separate; a matching endpoint can still jerk. Use quaternion hemisphere continuity and semantic phase correspondence where appropriate, without altering source reconstruction keys.

Test both leads at 30/60FPS: small tap, diagonal change, 90°/180° reversal, rapid alternating inputs, run-release, Aim entry/release, immediate fire, repeated events, moving jump and landing interruption. Test input latency as well as contacts/grips. Preserve source and physics timing authority; never fix a visual boundary by delaying accepted controls without an explicit gameplay decision.
