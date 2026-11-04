# Optional direct presentation — private Day research

Open the existing `MD2OverworldFidelityTest.tscn`, press F7, then enable **Direct log-LUT + pre-grade vignette**. Compare by unchecking it. Source bloom remains independently selectable. Original, HDR baseline, Neutral, phase changes and Auto restore their previous grading and vignette context. Default is OFF.

Original generic implementation: aspect-normalized vignette before logarithmic 3D color lookup, bounded triangular dither, display-to-linear conversion for the engine's physical HDR target. This replaces the final LE writeback; it adds no fullscreen pass. Engine adjustment/glow and old Canvas vignette are suppressed while active to avoid processing the image twice. Existing source1.35 scene calibration remains; it is not a newly recovered exposure constant.

The external private profile provides a typed linear RGBA10 LUT and scalar parameters. No reference LUT, asset, captured shader or parameter table is shipped here. Editor/private-workspace and existing rendering-policy restrictions apply. Unsupported formats or render errors return through the existing fallback. Auto/low-device remains OFF until handset validation. The private baseline64-cube LUT remains cached for immediate comparison; the optional typed32-cube adds131072 texture bytes, plus4black bytes and112 scalar-buffer bytes, excluding driver objects.

Validation: native same-input final-stage model covers2048x1152 pixels, maximum2/1023 error and strict exact comparison still FAIL; it is not a bit-exact full engine. Actual public shader259 swatches (including12 beyond old linear domain2) pass the existing3/255 gate, worst0.241789/255. Actual scene49checks and29older frozen images preserved; controlled fault/profile guards/resize exercised. Private paired desktop measurements are not phone FPS or isolated causal cost.

Limits: underlying spatial GI, source scene registration, camera/geometry differences, native noise precision, final R10 quantization/FXAA differences, temporal behavior and mobile performance remain separate. No claim of whole-image MD2 equivalence or human artistic approval.
