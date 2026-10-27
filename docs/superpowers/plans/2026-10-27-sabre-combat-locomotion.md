# Sabre combat locomotion from native events

Continue the same Valorie/Sabre scene and private source rig. Preserve7m/s,
1.888Hz common gait phase, raw1x review/keys, accepted jump and graphics.

The captured1H cohort and montage main LinkValue agree on early ResumeMovement
and RecoveryStart queue gates. Prior claims that Recovery2 changed were wrong:
EndLink is a separate cached field, while the authoritative instant-notify keys
agree across both snapshots. Correct that finding in place.

Architecture: optional validated private combat profile; deterministic source-
time combo boundaries drive movement permission and chaining. Forecast the same
state machine across each physics tick to integrate only its open time, without
moving during windup or depending on a fixed distance. Existing AnimationPlayer
retains attack/recovery source poses; override only native leg branches with the
current phase-synchronized gait when movement is permitted. Independent bounded
wall-time leg handoff, existing direction/presentation pipeline, no asset baking.

Unknowns stay labelled: original input-device timestamps/buffer duration, exact
native bone-mask blend curve/contact solver, vanilla input versus installed WASD
mod. Retain the bounded220ms one-command buffer as a disclosed adapter. Do not
invent root lunges or change jump/air timing. Source composite holds/trims and
variant rates define unqueued section playback; held chains use RecoveryStart.

- [x] Derive and preserve source windows, ordered cohort comparisons, displacement and turning evidence; build private profile.
- [x] Reproduce failures with tests for unlock/chaining, overshoot/physics-rate invariance, queue/release and malformed profiles.
- [x] Implement event state machine, permission-based physical integration and leg-only gait composition; remove fixed-step policy from normal source mode.
- [x] Validate30/60/120Hz movement/turn/release/chain/recovery/collision/jump, raw32bone parity and all existing applicable regressions.
- [x] Inspect actual same-lab native captures/weapon/VFX continuity, compare measured windows/displacements with native trace, perform independent review and update existing guidance.

Result:31suites/1260checks pass; full-grass native capture15frames/513states.
Raw32bone/288time comparison covers all13originals plus the two actual native
Axe finisher clips, with unchanged source GLB/Blender hashes. Source animation
keys are unchanged; upper-body/face parity is tested during moving combat.
Independent review defects (atomic optional import, mask confinement, tiny-time
nonprogress, bad semantic type) were reproduced and fixed with regressions.

Evidence changed the planned cross-stop foot-phase policy: all14captured native
resumptions restart near0..2evaluator ticks, so reset phase on resume while
keeping the Walk/Run samples synchronized. Keep the remaining~37ms second-strike
open-window discrepancy visible; inputs were not timestamped and no speculative
delay is added. New read-only current-owner melee speed/input ability evidence
does not expose the original buffer duration or historical queue timestamps.
