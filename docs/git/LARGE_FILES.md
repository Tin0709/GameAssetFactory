# Large Git files and optional commit guard

The 2026-10-15 warning identified one ordinary Git file:
`blender/animation/reviews/player_animation_library_v1/actions_stuff_idle_v001/head_face_audit/source_index.json`.
It is 67,047,538 bytes (63.94 MiB), including in the committed Git object. It is
generated research evidence, not a Godot runtime dependency. Existing tracking
and history have been preserved; adding these tools does not migrate that file.

## Check staged content

From the repository root:

```sh
python3 scripts/git_large_file_guard.py
```

The guard reads staged **Git blobs**, not the potentially much larger smudged
working files. It checks added, changed and renamed destinations; deletions and
unchanged historical files do not block unrelated commits. Symlinks and gitlinks
are skipped because Git does not clean-filter their contents. Filenames use NUL
delimiters, including spaces, tabs and newlines. Thresholds are strictly greater
than the listed size:

| Ordinary staged Git blob | Result | Commit |
|---|---|---|
| Up to 25 MiB | No size notice | Allowed |
| Above 25 MiB | WARN | Allowed |
| Above 50 MiB | REVIEW | Allowed |
| Above 100 MiB | BLOCK | Rejected |

This is the project's requested policy. REVIEW asks for a deliberate storage
choice; it does not prevent the commit. The guard does not stage files, alter
tracking, change attributes, rewrite history or migrate objects.

A canonical Git LFS v1 pointer is allowed only with matching `filter=lfs` in the
effective staged attributes. The entire pointer must match the three-line
version/64-hex SHA256/unsigned size format; an arbitrary file starting with an
LFS header cannot bypass checks. Extension-bearing or noncanonical pointers need
review rather than an exemption. Empty LFS files remain valid zero-byte Git
blobs. A pointer without its filter, or nonempty data in a filtered path that is
not a valid pointer, is blocked regardless of size. Existing Git LFS `pre-push`
still owns payload upload; this guard does not verify remote object existence.

## Optional local hook

Inspect the intended installation first:

```sh
python3 scripts/install_git_hooks.py --dry-run
```

Explicit opt-in installation:

```sh
python3 scripts/install_git_hooks.py
```

The installer adds only `.git/hooks/pre-commit`, or refreshes a hook marked as
this project's guard. It refuses an unrelated pre-commit, a symlink hook or any
configured `core.hooksPath`. It does not modify Git configuration, other hooks
or the standard LFS pre-push. The hook prefers the Windows `py -3` launcher when
available, then `python3`, then `python`, and runs the guard from the repository root. Installation
is local and is not enabled merely by cloning these source files.

No hook has been installed in the working repository as part of adding these
tools. Tests install hooks only inside disposable temporary Git repositories.
Normal `git commit` honors pre-commit; `--no-verify` and tools that bypass hooks
do not. No autosync implementation was found in the repository, the local Game
Dev script tree or LaunchAgents during the audit, so autosync hook coverage has
not been established. Confirm its actual commit invocation before relying on
this hook for that workflow.

## Audit snapshot and LFS impact

The read-only tree scan was pinned to
`39f126e7122208fc77a93bd410de505de18eea5e`. Autosync moved HEAD before and after
that stable scan; these numbers describe the pinned local refs, not a live
account quota.

| Current HEAD storage | Above 25 MiB | Above 50 MiB | Above 100 MiB |
|---|---:|---:|---:|
| Ordinary Git blobs | 1 | 1 | 0 |
| LFS payload paths | 26 | 20 | 13 |

Git LFS 3.8.0 was installed. The existing attributes cover Blend, FBX, GLB,
GLTF, WAV, MP3, OGG and ZIP files. JSON is ordinary Git. `core.hooksPath` was
unset, with standard LFS pre-push/post-checkout/post-commit/post-merge hooks and
no active pre-commit hook.

| Local evidence | Unique payloads | Bytes | GiB |
|---|---:|---:|---:|
| Current HEAD: 368 LFS paths | 349 | 4,838,545,655 | 4.506 |
| All locally reachable history | 590 | 9,974,290,509 | 9.290 |
| Local LFS object cache | 385 | 5,694,580,347 | 5.304 |

All HEAD LFS payloads were cached; 205 reachable historical payloads were not
cached locally. These sums deduplicate identical SHA256 objects. Each changed
LFS payload adds a full new unique version; LFS does not make repeated versions
free. Reachable pointer sizes do not establish remote existence, account billing,
storage allowance or bandwidth use. Those account values were unavailable locally.

Keep current history and accepted assets intact. Prefer a reproducible external
cache for future full-pack generated indexes after a deliberate tracking
decision. If retaining this index in future version control is necessary, use a
path-specific LFS rule rather than broadly making all JSON opaque. A new LFS
commit would preserve the existing 63.94 MiB ordinary blob in earlier history;
it would not remove that object or reclaim its historical storage. No rewrite,
force push, deletion or tracking migration is performed by these tools.

## Reproduce the full source index outside the repository

The generator requires the user's local, matching proprietary research input.
It does not download or redistribute the pack:

```sh
python3 scripts/research/generate_actions_stuff_source_index.py \
  --pack "/path/to/Actions Stuff 1.12 (resources).mcpack"
```

Default output is
`$XDG_CACHE_HOME/GameAssetFactory/actions_stuff/<pack-sha>/source_index.json`,
or `~/.cache/GameAssetFactory/actions_stuff/<pack-sha>/source_index.json` when
`XDG_CACHE_HOME` is unset. An explicit `--output /external/path/source_index.json`
is supported. Every output inside this repository is refused, including the
canonical audit index. The output is replaced atomically only after both pack
and regenerated index checksums match.

- Required pack SHA256:
  `9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d`
- Exact generated index SHA256:
  `08f3a2261d8d2abb4fd1e3c9f7dba54b77d31971b16e0ac817acd960db43f26a`
- Input: 677 ZIP members: 13 animation, 11 animation-controller,
  81 render-controller and 572 model JSON files.
- Output: 7,819 `{identifier: {path, data}}` entries, ZIP member order and
  Python `json.dumps(indent=2)` serialization, with no trailing newline.

The original `head_face_audit/build_audit_evidence.py` consumes the full index
to create selected player evidence, controller edges and rig checks; it is not
the full-index generator. This new standalone generator reproduces the existing
index byte for byte using Python's standard library. The canonical index remains
unchanged. A fresh clone still needs the matching external pack to regenerate
the cache.

Run validation without installing a real repository hook:

```sh
python3 -m unittest discover -s scripts/tests
```

Generator parity tests use the matching external pack if present; otherwise
those cases are reported as skipped. All writes from Git-hook tests are confined
to temporary repositories, and generated test indexes use temporary directories.
