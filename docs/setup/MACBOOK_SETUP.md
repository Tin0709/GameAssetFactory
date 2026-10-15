# MacBook setup — GameAssetFactory

Migration prepared2026-10-14 on Windows. The five-viewer startup workflow was subsequently tested on this Mac with Blender5.2.2 on2026-10-15; the Godot migration checks still require their own visual smoke test before asset authoring. Cleanup is validated locally and the user has authorized final Git synchronization. Confirm the successful push and final commit hash from the handoff before cloning on Mac.

## Versions and tools

| Tool | Validated Windows baseline | Mac requirement |
|---|---|---|
| Blender |5.2.2 LTS; .blend version5.2|Use the matching5.2.2 Mac build; do not save approved sources through an older build|
| Godot |4.7.2.stable.official.ed1daf0bf|Matching standard editor, not .NET; check `--version`|
| Python |3.13.5|Python3.11+ for portable helpers;3.13 recommended for reproducing this environment|
| Git / Git LFS |Git2.50;LFS3.6.1|Git and Git LFS installed before retrieving assets|
| Blender Lab MCP extension + client |1.0.3|Install both the Blender extension and the pinned uvx client|
| uv / uvx |Installed on Windows|Required only for the Blender MCP stdio client|

Download Blender/Godot for your processor (Apple Silicon or Intel), place in `/Applications`, and verify versions. These are recorded project versions, not claims about the newest public releases. If the exact Mac build cannot be obtained, stop before saving approved files and review a supported version change separately. Export templates are needed only when exporting a game, not to open/run the editor.

Using Homebrew, install tooling with `brew install git git-lfs python uv`. Alternatively use the tools' official installers. Then run:

```sh
git --version
git lfs version
python3 --version
uvx --version
/Applications/Blender.app/Contents/MacOS/Blender --version
/Applications/Godot.app/Contents/MacOS/Godot --version
```

Keep at least30 GB free during setup. Current working source is about6.44 GB; Git/LFS stores additional copies and full Git history is large. The shallow single-branch workflow below avoids downloading unrelated history. It does not rewrite or prune the remote repository.

## Clone and restore LFS

Use the configured origin and sign in to GitHub using your own account/credential manager if required. Do not copy Windows credentials into the repository.

```sh
mkdir -p ~/Developer
cd ~/Developer
git lfs install
GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 --single-branch --branch main https://github.com/Tin0709/GameAssetFactory.git
cd GameAssetFactory
git lfs pull origin main
git lfs fsck
git status --short --branch
```

Clone after receiving confirmation that the cleanup commit was pushed. Use `git log -1 --oneline` and compare the checked-out commit hash against the final synchronization handoff. All330 unique LFS objects reachable from the pre-cleanup main snapshot were verified locally and available through GitHub's authenticated download-batch API. This is not a GitHub billing/quota audit or verification of every historical branch.

Do not accept128-byte text pointers as working `.blend`/`.glb` assets. If `git lfs pull` fails due to auth/quota/network, resolve that before opening assets. Request missing objects from the Windows checkout rather than recreating them. To retrieve older commit history later, use `git fetch --unshallow origin` when you actually need it.

## Configure executable paths

The portable launcher automatically checks PATH and `/Applications/{Blender,Godot}.app`. If your bundles have different names, set the actual binary paths:

```sh
export BLENDER_BIN='/Applications/Blender.app/Contents/MacOS/Blender'
export GODOT_BIN='/Applications/Godot.app/Contents/MacOS/Godot'
python3 scripts/dev.py doctor
```

Add these exports to your local shell configuration if desired. The executable inside the app bundle is required, not the `.app` directory. The Godot launcher uses the Mobile renderer and leaves driver choice to Godot on Mac; it preserves D3D12 on Windows. Do not pass the Windows-only D3D12 flag on macOS. These command-line details follow the [Godot command-line guide](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html).

## Open in Codex and Godot

Open the cloned `GameAssetFactory` folder as a local project in Codex. Read `AGENTS.md` before editing. Codex tasks, credentials, per-user plugins and Windows app settings are not transferred by Git. Reinstall needed local plugins/settings separately; do not copy a user's whole `.codex` directory.

```sh
python3 scripts/dev.py godot --editor
python3 scripts/dev.py godot --scene snappy
python3 scripts/dev.py godot --scene expressive
python3 scripts/dev.py godot --scene meadow
```

