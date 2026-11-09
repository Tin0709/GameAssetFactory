# Captured phase bloom response implementation plan

Use superpowers:executing-plans inline; autonomous main-scene implementation is authorized.

Goal: correct the main scene's fixed bloom response using the measured relative convolution gain across nine existing Forest frames, while preserving Noon and all approved light/fog/gameplay.
Architecture: pinned external scalar profile, original existing clock interpolation; one existing air.x uniform multiplies its approved .16 gain. No shader sampling changes, new passes, textures, scene or arbitrary haze/brightness fit. Full six-scale shape remains a separate next task.
Spec: current user graphics objective; private multiscale_bloom_v001/source_gain_validation.private.json validates108native draw programs,648RGBcomponent responses with max5.96e-8 error. Normalized six-level weights stable2.54e-8; observed total/reference ratio .4524..1.8, stored externally. Source clock and cross-engine radiometry not recovered.
Constraints: keep camera, controller, skin, Sabre, grass, mist, gentle Noon and previous baseline. Runtime only private editor data; missing/corrupt profile restores unity. UI L comparison. Default ON only with valid proof after imagery validation.

- [x] Red: test new main setter, loader/fallback, original clock anchors, actual air uniform, OFF and baseline/Noon compatibility.
- [x] Green: add loader, existing scalar update API, main setter/UI; no new GPU pass. Validate NaN and missing/corrupt data.
- [x] Main five-phase two-site before/after/restore captures, actual day-cycle continuity, gameplay and regression suites. Compare intensity changes independently from optional edge filter (OFF).
- [x] Performance: same passes/resources; direct RD measurement on Mobile/D3D12, preserve noisy blocks; no phone claim.
- [x] Review focused new code, record outcomes and keep immutable previous results. Future multi-scale reconstruction must use recovered tap/radius data rather than assume blur width is unchanged across resolutions.

Ruling: source discovery changes task order: relative intensity is a verified current implementation gap; apply/test it before more convolution passes. Existing checkout/main is user-selected; no new project or scene.

Result: implemented and validated relative response only. Full multi-scale shape remains next.42captures retain one3pixel restore residual; not all bitexact image gates pass. Native time/radiometry/handset performance remain unverified.
