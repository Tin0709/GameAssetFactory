# Optional normal-dependent fill reference

Run the existing Overworld fidelity scene, press **F7**, and enable **Directional fill - single-probe reference**. It can be compared with or without the separate source-bloom checkbox. Uncheck for the previous RGB field; **Original** restores the previous graphics session. HDR baseline/Neutral/phase changes suppress the correction. Default OFF; same editor/private-reference gate as Local Exposure.

The original helper evaluates supplied mean-radiance SH9 as E/pi using the documented Y-up basis, normalizes by its upward response, and preserves a supplied direction-independent residual. It changes only the existing indirect-fill contribution. Existing direct lights, base colors, intrinsic emission, assets, gameplay and animation stay intact.

This is a calibration adapter, **not recovered Lumen or spatial GI**. Private research supplies one recovered SH fixture at sourcepixel320,256 and a separate ground reflection fraction. They are not a co-located or universal material decomposition. Spatial visibility, exact scene-axis registration, material-dependent reflection and foliage back irradiance remain unresolved. No fitted strength/exposure/yaw is added. A future production profile must use our own lighting data.

Captured coefficients and research images remain outside the repository. `GAF_DIRECTIONAL_FILL_PROFILE` selects a permitted external private profile. Off restores all three material uniforms; no extra textures or scenes are created. Desktop paired rendering and same-input GPU checks live in private Research `godot_lab/day_light_components_v001`; handset30/60/120Hz validation is still required.
