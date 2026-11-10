# Captured sky-source phase response — 2026-11-10

The existing main WorldMap now transfers relative sky-source RGB into its existing ambient, terrain and player lighting paths. This corrects the previously excessive uniform Night fill. It adds no shader, GPU pass, geometry or texture and preserves the approved Noon through an explicit bypass.

## Review

Open `game_mobile_3d/project.godot`, press F5, then L for the lighting controls. Change the time to Night and compare **Light - captured sky phase response** ON/OFF. ON is the default when the private proof is available. OFF restores the previous ambient palette. Keep the earlier direct-key response enabled to review the combined result. The original graphics baseline remains available.

The numeric profile remains outside this repository under the MD2 Research workspace. `world_map_sky_response.gd` requires the editor feature, a matching SHA-256 and validated schema. Missing or mismatched private data leaves the old palette intact. An export does not load this private profile. This gate does not certify the rest of the existing private showcase for distribution.

## Evidence and limits

Existing PIX captures provide the bound directional sky cubemap and its shader RGB multiplier. The independently calculated solid-angle-weighted source mean is normalized to the Day reference. Multipliers alone are insufficient: sampled sky radiance also changes substantially.

This is a low-frequency source transfer, not recovered Lumen irradiance. Original GAF spatial visibility, bounce caches, clock anchors, smooth interpolation and mirrored evening remain approximations. Native clock, absolute radiometry and full angular transport are not recovered. No native shader code or asset is embedded here.

## Validation

- Runtime RED/GREEN against eight source anchors; schema unit tests: 36 checks. Actual missing-file, bad-hash and valid-file loading tested.
- Native context/toggle tests and existing player transport, player phase, direct-key and showcase regressions pass. Continuous cycle tested for 300 frames.
- Existing WorldMap controller: render caps 30/60/120 Hz, physics 60 Hz; Run, jump, landing and attacks exercised; feature and repeated-control trajectories match. This does not validate physics at three different tick rates.
- 42 locked-camera HDR captures: both Noon views unchanged. 13/14 primary restores bit-exact; one pixel/three components differs by at most 0.0003662109375 HDR. Strict all-restores criterion FAILED. An unchanged OFF control also produces sparse variation (nine components, same maximum); the exception is retained, not silently waived.
- Desktop Mobile/D3D12 at 1280×720: GPU medians approximately unchanged; draw counts and texture memory unchanged within each comparison. P95 is noisy. No handset FPS or thermal claim.

Private evidence, scripts, images, raw readbacks and findings: `C:\Users\ADMIN\Desktop\MD2 Research\godot_lab\world_map_unified_showcase_v001\night_fill_audit_v001`. Start with `FINDINGS.txt` and `visual_v001/comparison.png`.

Next: separate angular/spatial visibility and bounce from the source mean; recover native Sun/Moon clock only if evidence supports it. Do not retune fog or animation to compensate for an indirect-light discrepancy.
