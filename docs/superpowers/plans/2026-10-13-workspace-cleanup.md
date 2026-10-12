# Workspace cleanup plan

**Goal:** Move unused generated data and backups into the user-selected `C:/Users/ADMIN/Desktop/Unuse Files/`, preserving a working project and a reversible archive.

**Scope:** The user authorized cleanup and moving files. Preserve Git history, all canonical Blender sources, both Showcases and their manifest sources, production/test Godot resources, source maps, textures, code, documentation, final review media and compact validation baselines. Do not redesign assets or gameplay.

- [ ] Inventory sizes and inspect existing archive policy; audit external Blender dependencies and Godot resource references.
- [ ] Build an explicit per-file move plan for inactive validation media/checkpoint copies, encoded raw frame sequences, automatic backups and Python caches/logs. Protect dependency matches and uncertain inputs.
- [ ] Save before hashes and a restore helper. Verify absolute source/destination boundaries and no destination collisions. Rename files on the same volume; journal each result and verify bytes.
- [ ] Confirm retained file hashes, source manifests, Blender reopening/selection/dependencies and Godot scene loading. Run restore dry-run and report measured sizes.

**Verification:** No source missing or changed outside the explicit move plan/documentation; all moved file SHA256 hashes match; existing dependencies are unchanged; no new required missing resources; restore never overwrites existing files.

**Execution:** Perform this bounded, reversible cleanup in the current workspace as directly requested. Keep audit/scripts/restore details with the external archive. No branch, commit, permanent deletion or Git object cleanup is required.
