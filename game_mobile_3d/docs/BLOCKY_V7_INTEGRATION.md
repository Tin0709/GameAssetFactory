# Authored blocky V7: first Godot integration

Source GLB: `../../blender/characters/player/cuboid/export/player_cuboid_animated_v1.glb`.
Godot GLB: `../assets/characters/player_cuboid_animated_v1.glb` (byte-identical).

`CuboidPlayer.tscn` retains the original CharacterBody3D, collision, controller,
Pistol and WeaponDebug. Only Visual's script and Model resource change. The
previous player scene is preserved as `CuboidPlayerBeforeBlockyV7.tscn`; restore
its contents to the original scene path for rollback. Old model assets remain.

`player_blocky_v7_integration.gd` extends Runtime V2. It checks all ten rest
bases against the old model, imports the old Walk/weapon clips, and copies the
existing non-deforming WeaponSocket under Chest into the runtime skeleton.
There is one live skeleton; the temporary legacy instance is freed immediately.
Blender files and GLB skeleton/animation data are not changed.

Runtime V2 has an opt-in authored_locomotion flag, default off everywhere else.
Idle and Run use the new clips. Walk and combat behavior use the existing clips
and socket composition. The existing 0.13s move/run/aim weights drive blending
from actual velocity. Run's independent seconds clock advances continuously at
1x, including turns, with no cadence calibration or restart. Walk still uses
its existing cadence. No AnimationTree or competing pose writer was added.

For un-aimed Idle/Run, the final body pose fades to the authored clip, removing
the old procedural secondary motion and hand-hold override from that preview.
Existing aim/recoil and weapon sockets remain active during combat. A running
character's freely swinging hands are not attached to the weapon; the gun stays
on its existing Chest socket. Final authored hand/weapon presentation needs a
later weapon pass. Firing gates, projectile origins and weapon switching work.

The dedicated post-import hook enables Idle/Run loops. Idle=2s;
Run=0.6666666865s (16/24), no extra closing-frame hold. Native GLB +Z faces
movement via the existing face_direction function; no orientation correction,
gameplay rotation change, bone rotation fix or scale adjustment was needed.

Speeds are unchanged: Walk 4.25 m/s, Run 6.25 m/s, combat movement 2.6 m/s.
At full Run speed the body travels 4.166667m per authored cycle. The near-ground
support-corner velocity is positive along travel: visible forward foot sliding.
The sample median is recorded in tests/blocky_v7_integration_validation.json;
rigid corner changes can produce spikes. Neither speed nor animation was tuned.

Validation: 35 integration checks in headless (including final rotation/scale
checks), 34 in D3D12 Mobile rendered mode,
plus the existing 798 movement/weapon regression checks. Start/stop, direction,
full-speed Run, preserved Walk, floor/wall collision, active camera, textures,
three firing profiles and socket muzzle positions pass. The Run clock and Root
translation error are zero; body positions match imported Run within 2e-9m.
Godot did report sandbox user:// shader-cache/editor-settings write warnings;
the rendered game itself and tests ran. No phone/device performance test was made.

Review: run the existing CuboidGameplayTest main scene, choose a weapon, use
WASD and Shift. Captured gameplay views and a short actual-motion GIF are in
tests/blocky_v7_*. No controller, camera, combat, enemy or speed code was edited.
