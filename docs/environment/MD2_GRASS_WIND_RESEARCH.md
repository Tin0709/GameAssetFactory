# MD2 Grass Wind v001 — research and Blender review

Status: Pending. Scope is the existing environment Blender study only. No Godot integration or character interaction is authorized in this pass.

## Design and implementation plan

The user's detailed brief is the design contract: soft anchored bending, a shared moving gust field, distinct short/tall responses, restrained secondary flutter, a 20-second original-speed field preview, individual/field/static comparison views and nine controls in the existing viewer. Preserve all existing source meshes, materials, cameras and approved libraries. Finish the preceding pale-stalk fan refinement first; its published geometry is the wind baseline.

Selected approach: one native Geometry Nodes deformation group on separate Pending copies, evaluated from rest coordinates and scene time. Each card receives explicit root, normalized height, length and group-phase attributes on independent mesh copies. Existing 3/4 horizontal rings are sufficient for a restrained piecewise curve; no source topology changes. World-space sampling coordinates and inverse object heading make rotated neighbors respond to the same wind. Static meshes remain available. This continues the existing review-only wind workflow while replacing its per-frame Python mesh writes for this new grass family.

Alternatives considered: the older Python frame handler is easy to extend but depends on script registration and edits every vertex on the CPU; rigid object rotation is cheap but fails the requested root/upper-blade behavior. Geometry Nodes keeps native review animation self-contained after opening and exposes the same rest/mask contract intended for a later GPU shader. Blender modifier evaluation is not evidence of Godot/mobile performance.

Execution checklist:

- [x] Fan the pale central seed cards outward and verify preserved roots, Z, leaf cards, UVs and materials.
- [x] Inspect the accessible actual TikTok sequence before choosing motion; investigate official gameplay and primary technique references.
- [ ] Add separate wind-capable copies, shared native nodes and mixed field in the same scene/library.
- [ ] Add controls, individual short/tall views, close/gameplay field and static comparison routes.
- [ ] Check roots, zero strength, finite bounds, heading coherence, non-accumulation and 30/60 time sampling against evaluated native geometry.
- [ ] Render and inspect a 20-second original-speed preview and contact sheets; reopen source and verify original assets/other files.
- [ ] Open the existing environment viewer ready for visual review; keep Pending and stop before player interaction/Godot.

Review focus: root attachment under gusts; short grass not shaking like a carpet; secondary motion not tearing cards apart; direction/strength controls working after reopen; world field remaining coherent for rotated clumps; source assets unchanged; restoring original static routes/timeline.

## Evidence and limitations

Motion settings below are authored adaptation values, never undocumented Minecraft Dungeons II internals. Research performed2026-10-21. Actual source sequences were decoded and inspected; this does not mean every source was watched uninterrupted.

### Verified visual references

