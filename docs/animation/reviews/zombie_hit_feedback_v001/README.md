# Zombie hit reaction and combat feedback — 2026-10-21

User accepts Combat Strafe as a **provisional gameplay baseline**. Its implementation is preserved exactly. This milestone changes only zombie feedback adapters loaded by the existing `res://scenes/dev/ActionsStuffWalkRunTest.tscn`; no scene, project, Blender Action or production asset was created/replaced. New feedback awaits user gameplay review.

## Source evidence and limits

Fresh direct inspection of the supplied `Actions Stuff 1.12 (resources).mcpack` (SHA256 `9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d`) resolves `entity/dup.json`, the base zombie's72 local animation/controller aliases, and its render controllers. Compared against the existing Mobs Library combat findings and exact imported Idle/Walk/Attack profile.

- `render_controllers/hbh.json`: `bkmptz` / `gnqylr` `is_hurt_color` specifies red with alpha0.2 and sets `v.tsrqrd=1`.
- `entity/dup.json`, `scripts.pre_animation[30]`: copies that flag to `v.rjwqox`, then clears it.
- `animation_controllers/616f2ff7.json`, `nwwoke`: that flag drives armor-material sounds. It has no skeletal Hurt motion.
- The existing Attack is `craixf` in `animations/f2da1071.json`, driven by `aioksj` / engine `v.attack_time`; it is an outgoing attack, not a receiving-hit animation.
- No dedicated skeletal Hurt clip or documented hurt trajectory/timing was found in the mapped base zombie definitions. Existing Mobs research also records the base/SP0/SP1 limitation. We did **not** label a fabricated Hurt Action as source-derived.

The directional physical response below is an **original gameplay adaptation**, layered over the existing source-authored Idle/Walk/Attack. The source supplies layered motion style and hurt-color separation; its pack does not supply these spring constants or knockback values. Full private source excerpts/file hashes remain outside the repository at `/Users/tin/Documents/ChatGPT/New project/experiments/zombie_hit_feedback_20261021/source_evidence.json`. No pack assets/raw tables are added here.

## Implementation

- `zombie_combat/source_visual.gd`: world-space critically damped impulse after every clean evaluated source pose. Peak occurs around36ms, with quick recovery; Chest/Spine share the reaction75/25%, Head counters18% for restrained follow-through. Both rigid arms inherit the chest. No scale deformation, elbow bend, hip/leg rewrite, gait reset, AI stun or per-hit tween. Analytic integration at28/s preserves behavior at30/60Hz. Rotation is capped7deg, translation12mm and impulse velocity is bounded; new shots add a bounded impulse without resetting a reaction timer.
- `physics_zombie.gd`: accepted surviving hits use1.35m/s knockback with a1.6m/s vector cap. Existing exponential recovery and chase controller continue. Lethal hits bypass the live impulse and retain the last displayed pose for the existing native handoff.
- Existing per-instance material flash now lasts65ms, clearly separating6Hz bullets. Retain existing13cm/140ms pooled bullet impacts and existing hit/impact/death audio, with the original fixed voices/event coalescing. No added particles, lights or sound system.
- New dev-only `hit_feedback.gd` uses the existing health-bar shader and damage-number asset with four prewarmed labels per zombie. Six shots/s ×.65s display fits four slots; oversized bursts replace the oldest. No per-hit Node or Tween creation. Four health bars plus16 labels maximum in this encounter.
- Existing death graph, seven rigid parts/six joints/60kg, directional240N·s +48N·s lift,18m/s² gravity,.20 damping, scene-local solver,1.20s cleanup and max4ragdolls remain unchanged. Death handlers still reject repeat damage, retain animated pose and release all physics resources.

## Verification

Behavioral RED before implementation: zero skeletal hit response; repeated direct hits accumulated knockback and created new number nodes. GREEN tests at30/60 cover front/back/side and rotated targets, independent flash/short duration, preserved lower-body source pose, recovery,6Hz train and100same-tick hits, fixed feedback nodes, ongoing chase, one native lethal handoff and1.2s cleanup. `hit30.json` / `hit60.json`: Chest local peak3.55deg; lower-body quaternion-dot/position error below1.8e-7; worst burst6.77deg; knockback bounded1.6m/s; no residual rotation after recovery.

Existing actual-projectile combat/death/cleanup/reset, continuous fire, auto-aim/moving fire/jump/grips, and Combat Strafe30/60 regressions all pass (`regressions.json`). Combat handoff error stays under0.2mm, joint error under50mm and native ground-contact bound under75mm, as previously required. Fire test159shots, no pool misses, zero recovered-pose drift. Player source/controller files and approved assets are hash-preserved.

Actual native Metal **Mobile renderer**,1280×720, AppleM2Pro, ordinary existing camera and four-zombie encounter: both30/60 caps show live reactions, four actual projectile kills, cleanup, zero pool misses and at most two simultaneous corpses in the captured sequence. Wall-frame median/p95:30cap33.35/34.27ms;60cap16.67/17.29ms. Physics remains60Hz. These are local desktop smoke checks, not Android/iOS device certification. Engine process-monitor values are whole-engine telemetry, not isolated hit-layer CPU cost. Screenshots are native captures, not generated mockups.

## Play

Open/run `res://scenes/dev/ActionsStuffWalkRunTest.tscn`.
WASD move; Shift run; Space jump; **hold E to Aim + Auto-Aim + Fire**; RMB Aim/Orbit; Q/C turn; wheel zoom; **R resets the four zombies**. Infinite ammo,6Hz, approved movement speeds/player animations/Combat Strafe/grips/camera/jump unchanged. Research/dev only; production WorldMap/export behavior unchanged.

Preservation audit:8,588pre-existing gameplay/Blender files checked;8,585exact. Only the dev zombie `source_visual.gd`, `physics_zombie.gd` and its README changed; none missing. New helper/tests and this evidence are scoped to dev/docs. See `preservation.json`. Existing scene launched for user review with normal audio (no Dummy driver or silent-review flag), startup free of script/runtime errors.
