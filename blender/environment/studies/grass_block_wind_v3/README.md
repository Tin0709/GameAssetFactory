# Dirt block + full-surface 2D grass — Blender review v3

Latest review file: **grass_block_wind_v3.blend**. Created October 8, 2026. Separate Blender study; production files and Godot runtime assets were not modified.

## Latest art direction

49 flat 2D leaves cover the entire top of the block. Roots use an even 7×7 layout with a small jitter; blade angles and lengths vary so the leaves moderately interweave. There is no blade thickness. The opaque material renders both sides of each sheet. The blades grow directly from the root plane, with no visible floating base.

Leaf height is approximately 60% of a full block, with unequal lengths: measured minimum **0.481 m**, maximum **0.698 m**, and mean **0.570 m**. Whole-patch bounds in the undeformed basis are about **0.944 × 0.949 × 0.698 m**. The width/depth cover the full top with a small margin for leaf widths. The ground roots are at local Z=0 and the patch is placed at world Z=1.

## Objects and geometry

| Object | Dimensions / purpose | Geometry |
| --- | --- | --- |
| `ENV_GrassDirt_Block_1m` | Exact **1.000 × 1.000 × 1.000 m** | 174 vertices, 344 triangles, one closed connected mesh |
| `ENV_Grass_Full_Surface_2D` | Full-surface flat-leaf patch | 392 vertices, 147 quads, **294 triangles**, 49 leaves |
| `ENV_Wind_Global` | Shared wind phase controller | Empty, no render geometry |
| `DEMO_Grass_Wind_Plus_Player` | Demonstration copy in the Player scene | Same leaf topology and deformation data |
| `DEMO_Player_Proxy` | Blue marker illustrating the Player's movement | A small cuboid, not a character asset |

Both primary assets have identity rotation and scale. The block origin is bottom center; grass origin is its ground plane. The block's actual stepped grass rim hangs 6 mm beyond the inset dirt body while staying inside exact 1m bounds. Block geometry and the packed nearest-sampled 64×64 pixel atlas are preserved from the first study. Both assets share one opaque pixel material. No bevels, subdivision, alpha cutouts, physics, or armatures.

## Inspect in Blender

The file starts in `ENV_Grass_Block_Wind_Review` with the hero camera selected for viewing. Press **Space** over the viewport or timeline to play the four-second wind loop. **Numpad 0** leaves/returns to the camera so you can orbit and inspect the flat leaves.

Choose **ENV_Player_Reaction_Demo** in the scene selector at the top of Blender to inspect the optional eight-second interaction example. The blue Player marker walks right, then runs left. A small local disturbance moves through the leaf columns, follows through, and recovers softly with a small rebound. Farther rows continue with wind alone. This is an authored illustration using shape-key curves, not a runtime proximity-query system or a physics simulation.

`REVIEW_Camera_Hero` shows the whole block and taller grass; `REVIEW_Camera_Grass_Detail` shows the grass shape; `REVIEW_Camera_Block_Back` shows the other block sides. Hide `03_REVIEW_STUDIO` for asset-only inspection. The in-file `REVIEW_NOTES` text repeats the technical guidance.

## Wind and Player deformation readiness

**Ready for both global wind and future Player vertex deformation.** Each leaf has four height rings at normalized heights 0, 0.22, 0.65, and 1, giving three bending segments while preserving the blocky silhouette. Both vertices at each root stay fixed. Upper vertices respond with height squared, so the effect is a bend rather than a rigid rotation.

Prepared data:

- `WIND_HEIGHT_SQUARED` vertex group: inspectable root-to-tip bend mask.
- `GRASS_BEND_DATA`, point-domain float color: **R=t²**, **G=t**, **B=blade height/0.70m**, **A=1**. This is shader deformation data, not albedo.
- `UV_Blade_Root`, the second UV map: the local root XY of each leaf encoded as `(x+0.5,y+0.5)`. Subtract 0.5 and transform the root into world coordinates for per-leaf Player distance. This is necessary for localized response across a full patch.
- Four analytic wind shape keys plus dormant `Player_Bend_X/Y` keys in the main scene, showing that wind and local disturbance can add without moving roots.

The current Blender material ignores the deformation color attribute. A future custom shader should also keep that attribute separate from the pixel atlas color. No export was performed; attribute preservation should be verified when later engine integration is requested.

Wind phase is shared: `2*pi*(frame-1)/96`. The four signed sine/cosine keys create:

```text
dx = 0.018 * t² * sin(global_phase - 0.28*t)
dy = 0.007 * t² * sin(global_phase + pi/3 - 0.23*t)
dz = 0
```

Playback is **frames 1–96 at 24 fps**, four seconds. Frame **97 matches frame 1** and is excluded from playback. Fresh-file validation measured zero seam position error, zero root movement, and at most 1.83 cm wind displacement. Position and velocity continuity were checked at the seam.

The Player demo uses **frames 1–192 at 24 fps**. Walking is 0.552 m/s; running is 1.38 m/s. Measured Player tip displacement peaks are about **4.95 cm walking** and **8.96 cm running**, in addition to wind. Local column responses are staggered as the marker passes. Blades at least 0.30m sideways from the illustrated path receive zero Player offset; 21 of the 49 blades meet that condition. All 98 root vertices remain fixed. The demonstration grass also returns to the same pose across its eight-second loop.

## Future Godot approach — documentation only

Use **one shared GPU vertex shader** and **one global wind phase/direction** for all grass instances. Final displacement is global wind plus local Player disturbance. Use optional small seeded amplitude variation if desired, keeping the same global clock.

Only the Player should publish world position, movement direction/speed, and a short fixed history of recent movement segments and timestamps, such as four segments. Enemies do not publish interaction inputs. Each grass leaf uses its stored world root to calculate distance to current/recent Player movement. Smoothstep falloff gives zero influence outside a small radius. Combine outward push with a smaller movement-direction component; increase strength and shorten response time for running.

Smooth follow-through after the Player leaves requires recent movement history or another compact global record of past disturbance. Current Player position alone cannot describe patches the Player has already passed. A stateless shader can evaluate a smooth age envelope or damped response from those timestamped segments, fading continuously at radius/age boundaries. Apply the root mask to both effects, optionally use G for a small height delay, and cap total bend. Keep the world wind direction coherent by converting it into each instance's local coordinates. Convert Blender Z to the engine's up axis when integrating.

Avoid per-grass physics, scripts, and individual AnimationPlayers. The authored Blender demo curves only illustrate the intended look and are not a proposed implementation for thousands of game instances. No Godot shader, provider, scene, export, or runtime code was created.

## Deliverables and verification

- `grass_block_wind_v3.blend`: final review asset and two review scenes.
- `preview_hero.png`: overview with the final taller flat grass.
- `player_reaction_demo.gif`: eight-second walk/run example, sampled at 8 fps.
- `validation_report.json`: geometry, coverage, leaf heights, mask/UV, wind seam, roots, additive motion, and unaffected distant-blade measurements.
- `REVIEW_NOTES.txt`: full guidance also packed as Blender text.
- `environment_atlas_64.png`: inspectable copy; the actual image is packed in the Blender file.
- `prepare_flat_grass.py`, `set_grass_height.py`, `verify_study.py`, `render_previews.py`, `package_preview.py`: scoped authoring/verification recipes. `set_grass_height.py` is a one-time adjustment and refuses a second application.

Still needs human art review: full-surface density, the 0.48–0.70m height variation, flat-leaf silhouette, palette, subtle wind visibility, and walk/run bend/recovery. Mobile engine performance and exported attribute mapping are future integration checks. Work stops at Blender review.
