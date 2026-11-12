# Forest daylight mix

In the existing WorldMap, press **L → Lighting mix → Apply Forest daylight** and compare 07:00 and 16:30 near the western forest. Adjust any slider, then choose a slot and **Save mix**. **Reset mix** restores the standard values. The button applies five scene-authored values to the live mix. It leaves other personal sliders in place. Saving still requires the normal Save mix action.

The preset uses the current sunlight openings, terrain and grass diffuse fill, local mist and player reflection controls. WorldMap keeps the original settings when starting a fresh session. The preset targets morning and afternoon and preserves the tested Noon and Night anchors. The character reflection depends on the existing validated terrain field, and local mist depends on the map's own region.

To author a starting mix for another scene using these controls, duplicate `game_mobile_3d/assets/graphics/worldmap_forest_daylight_mix.tres`, change its display name and set the desired keys in `strengths`. Assign it to the scene's `scene_lighting_mix` property. The controller applies the resource atomically and keeps unspecified controls at their current values. A new map still needs its own lighting inputs, mist placement and verification of the morning, Noon, afternoon and Night appearance.

Private MD2 comparisons and the gameplay review launcher are listed in the MD2 Research checkpoint.
