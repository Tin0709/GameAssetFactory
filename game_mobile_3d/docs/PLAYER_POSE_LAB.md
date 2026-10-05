# Player Pose Lab (development only)

Open `scenes/PlayerPoseLab.tscn` in the existing project and run that scene (F6).
The normal main scene remains `CuboidGameplayTest.tscn`; no gameplay menu or
startup flow links to the lab. It can also run independently with:

```powershell
godot --path game_mobile_3d res://scenes/PlayerPoseLab.tscn
```

The lab contains one current player visual with the existing Animation Runtime
V2 and weapon socket, a flat floor, simple bright lighting, an orbit camera and
a compact control panel. It does not instantiate CuboidPlayer's gameplay
controller, automatic firing, damage, zombies, spawning, combat or progression.

## Controls

Every action is also available as a clickable button.

| Control | Action |
| --- | --- |
| 1 / 2 / 3 | Pistol / M4A1 / Shotgun |
| I / W / R | Idle / Walk / Run, physically in place |
| L / A | LowReady / Aim, independently of locomotion |
| F | Real selected-weapon recoil, without projectiles or damage |
| Space | Freeze current pose / resume |
| . | Advance one animation frame while frozen |
| N / H / Q | 1x / 0.5x / 0.25x playback |
| Right mouse drag | Orbit (horizontal and vertical) |
| Mouse wheel | Zoom in/out, distance clamped to 1.4–8m |
| C | Reset camera to the close 3/4 view at 3.8m |
| V | Cycle Front / Side / Rear / 3/4 / Isometric |

Camera buttons offer presets, horizontal orbit and zoom without mouse dragging.
R selects Run in this isolated scene; it does not reset a gameplay run.

While frozen, locomotion/Aim choices are queued until a frame step or resume.
F triggers/queues the existing recoil impulse; step to inspect it frame by frame.
Weapon selection changes the visible model immediately and its stance blend
continues on step/resume. Use freeze after a settled switch to inspect contact.
The HUD distinguishes the requested preview from the currently evaluated pose.

## Lab-only overrides

`scripts/player_pose_lab.gd` is an adapter, not a second animation system:

- Disables automatic processing only on this scene's visual controller and
  becomes its sole clock. Calls production `update_motion` / `_process` with
  delta multiplied by the selected playback rate.
- Supplies synthetic forward velocities at 0 / 4.25 / 6.25m/s without moving
  the player node, preserving the production gait, lean and locomotion layers.
- Sets the existing `has_target` input after motion update to preview Aim
  without any enemy/target node.
- Uses production `equip_weapon` and `shot_recoil`, including the existing
  hold tuning, weapon categories, switching and recoil queue behavior.
- Freezes by skipping clock advancement; neither SceneTree pause nor the
  production defeat/frozen flag is used. Camera/UI remain interactive.

No overrides or new fields were added to the production controller. Its
implementation and the normal gameplay scene/configuration were not changed.

## Validation

143 checks passed headless and with Godot 4.7.2 Mobile / D3D12 rendering.
Verified isolated scene loading, absence of gameplay actors/services, all three
weapons, one visible model, Idle/Walk/Run, LowReady/Aim without enemies,
standing/moving real recoil, playback-rate clock scaling, frozen bone poses,
single-frame stepping, keyboard/mouse button routing, and camera preset,
orbit, zoom and reset while frozen. Reviewed close rendered screenshots for
each weapon. Physical phone hardware was not tested.

```powershell
godot --headless --path game_mobile_3d --script res://tests/validate_player_pose_lab.gd
godot --path game_mobile_3d --script res://tests/validate_player_pose_lab.gd -- --capture
```

Reports: `tests/pose_lab_headless_validation.json` and
`tests/pose_lab_rendered_validation.json`. Captures: `tests/pose_lab_pistol.png`,
`tests/pose_lab_m4a1.png`, `tests/pose_lab_shotgun.png`.

## Added files

- `scenes/PlayerPoseLab.tscn`
- `scripts/player_pose_lab.gd`
- `tests/validate_player_pose_lab.gd`
- This document and the five validation JSON/PNG artifacts above.

All changes are new lab-specific files. Blender assets, player/weapon meshes,
production Animation Runtime V2, gameplay scene behavior/tuning, spawning,
combat, progression, HUD and startup weapon selection remain unchanged.