You can instead import `game_mobile_3d/project.godot` through Godot Project Manager. Allow the first `.godot` import to finish. F5 opens the existing WorldMap main scene; F6 runs the current development scene. Snappy controls: WASD/arrows, Shift run, Space jump, Tab A/B,4 original camera,R reset,F9 demo. Original travel speed remains3.0375/5.977875 m/s; locomotion animation cadence is75% of the earlier fast test. This cleanup does not alter that behavior.

The launcher supports `--dry-run` to print the exact argument list without launching. Old PowerShell/CMD entry points are Windows wrappers; Mac uses `python3 scripts/dev.py`.

## Five Blender viewers on macOS

Run these exact commands from **any directory** on this Mac. Each command opens its existing file in the Blender GUI and returns Terminal control immediately. No trailing `&`, watcher, launcher daemon or extra Terminal window is needed.

```sh
python3 "/Users/tin/Desktop/Game Dev/GameAssetFactory/scripts/open_blender_viewer.py" asset
python3 "/Users/tin/Desktop/Game Dev/GameAssetFactory/scripts/open_blender_viewer.py" player
python3 "/Users/tin/Desktop/Game Dev/GameAssetFactory/scripts/open_blender_viewer.py" animation
python3 "/Users/tin/Desktop/Game Dev/GameAssetFactory/scripts/open_blender_viewer.py" weapon
python3 "/Users/tin/Desktop/Game Dev/GameAssetFactory/scripts/open_blender_viewer.py" mobs
```

| Viewer | Existing file, relative to the repository |
|---|---|
| Asset Style V2 | `blender/environment/studies/dungeons_ground_style_v2/dungeons_ground_style_v2.blend` |
| Player Animation Library V1 | `blender/animation/reviews/player_animation_library_v1/player_animation_library_v1.blend` |
| Animation Showcase | `blender/animation/showcase/Animation_Showcase.blend` |
| Weapon Showcase | `blender/weapons/showcase/Weapon_Showcase.blend` |
| Mobs Animation Showcase | `blender/animation/showcase/Mobs_Animation_Library.blend` |

`scripts/open_blender_viewer.py` is the standard public entry point, with five positional options: `asset`, `player`, `animation`, `weapon`, `mobs`. It delegates to the shared detached launcher, so the existing `dev.py blender --viewer ...` and `--showcase animation/weapon` commands remain compatible. `BLENDER_BIN` / `--blender-bin` overrides and `--dry-run` remain available. Paths with spaces are passed as individual arguments.

After moving the repository to another Mac or Windows machine, change the absolute script prefix in these commands to that checkout's location. All asset/UI paths inside the launcher are relative to the repository, derived from the script location rather than the Terminal working directory. From the repository root, `python3 scripts/open_blender_viewer.py asset` also works. No shell aliases, login service, Python Console initialization or saved add-on preferences are required: each new Blender launch loads the UI explicitly, including after restarting the Mac.

Each different viewer needs one Blender process. Repeating a command detects that exact executable/file in the process list, reports its PID, requests macOS to bring its window forward and starts no duplicate. Unsaved work is preserved; if macOS declines activation, switch to its existing window. Detection identifies the startup file: if you manually open a different file in that process, close it before relaunching the original viewer. After updating the launcher/UI code, close and reopen any old viewer once to load the new code. The existing Mobs `.command` shortcut delegates to this same launcher.

Four viewers load existing custom panels through `scripts/load_showcase_ui.py`: **Player Review** for Player Animation Library V1, **Animation Library**, **Weapon Library**, and **Mobs Animation Library** for the three Showcases. Their N sidebars are shown automatically. Select the named tab; press N if you later hide the sidebar. Registration is guarded so rerunning the bootstrap does not register duplicate classes. The Player panel uses the repository's existing `review_controls.py`, also stored in the file as `START_HERE_review_controls.py`; no replacement interface is created. The other three panels restore their saved registries.

Asset Style V2 has no custom review panel. It opens its existing saved workspace without a UI bootstrap. No per-user library add-on or embedded Python auto-run is needed for any of the five commands.

