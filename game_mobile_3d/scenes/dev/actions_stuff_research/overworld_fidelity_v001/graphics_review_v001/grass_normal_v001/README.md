# Optional captured grass world normals

Open the existing Overworld lab, press **F7**, then **World-up normals - captured grass**. Default OFF. Uncheck for the old wrap; Original restores the session. HDR/Neutral suppress the override while retaining its small parameter cache; Original/phase/Auto/fault release it.

This original response applies the supplied normal/up weight in world space after interpolation. Both the fragment lighting normal and indirect fill's up weight use that same result. Only compatible tinted-grass reference materials are selected. Tree, leaf, terrain and flower materials retain their previous behavior. No mesh, texture, animation, wind or camera is changed.

The private profile supplies a hash-pinned parameter file and byte offset; native buffer contents are never embedded here. Missing/changed/invalid inputs leave the effect disabled. The captured Day parameter is validated for two grass draw paths; other biomes/weights remain unverified.

Private evidence: Research `godot_lab/grass_normal_response_v001`.129source cases/387GPUcomponents match exactly; native10bit target rounding retains the prior one-code residual. Actual-scene A/B/restoration/gameplay, tilted/nonuniform-world diagnostic, malformed-profile guards and paired desktop timing are recorded. Most short/medium meshes already have nearly-up normals, so the visible change is concentrated on tilted/tall cards. This does not solve missing spatial GI/back irradiance or establish phone30/60/120FPS. No new texture or render pass is required.
