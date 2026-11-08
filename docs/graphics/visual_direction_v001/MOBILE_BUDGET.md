# Mobile constraints and proposed performance budgets

Status: planning allocations, not current device measurements. Device models
remain unspecified. The current project uses Godot4.7.2 Forward Mobile; desktop
RTX4070TiSUPER results do not establish smartphone speed or thermal behavior.

## Rendering choices

Keep the current Mobile path for the first slice. Treat Compatibility as a
separate appearance/acceptance path when older hardware needs it, rather than
assuming a renderer switch is just a lower setting. This follows the
[Godot4.7 renderer overview](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html).

Use the current original static fill/contact approach, one main directional
light and restrained shadows first. No real-time GI reconstruction, volumetric
fog or new fullscreen stack is necessary to establish the direction. Preserve
the visual hierarchy when optional effects are off; expensive effects should
add refinement rather than make the basic scene readable for the first time.

Manual MultiMesh reuse is important:Godot's automatic 3D instancing is specific
to Forward+, not Mobile. Keep nearby batches spatially partitioned; the current
terrain/plant chunks are10m. Do not merge the entire dressed region into one
uncullable batch. Use reviewed visibility ranges/derived LODs only where useful;
existing source import contracts forbid automatic unwrap/LOD/compression edits.
See [3D performance guidance](https://docs.godotengine.org/en/4.7/tutorials/performance/optimizing_3d_performance.html).

Retain opaque closed-volume V3 crowns. Keep alpha-tested plant cards tight around
their silhouettes and avoid stacks of large alpha-blended surfaces. More grass
can increase fill cost even with few draw calls. Reuse materials/atlases and
measure pixel cost as well as geometry. See
[GPU optimization](https://docs.godotengine.org/en/4.7/tutorials/performance/gpu_optimization.html).

Source UV2/COLOR_0 can carry roots, bending or authored colors. A lightmap bake or
new attribute use is not a drop-in operation. Do not overwrite those streams or
approved assets to obtain a cheaper lighting setup.

## Initial allocation envelope

| Target mode | Whole-frame budget | Suggested GPU allocation | Suggested main-thread allocation |
|---|---:|---:|---:|
| Low-device target30FPS |33.33ms|20ms|10ms|
| Standard target60FPS |16.67ms|10ms|6ms|
| Optional high-refresh120FPS |8.33ms|5ms|3ms|

These are proposed headroom allocations for planning, not promises or hardware
requirements already met. CPU/GPU work overlaps; do **not** add those columns to
derive frame time. Measure the actual critical path and presentation. Budget
must include future gameplay, animation, UI and audio, not just the environment.
Current WorldMap disables combat/spawn, so its measurements have a narrower scope.

A120Hzdisplay alone does not qualify120FPS. Low-device30FPS still requires a
specific supported handset/renderer test. Start by selecting real devices and
measuring the baseline, then set instance, draw, shadow and memory caps from that
evidence. There is no universal triangle count or draw-call limit in this plan.

## Quality-tier priorities

Preserve the landmark silhouette, path readability, ground palette, character
contrast and timing in every tier. First reduce decorative edge instances,
unimportant shadow casters and optional postprocess work. Next evaluate shadow
resolution/filtering and internal render scale, checking temporal quality and
material readability each time. Reduce a measured bottleneck; do not silently
remove the composition that made the scene attractive.

Start with roughly the existing visible tree count and shared source assets;
spend the first art iteration on placement. Track draws, visible/shadow
primitives, transparent coverage, resource residency and CPU/GPU times at the
same views. Set hard scene-specific resource caps after the first device pilot.

Existing scoped resource facts from the checkpoint:global sky448KiBadditional
texture residency, ground reflection576KiBobserved texture residency, actor
coefficient payload900000CPU bytes plus overhead, terrain visibility203576GPU
buffer bytes. These are not the whole scene memory cost. Toggles can leave
caches resident, so warm A/B is not an allocation measurement.

## Measurement and acceptance protocol

After an original-only development export/dependency audit, record device/OS,
renderer/backend, resolution/render scale, AA, feature state, target refresh,
power mode, temperature information if available and source/profile revision.
No export preset is currently verified; do not export the whole private-research
project indiscriminately.

Warm the scene, then collect repeated fixed-route and stationary samples.
Use a sustained approximately15minute device session to expose thermal drift;
record unavailable thermal metrics honestly. Proposed tier targets:steady p95
frame time within the selected budget, p99 within1.5times that budget, no
recurring gameplay stalls above100ms after warm-up. Record pacing and hitches,
not just average FPS. These thresholds need explicit review with the first
device pilot and do not constitute current acceptance.

Keep screenshot/movie readback out of timing runs. Use quiet desktop runs only
as diagnostics; the user previously deferred them, so do not request shutdowns
automatically. Offline clips and synthetic delta partitions prove behavior,
not real-time performance. Requalify with representative approved action load
before any shipping-game claim.
