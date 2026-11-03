# GameAssetFactory

Blender sources, original game assets, animation research and the Godot mobile project.

- [Current Windows Desktop workspace](docs/setup/DESKTOP_DEV.md)
- [Windows handoff — Sword/Rifle lab snapshot, 25/10/2026](docs/setup/WINDOWS_HANDOFF_2026_10_25.md)
- [MacBook / Windows setup](docs/setup/MACBOOK_SETUP.md)
- [Cleanup results and validation](docs/setup/CLEANUP_RESULT_2026_10_14.md)
- [Initial repository audit](docs/setup/REPOSITORY_AUDIT_2026_10_14.md)
- [Development instructions](AGENTS.md)
- [Animation progress](docs/animation/ANIMATION_PROGRESS.md)
- [Snappy gameplay test](docs/animation/SNAPPY_LOCOMOTION_GAMEPLAY_TEST.md)

Use Git LFS when cloning. Start from `python3 scripts/dev.py doctor`; open Godot with `python3 scripts/dev.py godot --editor`, or Blender with `python3 scripts/dev.py blender --showcase animation` / `--showcase weapon`. On Windows use `py -3`; `Open_Combat_Lab.cmd` or `py -3 scripts/dev.py godot --scene combat --weapon sword` opens the current lab. Private Fiery data transfers separately outside Git. No production gameplay is changed by setup tools.

See the setup guide for the validated cleanup snapshot, clone instructions and manual Mac smoke tests. Confirm the Git commit against the synchronization handoff before moving development to another machine.

## Open the current labs (Windows)

Open `game_mobile_3d/project.godot` in Godot, then choose the scene for the test you want:

| Test | Scene to open before pressing F6 | Direct launcher |
| --- | --- | --- |
| Player locomotion and Sabre combat | [ActionsStuffWalkRunTest.tscn](game_mobile_3d/scenes/dev/ActionsStuffWalkRunTest.tscn) | Double-click `Open Sabre Prototype.cmd` in this repository; it selects Sabre mode. |
| Private MD2 Overworld meadow | [MD2OverworldFidelityTest.tscn](game_mobile_3d/scenes/dev/MD2OverworldFidelityTest.tscn) | Double-click `Open Overworld Meadow.cmd` in this repository. |

**F6 runs the selected scene. F5 runs the project's main scene, `WorldMap.tscn`, rather than the selected lab.** Use `Open Sabre Editor.cmd` to open the combat scene in the editor.

The Overworld launcher uses the private bundle at `%USERPROFILE%\Desktop\MD2 Research\godot_lab\overworld_fidelity_v001\bundle.private.json`. Set `MD2_OVERWORLD_BUNDLE` to use a different bundle location; an existing override is preserved. Models, textures and audio remain private and outside this repository. A Git clone alone does not restore them; keep the Research workspace separately and do not copy its proprietary files into `res://` or distributable builds.

Use `py -3 scripts/dev.py godot --scene overworld` to play, or add `--editor` to open the scene in Godot. To check the selected scene and executable without starting Godot, add `--dry-run`; the Windows launcher also accepts `--dry-run` and `--editor`.

Run `py -3 scripts/dev.py scenes` to list scene aliases and check that their scene files exist, even before installing Godot. This checks scene files only; it does not validate imported assets or private research bundles. Use `py -3 scripts/dev.py godot --help` for launch options.

`py -3 scripts/dev.py doctor` also reports whether `project.godot` and the configured private Overworld bundle file exist. The bundle report preserves `MD2_OVERWORLD_BUNDLE` overrides and shows whether the path is absolute; it does not read asset contents or validate the bundle schema.
