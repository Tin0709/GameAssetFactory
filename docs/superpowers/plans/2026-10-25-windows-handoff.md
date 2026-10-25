# Cleanup and Windows handoff

> Execute inline with superpowers:executing-plans. User explicitly authorizes reversible cleanup and Windows/Git preparation in the existing checkout. No new artistic design, installation, push or history rewrite.

**Goal:** archive disposable local files on Desktop and make the current branch, viewers and Sword/Rifle lab straightforward to continue on Windows.
**Architecture:** preserve every tracked asset and existing Git/LFS object; move only an audited allowlist of ignored outputs with per-file hashes and a no-overwrite restore. Extend the established portable launcher. Ship private research separately outside the public repository.
**Tech:** Python standard library, Git/LFS, existing Godot/Blender, PowerShell instructions.
**Spec:** user's cleanup/Git/Windows handoff request; existing docs/setup and docs/git policies remain authoritative.

- [ ] Record tracked-file baseline, branch/remote, LFS/push objects, dependency protections and archive allowlist. Preserve active editor caches and linked validation inputs; keep compact JSON/scripts.
- [ ] Move disposable validation media/checkpoints, automatic Blender backups, logs and bytecode to a dated Desktop archive. Verify hashes, mappings and no-overwrite restore. No permanent deletion, tracked-file removal, garbage collection or history migration.
- [ ] Add tested combat/Sword and optional GPU-driver launch options to scripts/dev.py; remove Mac-only output/test assertions. Preserve gameplay and all approved source bytes.
- [ ] Prepare Windows setup/checklist and a verified private transfer ZIP outside Git; retain the source private directory on Mac. No credentials, application installers or unofficial game archive in the kit.
- [ ] Run portable launcher/guard tests, local LFS integrity, case/path/dependency checks, actual Godot Sword smoke and source preservation comparison. Supply exact current-branch push/clone commands; do not push for the user or change repository visibility.

Review focus: ignored does not mean disposable; .gitignore does not untrack files; public remote must not receive private transfer data; fresh Windows clones need LFS and per-clone hooks; Fiery must resolve outside res://; old historical authoring paths are not silently rewritten; native Windows execution cannot be certified on this Mac.
