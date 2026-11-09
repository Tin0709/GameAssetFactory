# Recovered player point-light radial kernel

Main WorldMap now defaults **L -> Light - recovered point radial cutoff** ON in the supported private combined preset. OFF compares the previous noninverse quartic window. The prior noninverse toggle remains available; its OFF returns the original distance^-2 response. Noon remains exactly unchanged in both locked views.

Recovered actual native deferred-light operations and recorded8m/power2 constants give `max(1-(d/R)^2,0)^2`. An independently authored shader helper converts Godot's decay0 window through the factor `1/(1+(d/R)^2)^2`. Energy, color, range, pose, camera, material parameters and source assets are retained. No native code or bytecode is included in production; numeric proof is external and hash-pinned.

The helper covers terrain, player and foliage, including the separate study-grass override discovered by runtime inventory. It reconstructs the current surface point from existing fragment depth/matrices without a depth copy, new pass or vertex changes. Unsupported receiver controls (including F3off), missing proof, extra local lights on the receiving layer and B baseline suspend it.

Source SSA5001samples: closed-form error1.37e-7; original GPU scalar helper error1.79e-7. Actual engine generic/grass tests each17samples across two projections: maximumratioerror0.0471%. These prove the radial kernel, not complete native BRDF, radiometry, softsource or all pixels. Runtime receiver inventory found697lit surface/batch entries through4families and1unshaded effect, no unsupportedlit entries in the default preset.

Final42locked main images: bothNoon views exact0;13/14OFFrestores exact, oneDusk view retains42halfcomponents up to0.00048828linear. Actual daycycle300frames, controller30/60/120 and native19/headless4 + related regressions pass. All failed diagnostics and residuals remain private.

Final desktop720p whole-frame medians:Night0.520ms previous /0.537ms new;Dusk0.500/0.519ms. Draw/pass/texture counts unchanged;2small globals added. P95spikes in both modes; no phone certification.

The warm-air radial transfer is a separate OFFexperimental study: default far-start medium showed no RGB response near the lamp. We did not move fog closer to manufacture a result. Complete native volumetric composition is still unverified. The delivered visual correction is on surfaces.

Private evidence: MD2 Research/godot_lab/world_map_unified_showcase_v001/point_light_kernel_v001/FINDINGS.txt, readbacks, radial_model.private.json, generic_plane_final, grass_plane_final, receiver_inventory.private.json and surface_visual_v002/comparison.png. No new capture/scene/tool needed.

Next: native soft-source response, absolute light/exposure units, spatial indirect fill and camera-relative atmospheric depth. Full graphics goal remains active.
