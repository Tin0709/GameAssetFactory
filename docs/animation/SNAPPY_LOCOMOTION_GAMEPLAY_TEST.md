# Snappy locomotion gameplay test

Current scene: `game_mobile_3d/scenes/dev/SnappyLocomotionFastJumpTest.tscn`. Open it in Godot and press **F6**.

WASD/arrows move; Shift runs; Space jumps; Tab switches Snappy/Expressive;4 restores the original camera;R resets;F9 demos;F8 caps30/60 FPS. Walk3.0375 m/s, Run5.977875 m/s. Exact existing Expressive camera: orthographic size11.25,25 m relative distance, rotation(-36.315886,36.869898,0), offset(12,15,16). Existing2 m jump reused.

[Review movies, checks and evaluation](reviews/godot_snappy_locomotion_v001/fast_jump/README.md). [Preserved native-speed test](reviews/godot_snappy_locomotion_v001/README.md).

Single inherited pose writer, persistent gait phase, contact-aware handoffs, distance-driven cadence and bounded rigid-leg foot anchors. Fast version41 checks per30/60FPS; native version72. Desktop Mobile renderer only; artistic review and mobile hardware validation remain outstanding. Source Run has less vertical excursion/flight than the already hoppy Walk, so any remaining running-feel issue should be assessed in the source timing rather than hidden by additional blend layers.

All original Godot scripts/scenes/settings, approved Blender Actions and character rig remain unchanged. These are separate development scenes; production locomotion has not been replaced.
