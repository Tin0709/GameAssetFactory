# Consistent scene and bloom exposure

Existing F5 WorldMap/L → **Air · consistent scene / bloom exposure** defaultsON. OFF restores the preceding source equation. The optional source Forest LUT staysOFF. No lighting/material/grass/fog density/blur radius/gain parameter or controller tuning; final APPLY math and all6passes/targets remain.

The previous bloom source used only the local meter. Final scene APPLY also used5-neighbor area/pixel moderation, dark toe and packed peak protection. Therefore the same scene point entered blur with a different exposure treatment. Native matched BloomSetup/final research supports coherent local exposure before bloom filtering; our bounded exposure formula itself is still an ORIGINAL Mobile adapter.

The corrected source reuses the authoritative gain body from APPLY and evaluates each integer input texel before4×4averaging. Partial edge tiles repeat the last valid texel. This avoids interpolating colors before nonlinear exposure and fixes the mismatch at resolutions not divisible by4. The legacy source remains available for comparison. Marker guards report a maintenance error if the APPLY contract changes.

Private evidence: MD2 Research/godot_lab/world_map_unified_showcase_v001/coherent_exposure_v001.

-Actual GPU pair probes compare exposed full-resolution scene with the pre-blur source, not uploaded expected images. Corrected source passes22,278RGBcomponent comparisons across448×64 and449×65, HDR andpacked. Destination-aware budgets:HDR2halfULPs+5e-6, packed1/1023+5e-6. Source diagnostic usesRGBA32F to isolate math; production retainsR11targets. Native entire shader equivalence is not claimed.
-30productionR11screenshots cover meadow/cliff at7/12/16.5/18.5/22h. Visible change is subtle: max whole-image displayMAE.204bytecodes. Strict bit-identical OFF restore passes9/10views; oneNoon meadow view differs in2half components at onegrass pixel, max.00024414linear. That strict gate remainsFAIL; no tolerance was relaxed or cause asserted.
-Native/spatial/showcase and actual gameplay30/60/120 pass; max.130486mm trajectory difference equals control-repeat noise. Optional sourceLUT ownership/fallback transitions also pass.
-Five-phase shared4070TiSUPER/720p/MobileD3D12 directRD6-stage medians.04608msold/.05632–.057344msconsistent. Same8,071,200ownedbytes and draws within eachpair. No extra pass/texture. Phone/thermal and first-use compilation cost remainunverified.

This fixes a real implementation inconsistency. It does not close the much larger native bilateral exposure, bloom pyramid, radiometry, indirect lighting or overall artistic fidelity gaps. Continue those using existing captures, not an invented brightness/fog increase. Reviewer identified the odd-size case; fresh actual GPU RED→GREEN verifies the fix. Fullscreen comparisons use approved orthographic camera, not a changed perspective.