Startup uses factory preferences and disables embedded auto-execution. It never refreshes/imports new Actions, rebuilds assets, saves a `.blend`, writes preferences or changes Godot. For Blender 5.2, the sidebar uses the supported writable [`SpaceView3D.show_region_ui`](https://docs.blender.org/api/5.2/bpy.types.SpaceView3D.html#bpy.types.SpaceView3D.show_region_ui) property and `Area.tag_redraw()`. It does not assign `Region.active_panel_category`: categories are generated during drawing and the assignment can be read-only during startup. The registered tabs remain available without forcing an active category.

Blender is detached with its input disconnected and output redirected to a per-viewer startup log under `~/Library/Caches/GameAssetFactory/viewers/<repository-id>/`. The command prints the exact log path and Blender PID. If a window fails to appear, inspect that log for missing resources or Python errors. The short-lived launch lock prevents simultaneous launcher calls from opening duplicates; it is released as soon as the command exits. Closing Blender ends the viewer; there is no launcher process to stop.

## Blender MCP on macOS

There are two parts: the **Blender Lab MCP extension1.0.3** inside Blender and the **stdio MCP client** launched by Codex through uvx. The local bridge listens on loopback port9876. It is not a Godot service and is not a public HTTP endpoint.

Obtain the matching extension ZIP from the [official Blender Lab MCP project](https://projects.blender.org/lab/blender_mcp) / [Blender Lab MCP page](https://www.blender.org/lab/mcp-server/). In Blender Preferences > Get Extensions use Install from Disk for that ZIP. Confirm id `mcp`, version1.0.3, and enable it if using the extension's own controls. Online Access may be needed by the extension's UI. The Windows installed extension manifest and source were inspected; the upstream documentation pages could not be fetched in this audit, so verify the current download packaging on Mac.

Default installed location is under `~/Library/Application Support/Blender/5.2/extensions/user_default/mcp`. If you installed another extension repository, set:

```sh
export BLENDER_MCP_ADDON="$HOME/Library/Application Support/Blender/5.2/extensions/user_default/mcp"
export BLENDER_MCP_HOST=localhost
export BLENDER_MCP_PORT=9876
python3 scripts/dev.py bridge --viewer animation
```

The five standard `open_blender_viewer.py ...` commands and legacy `dev.py blender --viewer ...` commands do not start MCP or bind port 9876, even with several viewers open. Factory startup prevents installed add-ons from starting their own bridges. Existing MCP client configuration stays compatible.

`bridge --viewer ...` accepts all five viewer names, returns Terminal control immediately and starts the installed bridge only in that viewer, using a Blender timer. If that viewer is already open without MCP, close it first; the launcher will not spawn a duplicate to add a bridge. If the requested port is busy, it reports the conflict before opening a new window and leaves the current bridge untouched. A port claimed between this check and Blender startup is logged as `GAF_MCP_BRIDGE_SKIPPED`; the new window remains a plain viewer. Startup logs contain `GAF_MCP_BRIDGE_READY` when binding succeeds.

Use either this launcher or the extension's Start MCP Bridge Server control in a process. For an additional MCP-enabled viewer, choose a free port explicitly, for example `BLENDER_MCP_PORT=9877 python3 scripts/dev.py bridge --viewer weapon`, and configure that MCP client with the same port. Ports are never silently reassigned. No global add-on auto-start or scene save is enabled.

In your private `~/.codex/config.toml`, merge the following server entry rather than replacing other settings:

```toml
[mcp_servers.blender]
enabled = true
command = "uvx"
args = ["--from", "git+https://projects.blender.org/lab/blender_mcp.git@v1.0.3#subdirectory=mcp", "blender-mcp"]
startup_timeout_sec = 60
tool_timeout_sec = 300

[mcp_servers.blender.env]
BLENDER_MCP_HOST = "localhost"
BLENDER_MCP_PORT = "9876"
```

If a GUI-launched Codex cannot find Homebrew's uvx, replace `command` with the output of `command -v uvx` (often `/opt/homebrew/bin/uvx` on Apple Silicon). Restart/reload Codex's MCP connection and, where the CLI is installed, check `codex mcp list`. This config shape is supported by [official OpenAI MCP documentation](https://developers.openai.com/codex/mcp/) and [configuration reference](https://developers.openai.com/codex/config-reference/); the pinned Blender arguments come from this workstation's inspected working configuration.

Ask Codex to read Blender's current version/object count first. Do not use a modifying operation as the connection test. A real execution request against an isolated bridge on port19876 passed on Windows. For the installed Mac build, viewer and bridge validation is recorded below; after migrating to another machine, repeat this read-only connection check. If unavailable: check extension install path, one process per port, matching host/port, uvx on the GUI PATH, and client startup logs. Keep this code-executing service on loopback.

## Python dependencies and research

`dev.py`, path discovery and launcher unit tests use only Python's standard library. Blender scripts run in Blender's bundled Python (`bpy`, `mathutils`); do not pip-install a substitute bpy into the project environment.

For reference analysis use an optional isolated environment:

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r docs/setup/requirements-research.txt
```

Five original user-provided recordings now live in `references/motion/actions_and_stuff/`, with exact SHA256 in `manifest.json`. The portable deep-study input helper checks their hashes and chooses a local font fallback. It does not rerun/rewrite the existing atlas or motion data. Regenerated fonts can look different on Mac; source frames/timing and measurements must stay separate from annotation appearance. These recordings are reference footage, not proprietary pack animation assets or production content.

Optional Minecraft map tools have their own pinned requirements at `minecraft_maps/m2_v1/requirements.txt` and `game_mobile_3d/tests/m2_v1/requirements.txt`; install those only when working on that subsystem. The active World Map importer defaults to its tracked `.litematic` source instead of a PrismLauncher user path.

Historical builders/tests may assume ignored `.validation` snapshots, desktop attachments, fonts or old Git baselines. Read [historical tool limitations](HISTORICAL_TOOL_LIMITATIONS.md); adapt one tool under a separate task before executing it. Do not run all old authoring scripts. Existing historical JSON/Markdown paths are provenance and are not silently rewritten. Local ignored validation backups/raw archive are outside the clone contract. A verified4,896-file/2.57 GB historical validation snapshot is available under the external migration archive; copy it manually if you want that local history on Mac. Windows locations and restoration manifests are in [the cleanup report](CLEANUP_RESULT_2026_10_14.md).

## Smoke test and daily startup

After the final authorized push, confirm the expected commit and LFS, then:

```sh
cd ~/Developer/GameAssetFactory
python3 scripts/dev.py doctor
python3 -m unittest discover -s scripts/tests
python3 scripts/dev.py godot --editor
```

Checklist:

- [ ] Matching Blender/Godot versions and architecture; LFS pull/fsck succeeds.
- [ ] First Godot import completes; WorldMap opens with expected terrain/textures/audio.
- [ ] Snappy and Expressive tests run; camera, move/run/jump and A/B work visually.
- [ ] All five viewer commands return immediately; repeating one starts no duplicate.
- [ ] Player Review, Animation Library, Weapon Library and Mobs Animation Library show their saved lists in the custom N-panel tabs.
- [ ] Viewer selection/playback works without changing approval states.
- [ ] No pink textures/missing models; source/rig proportions and Actions look unchanged.
- [ ] MCP reads version/object count from the intended Blender window.
- [ ] Close review files without saving; `git status --short` contains no unintended asset changes.

Viewer startup validation on2026-10-15:31 standard-library tests passed. All five exact public commands ran from `/tmp`, opened the real files in macOS Blender5.2.2 and returned in0.071–0.096 seconds (GUI loading continues after command exit). Repeating each command reused its original PID. Runtime checks confirmed all four custom panels were registered with visible sidebars and populated saved lists: Player Review61, Animation Library37, Weapon Library3 and Mobs Animation Library6 entries at validation time. Running the bootstrap twice in each GUI session produced no duplicate-registration or read-only-category error. The existing MCP process retained port9876 throughout; a subsequent read-only version/object-count request succeeded. SHA256 checks confirmed all five `.blend` files were unchanged. Temporary validation windows were closed without saving. This checks viewer startup, not artistic quality or gameplay.

For later sessions: stop any automatic checkpoint while authoring/validating; `git pull --ff-only` only on a clean tree; `git lfs pull`; open the repo in Codex; start Godot or the appropriate Showcase/bridge with the commands above. Commit and push only coherent reviewed changes with a single Git writer. Do not run the Windows legacy launchers on Mac.

## What transfers through Git versus separately

The five original Actions & Stuff reference recordings, including walking.mp4 and Running.mp4, are included under `references/motion/actions_and_stuff/` with SHA256 in manifest.json (8.05 MB total). They are immutable small reference inputs kept in ordinary Git; no LFS history migration or new large LFS upload is needed. The archived AVI files are raw Godot review captures, not the original Actions & Stuff references; final MP4 reviews are already in the repository.

For optional local history, manually copy `Unuse Files/GameAssetFactory_Migration_2026_10_14/` from the Windows Desktop to the Mac or an external drive. It contains verified local validation drafts/backups, raw review captures and restoration manifests. This archive is intentionally outside Git. Reinstall per-user Blender MCP/Codex configuration, credentials and application binaries on Mac rather than copying caches into the clone.
