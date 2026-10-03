# Survivor — first playable slice

Open `game/project.godot` in Godot 4 and press **F5**. The configured main scene is `scenes/main.tscn`.

- **WASD / arrow keys:** move freely in eight directions; diagonals have the same speed as straight movement.
- The starting pistol automatically aims at the nearest living zombie within 650 pixels and fires every 0.5 seconds.
- Zombies chase, deal contact damage, and die after three pistol hits. Hits flash their sprite and display remaining HP.
- Walk over the green gems dropped by dead zombies to collect EXP. The first level costs 5 EXP; each later requirement grows by 3. Excess EXP carries forward, including through multiple levels.
- You start with 100 HP; contact deals 10 damage with 0.75 seconds of protection between hits. **R** restarts after death.
- One zombie spawns immediately, then one every 2 seconds around the player, up to 45 active zombies. The arena is open and the camera follows the player.
- The HUD shows level, EXP progress, HP, pistol stats, kills, active zombies, and survival time.

## Structure

```text
game/
  project.godot
  scenes/
    main.tscn          # Arena, player, spawn timer, HUD
    player.tscn        # CharacterBody2D, pistol, follow camera
    zombie.tscn        # CharacterBody2D and animated sprite
    bullet.tscn        # Bullet with swept physics hit detection
    exp_pickup.tscn    # Area2D collection trigger
    hud.tscn          # CanvasLayer display
  scripts/
    main.gd           # Spawning, death drops, restart
    player.gd         # Movement, HP, EXP, level rollover
    zombie.gd         # Chase, animation, HP, hit/death feedback
    pistol.gd         # Nearest target and fixed fire interval
    bullet.gd         # Straight flight, collision, damage, lifetime
    exp_pickup.gd     # One-time EXP collection
    hud.gd            # Stats display
    sound.gd          # Persistent Sound autoload and audio hooks
  assets/
    zombie/           # Idle/walk PNGs and shared animations.tres
    audio/            # Six reused gameplay MP3s
  tests/
    smoke_test.*      # Headless physics integration checks
    render_preview.*  # Optional GPU screenshot check
```

## Assets and audio

The 24 idle and 24 walk PNGs are copied unchanged from `../exports/zombie/`. The shared SpriteFrames resource reuses the pipeline test's 24 FPS animation definitions. Sprite scale is 0.35 with a foot-positioned collider; zombies flip horizontally when chasing left.

The Sound autoload creates six named AudioStreamPlayer nodes: `pistol_shot`, `bullet_impact`, `zombie_hit`, `zombie_death`, `exp_pickup`, and `level_up`. All six use existing files copied from `../audio/game/`. Calls use `Sound.play(&"event_name")`; a missing stream is silently skipped. Add or replace matching `.ogg`, `.wav`, or `.mp3` files under `assets/audio/` to change the sounds. Headless validation loads the hooks but skips playback.

## Validation

From the `GameAssetFactory` directory, with your Godot executable available as `godot`:

```powershell
godot --headless --path game --editor --import --quit
godot --headless --path game res://tests/smoke_test.tscn --quit-after 600
godot --headless --path game --quit-after 300
```

The smoke test exits with code 0 and `SMOKE TEST: 0 failures` when checks pass. It covers continuous spawning, normalized movement, animation and flipping, nearest-target automatic fire, real bullet damage and kills, death drops, physics pickup collection, multi-level EXP rollover, damage protection, death, and R restart.

For an optional rendered screenshot, create `game/.validation/`, then run:

```powershell
godot --path game res://tests/render_preview.tscn --quit-after 600
```

The screenshot is saved as `.validation/preview.png`. `.godot/` and `.validation/` are generated local data and are ignored. Validation used the locally installed Godot 4.7.2 executable.

This slice has a single pistol and level progress only. Leveling does not yet grant upgrades. There are no menus, upgrade choices, bosses, saves, or networking.
