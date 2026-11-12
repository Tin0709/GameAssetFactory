# Local cliff skylight

In the main WorldMap, open **L → Lighting mix → Local cliff skylight (preview)**. Start at 40% near the northwest cliff at 07:00. This works with **Apply Forest daylight** and the existing Save mix, Load mix and Reset controls. The initial value is 0%. The approved 12:00 and night lighting bypass the effect. Balanced and Original graphics also bypass it. Version 42 and earlier saved mixes load with the new strength at 0%.

The scene resource defines a 9 m inner radius and an 18 m outer radius centered at (-42, -29.5) in world XZ. The existing terrain transport validates the private receiver mapping before attaching one additional float to its diffuse vertex stream. On first use, one RGB9E5 texture is shared by the terrain, cutaway materials, and grass roots. The shader raises existing linear diffuse incident light only where the directional sky estimate is brighter. It preserves the existing incident hue. The data, its SHA references, and the scene materials are separate from the reusable shader. A different layout requires a matching baked transport and receiver field. The packed input is only read in the private editor workflow. Missing or changed inputs leave existing terrain lighting in use.

The underlying model projects eight captured MD2 sky inputs onto original GAF geometry. It is an independent approximation of diffuse sky. The recorded source does not establish original Lumen irradiance, actual capture clock times, or a complete forest match.

Private evidence lives in `MD2 Research/godot_lab/world_map_unified_showcase_v001/regional_sky_integration_v001`. Use **Open WorldMap Cliff Skylight.cmd** to begin at the comparison spot. **J** compares the selected strength with 0%, **T** changes phase, and **L** opens the main scene controls. The launcher uses the existing F5 scene.

