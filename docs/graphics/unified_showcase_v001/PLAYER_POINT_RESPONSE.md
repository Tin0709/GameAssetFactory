Latest 2026-11-10: radial cutoff now recovered and applied; see PLAYER_RADIAL_KERNEL.md. Earlier cutoff-unrecovered statements below are historical. Six-scale bloom remainsOFF.

# Player point-light distance mode

2026-11-10: F5 WorldMap now enables **L -> Light - recovered non-inverse player falloff** in the supported private Forest context. OFF restores the old response. Noon stays unchanged because the player light is hidden there.

Recovered MD2 runtime evidence explicitly disables inverse-square attenuation. The previous Godot value2 introduced that extra distance factor: the similarly named exponents have different meanings. The original adapter now uses Godot decay0 while preserving existing phase intensity, color,8m range and lamp-follow position. No arbitrary brightness increase or disabled spotlight was added.

This corrects the distance mode; it does **not** reproduce the complete native radial cutoff, soft-source response or radiometry. Godot's quartic range cutoff remains an approximation. The source proof is external/editor-only/hash-pinned. Missing or unsupported data, B original and other contexts restore the old mode; no proprietary data or shader code enters Git/builds.

Actual Mobile-renderer isolated direct-light samples at10distances agree with the expected removal of distance^-2 within0.0872%maximum relative error. The initial probe accidentally retained the camera finish and is preserved as a failed measurement. Corrected probe removes both camera/environment compositors.

42locked main images: bothNoon views exactly unchanged; Night local warm field visibly broader, mean3.23–9.79display-code changes.11/14OFFrestores exact; small half-code residuals in3views remain unresolved. Native16/headless5 plus7regressions,300frame daycycle and actual controller30/60/120 pass with0trajectory discrepancy.

Desktop720p ABBA: whole-viewport medians effectively unchanged (~.510ms atNight), same resource/pass counts. P95spikes~4.5ms in both modes, editor open. No phone certification. Source-derived bloom response staysON; optional six-scale shape and display-edge experiments stayOFF.

Private repeatable evidence: MD2 Research/godot_lab/world_map_unified_showcase_v001/point_light_response_v001/FINDINGS.txt, source_proof.private.json, plane_linear.gd/evaluate_plane.py, visual_v001/comparison.png, raw measurements and logs. No new capture, tool, project or scene.

Godot mathematical reference: [official light attenuation implementation](https://github.com/godotengine/godot/blob/master/servers/rendering/renderer_rd/shaders/scene_forward_lights_inc.glsl). Pinned local source plus actual engine experiment are recorded privately; current master alone is not version certification.

Next: link native local-light cutoff/transport to warm mist and indirect/spatial shade using existing PIX data. Preserve Noon; do not treat this correction as full MD2-quality completion.
