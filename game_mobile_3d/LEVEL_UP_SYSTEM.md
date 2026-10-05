# Level-up and upgrade selection prototype

Open `project.godot` and press F5. Kill zombies and collect three cyan drops to earn the first selection. Click/tap a card, or press 1/2/3, to choose. R resets from gameplay or while selecting. Debug builds only: L grants exactly the EXP remaining to the next threshold; `Progression.debug_exp_shortcut` disables this test shortcut. The [SpawnDirector](SPAWN_DIRECTOR.md) now provides continuous enemies and natural EXP for subsequent levels; L remains optional for isolated testing.

## EXP and state flow

Player owns `level` (starts 1), `experience` (progress inside the current level, starts 0), and `total_experience` (debug/accounting cumulative total). Existing player movement/HP values stay on the player; damage, intervals, speed, acquisition range, travel range and lifetime stay on Pistol.

`level_progression.gd` owns the threshold formula, pending selections, RNG and pause/resume flow. Inspector defaults: `base_requirement=3`, `requirement_growth=2`. Required EXP is `max(1, base_requirement + (level - 1) * requirement_growth)`: 3, 5, 7, 9...

Each positive gain finishes processing all thresholds before opening UI. Thresholds are subtracted from progress and the level increases; excess EXP is retained. Example 2+3 EXP at Level 1 becomes Level 2 with 2/5 progress. A fresh 17 EXP becomes Level 4 with 2/9 progress and three pending selections. Titles identify the earned level for each successive choice, while the HUD already shows the fully processed level/progress.

On a threshold: mark selection open, choose three unique entries with partial Fisher-Yates using a scene-local RNG, pause the SceneTree and show the overlay. Further gains and direct fire are rejected during selection. Pausable gameplay nodes freeze movement, physics, projectiles and age timers, attacks/cooldowns, skeletal playback, pickup bob/travel, recoil, impact and death tweens. The overlay, coordinator and two menu audio players run during pause. After a valid choice, lock input, apply effects once and highlight the selected card for 100ms. If selections remain, reuse the same three buttons for the next choice while staying paused. Otherwise hide the overlay and resume. Duplicate/echo input cannot apply an upgrade twice. R reloads a clean scene and clears the paused state, stats and pending choices.

## Upgrade pool

`upgrade_catalog.gd` contains five entries, names/descriptions and small effect dictionaries targeting player/pistol properties. Add another entry and its numeric effects to extend the pool without changing UI or selection logic. Current to new values are calculated from actual stats whenever a selection opens. Upgrades stack and can return on later levels, with no duplicates within one offer. Entries whose effects can no longer improve stats are omitted; capped Rapid Fire leaves four available entries, so three choices remain available.

| Upgrade | Effect |
|---|---|
| POWER SHOT | Pistol damage +5; 20 → 25 → 30... |
| RAPID FIRE | Interval ×0.9; minimum 0.18s; remaining cooldown also clamps to the new interval |
| RUNNER | Walk and run ×1.08; acceleration, braking, normalized input and animation sync remain in use |
| TOUGHNESS | Max HP +20; heal 20 clamped to the new max; e.g. 50/100 → 70/120 |
| BALLISTICS | Projectile speed, explicit travel range and target acquisition range ×1.1 |

Baseline acquisition range is 8m; baseline travel range is 12.6m (the existing 14m/s ×0.9s lifetime). These are different limits and both are displayed honestly. Bullet collisions still sweep the traveled segment. Travel range now has an explicit distance counter/limit, while lifetime remains a safety cleanup bound. Speed and travel are multiplied together by Ballistics, so the existing lifetime remains suitable.

## UI and audio

One `UpgradeSelection.tscn` instance contains a dim backdrop, title/help and grid. Exactly three Buttons are constructed once per scene and reused. At 1280×720 they are arranged in three columns, approximately 393×244 logical pixels each. Narrow logical viewports below 850px use a vertical layout, with at least 132px card height (long text can increase it). Container layout, wrapping and viewport anchors keep cards readable at the tested 1280×720, 1560×720 and 720×1280 sizes. The overlay captures mouse input, keeps keyboard focus, and its buttons use Godot's normal GUI input for mobile touch. There is no blur, dynamic light or UI particle effect. Selected cards briefly tint cyan.

