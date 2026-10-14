# GameAssetFactory

Blender sources, original game assets, animation research and the Godot mobile project.

- [MacBook / Windows setup](docs/setup/MACBOOK_SETUP.md)
- [Cleanup results and validation](docs/setup/CLEANUP_RESULT_2026_10_14.md)
- [Initial repository audit](docs/setup/REPOSITORY_AUDIT_2026_10_14.md)
- [Development instructions](AGENTS.md)
- [Animation progress](docs/animation/ANIMATION_PROGRESS.md)
- [Snappy gameplay test](docs/animation/SNAPPY_LOCOMOTION_GAMEPLAY_TEST.md)

Use Git LFS when cloning. Start from `python3 scripts/dev.py doctor`; open Godot with `python3 scripts/dev.py godot --editor`, or Blender with `python3 scripts/dev.py blender --showcase animation` / `--showcase weapon`. On Windows use `python` and the existing wrappers. No production gameplay is changed by setup tools.

See the setup guide for the validated cleanup snapshot, clone instructions and manual Mac smoke tests. Confirm the Git commit against the synchronization handoff before moving development to another machine.
