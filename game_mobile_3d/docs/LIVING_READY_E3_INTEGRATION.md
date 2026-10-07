# E3 — Living Ready integration, 7 October 2026

Integrated non-destructively for human review. No Blender motion was polished,
no animation V2 was authored, and no locomotion or weapon state was redesigned.

## Assets and preservation

Production GLB: `game_mobile_3d/assets/characters/player_cuboid_animated_v4.glb`.

Imported production clips: **Idle, Run, DrawLongGun, HolsterLongGun,
LongGunReadyIdle, LongGunReadyRun**. The existing adapter still supplies its
previous Walk/weapon library and non-deforming WeaponSocket; there is one live
player skeleton and one pose writer.

Export-safe Actions are retained separately in
`blender/characters/player/cuboid/export/ready_e3/LongGunReady_export_copies.blend`:

| Export Action | Unchanged authoring source | Cycle |
| --- | --- | --- |
| LongGunReadyIdle | LongGunReady_Loop_V1 | 32 unique frames + endpoint 33; 24 FPS; 1.333 s |
| LongGunReadyRun | LongGunReady_Run_V1 | 16 unique frames + endpoint 17; 24 FPS; 0.667 s |

Both clips were sampled at 96 Hz and validated **before import**. They contain
only Spine, Chest, Neck, Head, Arm.R, Arm.L and WeaponCarrier channels, with no
Root/Hips/leg/scale tracks. Loop endpoints match exactly. Maximum source position
error was below 0.00000045 m, and measured rotation error below 0.032 degrees.
The GLB has one mesh and skin, and excludes authoring versions, reference meshes,
cameras, lights and Mixamo data.

The v3 mesh, skeleton, materials, textures and four prior GLB animations are
byte-preserved. Every source Action fingerprint and the development `.blend`
SHA-256 remain unchanged. `LongGunHold_V2.tres` is unchanged and retained.
See `export/ready_e3/validation.json` and `protection.json` for evidence.

Godot's default animation key optimization changed these subtle motions during
the first import. v4 therefore disables the AnimationPlayer key optimizer,
while its post-import hook copies the **exact native v3** Idle, Run, Draw and
Holster resources. Every prior native animation key is tested for equality;
existing playback therefore retains its previous interpolation as well.
This follows the optimizer controls described in the
[Godot import documentation](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/advanced_import_settings.html).

## Contexts and phase

`player_ready_e3_integration.gd` extends the existing D5/D2/V2 runtime. The only
base hook extracts the existing carry application into `_apply_weapon_carry()`.
The new layer executes there, **before** the unchanged Draw/Holster final layers.
It adds no weapon state, IK, retargeting, procedural bone solving or second
animation writer. Bone indices and sampler tracks are cached at initialization.

| Actual context | Living Ready upper behavior |
| --- | --- |
| READY at rest | LongGunReadyIdle over the unchanged base Idle |
| READY with normal Walk | Exact previous LongGunHold_V2 behavior |
| Actual Run contribution | LongGunReadyRun, weighted by the existing Run weight |
| Sprint | Existing Holster/STOW behavior; Ready fades out |
| Pistol | Previous behavior, including on the long-gun switch tick |

**User clarification applied:** normal gameplay movement remains Walk. Near an
enemy it retains its 2.6 m/s combat cap; otherwise its 4.25 m/s movement is
unchanged. Shift selects 6.25 m/s Run and stows the weapon. Consequently, natural
gameplay does not sustain READY + Run V7. The new Run composition is available
for its actual Run contribution and in a labeled diagnostic, rather than forcing
Run onto normal movement.

ReadyRun was authored to compensate Run V7 specifically. A normalized phase
alone would not make its correction suitable for the different Walk motion.
Walk therefore uses the safest validated Hold fallback, without sampling the
ReadyRun layer at steady Walk. A dedicated **LongGunReady_Walk_V1** requires
later authoring and human review. It was not created in E3.

For Run, the sample time is derived directly:

