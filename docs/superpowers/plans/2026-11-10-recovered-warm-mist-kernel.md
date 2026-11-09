# Recovered radial kernel in warm mist implementation plan

Use superpowers:executing-plans inline; existing user-approved main checkout/WorldMap. Active graphics goal; preserve Noon and all source assets/gameplay.

Source: existing native frame1 draw2103 DeferredLightPixelMain573405..., captured CB1 r3.w=.00125cm^-1, r4.rgb=[6,3.50447,1.31716],r4.w2,r8.x-2. Matches saved warm8m noninverse player point. Actual SSA noninverse branch recovers pow(1-saturate(dot(ToLight*invR)), exponent).5001synthetic vectors through recorded subgraph vs closed form maxerror1.37e-7. No full nativepixel/volumetric parity claim. Current GAF mist warm mask uses pow(1-d/R,2), so apply recovered surface kernel to the ORIGINAL Mobile participating-medium approximation; native volume producer remainsunverified.

Design: pin private numeric kernel proof, optional source-warm toggle defaultON only if validated and existing noninverse mode/context supported. Use existing integration.w reserved float; retain all density/noise/height/range/scatter amplitude/optical integration and224Bbuffer. Generic independently authored positive squared-radius function; no new texture/pass/scene, no source instructions copied into production. Oldmask restored by L/OFF, missing/corrupt proof, noninverseOFF and baseline. Godot SURFACE quartic cutoff remains an acknowledged gap; do not claim it was replaced.

- [ ] RED existing main exposes source-warm control and native parameter packing.
- [ ] GREEN pinned proof + control/owner + original GLSL helper, existing reserved float only. Test fallback and no rebuild.
- [ ] Actual GPU helper vs recovered SSA/closedform; whole-volume old/new alpha must be identical, no-force/Noon equal, finiteRGB.
- [ ] Same-camera42mainHDR images at7hours/2sites; sourcewarmOFF/new/restored, no density or energy changes; recordstrictresiduals.
- [ ] Actualcycle/controller30/60/120, Mobile regressions and GPU/memorycost. Fresh review and save exact boundaries/defaultdecision. Goal remainsactive.

## Evidence-driven scope correction
Actual default field comparison found NightRGB delta0 even with flag1: captured GAF start plane36m excludes the8m lamp field. Noon frozen capture was not rerendered, so is NOT independentNoonproof. Native fog PSExponentialPixelMain has no3Dtexturebinding; active runtime component VolumetricFogDistance0 means propertybEnabletruealone cannot prove active localvolumetriclighting. Do not pull fog near merely to show an effect. Preserve warmtrial snapshot and keep OFFexperimental.

Primary usable deliverable is now native SURFACE radial cutoff: original generic shader helper multiplies existing Godot decay0 quartic cutoff by1/(1+q)^2, q=d²/R², yielding recovered(1-q)^2. Use FRAGCOORD/INV_PROJECTION/INV_VIEW to reconstruct current surface position in light() without depth copy or vertex/animation edits. Shared3light includes, camera-scoped generic global source vector, proof/context gates, optional L/sourcepointcutoff. Validate actual engine output on existing diagnostic plane at several distances, projections and non-targetlight, then locked mainimages/perf/cycle/controller. Native full radiometry/softsource/volume remainunproven. This replaces the unproductive goal of promoting a no-signal warmmask.
