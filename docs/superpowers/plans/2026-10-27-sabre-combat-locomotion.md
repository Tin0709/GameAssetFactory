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

- [ ] Derive and preserve source windows, ordered cohort comparisons, displacement and turning evidence; build private profile.
- [ ] Reproduce failures with tests for unlock/chaining, overshoot/physics-rate invariance, queue/release and malformed profiles.
- [ ] Implement event state machine, permission-based physical integration and leg-only gait composition; remove fixed-step policy from normal source mode.
- [ ] Validate30/60/120Hz movement/turn/release/chain/recovery/collision/jump, raw32bone parity and all existing applicable regressions.
- [ ] Inspect actual same-lab native movie/face/weapon/VFX continuity, compare measured windows/displacements with native trace, perform independent review and update existing guidance.