| Source / timestamps | Direct observation | Confidence / limits |
|---|---|---|
| [User TikTok](https://vt.tiktok.com/ZSgUMrJ2A/), resolving to [verified @minecraft](https://www.tiktok.com/@minecraft/video/7697877006108626207), daylight0.00–1.60s; samples every0.20s | Stones, mushroom, pond edge and wooden arch stay visually stable while broad upper grass/fern silhouettes sweep laterally. Lower clump footprints remain planted. Neighboring silhouettes respond together with local differences; thin white flowers also move. | Strongest visual evidence. Roots are occluded, so literal zero root-vertex displacement cannot be measured. The fern has more screen sweep than dense short grass, but depth/height differ; no numeric response ratio follows. |
| Same TikTok,1.6–2.5s and2.5–6.5s | Daylight visibly changes to night; vegetation continues moving. | Edited promotional footage, not a calibrated normal-speed gameplay clock. Its7.10s duration does not establish a wind cycle. TikTok web-tool access failed, but public HTML/media access succeeded; no missing MP4 request is needed. |
| [Official Minecraft article](https://www.minecraft.net/en-us/article/minecraft-dungeons-ii-gameplay-trailer) and matching-title/date [Minecraft channel trailer](https://www.youtube.com/watch?v=vBNE3bKMpu8),44.30–45.80s merchant shot | Layered upright tufts show continuing upper-blade silhouette changes around the merchant. | Supporting evidence; slight camera/character motion and the short shot limit isolation of pure wind. Flat-looking silhouettes do not prove card meshes or a shader technique. Article embed ID was not exposed by the text extraction; video provenance is matching title/date and official channel. |
| Official trailer42.50–44.00s | Outdoor vegetation frames the path/terraces during combat. | Camera tracking and effects make wind measurement unreliable.44.25s is already the following shot. |
| [XboxDynasty original recording](https://www.youtube.com/watch?v=mgzk7uhAfjk), [uploader's Series X capture description](https://www.xboxdynasty.de/news/minecraft-dungeons-ii/9-minuten-neues-gameplay-direkt-von-der-xbox-series-x/comment-page-1/),150–158s and220–228s; dialogue225.50–227.50s | Continuous HUD gameplay, including grass at the right wall during dialogue. | Published frame timing retained without local retiming; recording speed is not independently calibrated. Night lighting, compression and camera drift yield no additional reliable wind measurements. |

Research source encodings: TikTok720×1280/30fps; official trailer1280×720/59.94fps; uploader samples720p/60fps. These are acquisition properties, not game simulation rates. Community resource-pack screenshots influenced the existing static assets, but are not substituted for genuine MD2 wind footage.

Timestamped comparisons: [TikTok daylight](../../blender/environment/studies/dungeons_ground_style_v2/grass_wind_md2_v001/research/tiktok_daylight_motion_sheet.jpg), [official merchant shot](../../blender/environment/studies/dungeons_ground_style_v2/grass_wind_md2_v001/research/official_trailer_merchant_grass_sheet.jpg). Six native source frames and detailed acquisition notes remain in `.validation/md2_grass_wind_v001/research_visual/`. Research excerpts are not production textures/assets or an invitation to redistribute the source videos.

### Observed versus unresolved motion

The usable evidence supports a planted footprint, stronger upper response, broad soft sway and local variation. Apparent lateral direction changes are visible; the world-space prevailing vector cannot be recovered reliably from these views. Small continuing motion is clear, while the footage does not isolate a complete stronger-gust/recovery cycle. Coordinated neighboring motion is visible; actual front propagation speed is not measurable. Fine flutter cannot be reliably separated from overlapping silhouettes/compression. No exact meters, degrees, frequency, damping constant or source formula is asserted. Tracking a single blade through these occlusions would give spurious precision, so no pixel-to-meter estimate is reported.

The moving gust and secondary flutter in our candidate implement the requested artistic behavior as original additions. There is no evidence here that MD2 uses Pivot Painter, vertex colors, this noise, these frequencies or individual blade physics. Its use of Unreal Engine does not establish its foliage implementation.

## Technique references and local asset audit

[Victor Karp's author tutorial](https://victorkarp.com/godot-foliage-wind/) uses panned noise, height/tip vertex-color masks and world-position variation. Its useful principles are separate anchoring/tip response and coherent world direction. [Malido's published shader](https://godotshaders.com/shader/stylized-multimesh-grass-shader/) samples world noise and uses an assumed `1−UV.y` height convention; the author warns about zero wind direction. This project's packed-atlas UVs do not satisfy that convention. The source code is CC0; depicted images/video/assets are excluded. Our Blender equations/nodes are independently authored.

[Epic Pivot Painter2.0](https://dev.epicgames.com/documentation/unreal-engine/pivot-painter-tool-2.0-in-unreal-engine) stores per-element pivot/direction/hierarchy data for vertex animation. The general pivot idea transfers; its Max/Unreal hierarchy pipeline is unnecessary for these low-card tufts. No Epic script/material/asset is copied, and no connection to MD2 internals was established.

Current short cards have three horizontal vertex rings; tall cards have four. Individual source tufts have `Wind_Metadata`, but merged clusters do not all retain it. Native audit therefore uses connected card components on independent copies to author equivalent POINT attributes: immutable `md2_wind_rest`, per-card `md2_wind_root`, normalized `md2_wind_t`, length and phase. Texture UVs, source geometry and colors remain exact. Three/four rings are enough for this restrained piecewise bend; close extreme deformation would need more subdivisions on a future candidate, not a source overwrite.

Local existing `blender_strong_wind_v1.py` edits tagged independent preview meshes from rest. The new native Geometry Nodes group follows that rest-based principle without a frame handler. Existing Godot `m2_grass.gdshader` already has root/mask/instance metadata and cutout behavior, but belongs to a different asset contract; it has not been reassigned or edited.

## Selected Blender implementation

`MD2_Grass_Wind_v001` is one shared native modifier group on11 independent wind meshes representing all5short and6tall assets. Its new Pending collection and view layer are in the SAME existing scene/library. The mixed7×5block field has47clumps/1,790grass triangles; static ground uses existing linked mesh/material data. Wind cards retain the original topology and silhouette at rest. No flower, ground, source grass, character, Action or other library was modified for wind.

For card height fraction `t`, horizontal offset grows approximately with `t²`; small vertical shortening grows with `t³`. This is a small-angle arc approximation applied to the rest curve, with identical offsets across each ring pair. Roots have exactly zero weight. Main bending, a small transverse sway and tip-only `t⁴` flutter are summed from rest every evaluation. Blade groups receive phase differences, rather than independent random vertex jitter. The existing fan-out of the pale seed cards is retained.

The gust envelope is a smooth positive sine lobe raised to the fourth power. Its phase depends on time minus root position projected along the common wind vector, so the crest moves through the field. Low-frequency4Dworld-noise variation follows a circular path, and ambient/flutter harmonics close at the default20s duration. This deliberate periodic path avoids assuming ordinary scrolling noise loops. Other direction/strength/response settings remain usable; arbitrary changes to speed or gust frequency need not loop in exactly20s. Recovery is a smooth envelope/curvature return, not a physical spring simulation.

World origins and Z headings are native transform drivers. Bend vectors are converted back to the local heading; rotated clumps therefore respond to the common field. The reviewed copies use applied unit scale and Z rotation only. This group is not a general arbitrary-deformation/hierarchy simulator. Future Godot transforms require their own verified implementation.

### Controls and authored defaults

All are in **Grass MD2 — Wind · Pending**, within the existing **Grass MD2** sidebar tab.

| Control | Default | Practical range / purpose |
|---|---:|---|
| Wind Enabled | on | Off restores exact rest. |
| Wind Direction |0.60rad/~34°|−π…π, global horizontal direction. |
| Wind Strength |0.85|0…2; zero restores rest. |
| Wind Speed |1|0…2; zero freezes the field. |
| Gust Strength |0.70|0…1.5. |
| Gust Frequency |0.05Hz|0.01…0.15Hz before speed; default one traveling envelope per20s. |
| Per-Clump Variation |0.65|0…1, small phase/noise/tip differences. |
| Short Grass Response |0.38|0…1.5, restrained/grounded. |
| Tall Grass Response |1|0…1.5, more readable bend. |

These settings were tuned for our0.5m short and0.72–0.94m tall family. They are not measurements from MD2. Main bend is bounded at0.9rad for control extremes. Root anchoring and width preservation are structural; visual likeness still needs user approval.

Views: Mixed field, Close-up, Gameplay and Static/Wind, plus11individual short/tall/cluster entries. Play/Pause is original-speed timeline playback; Restart returns to the beginning. Startup opens the field and starts playback through the trusted viewer bootstrap. Static routes remain in the existing panel and restore the static review timeline. No global auto-run preference change is required.

## Recommended Godot4 Mobile implementation — proposal only

Use an original GPU vertex shader after visual approval; do not export baked per-frame mesh animation or simulate every blade. Keep a shared direction/strength/clock field, explicit rest-height masks and a small tip term. Preserve atlas UVs. Map Blender Z-up to Godot Y-up deliberately. If masks later occupy vertex colors, read them intentionally rather than tinting the atlas accidentally. Shader masks and per-instance color multiplication need a documented import contract.

Choose one coordinate convention: [Godot spatial shaders](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html) default to local vertices; `world_vertex_coords` permits world editing. A local implementation needs the true inverse model basis for world displacement. A transpose is only sufficient for an orthonormal basis. Use a shared custom clock if pause/scrub/long-session behavior matters; built-in `TIME` is time-scale-dependent and rolls over by default.

[Global shader uniforms](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html#global-uniforms) suit the common field. Set values without per-clump CPU animation or repeated rendering-server readback. Each [MultiMesh](https://docs.godotengine.org/en/4.7/classes/class_multimesh.html) batch can use `INSTANCE_CUSTOM` for stable phase/amplitude/stiffness data; a node-level `instance uniform` is not a separate value for every MultiMesh blade. Configure custom-data/transform flags before allocating instance count.

Partition grass into local regions: [MultiMeshes are culled as a whole](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html), not per tuft. Reuse a mesh/material within each batch; region size and density must be measured. Set conservative local `custom_aabb` from the transformed rest bounds plus maximum wind displacement. The present unit-scale parameter bounds imply roughly0.54×card-length horizontal and0.14×card-length downward allowance; validate actual imported bounds, then add a separate bound for future interaction. Do not use a map-sized box to conceal culling errors.

Keep hard-edged [alpha scissor](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html#transparency) and tightly fitted cards. Avoid unnecessary transparent overlaps/blended fading. Animated shadow cost is a separate choice: the current wind copies retain source grass no-cast-shadow behavior. `shadows_disabled` stops receiving shadows, not casting; node cast-shadow settings must be managed explicitly. [Mobile GPU guidance](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html) favors simple shaders/few texture reads; triangle counts alone do not establish performance.

Suggested scalable tiers are proposals, not measured presets: low uses regional density reduction and one cheap bend; medium adds coherent gusts; high/near adds restrained tip motion/noise. Use genuinely cheaper shader variants where needed. Merely multiplying expensive terms by zero does not prove the work is removed. [Smooth visibility-range fades are Forward+ only](https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html); use sensible regional hysteresis on Mobile. Automatic MeshInstance instancing is also a Forward+ feature, so explicit MultiMesh batching is the relevant Mobile strategy. Test static/wind, density, shadows and resolution on actual Android/iOS hardware, with sustained30FPS/33.3ms targets. No phone performance result is claimed here.

## Future player/zombie interaction boundary

Reserve an additional root-masked local interaction displacement after the environmental wind calculation. A later bounded world-space force field can bend away from characters and recover through its own time/envelope contract, while sharing the root/mask metadata and final displacement bounds. No player positions, collision queries, compression, actor physics or interaction forces are implemented now. Godot production WorldMap and current gameplay remain untouched.

## Validation and review outputs

Evidence is under `.validation/md2_grass_wind_v001/`; native fresh-read checks compare all pre-existing content at matching frame/dependency-graph state and verify original grass mesh/UV/material data separately. The build also performs immediate native preservation checks before staging. Frame-cache differences on untouched original files are not mistaken for authored edits.

Essential checks cover exact roots, unchanged ring widths, finite positions, zero strength/disabled rest, frozen time, deterministic scrubbing, the default20s seam, 30/60FPS equal-time shape parity, world headings0/90/180/−90°, exact15route render/viewport isolation, static timeline restoration and protected-file hashes. Original-speed rendered clips and native viewer review are the visual evidence; numeric checks are not artistic approval or a mobile benchmark.

Final preview paths and measured check results are recorded in the adjacent wind manifest/README after verification. No new permanent library, project, scene, Blender Action, Godot integration or player interaction is part of this work.
