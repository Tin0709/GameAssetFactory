# Cleanup and Windows handoff

> Execute inline with superpowers:executing-plans. User explicitly authorizes reversible cleanup and Windows/Git preparation in the existing checkout. No new artistic design, installation, push or history rewrite.

**Goal:** archive disposable local files on Desktop and make the current branch, viewers and Sword/Rifle lab straightforward to continue on Windows.
**Architecture:** preserve every tracked asset and existing Git/LFS object; move only an audited allowlist of ignored outputs with per-file hashes and a no-overwrite restore. Extend the established portable launcher. Ship private research separately outside the public repository.
**Tech:** Python standard library, Git/LFS, existing Godot/Blender, PowerShell instructions.
**Spec:** user's cleanup/Git/Windows handoff request; existing docs/setup and docs/git policies remain authoritative.

- [x] Record tracked-file baseline, branch/remote, LFS/push objects, dependency protections and archive allowlist. Preserve active editor caches and linked validation inputs; keep compact JSON/scripts.
- [x] Move disposable validation media/checkpoints, automatic Blender backups, logs and bytecode to a dated Desktop archive. Verify hashes, mappings and no-overwrite restore. No permanent deletion, tracked-file removal, garbage collection or history migration.
- [x] Add tested combat/Sword and optional GPU-driver launch options to scripts/dev.py; remove Mac-only output/test assertions. Preserve gameplay and all approved source bytes.
- [x] Prepare Windows setup/checklist and a verified private transfer ZIP outside Git; retain the source private directory on Mac. No credentials, application installers or unofficial game archive in the kit.
- [x] Run portable launcher/guard tests, local LFS integrity, case/path/dependency checks, actual Godot Sword smoke and source preservation comparison. Supply exact current-branch push/clone commands; do not push for the user or change repository visibility.

Review focus: ignored does not mean disposable; .gitignore does not untrack files; public remote must not receive private transfer data; fresh Windows clones need LFS and per-clone hooks; Fiery must resolve outside res://; old historical authoring paths are not silently rewritten; native Windows execution cannot be certified on this Mac.


## Completion evidence

-6,699ignored files/4,474,778,724bytes(4.168GiB) moved and SHA256-verified externally;943possible referenced inputs retained, plus compactJSON/helpers and activecache. No tracked asset removal or Git/LFS pruning.
-Private ZIP1924files,1,011,747,940bytes; SHA256 in Desktop reports. Complete manifest/integrity checked, source originals retained, generated duplicate staging removed. Dry-run matched1923existingfiles/1newportableviewer helper on Mac;5isolated restore cases pass.
-42launcher/viewer/guard tests pass. ActualFiery source scene60Hz has hits[1,1,1],Roll/palm/terrain/switch checks pass; Idle8286samples/Jump2160samples pass with portable user:// outputs.6Blender viewer external dependency inventories:0unpackedexternal dependencies.
-411LFS paths,localfsckOK,no ordinary newGitblob>25MiB,Windows name/case audit clean,maxtrackedclonepath194characters. Baseline10221trackedfiles preserved except explicitsetup/docs/test/launcher edits;0Blender source changes,0Godot runtime changes,0missingtrackedfiles.
-Fresh final review fixed archive restore symlink confinement and the MCP directory example; independent recheck passes. No remaining review findings. NativeWindows execution still must be checked on target machine.
-Existingpublic origin/branch retained; no install, push, history rewrite, visibility change or credentials transfer. Automaticcheckpoint manager remained active; exactHEAD can advance, so push uses the current named branch.