HUD now shows Level, HP, living zombies, speed and FPS, plus a cyan EXP bar and progress text. Bottom HUD elements anchor to the viewport bottom. The underlying game HUD remains frozen/dimmed during selection; the overlay remains interactive.

Existing `audio/game/Level up.mp3` and `Upgrade selected.mp3` are copied into runtime assets and connected to their named events. Original recordings are unchanged. Menu players work while paused and are capped to one simultaneous voice per event; existing same-event throttling also applies. Reset/scene teardown stops voices. Compressed audio is intentionally skipped by the existing headless driver workaround, while resource loading is still checked.

## Files for this pass

Created:
- `scripts/level_progression.gd`
- `scripts/upgrade_catalog.gd`
- `scripts/upgrade_selection.gd`
- `scenes/ui/UpgradeSelection.tscn`
- `assets/audio/level_up.mp3`, `upgrade_selected.mp3` and generated import sidecars
- `tests/validate_progression.gd`, validation reports and three aspect-ratio previews
- This guide and generated script UID sidecars

Updated:
- `scripts/cuboid_player.gd`: level/progress ownership and EXP delegation
- `scripts/auto_pistol.gd`: explicit travel-range stat
- `scripts/pistol_projectile.gd`: range counter/expiry
- `scripts/combat_director.gd`: paused-fire guard and range snapshot
- `scripts/combat_audio.gd`: two paused-menu audio hooks
- `scripts/gameplay_test.gd`: Level/EXP HUD and debug-build help
- `scenes/CuboidGameplayTest.tscn`: coordinator, HUD bar/text and overlay instance
- `assets/audio/audio_manifest.json`: copied audio provenance
- `tests/validate_combat.gd`: ten audio resources; isolate cumulative combat accounting from progression
- Existing combat/gameplay/mobile guides and generated validation results

Character GLBs/Blender files, zombie model and behavior, arena geometry, camera, renderer, polished movement defaults and existing hit/attack/death feedback are preserved. Earlier movement-polish files remain part of the current project.

## Validation

From the project folder, replacing `godot` with the executable:

```text
godot --headless --path . --script res://tests/validate_progression.gd
godot --headless --path . --script res://tests/validate_combat.gd
godot --headless --path . --script res://tests/validate_gameplay.gd
godot --headless --path . --script res://tests/validate_polish.gd
godot --path . --rendering-method mobile --rendering-driver d3d12 --resolution 1280x720 --script res://tests/validate_progression.gd -- --capture
```

The progression suite checks real pickups, actual three-kill/drop/collect/level integration, progress HUD, threshold and overflow math, three pending level-ups, unique offers, three reused buttons, every upgrade via the selection flow, stacking, Rapid Fire floor, wounded/full Toughness, normalized upgraded sprint, actual weapon snapshots/range expiry, full physics/presentation pause, actual GUI mouse routing, keyboard 1/2/3, debug L, and R both after stacked upgrades and while paused. Rendered checks also verify card bounds/touch sizes at three aspect ratios and save previews. Passed on Godot 4.7.2: 85 headless progression checks, 95 rendered progression checks, 77 combat checks, 354 movement/import checks, and 42 polish checks. JSON reports record check totals. Tests clean up the scene and drain audio before shutdown.

The combat regression disables progression to separately verify 15-drop/15-EXP accounting without opening upgrade UI. The progression suite tests the combined flow. Existing movement/import and polish suites verify previous behavior still works.

## Limits and mobile budget

This is a scene-local, transient prototype: upgrades reset with R and there is no save/meta progression. The SpawnDirector adds continuous perimeter enemies up to 40 active. No discrete waves, inventory or new weapon systems. Overflow and multiple pending levels are also covered by debug grants and tests.

Three reusable buttons and a dim screen quad add a small UI cost; no gameplay per-frame progression scan. Randomization and value formatting happen only when opening a selection. UI feedback uses one short tween. Physical phone/touch-device testing, notch-safe margins and exported mobile builds remain untested; desktop captures verify logical layouts and Mobile rendering, not phone GPU/audio performance. The inherited shadows, audio decoding and frequent effects at very low fire intervals should be profiled on target devices before scaling enemy counts.
