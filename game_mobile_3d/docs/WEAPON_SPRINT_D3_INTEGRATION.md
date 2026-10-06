# D3: sprint-driven weapon stowing

Sprint uses the controller's existing speed-selection condition: `sprint` input held with a nonzero movement vector. That condition is now published as `fast_sprinting`; weapon behavior reads it rather than detecting velocity or re-reading input. Shift alone does not sprint. Walk remains 4.25 m/s, sprint 6.25 m/s, and the existing combat walk cap remains 2.6 m/s.

The controller runs before WeaponBehavior, which runs before the gun. The current physics tick's sprint intention therefore blocks firing even while accelerating below the old 3 m/s firing threshold.

Decision priority is centralized in WeaponBehavior: disabled/dead guard, sprint -> STOWED, valid threat -> READY, otherwise the existing safe grace (1.5 seconds). Awareness continues during sprint, including the existing acquire/retain ranges; an acquired threat keeps its retain range while the weapon is physically stowed.

## Transitions

- READY + sprint: immediately request the existing Holster, bypassing safe grace.
- STOWED + sprint: no repeated request or state change.
- HOLSTERING + sprint: keep the current clip/token/time; finish normally.
- DRAWING + sprint before placeholder handoff: weapon is already on Back/Hip. Cancel Draw and invalidate its token without moving it.
- DRAWING + sprint after placeholder handoff: start normal Holster from the captured current pose, invalidating pending Draw callbacks. No reversed clip.
- Threat during sprint: update awareness but suppress Draw throughout sprint.
- Sprint ends with threat: request Draw immediately if stowed. An unfinished authored Holster completes before Draw.
- Sprint ends without threat: stay stowed.
- M4A1 and Shotgun: unchanged authored HolsterLongGun, hand -> Carrier -> BackWeaponSocket. Pistol: unchanged D0 placeholder -> HipWeaponSocket_R.
- Switching during sprint cancels the previous transport and puts the newly selected pooled weapon at its category's stow socket. No duplicates or stale carrier mounts.

READY firing remains normal outside sprint. Sprint/STOWED/DRAWING/HOLSTERING cannot fire. The existing animation writer releases the upper layer after Holster, restoring free-arm locomotion. Run clock, cadence 1.60, sockets, Hold_V2, collision, camera, firing profiles, muzzle logic, Blender sources and animation assets were not edited for D3.

The existing optional debug (`debug_visible`) now shows sprint, desired state, actual state, threat and full attachment socket name.

## Changed files

Production: `scripts/cuboid_player.gd`, `scripts/weapon_behavior.gd`.

Validation/review: `tests/validate_weapon_sprint_d3.gd`, `tests/review_weapon_sprint_d3.gd`, `tests/review_weapon_sprint_d3_controls.gd`; D0 and D2 live regression fixtures were adjusted where their old expectations conflicted with the newly requested sprint priority. Generated JSON reports and this document record results.

## Verification

Headless actual-controller input test: 1,127 checks, zero failures, all A-M cases across M4A1/Shotgun/Pistol. Root travel 0; sprint shots 0; Run clock error below 1e-16 s. Tests include Shift at rest, first acceleration tick, both Draw interruption sides, stale events, no repeated request, enemy arrival/loss, retained-range threat, movement continuity, weapon switching and disabled/dead guards.

Regression: D2 deterministic 9,088 checks; D2 live 50 checks; D0 112 checks, all zero failures. Interactive harness smoke test verifies natural READY -> sprint/back -> release/READY through real input and awareness. GPU validation passed 1,184 checks with zero failures using the mobile D3D12 renderer and the same gameplay scripts. Screenshot waits are excluded from the per-physics-tick clock measurement and stowed images wait for the normal exit blend to settle. Images confirm Carrier transport, Back/Hip attachments and restored free-arm Run; no new pose discontinuity was apparent in these sampled frames.

No new runtime warnings were observed. Existing D2 placeholder Draw and the documented brief Shotgun stock/chest overlap at Holster entry are unchanged; D3 adds no new animation or pose adjustment.

## Interactive review

Standalone harness loads the actual gameplay level, equips M4A1, and lets awareness naturally reach READY. A review-only durable non-attacking enemy follows at 3 m to keep a valid threat during repeated movement tests; automatic waves and level-up prompts are disabled only in this harness. Production scene/resources are unchanged.

Use WASD + Shift to sprint/stow, release Shift to Draw while the threat remains, T to move the review threat in/out of awareness, and the existing 1/2/3 weapon keys. READY firing uses the normal gun logic. The enemy is deliberately durable so repeated review does not remove the threat.

Entry point: `tests/review_weapon_sprint_d3.gd`. Screenshots/logs: `.validation/weapon_sprint_d3/` and `tests/d3_render_validation.log`.
