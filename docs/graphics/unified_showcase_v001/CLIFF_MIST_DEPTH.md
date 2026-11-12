# Cliff mist depth

In the main WorldMap, use **L → Lighting mix → Cliff mist depth (preview)**. Try 100% at the northwest stone turn at 07:00 or 16:30. Use 0% to compare. The preview is off on a fresh mix. Save mix persists both local mist controls in recipe v44. Earlier mixes load the cliff strength at 0%.

The original **Local mist volume** controls the forest bend. The new **Cliff mist depth** independently controls a shallower layer above the northwest stone and grass terraces. Both use the same participating medium and can remain enabled as you move between areas. Combined gameplay and the near haze gate are required. Noon, Night, Balanced, Overview, and Original graphics bypass the added daylight layers.

A compatible map can author `local_mist_region` and `additional_mist_region` in its scene, using the same LocalMistRegion resource for each. Each has a world center, axis radii, extinction per metre and scatter color multiplier. The camera supports two regions in the existing local/near integration window. Optical depth sums across overlaps, and the scattering source is weighted by optical depth inside each depth interval. The interval treatment approximates ordering at sub-slice scales. No scene assets or additional volume texture are required.

The cliff placement is an original calibration to actual resolved WorldMap depth, inspired by the localized atmospheric separation measured in MD2 Forest PIX frames. It does not transfer native placement or radiometry. The optional layer adds 48 bytes of parameters and reuses the existing compute dispatch and texture. The second bank has desktop Forward Mobile verification. Handset performance remains open.

The private research folder contains the launcher **Open WorldMap Cliff Mist Depth.cmd**, the locked renders, and the observed results. **I** compares cliff strength against zero, **T** changes time, and **L** opens the existing controls.

