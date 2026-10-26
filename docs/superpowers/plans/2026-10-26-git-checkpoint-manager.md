# Git Checkpoint Manager Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build a Vietnamese desktop manager that checks two existing repositories every 10 seconds and creates local checkpoints when enabled; Push remains manual.

**Architecture:** Python standard-library Git controller, serialized desktop worker, Tkinter interface. Runtime state lives in local application data; all real-repository writes remain disabled during installation and tests.

**Tech Stack:** Python 3.13, Tkinter/Ttk, subprocess Git and existing Git LFS/hooks.

**Spec:** `docs/superpowers/specs/2026-10-26-git-checkpoint-manager-design.md`

## Global Constraints

- Preserve both existing repositories, branches, index contents, hooks and assets.
- Never force-push, rewrite, auto-push, auto-merge, or update research snapshots.
- Default timer 10 seconds; 250 ms stability sample, not a 60-second quiet period.
- First launch is paused; no real commit or push as part of installation/testing.
- Implement here on the existing feature checkout using new app/test/doc files only; do not switch branches or create another checkout.
- No sign-in task, hidden persistent service, new Git repository or extra dependencies.

## Review Focus

- Renames, deletions and unusual path names must stage only intended paths.
- Existing staged work, hooks failing, active locks and branch switches must stop safely.
- Private-research remote identity/privacy and secret redaction must fail closed.
- Non-fast-forward push and LFS failure must report honestly without force.
- Slow Git jobs must not freeze the window, overlap operations or persist after close unnoticed.

### Task 1: Safe Git controller and ten-second schedule

**Files:** `scripts/checkpoint_manager/core.py`, `scripts/checkpoint_manager/__init__.py`, `scripts/tests/test_checkpoint_manager.py`.

**Interfaces:** `RepoConfig`, `GitRepository.scan/checkpoint/push`, `AutoSchedule`, typed snapshot/blocked/error results. Existing `git_large_file_guard.inspect_staged` remains authoritative for staged large-file/LFS validation.

- [x] Add failing real temporary-repository tests for modified/deleted/untracked/renamed files, ignored/excluded paths, staged index preservation, locks/conflicts, detached/changed branch, hook failure, upstream push rejection and exact 10-second scheduling.
- [x] Run the new tests and observe missing-feature failures.
- [x] Implement controller with no shell interpolation, candidate stability checking, existing hooks and explicit configured upstream pushes.
- [x] Add remote URL/secret-redaction/privacy failure tests; never contact a production write endpoint in tests.
- [x] Run controller tests green. No real-repo commit.

### Task 2: Desktop worker and interface

**Files:** `scripts/checkpoint_manager/desktop.py`, `scripts/git_checkpoint_manager.py`, `scripts/tests/test_checkpoint_manager_ui.py`.

**Interfaces:** consume Task 1 controller; a single worker emits results to the Tk thread via queues. Pause affects future transactions; a transaction already staging/committing finishes safely.

- [x] Write UI/scheduler tests for initial pause, 10-second default, explicit enable, serialized worker and close/busy behavior.
- [x] Observe failures; implement two repo panels, changes preview, commit/push controls, interval, pause/resume, countdown and log.
- [x] Persist interval only; auto-commit requires enabling each time the app opens.
- [x] Verify real Tk rendering and responsive event processing with temporary repos.

### Task 3: Installation, documentation and final review

**Files:** desktop launch shortcut outside Git; `docs/setup/GIT_CHECKPOINT_MANAGER.md`.

- [x] Create a normal desktop shortcut using existing Python, with no Windows auto-start registration.
- [x] Run controller/UI tests plus the existing Python helper suite; document any unrelated failures.
- [x] Request a fresh read-only code review under requesting-code-review; fix material findings with regression tests.
- [x] Open the actual app paused and inspect its visible state; verify both real Git HEADs/indexes remain unchanged.
- [x] Deliver shortcut/app instructions and exact 10-second/manual-push behavior, including MD2 Release limitation.

## Execution ledger

Ruling: implement inline in the existing session, without another design/plan approval loop; the user's latest instruction supplies the concrete 10-second behavior and requests continued app work. No real commit/push is required to deliver this tool.

Completed: 25 dedicated controller/UI tests pass; helper suite 94 tests passes
with four existing optional skips. Knowledge suite 14 tests passes with one
Windows symlink-privilege skip. Fresh review's intent-to-add, implicit tag push,
close/resume and distinct push-URL findings each have reproduced red-to-green
regressions. A repeated-UI-fixture Tk GC flake was traced to the injected clock's
reference cycle; fixtures now release/collect destroyed Tk objects on the main
thread. Final helper suite is green after that fix.

Native UI inspected; desktop shortcut created and actual app opened paused.
Read-only GitHub API confirms MD2 destination private. Both real repository HEADs
and staged-entry hashes match before/after. No real commit, push or startup task.
Evidence: `.validation/checkpoint_manager_20261026/` (ignored local output).
