# GameAssetFactory graphics direction

Status: proposed art direction; selected mood confirmed by the user on
2026-11-08. The implementation checkpoint is `7e5a1702`.

## The intended impression

A warm woodland clearing invites the player forward. A worn ochre trail bends
through quiet grass into a pocket of cool shade. A distinctive oak, a restrained
flower bank and a short stone edge make the location recognizable. Plants share
the ground's color near their roots, separate into readable shapes toward their
tips, and move with one believable breeze. The player remains the clearest
moving silhouette.

Our style is a carefully composed voxel world: deliberate block geometry,
clustered pixel color, tactile matte surfaces, rich natural edges and crisp
gameplay presentation. The premium impression should survive normal gameplay
camera distance and a modest device tier. MD2 is the artistic quality reference;
its precise shapes, proprietary assets and complete rendering pipeline are not
the product specification.

## What the checkpoint taught us

The existing game already supplies directional fill, local crown visibility,
contact shading, ground-reflected light, wind and stable rendering. Their tests
prove specific behavior. They do not prove that an entire image has a compelling
composition. Additional renderer reconstruction has lower priority until a
visible problem in the actual game requires it.

Global exposure or stronger grading can erase local depth. The combined Day
review deliberately left Local Exposure optional after it lifted some shaded
grass too broadly. Solve a missing contact, material relationship or composition
locally before changing the whole image.

Temporal quality matters as much as the still: stable pixel clusters, matched
camera/player interpolation and coherent vegetation clocks already improved
presentation without retiming approved animations. Preserve those gains.

Vegetation volume becomes useful when it forms masses, transitions and quiet
spaces. The current scene contains many attractive individual ingredients;
placing more instances uniformly will not create a stronger location.

Original static lighting approximations are practical tools. Their scalar,
coarse and static limits should inform composition, not trigger a project to
rebuild desktop Lumen. The latest F12 image-comparison issue remains a technical
follow-up, separate from choosing an art direction.

Finally, desktop Mobile-renderer results are not phone qualification. Decisions
about expensive effects and vegetation density need a measured device budget.

## Seven visual pillars

### Lighting with readable depth

Use one clear daylight direction, warm illuminated planes and cooler, restrained
shade. Compose broad light and shadow shapes around the trail and clearing.
Maintain a bright-enough face and body under trees, with contact darkening close
to roots, rock junctions and grounded objects. Let open grass, tree shade and
stone recesses read as different places without crushing them to black.

Keep the current camera, exposure and grade fixed while evaluating composition.
Use existing original fill/contact tools first. Local Exposure stays optional;
the look must hold with F7 off. F12 remains experimental until its evidence gap
is closed. New sun-angle or grade changes require a separate matched comparison.

### Vegetation that forms an ecosystem

Design three nested scales: a few large tree masses, several connected grass
banks, and small flowers/root details. Use calm, transition and dense regions
instead of one density everywhere. The clearing and travel lane need visible
ground; taller plants belong mainly at banks and the woodland edge.

Reuse the two original oak variants before commissioning more species. Choose
one hero silhouette and quieter supporting trees through placement, rotation
and currently permitted scale. Keep rigid voxel structure. V3 oaks are authored
originals whose manifest still awaits user art review; use in the slice does not
silently change that status. Flower placement gets one dominant family, one
supporting family and sparse accent pockets rather than equal multicolor scatter.

### Materials with a shared visual grammar

Retain the approved pixel-cluster character: broad, intentional color patches
at a consistent world scale, with small detail subordinated to the large form.
Grass, soil, bark and stone should differ in hue, value and surface response
without looking as if they came from unrelated packs. Favor matte vegetation
and soil; reserve restrained highlights for appropriate hard surfaces.

Preserve source meshes, textures, UVs and approved looks. Test original derived
material variants separately. Existing short-grass COLOR_0 is bend data, while
other plant color channels have different contracts; UV2 also carries authoring
information. Do not repurpose these streams or enable new import processing as
a shortcut. Artistic approval and production eligibility remain separate records.

### Composition that gives the place a purpose

Build one recognizable destination: a hero oak beside a trail bend and a small
rock/terrace anchor. Use near, middle and background layers. Foreground plants
frame the lower corners; the central playable pocket stays quieter; background
tree masses support depth and the exit direction. The eye should find the
player, the destination and the route in that order.

Avoid filling the camera-facing edge with tall obstruction. Retain canopy reveal
and cutaway behavior. Preserve enough uninterrupted floor to judge movement and
future combat readability. A towering repeated stair wall should not become the
main subject of this meadow slice.

### Color with hierarchy

Use a restrained green family: warmer grass in light, deeper cool-green foliage
in shade, ochre earth and muted blue-gray stone. Cream/yellow flowers support
the daylight; a small lavender/blue pocket supplies a memorable accent. Existing
red/white/blue/yellow assets can be reused selectively; no new flower colors or
texture repaint is required for the first blockout.

The diagram's palette is an original display-space mood guide, not measured MD2
data, a new LUT or shader constants. Do not paste swatches into linear albedo
inputs. Respect the existing restrained warmth and assess changes after the
actual tone/grade pipeline. Warm highlights should not turn the whole scene yellow.

### Atmosphere that clarifies distance

Keep nearby ground, silhouettes and texture clusters clear. Let background
contrast and saturation recede gently. Use the existing inexpensive atmosphere
path only as needed; haze must not hide poor ground integration or wash out the
midground. A fixed Day state is the first target. Night, weather, volumetric
effects, water and elaborate ambient particles are outside this slice.

### Motion that feels alive and controlled

Preserve the current coherent breeze and rigid crown response. Background grass,
flowers and trees share a heading and gust rhythm, with different response
amplitudes and local phase. Nearby player passage has a separate localized bend
and recovery. Use movement sparingly enough that the environment supports the
character rather than competing with it.

Keep the approved player animations, controller timing, foot contacts and camera
behavior. Inspect texture shimmer, crown shadows, reveal transitions and grass
recovery during actual movement. Crispness and stability take priority over
motion blur, excessive bounce or stretching plants.

## Working approach

The recommended approach is a reversible, authored review zone inside the
existing WorldMap, using existing assets and shared rendering systems. It makes
composition decisions inspectable in gameplay and can become a reusable recipe.

A material/postprocess-only pass is cheaper to set up but leaves the current
composition problem in place. A broad new biome or asset-production pass would
spread effort before we know what makes the scene work. Neither is the first
milestone. The user selected the woodland-meadow mood; these engineering and
layout choices are recommendations, not additional user approvals.

## Approval boundary

The direction is ready to guide an M0/M1 review after approval. Exact tree
positions, the final site, palette values and budgets remain proposed. No
benchmark image, asset status or mobile performance tier is approved by this
document. The [evaluation contract](EVALUATION.md) defines how promotion happens.
