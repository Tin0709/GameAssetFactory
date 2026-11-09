# Phase edge finish implementation plan

Use superpowers:executing-plans inline. User authorized autonomous existing-scene visual work.

Goal: test a reversible, independently authored display-domain edge-resampling finish in the existing main WorldMap; do not replace fog or soften every pixel.
Architecture: the existing phase finish owns tone conversion outside Noon. Reuse its APPLY pass to write encoded display color into an optional RGB10 target, then edge-filter into display-linear scene color before UI. Preserve exact Noon bypass and previous OFF pipeline. No canvas filter before engine tone, no built-in HDR FXAA stacking.
Spec: user active graphics objective plus latest GRAPHICS_HANDOFF; source-bound observations in private display_edge_finish_v001. Existing Nvidia FXAA paper describes public edge resampling. No copied proprietary shader instructions/assets in project.

Constraints: existing scene and approved gameplay/assets unchanged; private editor-only phase owner; default OFF until user visual review. .75/.166/.0833 are observed controls, not recovered humidity. Optional phase weighting is original adaptation; Noon intentionally remains unchanged.

1. Add failing native/headless test for set_edge_softening, default OFF, Night enable, release/OFF/Noon/fallback, compatibility and resource reuse.
2. Independently author generic edge orientation/search shader, integrate as one optional extra raster pass, no extra pass or target OFF. Test solid colors and edge patterns against independent CPU model before main captures.
3. Add L comparison checkbox, source/approximation tooltip; same cameras at 7/12/16.5/18.5/22. Compare before/after/restore and reject if broad haze or color shift.
4. Validate main bridge suite, deterministic gameplay and GPU timing. Record strict numerical limitations and handset gap. Keep optional until artistic approval; do not promote merely to pass tests.

Review risks: stale framebuffer on resize, reference APPLY not ready, baseline ownership, near-Noon discontinuity, sampler/encoding mistakes. Test resource lifecycle and fallback, preserve full failed measurements.

Ruling: reuse user-selected checkout and existing main scene; main branch work is explicitly requested, do not create another project/scene or switch checkout. No new tools or captures.
