# MD2 Grass Interaction v001 — research and Blender review

Status: Pending; one new interaction candidate in the existing environment library. Wind v001 remains Pending and is preserved unchanged. No Godot gameplay/WorldMap integration in this task.

## Design contract and implementation plan

The user's detailed brief requests natural proximity/movement-directed bending, fixed roots, stronger running response, softer short grass, smooth recovery toward ongoing wind, six controls, one original-speed fixed-camera proxy demonstration and a practical Mobile implementation proposal. No grass, character, weapon or approved animation redesign.

Source footage research precedes motion design. Genuine player-passage footage has been found; current samples do not isolate an unambiguous bend/recovery response from wind, jumping, occlusion and camera movement. Therefore numerical interaction settings and spring behavior are explicitly authored adaptations of the requested result, not measured MD2 internals. Detailed timestamped evidence will follow below.

Selected Blender method: one fixed-step shared2Dspring field with displacement/velocity state, sampled from a FloatImage by a new native Geometry Nodes modifier on separate review objects. Reuse immutable existing wind meshes/metadata and the exact original first Wind modifier group. The new modifier reads incoming wind positions and adds bounded, root-masked interaction curvature; when interaction is zero/disabled its output must exactly match Wind. One deterministic cache supports scrubbing and equivalent time at30/60FPS. A simple1.8mblock-character proxy follows one route; no approved character data/Actions are touched. A shared field update avoids individual blade physics or per-clump simulation scripts.

Alternatives: per-blade rigid bodies are unnecessarily costly; pure instantaneous distance displacement snaps after exit; a full native simulation-zone cache adds review complexity and does not directly solve the future Mobile architecture. The shared grid provides visible recovery and a clear GPU-field analogue. Blender's NumPy/cache/ImageTexture implementation is a review tool, not a phone performance result or a claim that its code ports directly to Godot.

Plan:

- [x] Back up the current Wind library and8,879protected files; identify immutable Wind data/code.
- [x] Inspect genuine player-passage frames and primary technique references; keep observed/unknown separate.
- [x] Create one Pending field/proxy/interaction group in the same scene/library, sharing existing grass meshes/materials.
- [x] Add six controls and fixed gameplay/close/wind-only review routes through the existing launcher/sidebar.
- [x] Verify Wind unchanged, exact off/zero equivalence, roots/widths, directional falloff, standing contact, run/walk response, recovery, scrubbing and30/60equivalent times.
- [x] Render and inspect one clear original-speed preview covering short/walk, tall/run, dense passage, standing, exit and recovery.
- [x] Publish guarded native file, document actual evidence/limits, open the existing viewer and stop for visual approval.

Review risks: stale GN image evaluation; feedback/recursion in Blender handlers; proxy/grass timeline mismatch; preserving Wind controls and native group; root attachment under combined deformation; abrupt field-boundary/direction flips; state after reverse scrubs; static/Wind/interaction UI transitions; cache cost on control changes. All new work stays Pending.

## Verified visual references and limits

Actual native gameplay frames were inspected, rather than thumbnails or generated imagery. The saved comparison sheets and provenance notes are in `.validation/md2_grass_interaction_v001/research_visual/`.

