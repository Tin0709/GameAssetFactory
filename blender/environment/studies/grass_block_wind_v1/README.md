# Grass block and wind study v1

Blender review only, created October 8, 2026. No Godot runtime, export, or production environment asset changes.

Open `grass_block_wind_v1.blend` in Blender 5.2 or newer. The Layout viewport starts in the hero camera. Press **Space** over the viewport or timeline to play the wind loop; playback is frames **1–96 at 24 fps**, four seconds. Use **Numpad 0** to leave/return to camera view and orbit to inspect the geometry. The `03_REVIEW_STUDIO` collection holds the floor, lights, and three cameras; hide it for asset-only inspection. The in-file `REVIEW_NOTES` text gives the wind design and review instructions.

## Assets

| Object | Dimensions, X × Y × Z | Geometry |
| --- | --- | --- |
| `ENV_GrassDirt_Block_1m` | **1.000 × 1.000 × 1.000 m** | 174 vertices, 121 polygons, 344 triangles; one closed, connected mesh |
| `ENV_Grass_Tuft_Hero` | Approximately **0.479 × 0.362 × 0.440 m** in its undeformed basis | 224 vertices, 196 polygons, 392 triangles; fourteen closed rectangular blades in one mesh |
| `ENV_Wind_Global` | Preview controller, no geometry | One global phase driver |

The block has a green top, sparse pixel patches, brown dirt sides, and an actual stepped grass rim. A 6 mm inset dirt body gives the rim a small overhang while keeping the complete block inside its exact one-meter bounds. The green fingers descend to Z=0.75–0.875 m. Rotation is zero and scale is one on both assets; the block origin is at the bottom center. The separate grass mesh has its origin on the local root plane Z=0 and is placed at world Z=1 on the block.

Both assets use `ENV_Pixel_Atlas_Opaque` and the packed, nearest-sampled `ENV_Atlas_64_Nearest`. The standalone `environment_atlas_64.png` is included for inspection; the Blender file does not depend on it being present. No bevels, subdivision, transparency, armature, or dense modifiers.

## Wind loop

`ENV_Wind_Global["phase"]` is driven by `2*pi*(frame-1)/96`. Four signed shape keys (`Wind_X_Sin`, `Wind_X_Cos`, `Wind_Y_Sin`, `Wind_Y_Cos`) use that same phase. The upper blades bend with normalized blade height squared; the four vertices at each blade's root remain exactly fixed. A slight height-dependent phase delay creates a soft bend rather than rocking the whole tuft.

The equivalent local displacement is:

```text
t = normalized height within each individual blade
dx = 0.018 * t² * sin(global_phase - 0.28*t)
dy = 0.007 * t² * sin(global_phase + pi/3 - 0.23*t)
dz = 0
```

The `WIND_HEIGHT_SQUARED` vertex group stores `t²` for inspection and a possible later deformation mask. At maximum sway, measured vertex displacement is about **1.83 cm**.

The loop is seamless. Frame **97 duplicates frame 1** and is excluded from playback. Fresh-file validation measured zero position error at the seam, about 0.000000833 m/frame velocity error from finite differences, and zero root displacement across all 97 sampled frames. `validation_report.json` records these measurements and the geometry checks.

## Later synchronized wind in game — recommendation only

Use a shared wind material/shader with **one global time/phase**, `2*pi*global_time/4`, across all instances. Apply the same wind direction in world space, converting it to the mesh's local coordinates before displacement as needed. Anchor the local root plane and preserve the per-vertex height mask. With this varied-height tuft, normalizing against the entire mesh height would change the per-blade bend; use the stored mask and recover `t = sqrt(mask)` instead. Blender's Z axis will need conversion to the future game's up axis.

Keep phase identical by default. Optional small seeded amplitude variation, such as ±10%, can soften repetition. Small seeded phase offsets are also possible later if desired, using the same global clock. Avoid separate animation clocks per instance. This study provides the visual recipe only; no Godot shader, runtime code, or exported asset was created.

## Review views and outputs

- `REVIEW_Camera_Hero`: overall block proportions, palette, and grass scale.
- `REVIEW_Camera_Grass_Detail`: grass silhouette and subtle sway.
- `REVIEW_Camera_Block_Back`: opposite block sides.
- `preview_hero.png`: rendered overview.
- `wind_preview.gif`: four-second close-up loop sampled at 12 fps.
- `REVIEW_NOTES.txt`: the same guidance as the in-file text.
- `validation_report.json`: fresh-file measurements.
- `build_study.py`, `verify_study.py`, `render_wind_preview.py`: repeatable build, validation, and preview recipes. Build requires a fresh unsaved factory session and refuses to overwrite an existing study.
- `correct_atlas.py`, `refresh_packed_atlas.py`: repair history for the initial atlas color conversion and cached packed bytes; do not rerun `correct_atlas.py` on the corrected file.

Human review still needed: whether the light top palette and dirt contrast match the game's art direction, whether the stepped rim feels right, whether the tuft density and 44 cm height fit gameplay scale, and whether the calm sway is visible enough. No engine performance measurements have been made because this request ends at Blender review.

References: the two supplied `ChatGPT Image Oct 8, 2026, 05_55_40 AM.png` and `05_55_48 AM.png` images, used as style guidance. The atlas and meshes were authored for this separate study.
