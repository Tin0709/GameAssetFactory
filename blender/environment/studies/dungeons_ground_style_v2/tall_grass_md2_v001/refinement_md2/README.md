# MD2 meadow refinement and one shared grass viewer — Pending

Latest user request: tall grass closer to the supplied MD2 images and present it in the same short-grass review window. Current central file remains `dungeons_ground_style_v2.blend`; no new scene, project, animation, flowers, bushes or Godot content.

## Visual change

The supplied `user-dungeons2-gameplay-2026-10-09.png` visibly has dense green bases, upright stalks and small pale cream/gold seed tips. This is an image observation, not a claim about official game topology or shaders. Existing A–D and both clusters are refined in place: three narrower upper seed-stalk cards per tuft, with lower green leaf-group cards around them. Actual resource-pack tall/short masks are retained; the small seed tint is authored from the image direction. One128×128atlas/material, same48–60triangles per A–D and156/216per cluster; visible heights stay0.72–0.94m. Roots are now narrower, roughly0.61–0.76m on A–D. No phone benchmark is claimed.

Short grass remains exactly as the user requested previously:0.500m visible height, original at-least1×1m width/length, same topology, UVs, texture and material. Original tall material/image are retained with fake users; the refined tall meshes use a new independent material/image.

## Same review page

One **Grass MD2 — Short + Tall** panel replaces the former two panels. **ALL GRASS** shows the existing short display plus six linked tall presentation copies in a back row, in the SAME `Short Grass MD2` view layer and existing scene. Individual short/tall/cluster, comparison and mixed views switch locally within one native window. Source masters and old short camera transforms remain in place.

The provided screenshot was a legacy process bootstrapped with only `MD2_SHORT_GRASS_V001`; its loaded UI/data remained old despite the saved library update. The new viewer bootstrap requires `MD2_GRASS_LIBRARY_V001`. The refreshed viewer was verified in PID60658, with12routes sharing one window pointer and finalAll. This does not mean the older PID47096 was updated. Older windows were preserved to avoid discarding possible unsaved work.

For literal in-place refresh of that older window, `scripts/refresh_environment_viewer.py` is a trusted local helper: run it from that Blender Python Console. It saves a recoverable copy of the currently loaded state, reloads the SAME central file in the SAME process/window and installs the unified panel. No global auto-run/preferences change. The helper refuses any non-environment library. It is provided for that one-time legacy migration; no destructive process closure is used.

## Tall close-up options — 2026-10-21

The Tall section now has six full-width **TALL GRASS · CẬN CẢNH** buttons: A Soft Meadow, B Open Fan, C Low Sweep, D Uneven Crown, Cluster1Meadow and Cluster2Upright. Each isolates its existing asset and fits an orthographic review camera to the complete tuft, including roots. Compared with the ordinary views, magnification is approximately1.40–1.83×. Cameras are created/reused in memory only; the saved central Blender file, model geometry, materials and textures remain unchanged. Normal Tall overview, mixed, gameplay, side and opposite options remain available.

`refresh_environment_viewer.py` now replaces cached viewer modules when rerun, so an already-open window can receive this UI-only update safely. The same live-state recovery backup and environment-file guard remain. In-Blender headless checks verify six actual selector routes, camera reuse, complete projected framing and six panel button bindings; two renders were visually checked. A double-refresh check covers module-cache replacement. Evidence is `.validation/tall_grass_closeups_v001/`; no new desktop viewer window was launched for this small UI change.

## Evidence

- `validation.json`: current-source SHA, full pre-existing native content matches when only the six authorized tall candidate meshes are restored, unchanged short data, finite planar quads, one cutout material/atlas and21selector routes.
- `native_validation.json`: actual Material Preview, unified panel, both families visible together,12switches within one window, finalAll.
- `review/`: isolated tall/mixed/side/current comparison, combined all-grass render and actual native UI captures.
- `.validation/grass_md2_single_window_v001/`: before library, raw original tall meshes/fingerprints, prior atlas/material manifests and protected-file audit. Godot and every other Blender file remain unchanged.
- Two new unified-launcher tests were RED then GREEN; retained short/tall tests,10viewer tests and16launcher tests pass.

All tall candidates remain Pending. This supersedes the previous all-green tall appearance and two-panel layout; earlier source builds/checks are historical. Do not rerun the guarded additive builders against the completed library.
