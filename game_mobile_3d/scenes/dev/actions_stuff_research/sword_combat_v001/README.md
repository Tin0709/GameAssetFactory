# Sword combat lab — playable Pending review

The existing `res://scenes/dev/ActionsStuffWalkRunTest.tscn` now switches between the approved Rifle and a playable three-hit Sword system. It uses the requested **Sword Sand Block V1** and SOLDIER appearance. WorldMap/F5 remains unchanged.

## Launch and controls

Open that scene in the existing Godot project and press **F6**. Click **Sword** or **Rifle** at the bottom; **Tab** also switches. Normal audio is enabled when playing from the editor.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path "$HOME/Desktop/Game Dev/GameAssetFactory/game_mobile_3d" res://scenes/dev/ActionsStuffWalkRunTest.tscn -- --sword
```

- Sword: E or left click attacks; hold for repeated three-hit chains, or tap near recovery to buffer the next hit. Right mouse guards; a fresh timed guard parries. F rolls along WASD, otherwise along facing. Middle drag orbits.
- Movement: WASD, Shift run, Space jump, Q/C turn, wheel zoom and R reset retain the lab's controls. Rifle keeps E aim/automatic fire and right mouse aim/orbit.
- Existing spawn controls add batches and Kill All retains simultaneous native deaths. Sword mode enables practice damage, stamina and temporary knockout; switching Rifle restores its prior invulnerable practice behavior.

## Current selected motion: private Fiery source study

The user's 2026-10-25 correction selects the actual motion shown in `Fiery_Combat_Private_Research.blend`, replacing the independently authored combo **for this private lab test**. `sword_private_reference_enabled=true` loads a user-owned external AnimationLibrary from the sibling directory:

`../../private_research/fiery_combat_20261025/godot_lab/fiery_retarget_library.res`

That library and its source JSON, private Blender retarget, fixtures and provenance remain outside GameAssetFactory and Git. The enabled research export guard excludes the entire dev scene/subtree. The independent original library in this directory and its eight Pending Blender Actions remain preserved; they are the fallback if private data is unavailable, with a warning. No protected Fiery tracks were copied into this directory.

Verified source selection:

| Runtime clip | Actual Fiery track | Source duration |
|---|---|---:|
| Attack1/2/3 | `sword.attack_1/2/3` plus matching overrides | 1.2917s each |
| Roll | `roll` plus matching override | 0.6667s |
| Ready | `sword.base_pose` plus override | 10000s loop, sparse constant tail |
| Guard | `sword.move_guard` plus override | 10000s loop, constant pose |

`base_guard` has an unexplained Root −24-pixel offset requiring another base layer; the readable compatible `move_guard` is selected instead. Parry-success and Hurt remain our original candidate poses. The private evaluator retains raw Euler winding, source translations, paired-override order and changing `rightItem` rotation. Dense sampling preserves Roll's 390.48° overshoot and 360° endpoint. The final rigid palm remains attached to our character's actual arm, and the new sword receives its GLB axis conversion once.

This is a retarget onto a different body, not Bedrock engine emulation. Private documentation records changed pivots, source floor overlap, omitted held-item translation, and unverified additional `roll_head`/controller fades. The existing Godot contact, interpolation and locomotion pipeline still operates. Source export parity does not imply identical rendering or world physics.

## Explicit gameplay adapters

The following are adjustable original gameplay choices, not claims about Fiery or MD2 numerical values:

- Requested chain is 1→2→3; Fiery's source behavior sequence is 1→2→1→3. Attack clock uses `config.attack_speed=1.15`, consistent with source variable-speed playback; use 1.0 for source-time review. Roll uses real seconds.
- Private active sweeps are .35–.48 / .28–.48 / .35–.48 source-clock seconds, measured against the retargeted blade. Attack2 crosses the forward target earlier. Source BP's .4 damage gate is documented separately; it is not substituted for physical blade contact here.
- Combo cancel openings are .88/.88/1.05; buffered chains start at 1.03/1.03. Original buffer is .22 real seconds. Damage is 17/20/32, capped at eight nearest accepted targets per swing, once per target, with terrain line-of-sight.
- Guard cone, .18s parry window, stamina, directional physical roll, invulnerability, lunge, poise, hit-stop and camera feedback are controller-owned. Real hits alone trigger impact feedback; whiffs do not freeze the player. Global time scale is unchanged.

Edit the scene's `sword_config` Resource (`settings.tres` / `config.gd`) for damage, speed, defense, movement, feedback and VFX budgets. The native zombie death/ragdoll system is reused. Effects use one fixed 256-slot MultiMesh, a bounded ribbon, six synthesized audio voices and eight child nodes; medium quality limits active effects to160. No per-hit nodes, tweens, materials or dynamic lights are created.

## Validation and performance

Evidence is under `.validation/sword_combat_v001/` (ignored by Git). Actual private-scene tests pass at30/60Hz: each source attack hits the forward target exactly once, dynamic item rotation retains its palm, Roll preserves gait phase, and Rifle resumes movement facing. Original state, physical hit, defense, reset, effect-cap and switch tests pass. Existing Rifle fire/recoil/grip tests pass at30/60; jump, movement-turn and465-check crowd/spawn/cleanup regressions pass. Native Metal captures verify the visible new sword, source poses, accepted impacts, guard, Roll and Rifle switch-back.

The severe attack stall came from rebuilding the complete turn-controller VM every physics tick, not damage queries or particles. Reusing the compiled runtime reduced the same20-target native whiff benchmark from278ms median to9.77ms, with eight catch-up ticks/frame reduced to one. A first-use cold frame can still hitch.

A separate clean short100-live-zombie test on this M2 Pro, Mobile/Metal1280×720, full14,831 grass clumps and camera14.5, averaged120.30FPS stationary attacks,119.18 walking attacks and117.32 running attacks. Corresponding frame p95 was15.60/15.96/16.71ms: near120 average does **not** establish uniformly120FPS frame pacing. Test fixture used100000 enemyHP and incoming damage0 so attacks could continue; AI/collision/attack animation remained active. No physics catch-up, warmed pipeline compilation or pool growth occurred. This is a short Mac measurement, not mobile certification. Full lab reset still rebuilds the selected spawn batch and can briefly stall.

Approved source Actions, source weapons, SOLDIER assets, WorldMap and the shared player physics remain preserved. The central Blender Showcase contains eight additional independently named Pending original actions, with its93 previous action signatures and58 previous entries preserved.