```text
ready_time = authored_run_time / Run.length * LongGunReadyRun.length
```

There is no independently advancing ReadyRun clock. Run remains at **1.60**, a
0.417 s effective cycle. Changing direction does not reset either sample phase.
Walk retains its own previous locomotion phase, including its existing direction
handling. Idle Ready has an independent breathing clock, which is intentional.

Spine/Chest/Neck/Head compose the authored correction onto the existing base
matrix basis. Arms and Carrier use the authored Ready local pose. The existing
hand socket follows the same Chest-relative Carrier frame; all weapon-specific
mounts remain authoritative.

Movement context and A/B mode blend over **0.13 seconds**. The moving destination
blends Hold/ReadyRun by the existing Run weight. Entering ReadyRun always samples
the current Run phase, including during the blend; it never resets to frame 1.

## Transitions and rollback

- Standing Draw completes into Living Ready Idle through the existing **0.10 s**
  captured-endpoint exit blend. No intermediate Hold return is needed.
- Natural moving Draw completes into the **Walk Hold fallback**. A Run-context
  diagnostic completes directly into current-phase ReadyRun.
- Holster captures the currently displayed Ready pose and keeps its existing
  **0.10 s entry / 0.12 s exit** blends, authored trajectory, event times and
  hand/carrier/back handoffs. No required return to Hold is introduced.
- Inspector property: `ready_animation_mode`, **LEGACY_HOLD / LIVING_READY**.
  Default is Living Ready. In a debug game, **V** switches modes with the same
  0.13 s blend. The original v3 GLB and Hold resource remain available.

## M4A1 and Shotgun evaluation

Both weapons pass the natural controller checks: standing Draw/Idle, start/stop,
forward/back/side/diagonal direction changes, sprint stowing and threat-driven
Draw after sprint release. Normal movement continues to use Walk fallback.
Independent runtime composition tests cover sustained Run, circular direction
changes, variable timesteps and Draw/Holster at moving Run context.
The latter are **diagnostics**, not claims that natural READY Run is reachable.

Normal-speed A/B captures use the actual Godot Mobile/D3D12 renderer, the same
gameplay scene, original gameplay camera and an additional close inspection view.
Run is posed in place with the controller paused. Each clip shows 64 samples at
24 FPS (2.67 seconds, about 6.4 Run cycles), with no initial slow-motion pass.

Measured vertical travel in those sampled Run diagnostics:

| Part | Legacy M4A1 | Living M4A1 | Legacy Shotgun | Living Shotgun |
| --- | ---: | ---: | ---: | ---: |
| Chest | 78.7 mm | 53.5 mm | 78.7 mm | 53.5 mm |
| Weapon object origin | 97.5 mm | 32.1 mm | 101.8 mm | 34.0 mm |
| Head | 77.1 mm | 18.6 mm | 77.1 mm | 18.6 mm |

These are discrete gameplay-runtime samples, including the established native
base import. The weapon-origin metric is **not** a grip or muzzle measurement.

**Artistic observation, provisional: B — slightly too stabilized.** The rifle
is very steady compared with the moving torso and legs, but residual travel is
visible, and Chest remains alive. The inspected frames do not suggest clear
world locking. Head stabilization reads strongly; the two arms remain visually
connected to the weapon silhouette. Run remains readable at the gameplay camera
distance. The phase-coherent reduction is visible across the sampled cycle.

This is a concern for human normal-speed motion review, not artistic approval.
Repetition, perceived weight, shoulder sliding and long-play naturalness remain
open judgments. **Natural-gameplay ReadyRun approval is unavailable under the
preserved sprint/state rules.** Nothing was automatically changed in Blender.

Shotgun retains its existing offsets. The broader stock/chest proximity remains
visible; stabilization does not perceptibly resolve it and may make that proximity
feel more persistent. No new head intersection was evident in the inspected
comparison frames. Exhaustive all-angle collision clearance is not claimed.

