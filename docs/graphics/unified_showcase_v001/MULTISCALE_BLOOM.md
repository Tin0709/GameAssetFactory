Latest 2026-11-10: radial cutoff now recovered and applied; see PLAYER_RADIAL_KERNEL.md. Earlier cutoff-unrecovered statements below are historical. Six-scale bloom remainsOFF.

# Six-scale bloom comparison (2026-11-10)

The existing WorldMap now offers **L -> Air - six-scale spread (experimental)**. It is OFF by default. The prior measured bloom response remains ON. F5 still opens the approved Noon scene; the new graph has no extra resources at Noon.

The original implementation uses an independently authored separable pyramid and private measured numeric kernels. It changes spatial light spread at the existing energy, rather than adding a second fog/gray overlay. The captured numeric profile stays external, hash-pinned and unavailable to distributable builds; missing or unsupported data falls back to the existing quarter-resolution field.

Full same-input source comparison over589824pixels:99.993%RGBcomponents within two R11 codes, maximum five; relativeRMSE0.582%. Exact equality fails. Normalized production mapping has0.724%relativeRMSE when rescaled. Source prefilter/radiometry/native resolution adaptation remain unproven.

Validation: native24/headless7; seven existing regression suites; actual300frame cycle and controller30/60/120 with shape-active assertion and identical trajectories. Recovered an actual owner-update ordering bug that static comparisons had masked, plus legacy API/failure allocation issues. The old failed logs remain private.

Final42locked images: bothNoon views exactly unchanged;13/14restore images exact, one7h view retains five half-components up to0.00024414linear. Strict identity is not fully achieved. Visual change is subtle, mainly a tighter core and broader faint spread.

Desktop720p on4070TiSUPER: extra18low-resolution passes and~3.52MiB; final direct-post medians~0.132–0.138ms previous /0.214–0.216ms new. P95spikes up to~1.05ms in both modes, editor open. No phone benchmark. This cost and modest visual gain are why it remains optional.

Private reproducible evidence: MD2 Research/godot_lab/world_map_unified_showcase_v001/multiscale_bloom_v001/shape_transfer_v001/FINDINGS.txt, spatial_gpu.gd/evaluate_source.py, regression_summary.private.json, visual_v002/comparison.png and metrics/performance JSON. Older failures and visual_v001 remain intact. No recapture or new scene required.

Next: pixel-linked spatial local-light/ambient/occlusion comparison, not another global blur boost. Preserve Noon and approved gameplay. Full graphics goal remains active; this is not MD2-quality completion.
