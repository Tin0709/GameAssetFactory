# Actions Stuff unarmed arm audit v001

Read-only audit of actual `Actions Stuff 1.12 (resources).mcpack`, and existing Godot research runtime. No repository or Blender source edits performed by this audit.

## Proven cause

`source_direction_sampler.gd:set_snapshot()` forcibly writes `v.vbcdda=1`, `v.wfyvyl=0` before the holding layer. Actual pack `animation.oreville_ans.dpjhxl` (`holding`) has weight 0.5, with rightarm X `-this*v.vbcdda`, leftarm X `-this*v.wfyvyl`. Since this is additive to accumulated channels, final X is `X_before*(1-0.5*holding_weight)`. The current runtime therefore halves every right-arm locomotion X contribution, including its constant offset, while leaving left-arm X intact. The runtime is evaluating a right-held-item context even in its unarmed scene.

This changes amplitude, not frequency or phase. Both arms consume the same gait phase. Describing the two arms as independently drifting clocks is unsupported by the source or current sampler.

## Exact forward local-X statistics

Values are source Euler channel degrees before native retarget/world transforms. Steady walk uses `esnrkj=.6103515625`, so clamp(esnrkj*3)=1; steady run uses esnrkj=1. Direction weight=1. Idle has movement activation0.

| Mode | Gait period | Source right mean / amplitude | Source left mean / amplitude | Legacy right mean / amplitude | Legacy left mean / amplitude | Gameplay unarmed right / left |
|---|---:|---:|---:|---:|---:|---:|
| Idle | No gait | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | Same source |
| Walk | 0.8 s | 1.6 / 37.2 | 1.6 / 37.2 | 0.8 / 18.6 | 1.6 / 37.2 | Full source amplitudes |
| Run | 0.625 s | 0 / 55 | 0 / 55 | 0 / 27.5 | 0 / 55 | Full source amplitudes |

Walk: right X=-37.2sin(360p)+1.6; left X=+37.2sin(360p)+1.6. Right negative and left positive extrema occur at p=.25. Run: right X=-55sin(360p+10); left X=+55sin(360p+10). Those extrema occur at p=80/360=.222222. Run's authored +10-degree gait-phase advance applies to both arms. Arms are opposite in their swinging X component; the Walk common +1.6 baseline means they are not exact arithmetic negatives.

Walk Y is `-9.6cos(360p+40)` on both arms. Run Y is `18sin(360p)` on both arms, plus settled sprint layer right=-8/left=+8. Holding does not change Y or Z.

## Bob and authored variation

Bob uses entity lifetime, independent of the gait clock. Right arm Z is `sin(life*245)*1.25+1.15`, left is its negative; arm Y position is `cos(life*245)*.1+.05` on both sides. This is 0.6805556Hz, period1.469388s. Waist/legs include122.5deg/s terms, 0.3402778Hz, period2.938776s. Bob adds no arm X. It can make small apparent rhythm changes relative to gait and should remain untouched by the unarmed-X correction. The gait and bob superposition does not generally form a short exact loop.

Directional lateral clips intentionally add second harmonics: Walk lateral arm Z uses720p; Run lateral Z uses720p-12. Backward arms have different authored phase formulas. Do not impose forward-arm timing or mirror every axis onto those directional clips.

## Runtime chain and minimal scope

Controller pre_animation27/29/30 updates shared phase `eqhdel += dt*sqrt(abs(njrdop))*1.6`; holding variables belong to pre_animation29. In real source, holding flags drive weights toward1 using lerp0.2, and unarmed weights decay by `(1-9dt)`. The current controller starts weights0 and unarmed flags0; sampler hardcoding replaces that valid unarmed state.

The directional sampler computes Walk and Run at the same clock, blends their Euler channels by controller run_weight, adds root/turn/sprint/bob/holding/look layers, then uses the same transform construction for both arms. Upper arms and forearms receive one rigid arm transform, and forearm local pose cancels the inherited upper-arm transform. There is no separate left/right clock. The inherited moving pose residual uses symmetric damping24/s (18/s stopped); it only changes transient poses around pose_dirty events. R13 carry/recoil layers apply afterward.

A separate versioned gameplay profile that sets both holding weights0 is a minimal grounded unarmed correction. Keep immutable source default1/0 and all AST/source studies untouched. Changing the existing `source_run_sampler.gd` rightarm `*=.5` alone cannot fix this live scene: its target_pose path is now directional sampler. Gameplay current and future samplers must select the same gameplay profile, otherwise transition derivatives can inject old half-amplitude residuals.

## Validation and pitfalls

The audit independently evaluated actual compiled AST data across1024phases,6directional clips,4holding contexts,2arms:49152 holding-scaling assertions passed. This proves channel algebra, not visual/game-runtime performance. See numeric_evidence.json.

Recommended implementation checks: profile0/0 restores exact pre-holding X for both arms across direction and Walk/Run blend samples; default1/0 retains existing source parity; every nonarm channel remains bitexact; arm Y/Z/position/scale remain bitexact; current/future samplers share profile; cadence, controller state, bob and height output remain unchanged. Also check Idle, Walk/Run transition, start/stop, diagonal turns, phase seam and existing Jump land/recovery in the existing scene.

Weapon compatibility scope: preserve legacy profile as an armed reference. This unarmed scene explicitly disables weapon_equipped; retaining an unchanged legacy reference is meaningful coverage, but does not prove future actual equip/unequip visual behavior. Do not automatically route weapons through0/0 or claim carry regression coverage unless those paths were exercised. The current explicit unarmed correction needs no equip integration.

## Independent patch review

No blocking findings. The actual existing scene loads walk_run_visual.gd and explicitly sets weapon_equipped=false. It loads versioned unarmed profile0/0 into both current and future directional samplers before first evaluation; source sampler defaults remain1/0. Source lookup names remain original names; gameplay names are distinct metadata.

Independently reran Godot headless test_unarmed_arms.gd:2400samples, failures[], max_arm_error0, max_nonarm_error0, exit0. Independently reran existing test_direction_sampler.gd:275samples, failures[], exit0; max channel residual7.644281e-6 and run parity8.429370e-8. Pack SHA matches gameplay profile. Immutable source_library, run_source_profile, directional/controller AST data, legacyRunSampler, controller and height_field hashes match saved audit snapshot. SourceDirectionSampler intentionally gains a profile hook; its captured hash may postdate that edit and is not evidence of unchanged code from the original. Source Blender .blend hashes were not independently available in this audit.

Coverage is unarmed channel correction plus unchanged default-source reference. Four sampled directions include forward/back/lateral/diagonal, five Walk/Run blends and120phases; it is not exhaustive runtime state or weapon visual coverage.
