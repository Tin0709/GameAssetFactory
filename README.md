# GameAssetFactory

Blender sources, original game assets, animation research and the Godot mobile project.

- [Windows handoff — current Sword/Rifle lab, 25/10/2026](docs/setup/WINDOWS_HANDOFF_2026_10_25.md)
- [MacBook / Windows setup](docs/setup/MACBOOK_SETUP.md)
- [Cleanup results and validation](docs/setup/CLEANUP_RESULT_2026_10_14.md)
- [Initial repository audit](docs/setup/REPOSITORY_AUDIT_2026_10_14.md)
- [Development instructions](AGENTS.md)
- [Animation progress](docs/animation/ANIMATION_PROGRESS.md)
- [Snappy gameplay test](docs/animation/SNAPPY_LOCOMOTION_GAMEPLAY_TEST.md)

Use Git LFS when cloning. Start from `python3 scripts/dev.py doctor`; open Godot with `python3 scripts/dev.py godot --editor`, or Blender with `python3 scripts/dev.py blender --showcase animation` / `--showcase weapon`. On Windows use `py -3`; `Open_Combat_Lab.cmd` or `py -3 scripts/dev.py godot --scene combat --weapon sword` opens the current lab. Private Fiery data transfers separately outside Git. No production gameplay is changed by setup tools.

See the setup guide for the validated cleanup snapshot, clone instructions and manual Mac smoke tests. Confirm the Git commit against the synchronization handoff before moving development to another machine.
