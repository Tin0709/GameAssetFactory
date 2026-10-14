# Repository migration implementation plan

> Execute inline using superpowers:executing-plans; one final read-only review.

**Goal:** safe cleanup, verified GitHub sync and MacBook setup without artistic/gameplay edits.
**Spec:** user supplied Repository Cleanup, GitHub Sync & MacBook Migration request; audit in docs/setup/REPOSITORY_AUDIT_2026_10_14.md.
**Architecture:** keep critical paths; add stdlib portable developer launchers and read-only migration checks; preserve historical tools with explicit limitations. No new animations or gameplay.
**Tech stack:** Git/LFS, Python3, Blender5.2.2, Godot4.7.2.

- [x] Audit sizes/tracking/LFS local+remote/active work/path hazards and report before removal.
- [ ] Back up and verify rawAVI review intermediates externally, archive only the explicit8-file allowlist; retain restoration manifest.
- [ ] Add portable tool discovery/Blender Showcase/MCP/Godot launchers with tests for spaces, macOS app paths and overrides. Safe relative source paths for active importer/exporter; protect rig/artistic data.
- [ ] Add precise ignore/line-ending rules without changing existing LFS content; document remaining historical path dependencies.
- [ ] Validate central Showcases/Actions/textures, exact Godot references/case, fresh import clone, existing runtime tests, essential tracked data and unchanged source hashes.
- [ ] Create MacBook setup and concise final audit; fresh read-only review.
- [ ] Inspect and stage explicit intended paths only, commit/push existing main/upstream as authorized; verify remote SHA and LFS availability. Stop on serious risk.

Ruling: user explicitly authorizes cleanup/commit/push on current configured branch, so operate in this checkout with clean baseline, exact per-file hashes, external backup and HEAD guards rather than duplicate6.4GB in a worktree. Only safe disposable outputs move; unclear content stays. Do not stop for duplicate approval gates already answered by the user's detailed task.
Review focus: per-user add-on unavailable on clone; binary pointers vs actual LFS; runtime scripts/preload paths; cache-dependent .res imports; concurrent Git checkpointing. Verify each before push. macOS runtime is untested on this Windows host; distinguish static portability checks from actual Mac smoke test.
