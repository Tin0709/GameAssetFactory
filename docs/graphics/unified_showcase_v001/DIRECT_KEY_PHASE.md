# Captured direct-key phase response

Main WorldMap now selects **L / Light - captured direct-key phase response** by default when its private source profile is available. OFF restores the previous palette. Normal F5 still opens the approved Noon, which bypasses the new transfer exactly.

Additional read-only PIX queries recovered missing directional constant buffers from the existing nine Forest captures. All 18 selected draws, including the inactive opposite directional lights, are verified to write the same main SceneColor used by that frame's fog pass. One directional source has nonzero color in each captured sample. This is Sun/Moon direct-light input evidence, not a measurement of diffuse GI or final image luminance.

The original Godot transfer uses componentwise linear RGB ratios to captured reference frame 8. It anchors those ratios to the existing unsoftened Noon and retains the existing gentle-noon envelope. Color/energy alone change. Light direction, point lamp, ambient configuration, fog density/noise, material maps and all approved assets remain intact. Mist/bloom can respond naturally to the changed incoming light. Original clock placement and mirrored evening are reused, not claimed as recovered native time rules. Absolute Unreal/Godot radiometry is still open.

The external numeric profile is hash-pinned/editor-only; missing/corrupt data keeps the old palette. No captured code or assets enter production. Switching modes restores owners before recomputing light inputs; baseline/haze-only paths remain available. A targeted test caught stale active-state reporting after direct stage0 selection; that diagnostic state is now cleared.

Validation: actual white Lambert receiver in the existing Mobile scene reproduces all eight relative GPU input anchors within 0.05% through HDR readback. This proves the normalized transfer, not full native pixels. Sixty locked images cover two sites and ten hours: all 20 OFF restorations and both Noon ON comparisons are exact. Camera, direction, ambient, lamp and fog-density metadata are unchanged.

Native key62/headless17, radial19, soft-source22, phase44, phase-material105, player-transport121 and main showcase checks pass. Actual 300-frame day cycle and fresh controller replays at render caps30/60/120 retain zero feature/repeat trajectory differences. Desktop20ABBA blocks show unchanged draw/pass/texture counts and no resolved median cost; noisy tails/editor open and no handset measurements prevent a mobile certification claim.

Native-reference contact sheets are explicitly unregistered: scene layout, framing and gear differ. They show substantial remaining ambient/occlusion/composition differences, especially at midnight. This correction improves the incident-light input and some visible color separation; it does not establish MD2-quality completion. Next: isolate remaining ambient/spatial-indirect versus post-process fill and investigate the native Sun/Moon trajectory/clock relationships before changing directions or adding more mist.

Private evidence: `MD2 Research/godot_lab/world_map_unified_showcase_v001/player_direct_balance_v001/FINDINGS.txt`, `source_owner_audit.private.json`, `surface_v001/validation.private.json`, `visual_v001/comparison.png`, `reference_context.png` and native test/timing/controller outputs.

Engine normalization context: [Godot LightStorage source](https://raw.githubusercontent.com/godotengine/godot/4.7-stable/servers/rendering/renderer_rd/storage_rd/light_storage.cpp) and [spatial light built-ins](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html). Both directional and local lights include the same nonphysical-unit PI convention; no extra cross-engine intensity factor was inferred from that alone.
