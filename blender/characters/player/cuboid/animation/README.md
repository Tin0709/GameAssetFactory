# Original cuboid movement foundation

`player_cuboid_v5_movement.blend` contains three original actions on the existing V5 character. V5 remains unchanged. No external resource-pack files, formulas, timing or implementation were used.

| Action | Playback frames | Closing key / export range | FPS | Duration |
|---|---|---|---|---|
| Player_Idle | 1–48 | 49 / 1–49 | 24 | 2.000 s |
| Player_Walk | 1–32 | 33 / 1–33 | 24 | 1.333 s |
| Player_Run | 1–24 | 25 / 1–25 | 24 | 1.000 s |

The closing key duplicates the first pose. Blender playback excludes that duplicate; exporting through the closing key retains the intended duration. Actions have fake users, matching channel coverage, loop metadata, cyclic curves, and contact/down/passing/up pose markers. The file opens with Idle active.

Idle has 3 mm lateral body weight shift, 2.5 mm breathing, small shoulder and forearm overlap, and gentle head stabilization. Both leg sections remain fixed in world space while compensating the tiny hip motion. Walk has relaxed opposite arm swing, alternating contact/down/passing/up poses, approximately 33 mm vertical hip variation, hip/chest counter-rotation and delayed forearms/hands. Run increases stride and arm swing, knee lift, vertical hip variation (approximately 100 mm), forward chest lean (about 10 degrees), and brief airborne passing phases. Small side differences and phase offsets avoid exact mirrored motion.

Main animated bones: Hips, Spine, Chest, Head, UpperArm.L/R, Forearm.L/R, Thigh.L/R, Shin.L/R. Hand.L/R have mild delayed attachment rotations for future held items; visible hand follow-through is through the existing rigid forearm geometry. Idle includes constant shin reset keys and compensating thigh channels for planted feet. Root, Neck and Foot bones have no unnecessary animation tracks. No scale tracks, simulations, drivers, or runtime constraints are used.

Rig adjustment: only location authoring locks were unlocked on Hips, Spine and Thigh.L/R. Bone count (18), names, hierarchy, bind matrices and weights are unchanged. Mesh, proportions, UVs, V5 pixel atlas and material are verified identical. The character remains 120 triangles with one 64×64 atlas material. All rectangular mesh sections retain their edge lengths during every sampled pose; joints move by rigid transforms.

Validation sampled each loop at quarter-frame intervals, tested exact first/closing poses, root stationarity, rigid geometry, unit scales, action switching, and the unchanged source file. First/closing mesh error is zero for all three actions; maximum edge-length error is below 0.000001 m. Head world rotation stays below 0.8 degrees. Every playback frame was rendered from the isometric camera and reviewed in chronological frame sheets; looping previews are packaged at normal 24 FPS. See `movement_validation.json`, `actions.json`, and `preview_report.json` for exact results.

Foot contact observations: Idle ankle displacement is approximately 0.000002 m. Walk stance drift is at most 0.0073 m; Run at most 0.0253 m, measured after subtracting the intended in-place ground travel. Lateral stance drift is below 0.0003 m. Rectangular soles roll during support; sparse interpolation has approximately 1.4 mm walk / 2.9 mm run subframe ground penetration tolerance and intentional toe-off lift. These are in-place cycles: backward support-foot travel is expected. Match game movement speed and playback rate to the authored ground rates (Walk approximately 0.60 m/s, Run approximately 1.68 m/s) to limit sliding in Godot. Runtime Godot import/playback has not been tested here.

`Player_Idle.gif`, `Player_Walk.gif`, `Player_Run.gif` are normal-speed loops with a dark preview background. Corresponding `.apng` files preserve transparency. GIF frame delay quantization produces a 1.330 s walk preview; the Blender action and APNG retain the 1.333 s timing. `movement_preview.html` shows all three transparent loops. Full PNG sequences, key-pose sheets and all-frame sheets are included. The contact solve exists only in the authoring recipe; final actions use ordinary lightweight skeletal translation/rotation keys.
