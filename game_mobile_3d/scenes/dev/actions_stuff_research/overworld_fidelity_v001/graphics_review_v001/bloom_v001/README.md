# Optional Day bloom reference

Open the existing `res://scenes/dev/MD2OverworldFidelityTest.tscn` and run F6, or use the existing Overworld launcher. Press **F7** for the Local Exposure Day comparison, then enable **Source bloom - experimental Day**. Uncheck it to compare LE alone. **Original** restores prior graphics/camera/cycle; Auto quality retains the original renderer. No new scene or project.

The generic original renderer runs an external-parameter bloom setup, a cached multiresolution downsample/separable-filter graph, and combines bloom before the existing HDR grading adapter. It avoids applying final local exposure to bloom twice. Neutral comparison suppresses bloom and retains the baseline image. Resources rebuild on engine color replacement; runtime errors restore the saved graphics session.

Default OFF. Reference mode is editor/local-only and requires the private Research profile. No captured numeric buffers, LUTs, textures, models or native shader code ship here. `GAF_BLOOM_PROFILE` can select an external permitted private profile. Sources and the shader hash manifest are our original implementation.

Evidence in private Research `godot_lab/local_exposure_contract_v001/bloom_chain_v001`: all17filter stages and complete filter-chain output match the frozen native R11 frame bit-for-bit; native setup retains threeGreen-word residuals on its original cohort. Actual existing-scene UI/neutral/resize/movement/jump/Sabre and paired GPU tests are separate. A passing filter comparison does not establish whole-image equivalence.

This is a fidelity reference, not a phone performance claim. Work size is fixed1024x576 with17filter passes. Auto/weak-device fallback staysOFF; reduced-resolution/tap-count approximations need separate image and handset30/60/120Hz benchmarks. The older1.35grade adapter, indirect-light approximation and shadow differences remain visible rather than being hidden with a fitted bloom intensity.
