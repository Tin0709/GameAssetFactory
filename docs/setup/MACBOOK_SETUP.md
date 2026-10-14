# MacBook setup — GameAssetFactory

Migration prepared2026-10-14 on Windows. No Mac hardware was available: the setup is based on inspected source, matched versions and simulated macOS launcher tests. Perform the final visual smoke test on your Mac before continuing asset authoring. Cleanup is validated locally and the user has authorized final Git synchronization. Confirm the successful push and final commit hash from the handoff before cloning on Mac.

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

## Animation and Weapon Showcases

```sh
python3 scripts/dev.py blender --showcase animation
python3 scripts/dev.py blender --showcase weapon
```

These open `blender/animation/showcase/Animation_Showcase.blend` and `blender/weapons/showcase/Weapon_Showcase.blend`. The launcher explicitly loads the adjacent repository UI via `scripts/load_showcase_ui.py`, so a per-user Animation Library add-on is unnecessary. Embedded auto-execution is disabled, and factory startup prevents conflicting installed handlers. The helper validates the existing manifest; it does not import new Actions or save the file.

In Blender press N for the sidebar, then Animation Library or Weapon Library. Verify selection, playback/restart, and the weapon's Standalone/Ready/Holster modes. Keep approved sources unchanged during smoke tests; close without saving.28 registered Actions and3 current weapon entries were validated; all175 tracked Blender files had no unpacked external image/library dependencies.145 glTF assets had no external buffer/image dependencies. If a future file shows pink textures, check LFS and its image paths before relinking; use relative paths/pack resources only on a backed-up authorized edit.

## Blender MCP on macOS

There are two parts: the **Blender Lab MCP extension1.0.3** inside Blender and the **stdio MCP client** launched by Codex through uvx. The local bridge listens on loopback port9876. It is not a Godot service and is not a public HTTP endpoint.

Obtain the matching extension ZIP from the [official Blender Lab MCP project](https://projects.blender.org/lab/blender_mcp) / [Blender Lab MCP page](https://www.blender.org/lab/mcp-server/). In Blender Preferences > Get Extensions use Install from Disk for that ZIP. Confirm id `mcp`, version1.0.3, and enable it if using the extension's own controls. Online Access may be needed by the extension's UI. The Windows installed extension manifest and source were inspected; the upstream documentation pages could not be fetched in this audit, so verify the current download packaging on Mac.

Default installed location is under `~/Library/Application Support/Blender/5.2/extensions/user_default/mcp`. If you installed another extension repository, set:

```sh
export BLENDER_MCP_ADDON="$HOME/Library/Application Support/Blender/5.2/extensions/user_default/mcp"
export BLENDER_MCP_HOST=localhost
export BLENDER_MCP_PORT=9876
python3 scripts/dev.py bridge --showcase animation
```

This opens a fresh Blender with the Showcase UI and starts its installed bridge using a nonblocking timer. It does not enable global add-on auto-start or save the scene. Use either this launcher or the extension's Start MCP Bridge Server control, not both in the same process. Only one Blender may own a port; use matching alternate ports if you need multiple sessions.

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

Ask Codex to read Blender's current version/object count first. Do not use a modifying operation as the connection test. A real execution request against an isolated bridge on port19876 passed on Windows. Mac connection/startup remains a manual check. If unavailable: check extension install path, one process per port, matching host/port, uvx on the GUI PATH, and client startup logs. Keep this code-executing service on loopback.

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
- [ ] Animation Showcase lists28 entries, plays/switches/restarts without changing approval states.
- [ ] Weapon Showcase lists3 current entries and all fit modes work.
- [ ] No pink textures/missing models; source/rig proportions and Actions look unchanged.
- [ ] MCP reads version/object count from the intended Blender window.
- [ ] Close review files without saving; `git status --short` contains no unintended asset changes.

For later sessions: stop any automatic checkpoint while authoring/validating; `git pull --ff-only` only on a clean tree; `git lfs pull`; open the repo in Codex; start Godot or the appropriate Showcase/bridge with the commands above. Commit and push only coherent reviewed changes with a single Git writer. Do not run the Windows legacy launchers on Mac.

## What transfers through Git versus separately

The five original Actions & Stuff reference recordings, including walking.mp4 and Running.mp4, are included under `references/motion/actions_and_stuff/` with SHA256 in manifest.json (8.05 MB total). They are immutable small reference inputs kept in ordinary Git; no LFS history migration or new large LFS upload is needed. The archived AVI files are raw Godot review captures, not the original Actions & Stuff references; final MP4 reviews are already in the repository.

For optional local history, manually copy `Unuse Files/GameAssetFactory_Migration_2026_10_14/` from the Windows Desktop to the Mac or an external drive. It contains verified local validation drafts/backups, raw review captures and restoration manifests. This archive is intentionally outside Git. Reinstall per-user Blender MCP/Codex configuration, credentials and application binaries on Mac rather than copying caches into the clone.
