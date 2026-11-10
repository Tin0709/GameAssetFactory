# Raw downsample before bloom exposure — optional study

Existing F5 WorldMap → L → **Air - raw downsample before exposure (experimental)**. Default **OFF**: the measured visual difference is too small to promote this as a solution to the desired humid-air appearance. Noon and the current best graphics baseline remain unchanged. Six-scale spread excludes this option.

Existing MD2 GPU bindings show full SceneColor feeding a raw half-resolution copy, then BloomSetup applying local exposure. Our previous source averaged pixels after local exposure. These operations generally do not commute. `world_map_bloom_source.gd` provides an independently authored alternative using the adjacent reference effect's existing raw copy and exposure statistics. It replaces the existing source pass; no additional pass or image is allocated. The requested extra storage payload is 80 bytes; extra sampling/arithmetic still has a GPU cost.

The adapter retains the current bloom intensity coefficient. Quarter-resolution support, preserved-Noon policy, common-signal radiometry and phase crossfade are original adaptations. They are not recovered native clock or full native rendering equivalence. All captured textures, constant buffers and bytecode remain in the private Research workspace.

`world_map_source_reference.gd` latches the strength actually submitted to the exposure draw. The source only borrows ready resources from the same scene-color buffer. Missing, disabled or non-adjacent reference ownership falls back to the original source. Teardown never frees borrowed textures. Optional build failure rolls back locally without poisoning F7 or the existing phase grade.

Validation includes 21 live controls, F7, phase contexts, native release, injected build failure/retry, and three resize transitions. A reviewer found a real dependent-uniform lifetime bug; a native resize RED run reproduced three invalid-ID errors, and the corrected GREEN run has none. Requested 961×541 renders internally at 961×540 here; odd internal height remains untested.

At 1280×720 and actual 961×540, the live source agrees with an independent CPU mean/base model within two R11 steps for all 270,405 tested RGB components (maximum 1.137 steps). This is our original source model, not a native-GPU parity claim. Separate native same-input experiments retain strict maximum-error failures. Repeated PIX readbacks of the same native event also differ; do not fit shader parameters to one unstable replay.

Forty-two locked HDR images have 14/14 exact OFF restores and unchanged Noon pairs. Maximum mean display change is only 0.074 of a byte code. Actual controller runs at render 30/60/120 Hz, physics 60 Hz, retain zero feature/repeat trajectory error. Desktop direct-RD timing brackets show about 0.002–0.004 ms median increase outside Noon, noisy P95, and no phone/thermal certification.

Evidence and reproduction scripts: `C:\Users\ADMIN\Desktop\MD2 Research\godot_lab\world_map_unified_showcase_v001\bloom_input_order_v001`. Project-owned native regression: `game_mobile_3d/tests/validate_world_map_bloom_source.gd`, requiring Mobile, RenderingDevice and the existing private WorldMap data. Optional receipt path: `GAF_BLOOM_SOURCE_RESULT`.

The overall graphics goal remains unfinished. This study rules out source-order alone as the dominant perceptual gap. Next investigate the captured directional-light geometry and spatial incident-light balance, especially the night primary direction versus the separate fog-Sun direction; preserve approved Noon and label any coordinate/clock normalization explicitly.
