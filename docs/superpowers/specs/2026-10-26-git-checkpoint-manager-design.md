# Desktop Git Checkpoint Manager — proposed design

Date: 2026-10-26. Status: desktop approach selected; user requested automatic
scanning/checkpointing every 10 seconds. Implement with that updated cadence.

## Intent and scope

Provide a small Vietnamese desktop app for automatic local Git checkpoints and
explicit manual pushes for these existing, separate repositories:

- `C:\Users\ADMIN\Desktop\Dev\GameAssetFactory`
- `C:\Users\ADMIN\Desktop\MD2 Research`

The user selected a standalone desktop app. Python 3.13.5 and Tk 8.6 are
already installed. Use Python/Tkinter without a web server or new Git repository.
Keep the implementation in GameAssetFactory's existing `scripts` area, with
settings and runtime logs under the user's local application-data directory.
Create a normal desktop launch shortcut. No Windows sign-in task or hidden
background service is included in this scope.

## Approaches considered

1. Native Python/Tkinter desktop app — selected by the user. Uses existing
   installed dependencies and provides a window with direct controls.
2. Local browser dashboard — declined in favor of a desktop app; would require
   an additional web-server process.

## Window and controls

Show two repository panels with name, path, branch, upstream, working changes,
staged changes, local commit, last successful checkpoint and app operation state.
Ahead/behind counts must identify whether they use the last fetched remote state;
do not present cached remote-tracking data as a live GitHub check.

Each panel provides Refresh, View Changes, Commit Now, Push and an Auto Commit
toggle. A shared interval control and Pause All / Resume controls make it easy
to stop the app before manual Git work or another agent's Git operations.
Show an operation log and useful error messages without credentials.

Auto-commit is OFF at launch for initial review; after the user enables it, scan
and checkpoint every 10 seconds when changes exist. The previous 5-minute timer
and 60-second quiet period are superseded. A short 250 ms stability sample skips
files still being written without adding a separate long waiting period.
The interval is adjustable. Push is always manual. Closing the app stops its
timer; the desktop shortcut opens it again.

## Commit behavior and preservation

- Work only on each repository's current branch. Never switch branches, rewrite
  commits, pull, merge, rebase, reset or force-push automatically.
- Serialize app Git writes through one worker; prevent duplicate app instances.
  Detect Git lock files and merge/rebase/conflict states and skip safely.
- Pause automatic commits if files are already staged by another workflow.
  Do not silently commit or unstage someone else's staged changes.
- Before staging, recheck the branch/HEAD and stable candidate-file signatures.
  Stage only the displayed eligible files, using argument lists without shell
  interpolation and without `git add -f`. Respect existing ignore rules.
- Block newly untracked credentials, caches and disposable backup files. Display
  exclusions and reasons; do not delete files or silently change ignore rules.
  Existing tracked files remain visible rather than disappearing from review.
- Preview initial existing changes; installing or opening the app must not
  commit the current work. Commit Now is an explicit action in the app.
- Use ordinary `git commit` so existing hooks remain active. On a staging or
  commit failure, stop automatic commits for that repo, report the actual index
  state and leave all work intact for review; do not perform automatic rollback.
- Logs and settings stay outside both repositories, so they do not cause a
  self-triggering stream of checkpoint commits.
- This app cannot lock out unrelated editors or Git clients. Its UI must explain
  that Pause All is required before another session performs Git writes.

## Large files, private research and Push

Preserve GameAssetFactory's existing Git LFS attributes and pre-commit guard.
Validate candidate large files and LFS prerequisites before committing; do not
install tracking rules, migrate assets or bypass hooks automatically.

MD2's current README records later user authorization for a separate private
`Tin0709/MD2-Research` backup, superseding older local-only instructions. Keep
this separate from GameAssetFactory. Preserve its current `.gitignore`:
`extracted/` and `source_snapshot/` are stored in a multipart private Release,
not ordinary Git. The app must prominently distinguish a Git checkpoint/push
from a full research snapshot. Updating that snapshot is outside this version.

Push targets only the configured current upstream, after revalidating branch and
remote identity. Require the MD2 destination to be verified private; if GitHub
access cannot establish privacy, block MD2 Push with a clear explanation. Use
existing authentication, never store tokens in settings/logs. Use normal Git
push with LFS hooks. Report rejected pushes and LFS errors without retrying with
force, changing remotes or resolving conflicts. Verify the upstream branch SHA
after success; distinguish a Git ref sync from unverified remote LFS availability.

## Verification and delivery

Test Git behavior in disposable local repositories, including unchanged trees,
staged work, conflicts/locks, branch changes, excluded files, commit failure and
non-fast-forward push rejection. Do not test commits or pushes against either
real repository. Test the controller/worker separately from the Tk window and
open the app for a real UI smoke check. Check first-launch Auto Commit is OFF.

Deliver the app, desktop launch shortcut, concise usage instructions and a
clear account of untested remote/authentication paths. No real commit, push,
automatic snapshot upload, gameplay change or animation change is authorized
merely by installing this app.
