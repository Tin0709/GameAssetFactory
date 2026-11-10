# Fog-source phase response

Existing F5 WorldMap, 2026-11-10. L → **Air - captured fog-source phase response** defaults ON with the existing valid private phase data. OFF restores the previous incident-light amplitude. This is a source-input correction, not a claim that the scene now has the full desired humid appearance.

## Cause and implementation

The measured phase coefficients previously supplied chromaticity, while an original ambient/sun luminance formula supplied amplitude. That combination discarded the measured relative brightness: the lab's 9h source was approximately 1.396 times Noon, versus 0.804 for the corresponding captured coefficient. Clock placement is original GAF scheduling, not recovered native hours.

The new independently authored transfer anchors the measured linear RGB coefficients to the approved Noon source. It derives that anchor from existing Noon ambient/key settings, including gentle-Noon attenuation, without changing scene time. Only the published `scatter_energy` changes. Density, start distance, height falloff, world banks, lamp contribution, visibility, bloom, materials and controller remain unchanged. Noon has an explicit bypass. The existing hash-pinned private source is not copied into the project.

Missing proof, disabled measured atmosphere, Previous/Haze/Lighting review contexts and invalid numerical inputs retain the previous path. The relative coefficient is not absolute native radiometry or the complete native fog renderer.

## Important perceptual boundary

The player is about 25m deep in the current gameplay view, before the recovered 36m ray start. Most near-player imagery therefore does not pass through this mist. Forty-two matched images show a very small maximum whole-image mean display change, approximately 0.0121 of a byte code. Close cliff views have no measurable change. Increasing fog density to imitate softness would obscure the wrong part of the image.

Re-evaluation of the saved native final-shader counterfactuals instead points toward bloom and local exposure for the near-scene luminous softness. Those are conditional evaluations with recorded oracle residuals, not new GPU ablation captures and not a justification for arbitrary intensity increases. Different scene composition prevents direct amplitude calibration from these aggregate values.

## Verification and limits

- Eight actual published-source anchors: maximum absolute normalized RGB-ratio error below 1.2e-7; pre-fix test failed at approximately 0.710.
- 89 actual WorldMap checks: gentle Noon ON/OFF, source restoration, review contexts, missing/restored source. Nine original-fixture unit checks, including RED/GREEN nonfinite-denominator protection.
- Existing shared-mist GPU coverage and native-fog restoration tests pass.
- Both Noon ON/OFF image pairs unchanged. 12/14 OFF restores bit-exact; two sparse HDR residuals retained (maximum 0.000244140625). Strict all-restores gate remains FAILED.
- Desktop Mobile/D3D12 GPU medians unchanged in this run, with unchanged matched draw counts and texture memory. P95 spikes to about 11.75ms; these data are not a clean benchmark or phone certification.

Full raw evidence, final gameplay result and continuation instructions live under private Research `godot_lab/world_map_unified_showcase_v001/mist_source_audit_v001`. Do not infer a gameplay pass from a timeout or a partial log.
