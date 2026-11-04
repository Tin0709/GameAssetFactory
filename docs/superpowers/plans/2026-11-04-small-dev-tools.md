# Small developer tools implementation plan

> Execute inline with superpowers:executing-plans; verify before completion.

**Goal:** Make existing Blender libraries easier to find and automated Godot launches quiet.

**Architecture:** Extend the existing standard-library `scripts/dev.py` CLI. Read only the first 80 bytes of each registered viewer; never load Blender or proprietary research. Headless launches select Dummy audio only for that process.

**Spec:** User requests autonomous small GameAssetFactory tasks; existing README viewer aliases and AGENTS automated-test audio policy define scope.

**Constraints:** Preserve gameplay, scenes, graphics, animation files, private data boundaries, normal play audio, and existing CLI aliases. Work on main under the explicit repository direction. No new dependencies.

**Review focus:** Missing files; Git LFS pointers; valid compressed Blender files; unavailable tools; headless versus normal audio.

## Task 1 — Blender viewer discovery

- [ ] Add failing CLI tests for a `viewers` JSON catalog: every existing alias, source path, `ready` / `missing` / `lfs_pointer` / `unreadable` discovery status; no tool lookup or launch.
- [ ] Implement bounded file-header inspection, preserving compressed-file support. File discovery is not validation that Blender can open the file.
- [ ] Run launcher regressions and document the command in the root README.

## Task 2 — Quiet automated launches

- [ ] Add failing tests for Dummy audio on headless launches only.
- [ ] Add the process-only audio override; keep interactive commands unchanged.
- [ ] Run focused tests and CLI smokes, inspect diff, then commit/push only these original tooling changes under repository policy.

## Execution ledger

- Initial state: main at 9e5608f4, clean checkout; usage 3% used / 97% remaining. No engine process will be started by catalog tests.
