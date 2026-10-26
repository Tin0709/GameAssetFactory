# Descriptive automatic checkpoint messages

User requests new commits with the GitHub-expanded description shown in their
screenshot: a readable category/title, added/modified/deleted file totals,
text-line additions/deletions, binary count and quoted file list. Build this
deterministically from the final staged diff, not worktree contents. Treat LFS
assets as assets rather than counting pointer lines. Never invent intent such
as a bug fix, feature completion or artistic approval. Preserve older commits.

Implementation: add message builder under `scripts/checkpoint_manager`, exercise
real temp commits for docs, mixed text/binary, LFS and unusual names, then call
ordinary Git commit through UTF-8 stdin (avoid Windows command-line limits).
Keep hooks, Git safety checks, 10-second cadence and manual-only Push unchanged.

Latest user authorization: after finishing, open the actual app and enable
automatic commits for both folders. Add an explicit `--auto-commit` launch flag,
which enables only after initial status reading; normal launch stays paused.
Validate the first real new checkpoint description if eligible changes exist.
No Push is requested. Do not start a second manager over an existing one.

Verification: full helper suite 113 tests green with four existing optional
skips. Fresh review's deleted-LFS-attributes case was reproduced and fixed by
batch-identifying small old pointer blobs from HEAD; no other material findings.
Normal startup remains paused, explicit auto startup waits for initial status,
and Pause cancels the pending auto-enable. Real launch/first-checkpoint evidence
is recorded outside Git in `.validation/checkpoint_messages_20261026/`.
