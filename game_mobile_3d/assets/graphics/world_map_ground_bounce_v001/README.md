# Original WorldMap reflected-ground lighting

`normalized_ground.res` is generated solely from the original GAF WorldMap and
its existing materials, vegetation and shadows. It contains no MD2 texture,
geometry, captured frame, shader code or recovered proprietary coefficients.

The 274 x 220 RGBA16F image covers the actual 137 x 110 m source footprint from
(-77,-56), at two samples/metre. Logical texture data:482240 bytes; compressed
resource size is smaller. It is preloaded even when the comparison is off.

The native authoring render uses a unit white directional light at the current
Day direction, Lambert diffuse, no ambient/specular/fog/post-grade, and the
existing GAF material color/contact treatment. Original vegetation remains as
shadow-only geometry. Tiled orthographic 10 m renders have a60 m shadow range;
tile shadow precision differs from the gameplay camera's shadow cascades.

Regenerate using the installed Godot version, with output in a NEW scratch
directory, never over a completed bake:

```
godot --path game_mobile_3d --rendering-method mobile --rendering-driver d3d12 --audio-driver Dummy --script res://tests/bake_world_map_ground_radiance.gd -- ABSOLUTE_NEW_SCRATCH_DIRECTORY
godot --headless --path game_mobile_3d --script res://tests/pack_ground_radiance.gd -- ABSOLUTE_NEW_SCRATCH_DIRECTORY
```

Require error-free native bake logs. The packer requires the explicit current
runtime-map SHA256 in the bake metadata. Runtime also checks map hash, field
extent/resolution, matching sun direction, shadows, pixel Mobile rendering and
the current Day composition/finish. Rebuild after scene/material/shadow changes;
the runtime-map hash does not fingerprint every external material/shadow asset.

The original runtime approximation applies only to vertical mineral faces. Two
front-facing ground cells are sampled along the wall tangent; contributions are
interpolated after rejecting invalid or above-receiver floors. The finite-disk
view factor is

`F(h,R) = [atan(R/h) - R*h/(R*R+h*h)] / PI`, with original radius R=3 m.

A rational mobile approximation has absolute view-factor error below.0011.
Current sun color/energy and receiver-local cloud transmission scale the baked
unit-source field once. Receiver material diffuse is applied by Godot normally.
This adds reflected light before the receiver's direct-light cosine rejection;
it does not reuse the receiver's direct shadow attenuation or emission.

This is static approximate one-bounce diffuse lighting, **not** recovered MD2
Lumen. Two sampled cells represent a finite nearby patch; source shadows are
static, cloud attenuation is shared locally, and there is no dynamic occluder
transport, colored sky bounce, cliff sky-visibility solve or multiple bounce.

In WorldMap, Shift+F1 compares it independently of the F1 shadow filter. B/F8/U
and unsupported contexts preserve the previous baseline. Existing shaders,
source meshes, animations, camera, terrain topology and gameplay remain intact.
No additional draw calls or per-frame field simulation are introduced. Actual
phone energy/thermal and30/60/120FPS acceptance remain open; clean desktop timing
was explicitly deferred by the user.
