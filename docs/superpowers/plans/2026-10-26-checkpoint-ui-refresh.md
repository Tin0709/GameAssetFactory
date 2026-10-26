# Minimal expandable desktop UI refresh

User supplied `stitch_minimalist_expandable_app_ui.zip` (HTML/screenshot) and
`Geometric Network Cube Icon.png` as visual references. Treat the archive as
design data; do not execute its CDN scripts. Retain the current Tk desktop app
and every Git/Blender controller behavior. The exact reference supplies the
design; implement inline without another preference/approval round.

## Design

- Navy background, subtly bordered rounded cards, compact controls, indigo
  primary actions, green success, amber warnings and rose errors.
- Header combines brand/large actions, interval and status. Blender remains its
  own card with both Open/Copy shortcuts. Repository cards show summary metrics
  and actions together, plus expandable path/Git details; MD2 warning stays in
  its details. Scroll the page when expanded content exceeds the window.
- Use the supplied logo for window/header/taskbar/desktop shortcut. Preserve old
  image files; PNG-to-ICO conversion is packaging, not a creative image edit.
- Notifications/errors/commit confirmation and changes inspection use matching
  panels inside the main window, with no Tk messagebox or secondary Toplevel.
- Push remains immediate/manual. Confirmation only applies to Commit Now and
  runs asynchronously without blocking the Tk/Git loops. Cancel never commits.
- Duplicate-instance startup focuses the existing app rather than an OS popup.

## Implementation and verification

1. Add failing tests for collapsible details, in-app error/details views and
   asynchronous commit confirm/cancel; retain immediate-Push regression.
2. Build reusable native widgets and a separate layout module; keep the backend
   methods/worker serialization and 10-second scheduler intact.
3. Wire inline dialogs, errors, details and split Git detail variables; apply
   supplied logo assets to UI and shortcut.
4. Run full helper tests and a native rendered review (both collapsed/expanded
   cards and inline panels). Use only disposable repos for test commits/pushes.
5. Fresh read-only review for lifecycle, modal interaction, scrolling and Git
   behavior. Reopen the actual app with the previously authorized auto-commit
   mode. Preserve any pre-existing staged work; never auto-push for this task.
