# Windows workspace on Desktop

The user selected `C:\Users\ADMIN\Desktop\Dev` as the canonical development
location on 26 October 2026. The current workflow uses this existing checkout on
`main`, tracking `origin/main`, following the user's 1 November direction in
`AGENTS.md`. Preserve `codex/sword-combat-v001` and its complete Git/LFS history;
it is a historical branch, not the current default.

Open `game_mobile_3d/Open Sabre Editor.cmd`, then press F6. The selected scene is
`scenes/dev/ActionsStuffWalkRunTest.tscn` and starts the Valorie/Sabre prototype.
`Open Sabre Prototype.cmd` starts play directly. F5 still opens WorldMap.
The return button retains the older Rifle/Sword experiment.

For the private meadow, use `Open Overworld Meadow.cmd` at the repository root,
or `py -3 scripts/dev.py godot --scene overworld`. Add `--editor` to open its
existing scene in Godot. See the root README for external bundle setup;
`py -3 scripts/dev.py doctor` reports its configured path and file availability.

The original MD2 player, Sabre, rig, clips and audio remain exclusively under
`%USERPROFILE%\Desktop\MD2 Research`. The dev lab loads them transiently; the
repository contains implementation code and an independently authored fallback.
Do not add private source files, captures or backup archives to the public repo.
The existing research export guard excludes the dev scene/module from builds.

The former C-drive working copy was consolidated by content hash: 11,580 files,
8,173,050,365 bytes. Original versions and import/validation caches were retained
outside Git in the sibling `Dev\_migration_backup\20261026_from_C_drive` folder.
Newer Desktop Windows fixes were retained instead of overwritten by older copies.
No file data remains under C:\Dev; empty old directory handles may remain until
the processes holding that working directory exit.

Historical migration validation in this Desktop project: 247 Godot checks across ten suites,
eight direct-entry smoke checks, and 118 Python tests (four skipped). These are
desktop technical checks; they do not grant artistic approval or certify phone
performance, native jump physics or the inferred Sabre animation assignment.
