# Local mist in a map

In the WorldMap, press **F5**, choose **07:00** or **16:30** in **L**, and compare **Lighting mix → Local mist volume (preview)** at 0% and 100%. The first zone is behind the trees at the western forest bend. **Save mix** retains the value. Fresh and older mixes use 0%. The preview requires the Combined orthographic spatial mist and a nonzero Near haze density. Noon, Night, Balanced, the overhead view and baseline comparison keep the ordinary map look.

## Author another zone

Attach a resource using [local_mist_region.gd](../../../game_mobile_3d/scripts/local_mist_region.gd). Set the center and ellipsoid radii in world metres, peak extinction per metre and the linear RGB multiplier for the map's ambient scatter. Place the volume between the camera and the intended background, then check both zoom limits, the player path and the major foreground silhouettes. The existing WorldMap uses [its own scene resource](../../../game_mobile_3d/assets/graphics/worldmap_local_mist.tres).

A map with the shared mist can pass its optional resource and a gain to `set_local_region(region, gain)` on the camera's atmosphere volume. Its existing base mist profile supplies light color and the near/far boundary. Add `gaf_surface_mist` under `GAF_SHARED_MIST` in each receiving material's fragment function, using WorldMap's ground shader as an example. Connect those materials through the atmosphere volume's material provider. Test that receiver coverage includes opaque, cutaway and alpha-tested surfaces used in that scene.

The component currently accepts one region per active orthographic camera. A missing or invalid profile falls back to the base medium. The renderer integrates local extinction and scattered light into its existing volume, using the ellipsoid's actual entry for fragments before the global mist. The option uses the same effect instance, draw calls and texture allocation when toggled. More than one overlapping region per camera needs further design and testing.

The ForestMeadow V3 portability test attached the same component and a different profile to four existing material families in a private harness. Its scene file remains available in its existing form. MD2 capture images and locked before/after renders are in the private research checkpoint.
