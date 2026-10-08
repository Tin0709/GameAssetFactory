# Project guidance

- Before graphics, environment, camera, material, character, animation, VFX or mobile-performance work, read `docs/graphics/ART_DIRECTION.md` and the relevant sections of `docs/graphics/RESEARCH.md`. Follow their links to existing asset guides; do not duplicate the research into new reports.
- Inspect current `game_mobile_3d/project.godot`, scene resources and script inheritance. Older reports can describe superseded scenes/assets. Distinguish user-approved decisions, proposals, source observations and measured results; only explicit user confirmation establishes artistic approval.
- Preserve selected character proportions/full arms and hands, original Blender sources, and the established grass/no-fog decisions unless the user changes them. Keep experiments scene-local; research completion does not authorize wholesale renderer/architecture changes.
- Capture the baseline, change one visual group, compare the same camera/pose and inspect actual Godot pixels. Animation needs an in-game clip. Headless/import success does not prove visual quality; desktop performance does not prove phone performance.
- User target is 30 FPS; minimum phone remains unspecified. Run automated Godot tests silently with `--audio-driver Dummy` (or a test-process-only mute). User playtest launches must use normal audio; do not persistently mute the project/system.