| Primary recording | Inspected time | Visible evidence | What is not established |
|---|---|---|---|
| [Rubhen925 gameplay](https://www.youtube.com/watch?v=1H8sDTLzRNo&t=1266) |1266.00–1269.01s, native59.94FPS | Player traverses dense cyan grass; legs become partly occluded, then the player pauses near an orange glowing plant. | Grass/camera/ambient movement and glow do not isolate a local contact response. |
| [Same recording, meadow](https://www.youtube.com/watch?v=1H8sDTLzRNo&t=1105) |1105.50–1107.50s | Short grass close to feet during passage. | Shadows, pickups and pillar occlusion prevent reliable bend measurements. |
| [Same recording, seed-grass crossing](https://www.youtube.com/watch?v=1H8sDTLzRNo&t=1109) |1109.51–1111.51s | Player enters and crosses seeded grass. | Jump/landing occurs around1110.25–1110.75s; this is not a clean walk/run comparison. |
| [Shirrako co-op gameplay](https://www.youtube.com/watch?v=IgFaMgKg6vU&t=1145) |1145–1156s, native1080p60 | Repeated passage beside stone pillars and sparse grass. | Co-op rings, combat effects and follow-camera movement obscure local recovery. |

**Player-caused bending and recovery remain unverified in these samples.** This does not establish their absence. No exact radius, spring model, speed multiplier, recovery timing, vertex layout or engine technique is attributed to MD2. The candidate below is our original response design guided by the requested visual outcome and existing grass/Wind style.

## Selected deformation and recovery

One shared64×48world-XYgrid spans10×8m. Each cell stores planar bend angle and angular velocity; actor influence combines outward proximity with forward motion, weighted by smooth cubic distance falloff. Movement bias avoids a hard forward/backward flip while passing a root. Safe normalization handles zero velocity/distance. Influence is zero beyond the radius and on the outer grid border.

Authored defaults:

| Control | Default | Meaning |
|---|---:|---|
| Player Interaction On/Off | On | Exact incoming Wind passthrough when off. |
| Interaction Radius |0.90m | Smooth influence around the proxy. |
| Interaction Strength |1.15 | Speed-scaled target, capped at0.95rad before family response. |
| Bending Response |18/s | Contact spring response. |
| Recovery Speed |6/s | Critical recovery toward zero contact force. |
| Walk/Run Preview Speed |1× | Proxy route multiplier only; Wind time stays unchanged. |

A closed-form critically damped spring step at120Hz, with smoothly varying response near contact, prevents sustained ringing. After leaving, it tends toward zero contact displacement while Wind continues independently. For a stationary target removed from rest, the6/s spring is approximately95% recovered after0.79s; actual passing contact includes nonzero velocity. Short response is0.38, tall response1.0. A focused equal-distance1m/s versus3m/s check gives1.65×target strength; this is authored, not a source measurement.

The second Geometry Nodes modifier reads **incoming Wind Position**, immutable per-card root/rest/height/length attributes, and the shared field. World root coordinates map into the field, then sampled vectors rotate back into local space. It adds contact curvature to the current wind curvature and bounds the combined angle to1.1rad while contact is active. Tip displacement grows with height squared; vertical lowering uses height cubed. Every vertex pair on one card ring gets the same displacement, preserving width. Roots have zero deformation. Zero field/off/outside-domain passes incoming Wind exactly, including existing tip flutter.

The original Wind node tree, modifier inputs/drivers, controls, seeds, wind meshes/attributes, directions, gusts, speed and material data remain exact. No interaction state feeds back into Wind or the immutable rest/root coordinates.

## Blender review implementation

Same library: `blender/environment/studies/dungeons_ground_style_v2/dungeons_ground_style_v2.blend`; same scene: `REVIEW_DungeonsGround_Style_V2`. One top-level Pending collection and isolated view layer contain43linked grass clumps/2,566grass triangles,35existing ground-block mesh instances, a neutral1.8mblock proxy and dedicated cameras/lights. No new grass mesh, material redesign, Blender Action or scene. Existing data is shared; earlier review layers exclude the addition.

Implementation lives in `grass_interaction_md2_v001/`: `field.py`, `interaction_nodes.py`, `runtime.py`, `interaction_review_ui.py`. It caches60Hzfield samples for deterministic frame-order-independent scrubbing. One Non-Color float image upload and one shared node-group update tag refresh every user. A native probe established that image.update alone can leave paused Geometry Nodes stale; the group tag fixes this without per-clump update loops. Explicit root→UV links are required because an unlinked Image Texture Vector socket implicitly uses Position. [Blender5.2native node implementation](https://raw.githubusercontent.com/blender/blender/blender-v5.2-release/source/blender/nodes/geometry/nodes/node_geo_image_texture.cc)

Native frame handlers update the proxy and field from the same time; repeated evaluation never advances physics. A re-entry guard and state signature prevent handler recursion. Numeric control edits rebuild the cache synchronously: approximately0.50–0.52s and29.5MB at defaults on this host, approximately59MB at0.5×preview speed. These are Blender review costs, not a runtime design or phone benchmark. No per-blade rigid bodies or individual grass scripts are used.

The unified **Grass MD2 — Player Interaction** sidebar has fixed gameplay/close views, Play/Pause, Restart, six controls and an unchanged Wind comparison. Static/Wind/interaction switching restores the live prior timeline. Shared viewer bootstrapping changes only route registration; Wind's code files stay byte-identical. Open with the established `open_blender_viewer.py asset` command. Directly opening with auto-execution disabled needs that trusted launcher to register the new handlers/UI; no global auto-run preference was changed.

The20-second24FPSclip uses native fixed-camera frames, no retiming:

| Time | Review action |
|---|---|
|0–5.1s | Enter and walk through short grass. |
|5.1–8.4s | Run through tall seed grass. |
|8.4–10.5s | Cross the dense central patch. |
|10.5–13.5s | Stop; proximity contact remains while Wind continues. |
|13.5–18s | Leave, allowing grass to recover behind the proxy. |
|18–20s | Recovered field; Wind alone continues. |

The proxy is presentation-only; its route/gait does not modify or represent the approved gameplay animations or movement speeds. It starts/ends outside the field; field state has recovered to exact zero at the20sloop boundary. Wind's existing20sloop remains unchanged.

## Recommended Godot4Mobile architecture — planning only

Use a common vertex deformation function for ambient wind, gust, flutter and contact. Preserve immutable local root/rest/height data through custom vertex channels; the atlas UVs already locate texture tiles and must not be mistaken for a height mask. Transform roots into worldXZ, sample field/trails there, then transform displacement back. Include matching normal treatment and conservative combined-deformation bounds. Keep the existing texture/material/alpha presentation; tune masked-card density and overdraw before adding more blades.

For few nearby interactors, compare a bounded array of swept player/zombie trail segments against a small shared spring grid. Actor records should carry stable ID, current/previous ground position, planar velocity, radius, strength, height/region and timestamp. Reserve capacity for the player, cap summed influence, age stale trails out smoothly, and use swept stamping/substeps so fast running cannot leave holes. A capped CPU field offers genuine displacement/velocity recovery with cost independent of blade count; upload data in bulk, not pixel-by-pixel GDScript calls. [`ImageTexture.update`](https://docs.godotengine.org/en/4.7/classes/class_imagetexture.html#class-imagetexture-method-update) reuses initialized storage if dimensions/format/mipmap settings match; `set_image` reallocates.

The [Franos-cm author demo](https://github.com/franos-cm/grass-demo#player-interaction) provides a relevant history→shared-texture example. Its fading stamped history is a recovery technique, not a spring solver or MD2 evidence. No demo code/assets were copied. GPU fragment/compute ping-pong fields are optional later scaling paths: use separate read/write textures, deterministic scheduling, linear data encoding and no readback. Compute is supported by Mobile/Forward+, but official Godot documentation warns about mobile driver reliability. It is not the default requirement. [Godot compute guidance](https://docs.godotengine.org/en/4.7/tutorials/shaders/compute_shaders.html)

Partition foliage into regional MultiMeshes; one global field does not imply one global culling object. Each region's AABB must include instance transforms and maximum combined Wind/contact displacement. [Godot MultiMesh](https://docs.godotengine.org/en/4.7/classes/class_multimesh.html) documents single-object culling and instancing tradeoffs. At128², RG16F display displacement is64KiB/update; a pair of RGBA16F displacement/velocity state textures is256KiB total. These are sizing arithmetic, not measured mobile budgets. Start smaller and measure frame time, upload cost and overdraw on actual Android/iOS hardware at30/60FPS before selecting an updater/quality tier.

For a player-centered field, shift displacement **and velocity** by identical integer-cell world offsets, clearing exposed cells; changing only UV origin drags history. Handle teleport/reset explicitly. A flat2Dgrid cannot distinguish stacked bridges/caves at identicalXZ. Future terrain needs ground-height gating or per-surface fields; actor height alone at sample time cannot correctly classify older history. Current preview deliberately uses one flat ground surface. Transform support is heading/translation only with applied unit scale; arbitrary rotated/scaled parents require a full inverse basis.

## Internal verification and preservation

Fresh native Blender5.2.2LTSreads compare every pre-existing object's authored content, mesh, material, image, camera, light, world and scene-render data. Hidden Wind originals can load identity matrix caches despite correct evaluated transforms: establish an all-visible temporary graph, then tag objects and update again on both reads. No comparison fields were ignored. A separate digest includes the original Wind tree/interface, controls, modifier values, drivers and all Wind attributes. All matched.

Results in `.validation/md2_grass_interaction_v001/verification.json`:

- Fixed roots:0merror; preserved ring width: maximum8.43e−8m.
- Disabled and zero-strength versus actual first Wind modifier:0merror.
- Recovered contact at20s versus Wind alone:0merror; reverse/repeated scrubs:0merror.
- Native equal-time30/60FPSgeometry:0merror; largest adjacent sampled step47.8mmat30FPS,24.0mmat60FPS through running contact.
- Largest sampled contact contribution versus Wind:0.294m; largest total sampled displacement0.385m.
- Native automatic handlers matched forced evaluation; paused controls, stationary contact/Wind and live static↔interaction↔Wind timeline routes passed.
- Nine focused launcher/routing tests passed. Encoded clip decoded480frames,20.00s at24FPS.

These establish internal correctness on this desktop. Artistic quality awaits review; phone performance, complex terrain, many interactors and Godot shader integration remain untested and out of scope. Every pre-existing protected Blender/gameplay file is audited by SHA256; the only intended pre-existing Blender text changes are the shared UI registration and additive native catalog entry. Source-derived research assets remain development-only.

Published readback passed the same native suite. SHA256 audit:8,879pre-existing protected files,8,877exact; only the authorized shared grass UI and catalog changed. All Godot files, other Blender libraries and Wind v001 folder bytes are exact. The updated existing launcher opened native Blender PID6688 with the Interaction layer/sidebar, playback enabled, frame1→49 in2.008s (24FPS target). This is native API/log confirmation of playback, not a screenshot of that window or phone-performance evidence. The existing source Wind and unrelated Soldier windows were not operated on. Candidate status remains Pending.
