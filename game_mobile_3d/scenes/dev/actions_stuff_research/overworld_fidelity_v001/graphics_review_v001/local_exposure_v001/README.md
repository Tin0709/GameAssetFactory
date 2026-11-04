# Local Exposure - playable Day reference

This original implementation is integrated into the **existing**
`res://scenes/dev/MD2OverworldFidelityTest.tscn`. Open **Open Overworld Meadow.cmd**
from the repository root, or open that scene in Godot and press **F6**.
No new scene/project or animation assets are required.

## Comparison controls

- Default **Auto / low device** keeps the original graphics.
- **F7** enters the Day reference, then toggles **LE on / HDR baseline**.
- **Neutral** runs the complete graph with neutral contrast, preserving the
  common HDR baseline image. It is useful for isolating pipeline side effects.
- **Original** restores the previous graphics, camera mode and day/night state.
- Existing F9/F10 graphics controls and phase/wind changes safely exit this
  comparison. **H** hides the controls; movement, jump, Sabre and audio retain
  their existing controls.

Entering reference mode selects fixed Day and a validated FP16 HDR/LUT domain.
Use its **HDR baseline** for the effect comparison: it deliberately differs
from the old SDR precision path. LE removes the existing material shadow-lift
proxy instead of adding another correction on top. Original restores the old
path, including its HDR flag, field/LUT/compositor pointers and cycle settings.
Runtime errors also restore the previous graphics state.

## Implementation and boundaries

The six shader kernels and GDScript code are independently authored. Captured
buffers, LUTs, textures, meshes and game code are **not included** here. The
editor-only fidelity lab reads its existing private Research profiles outside
the project; these are not distributable game assets. Missing data, export,
unverified renderer or Auto quality preserves the original path.

The reference uses a fixed 1024x576 metering image, 16x9x32 bilateral grid,
four-level color pyramid, log luminance and separable filtering. Shader/pipeline
allocation occurs on activation or engine-buffer replacement, not each frame.
The effect owns its resources, never the global RenderingDevice or engine color.
Resize handling rebuilds the cached graph and avoids freeing engine-invalidated
bindings twice. Threaded diagnostics publish a copied snapshot.

Captured Day contrast settings are source-backed. The retained 1.35 grading
adapter is an older calibration, not recovered absolute scene radiometry.
Identity-grade research remains a separate control. This does not reproduce all
native GI, bloom, grading, biome settings or temporal behavior.

## Validation and mobile policy

- All 15 public-pipeline original/black/restored field outputs equal the pinned
  research implementation. Six public shader payloads match the audited kernels.
- Actual scene tests cover neutral/original pixel restoration, two viewport
  resizes, phase/Auto handoff, 7 m/s movement, jump and Sabre playback.
- An injected render-thread fault verifies restoration from Original + Auto
  night back to the exact prior owner/HDR state.
- The visible panel and actual Godot F7 input route are tested.
- Current paired RTX 4070 Ti SUPER measurements at 1280x720 give about
  0.23-0.24 ms median for the instrumented effect. Desktop clock/power state,
  scheduling tails and full-viewport side bias remain uncontrolled; this is
  **not a phone performance estimate**.

Auto/weak-device fallback is Off. No smaller reference grid or claimed
30/60/120 FPS phone tier is enabled without held-out image checks and handset
benchmarks. Own texture payload at 720p is about 10.6 MB, excluding engine HDR
buffers, grading texture and driver overhead. Seven pre-existing full-lab
TextureRID shutdown warnings remain; they are not presented as fixed here.

Private evidence and screenshots are in Research under
`godot_lab/local_exposure_contract_v001`, especially `integrated_play_v004`,
`integrated_UI_v002`, `integrated_fallback_green_v002` and
`paired_public_benchmark_v002`. Do not copy these private fixtures into Git.