Review captures live under `.validation/ready_e3/review/`: M4A1 and Shotgun,
Idle and Run, gameplay and detail A/B GIFs, plus sampled phase sheets.

## Technical verification and limitations

- **1,962 E3 composition/phase/import checks pass**, including all native prior
  animation keys, strict Ready masks, final upper poses against independently
  composed exported Ready samples, zero lower-position contamination, zero phase
  drift and pistol-switch preservation. Final composed position error is below
  0.00000025 m; the reported quaternion-angle floor is about 0.056 degrees.
- **41 live controller/awareness checks pass** for M4A1 and Shotgun.
- Existing Draw D5, Holster D2, sprint D3, weapon behavior D0, back carry D31,
  movement/weapons, progression, spawn, pose lab, bounce and damage feedback
  suites pass. Rendered D3 also reports zero failed checks and zero sprint shots.
- Movement speeds, collision, camera scene, awareness, firing profiles, source
  clips, back carry and socket code are unchanged. Run still advances at 1.60.
  No root motion, scaling, duplicate weapon instance or broken resource was
  found in E3 checks. The review capture/game log has no script errors.
- Seven older suites are **not green**. An isolated untouched-v3 baseline
  reproduces the same errors: Animation V2 (old bone-count/contact/target-loss
  expectations), Blocky V7 (old bone count), locomotion stop (leg-flip assertions),
  gameplay (old bone count), combat (out-of-range assertion), weapon select
  (firing/null fixture), and polish (death/drop/null fixture). They were not
  rewritten to hide failures. See `tests/ready_e3_regression_summary.json`.
- The editor emitted its known restricted-environment settings safe-save warning.
  Resource imports and runtime checks succeeded. Rendered sprint-test shutdown
  initially emitted cleanup diagnostics (10 objects / 3 resources); its verbose
  rerun completed without those diagnostics, as did the v3 rendered baseline.
  This transient teardown warning was not reproduced as an in-frame game error.

Independent review found and prompted fixes to the initial E3 test coverage.
The stronger tests then caught import optimization and a pistol-switch leakage;
both were corrected and verified.

## Performance

Desktop headless pose benchmark: 3,000 measured updates per context/mode after
200 warmup updates. Approximately **65 → 83 microseconds** for Idle/Run, an
additional **0.018 ms** per update. Steady Walk skips the new samplers and stays
around **65 microseconds**. This is CPU pose timing, not a rendered frame budget
or phone measurement. No mobile device was tested.

GLB size grows from 118,360 to 183,516 bytes (+65,156). The native imported scene
grows from 34,221 to 67,067 bytes (+32,846); those are file sizes, not measured
resident memory. The implementation uses fixed cached masks and native track
interpolation; no synchronization polling or per-frame bone solving was added.

## Review controls and reproduction

The standalone review starts **M4A1 READY** through real awareness/Draw. Its
durable, non-attacking target prevents interruption; endless firing is suppressed
only in this visual fixture. Production firing is unchanged.

- **V:** Legacy Hold / Living Ready.
- **WASD / Shift:** normal gameplay movement and existing sprint stowing.
- **T:** threat on/off; **1/2/3:** Pistol/M4A1/Shotgun.
- **G:** gameplay → Run-in-place diagnostic → Idle diagnostic → gameplay.
  Diagnostics are labeled and pause the controller without changing its rules.
- **C:** close inspection view / original gameplay camera.

```text
godot --headless --path game_mobile_3d --script res://tests/validate_living_ready_e3.gd
godot --headless --path game_mobile_3d --fixed-fps 60 --script res://tests/validate_ready_e3_live.gd
godot --path game_mobile_3d --rendering-method mobile --rendering-driver d3d12 --script res://tests/review_ready_e3.gd
```

Use the installed Godot executable if it is not on PATH. For a clean import,
`--editor --import` waits for completion; do not combine it with an early
`--quit`. The export and validation Python scripts are beside the authoring
file. Their generated expected-pose fixtures are required for the composition
test. Work remains uncommitted for review; stopped after E3 integration.
