# Damage, health and death feedback

Focused presentation pass, using the existing accepted damage events, HP, hurt grace, knockback, audio, collapse, EXP, progression and reset. No weapon/player assets, movement, combat stats or enemy behavior were redesigned. Nothing committed or pushed.

## Behavior

- Both actors flash red for 0.10 seconds: 35 ms at full strength, then a 65 ms fade. A shared transparent overlay preserves the original textures beneath a maximum 58% red blend. Cached body meshes get independent instance uniforms; no material is duplicated per hit. The overlay is removed when finished. Player weapon meshes are intentionally excluded from the body flash.
- The first accepted hit lazily creates one actor-owned, camera-facing health quad, 0.66 m wide and 0.095 m tall, 2.04 m above the actor root. HP updates immediately. It remains visible for 1.5 seconds after the latest hit, including a final 0.25-second fade. Additional hits restart the timer; hidden bars stop processing. A dark border/background and a green-to-red fill provide compact feedback. Main HUD HP remains unchanged.
- One bold, outlined integer number per accepted damage event. Enemy numbers are pale cream; player numbers are warm red. Numbers rise approximately 0.36 m over 0.65 seconds and fade over the final 0.25 seconds. Three alternating small horizontal offsets separate rapid hits. Numbers display the accepted event amount, including overkill, rather than HP clamped loss. Rejected grace/dead/nonpositive hits create no number.
- The existing zombie collapse finishes at the existing time. Before cleanup, its current fallen torso position is captured and eight original white/light-gray cubes burst there. Cubes spread outward, rise, grow by up to 55%, and fade over 0.70 seconds. EXP still appears at the original death location and time. The corpse disappears as the smoke starts.

Transient numbers and smoke belong to the scene's existing Combat/Effects container, surviving actor removal and disappearing on scene reset. Standalone actors can still show hit feedback without a combat director. Effects inherit gameplay pause; they do not write player animation poses.

## Files

Paths below are relative to `game_mobile_3d/`.

Changed:

- `materials/HitFlash.tres` — shared translucent red shader material.
- `scripts/cuboid_animation.gd` — fading per-mesh flash uniforms; unchanged pose logic.
- `scripts/cuboid_player.gd` — actor feedback creation and accepted-hit hook.
- `scripts/cuboid_zombie.gd` — accepted-hit hook and smoke emission before existing EXP/cleanup.
- `scripts/combat_director.gd` — small scene-local smoke spawn helper.
- `tests/validate_combat.gd` — allows longer-lived damage numbers after the short impact burst expires.

Created runtime resources:

- `materials/damage_flash.gdshader`
- `materials/overhead_health.gdshader`
- `materials/block_smoke.gdshader`
- `scripts/character_damage_feedback.gd`
- `scripts/damage_number.gd`
- `scripts/zombie_death_smoke.gd`

Created validation/documentation:

- `tests/validate_damage_feedback.gd`
- `docs/DAMAGE_FEEDBACK.md`
- `tests/damage_feedback_headless_validation.json`
- `tests/damage_feedback_rendered_validation.json`
- `tests/damage_feedback_regression_combat_headless_validation.json`
- `tests/damage_feedback_regression_animation_validation.json`
- `tests/damage_feedback_regression_progression_headless_validation.json`
- `tests/damage_feedback_hits.png`
- `tests/damage_feedback_bars.png`
- `tests/damage_feedback_gameplay_scale.png`
- `tests/damage_feedback_alternate_view.png`
- `tests/damage_feedback_smoke.png`
- `tests/damage_feedback_many_deaths.png`

Godot-generated `.uid` files accompany the seven new scripts/shaders, and `.png.import` files accompany the six captures. Earlier validation reports/captures were preserved; regression runs used temporary script copies under ignored `.godot/` with separate output paths.

## Performance approach

Shared quad/cube meshes, shader materials and bold font; cached actor/mesh references; one instanced draw per eight-cube smoke burst; no new textures, dynamic lights, physics particles, scene-tree scans per hit, bloom or volumetrics. Visible effects alone update. Transients are simple self-cleaning nodes, allowing later pooling without a framework now.

Forty-zombie desktop sample on the Mobile renderer, D3D12, RTX 4070 Ti SUPER: 120.03 FPS baseline, 119.91 during rapid feedback, 119.96 after recovery. Average draw calls rose from 116 to about 244 during the deliberately dense hit sample and returned to 116. Audio was suppressed for that visual-cost benchmark after separate audio-hook checks. This is a capped desktop sample, not a GPU/mobile budget measurement; process-monitor timings include engine scheduling and should not be interpreted as precise effect CPU cost. No phone was tested.

## Validation

- Dedicated suite: 46 headless checks and 53 rendered checks, all passed.
- Existing combat: 77 checks, passed, including swept hits, automatic fire, hurt grace, knockback, death, exact EXP accounting, defeat and reset.
- Existing progression: 85 checks, passed.
- Existing animation: 1,464 checks, passed.
- Dedicated cases include independent simultaneous hits, rapid-hit count/timeout refresh, smooth flash restoration, number lifetime, player feedback/HUD/audio, level-up pause/resume, final-hit collapse/smoke, 24 simultaneous deaths (192 cubes), exact drops, reset during feedback and 40-actor recovery.
- All three selected weapon models use the real shared projectile/recoil path successfully. M4A1 automatic firing was checked with the existing cadence. The project currently shares its automatic weapon stats/firing logic across models; this pass adds neither a distinct rifle rate nor shotgun pellets.
- Captures inspected at normal gameplay zoom, closer isometric framing and an alternate camera angle. `git diff --check` passed. Final rendered run shut down without leaked-object warnings.

## Retest

Open `scenes/CuboidGameplayTest.tscn` and press F6. Select a weapon; nearby zombies receive auto-fire hits. Walk within melee range to inspect player feedback, then move away to watch the overhead bar expire. Use 1/2/3 to switch models, K/J to spawn one/ten zombies, L to open the level-up pause, and R to reset. Inspect lethal hits for collapse → smoke/disappearance → unchanged cyan EXP pickup.

From the project directory:

```powershell
godot --headless --path . --fixed-fps 60 --script tests/validate_damage_feedback.gd
godot --path . --rendering-method mobile --rendering-driver d3d12 --fixed-fps 60 --script tests/validate_damage_feedback.gd -- --capture --benchmark
```

Use the installed Godot executable path if `godot` is not on PATH. Rendered mode checks audio hooks; this project deliberately disables audio in headless mode. D3D12 is the tested Windows driver; use the appropriate installed renderer driver on other platforms.

## Visual limits

Bars are intentionally small at normal gameplay zoom. Dense simultaneous hits can overlap floating numbers; no number-merging or pooling framework was added. Smoke cubes can overlap into a compact white cluster before spreading, and ordinary transparent sorting remains visible in dense bursts. The flash preserves texture detail but intentionally makes the whole body noticeably red. Actual device performance remains to be checked.
