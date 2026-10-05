# Zombie Cuboid V1

Created through Blender MCP from the player V5 structural standard. Player source unchanged (SHA-256 checked).

Mesh: Zombie_Cuboid_Base. Rig: Zombie_Cuboid_Rig. 80 vertices, 120 triangles, 10 rigid sections, 18 bones, one material.

Rest dimensions (width x depth x height):
- Head: 0.450 x 0.450 x 0.450 m (8 x 8 x 8 model pixels).
- Torso: 0.450 x 0.225 x 0.675 m (8 x 4 x 12).
- Each arm and each leg: 0.225 x 0.225 x 0.675 m (4 x 4 x 12).
- Overall rest height: 1.800 m; overall width: 0.900 m. Feet Z=0, head top Z=1.800 m.
- As on V5, arms and legs have two rigid cuboid sections to permit joint rotation. No scale, squash or soft deformation.

Original 64x64 pixel atlas, packed into the blend and also provided as PNG. Nearest-neighbor sampling. Moss/sage green skin, dark sunken eyes, original broad mottling, slate work jacket, faded undershirt, rust-colored repair patch, painted torn cuffs, charcoal trousers, brown shoes. Independently authored pixel placement and colors; reference used only for the general undead vibe. Roughness 0.59, specular IOR level 0.20, metallic 0.

Actions (24 FPS):
- Zombie_Idle: play frames 1-48, duplicate closing key 49, 2 seconds.
- Zombie_Walk: play frames 1-32, duplicate closing key 33, 1.333 seconds.
Exclude the duplicate closing frame when rendering continuous loops; include it as the export endpoint.

Both actions are original authored poses with periodic Bezier interpolation and phase offsets. Root is stationary and unkeyed. Hips, spine, chest, head, upper arms, forearms, hands, thighs and shins carry the action tracks. Both arms remain forward with different droop angles. Torso/head have delayed sway; walk uses staggered step timing, low clearance and uneven weight shifts rather than the player's coordinated opposite arm swing and athletic posture.

No bone hierarchy, bind-pose or vertex-weight changes. Only unlocked existing Hips, Spine and Thigh location channels for authoring. No runtime IK, constraints, drivers, cloth or simulation; ordinary location/rotation animation, with scale fixed at 1. Suitable for Godot skeletal playback; Godot runtime import not tested.

Validation after save/reopen: source mesh, UVs, bone hierarchy/rest matrices and weights match V5 exactly. New packed pixels preserved. All frames reviewed from the isometric camera, with 24 FPS full-loop GIF/APNG previews provided. Quarter-frame numeric sampling confirms rigid-edge errors below 0.000001 m, exactly matching first/closing vertices, and stationary Root. Action-switch checks pass.
Idle foot drift below 0.04 mm. Walk stance drift (after correcting for intended in-place travel at 0.48 m/s) below 9 mm; contact interpolation dips up to 1.9 mm below the floor. In-place stance feet travel backward by design: synchronize gameplay speed to the clip or adjust playback rate. No gross pose popping detected.

Transparent static previews: zombie_front.png, zombie_isometric.png, zombie_side.png.
Normal-speed loops: Zombie_Idle.gif, Zombie_Walk.gif. Transparent animated loops: corresponding APNG files.
Detailed measurements: zombie_validation.json. All-frame contact sheets supplied for visual review.
