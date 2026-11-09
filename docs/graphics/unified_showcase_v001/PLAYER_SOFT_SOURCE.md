# Player finite-source specular comparison

The existing WorldMap L panel now includes **Player - finite-source specular (comparison)**. It is **OFF by default**: the source-backed correction is measurable on player/Sabre highlights but the full-scene visual benefit is subtle. This is not a new fog, blur, diffuse-fill or shadow-softness effect. Normal F5 still opens the approved Noon configuration.

Original implementation broadens only the direct specular lobe for the supported private player lamp. Material textures, sunlight, diffuse lighting, ambient/IBL, light energy/color/range and atmosphere stay unchanged. Source constants/proof remain in private Research, hash-pinned and editor-only. Missing or corrupt proof leaves the previous response intact.

Recorded native DefaultLit arithmetic and an independently authored model agree on 5,001 synthetic cases. The production scalar helper invoked on Godot GPU agrees within 9.44e-7 relative error across lobe width, distribution and visibility terms. These are isolated arithmetic results, not proof of full native pixels or the SubsurfaceProfile route.

The actual production player `light()` was also exercised on a temporary isolated plane in the existing WorldMap: 38 nonzero samples, maximum old/new ratio error 0.287%. The comparison accounts for Godot Mobile's half-precision light inputs and perspective-to-camera VIEW vector even in the orthographic probe. Earlier parallel-VIEW and full-float assumptions failed and are retained privately. Wrong-camera and wrong-light ON/OFF pairs restore exactly in the plane test.

Owner/proof/baseline/fallback controls reuse the recovered radial scope. Fresh review found that descendant-only extra-light inventory missed sibling lamps; inventory now gates all local lights sharing World3D, including shared-world SubViewports, while excluding isolated worlds. Targeted RED then GREEN evidence covers that fix. Native soft-source 22 checks, headless 5, radial 19, phase 44, material 66 and phase-material 105 checks pass. Actual 300-frame day cycle and controller replay at 30/60/120 Hz pass; feature and repeat trajectory errors are zero.

Final controlled photos and timing details are in private `player_soft_source_v001/FINDINGS.txt`. Desktop 720p ABBA timing has no resolved median cost, no extra pass/texture; noisy tail timings and absent handset measurements prevent a mobile certification claim. The added global is a vec2; actual global-block allocation was not measured.

Next useful work: identify the native player shading-model coverage and source diffuse/SSS/indirect contribution before tuning fill or intensity. Soft-source width alone does not explain the remaining humid atmosphere or full character-lighting difference. All approved defaults and assets remain available; overall graphics goal remains active.
