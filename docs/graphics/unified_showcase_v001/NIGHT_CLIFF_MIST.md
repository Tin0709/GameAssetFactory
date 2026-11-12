# Night cliff mist in WorldMap

Open the main project with F5. Press **L**, select **Night**, open **Lighting mix** and adjust **Night cliff mist (preview)**. Start at 65–100% at the northwest cliff. Use **Save mix for slot** to keep the choice. Recipe 46 stores this control. Earlier recipes use 0%.

WorldMap assigns an original LocalMistRegion in worldmap_night_cliff_mist.tres. The region fades with the night phase and uses the existing second volume slot. The current map's morning and afternoon cliff profile uses that slot during daylight. The two fade through zero at 19:30. Combined lighting, the fog master and Near haze govern the control. Another map can supply a different night region through night_mist_region.

The region's shape and density are calibrated for WorldMap. The cool scattering color comes from the existing captured phase profile. For screenshots and benchmark records, see night_cliff_air_v001 inside the private MD2 Research workspace. The goal is paused after this milestone at the user's request.

