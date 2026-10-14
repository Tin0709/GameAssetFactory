# Cleanup and migration result —2026-10-14

Initial validation status: cleanup and validation completed locally with no staging, commit or push at that stage. The user subsequently approved final synchronization on2026-10-14, conditional on exclusive Git access. This report retains the original audit context; the final synchronization handoff supplies the resulting commit/push status. Current observed main HEAD: `c99ec80042749f38e434e6f32ee7eead2d83042a`; upstream `origin/main`, remote `https://github.com/Tin0709/GameAssetFactory.git`. That external process created/pushed `c99ec800` during the audit (audit/plan/test files); it was not this task's final cleanup commit. Do not rewrite it. Recheck HEAD/index after all writers are paused before the later authorized final commit.

## Cleanup and preservation

- Archived exactly8 ignored rawAVI intermediates, **201,727,388 bytes**, outside the repository under `C:/Users/ADMIN/Desktop/Unuse Files/GameAssetFactory_Migration_2026_10_14/archived_raw_reviews/`. Source/archive SHA256 matched before removing working copies; final H264 reviews remain. Restore paths/hashes: external `restore_manifest.json` and [durable copy](validation_2026_10_14/raw_review_archive.json).
- Preserved all existing approved/Pending Actions, rigs, models, materials/textures, Showcases, weapon versions, gameplay/controllers, research outputs, instructions and historical exports. All7491 initially tracked files were hash-checked; only17 intended existing text/config/tool entry files changed. [Preservation report](validation_2026_10_14/preservation_validation.json).
- Preserved local ignored validation history in place and made an additional byte-verified external migration snapshot: **4896 files / 2,570,577,334 bytes**, including drafts/backups/scripts/NPY caches. External `local_validation_snapshot_manifest.json` records every hash. Transfer this archive manually if local history is needed on Mac; it is deliberately not added to Git/LFS.
- Removed the temporary tracked-only Godot validation copy after verifying1815 source copies still matched and saving test reports. No unique source data deleted. Added precise macOS/Python/build-cache ignores; no tracked caches removed because none were found.
- Preserved11 identical Blender/GLB groups because paths may be historical or referenced. Existing LFS already deduplicates identical payloads. Git history, dangling objects and13 small old Git temp objects remain untouched; no `git clean`, gc/prune, history rewrite or LFS migration.

## Portability changes

- New standard-library `scripts/dev.py` discovers explicit/environment/PATH/default Windows and macOS app executables. Commands open Godot, either Showcase, or the installed MCP bridge; `--dry-run` prints arguments safely. Windows wrappers retain existing scene choices and D3D12, and no longer embed a user download path.
- Explicit repository Showcase UI loading works without a per-user Animation Library add-on. All source files remain unsaved. Portable MCP entry points locate the installed1.0.3 extension through Blender's user config path and retain loopback-only IPv4 binding.
- Active World Map importer, cuboid exporter and audio extraction tool use relative repository/project paths. Gameplay scripts, animation cadence, controller logic and approved Actions are not changed by this task.
- Five original research recordings (8,048,230 bytes) are now portable source inputs with exact hashes under `references/motion/actions_and_stuff`. Main deep-study decode entry scripts use those inputs and font fallbacks. Existing charts/annotations/measurements remain byte-identical.
- Added [MacBook setup](MACBOOK_SETUP.md), root navigation, scoped line-ending attributes and [historical tool limitations](HISTORICAL_TOOL_LIMITATIONS.md). Old builders/provenance are preserved; no mass path replacements or asset-directory renames.

## Verification and limits

| Check | Result |
|---|---|
| Current LFS |350 paths /330 unique objects /4.34 GB; all local hashes and GitHub download-availability metadata pass|
| Git connectivity |Pass; existing dangling objects preserved|
| Python launcher + map tests |19 pass; macOS app discovery/commands simulated on Windows|
| Tracked-only Godot import |Clean; no old .godot cache|
| Literal Godot source/resource links |529 checked; missing0/case mismatches0|
| Fresh-project runtime tests |Native72 + FastJump45 checks pass at30FPS, physics60Hz|
| Fresh main scene |Headless90-frame smoke exits cleanly|
| Blender |28 Actions/slots/ranges/source hashes,3 weapon entries/all fit modes pass;175 tracked .blend files scanned for unpacked images/linked libraries; missing0|
| glTF |145 assets parsed; external buffers/images0|
| MCP |Real read-only execute request succeeds on isolated port19876|
| Sources/reviews |All original binary assets, runtime controllers and research outputs byte-identical|

Evidence: [validation folder](validation_2026_10_14/). The Showcase test evaluates playback ranges and selection in background Blender; it is not a newly recorded manual GUI playback review. The LFS check verifies current required object availability metadata, not every historic branch or account quota. No new large LFS payloads or history migration were introduced. The old working project's earlier30/60FPS visual reviews remain preserved; this migration's fresh import test is30FPS and headless. Automated success does not prove visual game quality or Mac/mobile rendering/performance.

Manual Mac setup still required: install matching Blender5.2.2/Godot4.7.2, Git/LFS/Python/uv; retrieve LFS; install Blender Lab MCP1.0.3 and configure its local Codex client; transfer ignored local history if desired; run the [Mac visual/MCP smoke checklist](MACBOOK_SETUP.md). Full-history clones are large; recommended shallow clone avoids unnecessary history download. Do not use an older editor to save approved sources without separate review.

Final fresh read-only review found no blocking portability/preservation issue. Its minor IPv6 override mismatch was corrected to match the installed bridge's IPv4 sockets. The user has approved the single-writer final commit/push. Confirm its resulting SHA and remote status in the final synchronization handoff; the checks above describe the preserved cleanup snapshot.
