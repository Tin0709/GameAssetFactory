# Rifle gameplay decisions

## Infinite ammunition — permanent user decision, 2026-10-20

The rifle has **infinite ammo**. Do not add magazine depletion, reserve-ammo limits, reload mechanics, reload animations or reload interruptions. Continuous held firing is limited by a controlled fire interval, not ammunition. Retain responsive movement and the approved weapon/contact/camera behaviour. Future authorized rifle work follows this rule unless the user explicitly changes it.

The current implementation is confined to the existing `res://scenes/dev/ActionsStuffWalkRunTest.tscn`; production WorldMap is unchanged. Hold E raises Aim, then fires only once the Aim pose is fully raised; releasing E stops fire and lowers the weapon unless RMB separately holds Aim. LMB does not fire. RMB still aims/orbits; R resets. Current dev cadence is6Hz/360RPM to preserve the complete approved recoil recovery, while Walk2.70/Run~7.55m/s and physics/camera remain unchanged. Reuse existing combat feedback and bounded pools; avoid per-shot object construction, frame-stall shot backlogs and cumulative pose offsets.

Read `docs/animation/reviews/rifle_continuous_fire_v001/README.md` for the accepted source hashes, adapter, tests and limitations. The research export exclusion remains mandatory; this does not authorize proprietary source data in commercial production.

## Research auto-aim — user request,2026-10-20

In the SAME dev scene, E or RMB Aim selects the nearest living unobstructed zombie within rifle15m range. Use the existing encounter registry, no global per-frame group allocation or alternate combat/projectile system. Retain the current visible target when it is within20cm of the closest (nearly equal melee distances); switch on death, obstruction, range loss or a meaningfully closer target. Do not lock a target indefinitely.

Character facing follows the target while Aim is requested; WASD travel velocity/speeds/jump remain responsive. Outside Aim, normal movement facing resumes. A common bounded Spine frame carries the existing approved complete hold and source recoil, preserving hand/weapon contacts and head lean. Calculate tracking before recoil so auto-aim does not cancel the approved kick. Real muzzle direction still drives real swept projectiles; initial acquisition/large turns wait for actual barrel alignment. No invisible bullet redirection or homing. Preserve6Hz minimum shot spacing, infinity/no reload, research-only export exclusion, WorldMap and approved source data. See the auto-aim/camera review README for checks and adapters.


## Research stationary turning —2026-10-20

In the existing dev scene, Q/C intentionally turn standing look left/right; they work in Ready or Aim when auto-aim has no selected target. A selected nearest-zombie target supplies look instead. RMB camera orbit stays observational. Small adjustments lead with head/torso; the verified source controller starts actual left/right corrective clips beyond60deg head/body mismatch, caps each step at90deg and permits chaining. Movement interrupts footwork immediately and retains the existing gait cursor; no artificial stationary walking loop. The two-hand rifle assembly and approved base7deg lean remain coordinated under the existing aiming frame.

The native rifle needs a75deg total common-frame cone at rest within the source60deg yaw zone, allowing pitch and close-range muzzle parallax. Otherwise an in-zone target can permanently saturate the previous60deg total cone and block firing. Moving/airborne facing/bounds, actual projectiles,6Hz/infinite fire and all approved source clips remain. Source evidence, declared input/rig/easing/contact adapters and30/60FPS checks: [turn-in-place audit](../animation/reviews/turn_in_place_v001/README.md). Research-only; WorldMap is unchanged.


## Close combat and E turn priority —2026-10-20

User explicitly requests near-immediate E turnaround when chased from behind. Held E now prioritizes a bounded fast combat pivot for large standing acquisitions (>45deg, latched until aligned;180deg in0.10s), while small tracking retains stable feet and faster40/s common-frame acquisition; the approved0.24s Aim raise,6Hz rate, recoil, grip and movement remain. Old foot anchors release for the brief pivot, then replant; gait clocks do not reset. Q/C and RMB aim-only retain the observed source-turn path. This is an intentional gameplay adapter, not an undocumented Actions & Stuff animation.

Zombie melee is now close enough for visible hand/body contact. When a target overlaps the gun, the actual grip-to-muzzle segment can hit its collider before a forward projectile exists. Reuse existing swept-ray damage/impact/audio and fixed pools, with inside hits enabled. Auto-aim readiness accepts this actual selected-target contact when its center is behind the muzzle; do not redirect bullets backwards or grant remote hits. Details/tests: [close combat review](../animation/reviews/zombie_contact_weight_quickturn_v001/README.md).
