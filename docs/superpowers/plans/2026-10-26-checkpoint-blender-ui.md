# Checkpoint app: icon, Blender bridge and steady controls

User request: replace Python icon; start the supplied pinned Blender MCP command
from the app; display live connection state; replace scan-driven button flicker
with status lights. Continue the existing desktop app, 10-second Git cadence and
manual-only Push. These concrete changes do not need another approval loop.

1. Add failing regression for buttons staying visually enabled during scan while
   duplicate actions remain serialized. Implement static repo/activity lights.
2. Add a standard-library Blender bridge controller and monitor. Use the exact
   v1.0.3 uvx argv and localhost:9876 / 127.0.0.1:8000 settings. No shell or startup
   registration. Starting is an explicit button action. Recognize existing MCP,
   refuse another service occupying the port, and never kill an existing server.
3. Verify HTTP MCP identity, read-only addon response, and end-to-end MCP tool
   response before showing connected. Bound network timeouts; keep probes off
   the Tk/Git worker threads and back off after end-to-end timeouts. No edits to
   Blender data. Monitor stops on app close; launched MCP stays available.
4. Add the generated icon to project assets; convert PNG to a multiresolution
   Windows ICO, apply to window/taskbar and existing desktop shortcut.
5. Test protocol/launch failures against disposable local fake servers, plus UI
   lifecycle and steady buttons. Run helper suite and inspect the updated window.
6. Close the old app gracefully before reopening; do not force-stop Git or MCP,
   reset settings, commit or push any actual repository during installation.

Icon: built-in imagegen, original output preserved under Codex generated_images.
Prompt: polished navy rounded tile, turquoise isometric cube integrated with a
three-node checkpoint branch and subtle amber accent; no text or existing logos.

Root cause of flicker: `_submit` and `show_changes` disable every action button,
and `_poll` re-enables them after every passive scan. Keep the existing busy
guards, remove those visual state mutations and show working/idle/error lights.

User refinement: add prominent per-folder counts for files not committed,
commits not pushed, and commits known upstream but not local. Keep the cached
upstream qualification visible, not raw Ahead/Behind jargon. Test two local
commits becoming zero after a temporary local push.

During review another real app window was opened and its automatic checkpoints
advanced the real branches. Preserve these commits; do not reset or rewrite
them. Close the app gracefully for upgrading, then reopen paused. Add a Windows
named application mutex independent of state-folder environment overrides to
prevent simultaneous managers using different runtime data directories.

Completed verification: full helper suite 106 tests green, four existing optional
skips; nine bridge tests and nine UI tests cover the new protocol, timeout,
UTF-8, steady-button, named-mutex and pending-counter behavior. Fresh independent
review found no remaining material issues. Native preview sampled 452 button
states across a full 10-second scan with zero disabled samples; real read-only
HTTP-to-Blender health succeeded. Generated multi-resolution icon and desktop
shortcut inspected. The active manager's three GameAssetFactory checkpoints and
one MD2 checkpoint were preserved, with no reset/rewrite/forced push. Evidence:
`.validation/checkpoint_manager_mcp_20261026/`.
