# Independent source review — Player Idle v001

Result: **No substantive blockers found for the stated one-study scope.**

Reviewed `idle_runtime.py`, `build_idle_study.py`, `test_idle_runtime.py`, `idle_source_payload.json`, `source_audit/IDLE_RUNTIME_SCOPE.md`, `source_audit/primary_timeline.json`, `body_audit/BODY_IDLE_AUDIT.md`, the saved simulation trace and build validation, against the actual resource pack. This was a read-only review; the only new write was this report. No source code, Blender data/UI, repository, or Godot file was changed.

## Independent evidence

- All **584 payload clips and 80 controllers** exactly equal their parsed definitions in the archive's `animations/f2da1071.json` and `animation_controllers/616f2ff7.json`; no source-data differences found.
- Fresh `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_idle_runtime -v`: **10 tests passed**. These cover source eligibility, recent-action timing, seeded selection, fade/rearm, head/movement interruption, body keys, cancel-layer `this`, lifetime bob and scope rejection.
- Independently regenerated **2161 primary rows** match `simulation_trace.json` exactly after ordinary JSON normalization of tuple/list values.
- Primary profile remains ordinary **tnlxsa0**, with caller head yaw and target pitch zero; the actual random integer draw is1 from1..12. Source idle state enters at3.0083333333s and begins its source exit at7.2166666667s, then returns to waiting at7.5666666667s. No forced chooser or clip injection was found.
- Emitted recursive layer order includes ambient `bob`/`holding`, then `look_at_target`, then autonomous `tculwn`. Normal/egjh9 duplication is not double-applied to the native rig.
- `look_at_target` is source `relative_to.rotation=entity`, remains active in this ordinary standing profile, and the build explicitly uses the existing entity-relative head retarget. This preserves the distinction between caller-driven gaze, authored autonomous head keys and torso response.
- Prior movement,12-second attack-free age, settled motion and initial entity life are explicitly declared; the report does not present the controller as a never-moved spawn idle or claim an unconditional3-second timer.
- The Rana morph/profile2 distinction is correctly documented; no Rana-only idle override or Rana blink is included in the primary ordinary0 study.
- Source tculwn authored key times are projected into the bake alongside240Hz samples. The sub-tick PRS probes explicitly freeze controller decisions/variables between fixed ticks; for this primary constant-weight gesture and zero-input history, that declared interpolation does not introduce a new behavior. The build preserves the finite9-second presentation and explicitly marks it nonseamless.

## Material limitations are disclosed

The work reconstructs the source's upstream eight body channels on the existing13-bone character. The pack's separate face drivers, blink/expression render geometry, final geometry-capture pipeline, external vanilla.001 arm/leg layers and unknown Bedrock VM/PRNG/weight/fade semantics are not represented as verified native playback. These boundaries are documented in the source scope and audit reports. The source's real facial behavior is not replaced by a fake head squash, fabricated blink, painted atlas change or extra facial rig. This is appropriate for the explicitly unchanged rig/assets scope.

The fixed floor is an identified constant presentation envelope rather than a foot-lock or body-curve correction. Exact Blender playback/native-channel preservation and existing-data fingerprints are the main task's separate artifact validation; this review does not claim an independent UI playback check or binary-identical Bedrock rendering.

No changes are requested before registering the single Pending study on these source/head/face grounds.
