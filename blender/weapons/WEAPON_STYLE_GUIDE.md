# Weapon style guide

The blocky M4A1 V2 (geometry-clean successor: V3) is the style anchor for this game's weapon family. Preserve its chunky cuboid forms, charcoal/cool-gray palette, crisp pixel accents, and restrained light edges. Future weapons should read as distinct silhouettes while belonging to the same visual world.

## Shape and readability

Use angular boxes and simple extruded profiles. Exaggerate the stock, magazine, slide, receiver, or pump enough to identify the weapon at a small isometric gameplay size. Avoid realistic micro-detail, round smoothing, thin fragile sections, and copied commercial branding. Author original layouts and proportions.

M4A1 V2 width target: 0.103 m. Pistol length: 0.22-0.28 m. Shotgun length: 0.85-1.00 m. A shotgun should feel heavier than the rifle, with a broad independent pump. Use real meter units and compare weapons without individual scaling.

## Surface language

Reuse the M4A1 atlas palette and broad pixel motifs. Charcoal major surfaces, cool slate receiver/frame, one occasional small cyan badge. Restrict bright paint to important borders and corners. Preserve solid atlas gutters and avoid noisy micro-pixels. No logos, numbers, brand text, or expensive outline shader.

Use one packed 64x64 atlas and one main opaque material whenever possible. Nearest-neighbor sampling; nearest mip filtering for distance. Metallic 0, roughness 0.48, Blender specular IOR level 0.25. The glTF core material keeps metallic/roughness; highlights may differ slightly in Godot. Keep the shader simple, with no animated nodes or emission required.

Use tiny one-segment bevels only on important silhouette parts, generally 0.7-2.5 mm at the authored scale. Flat normals preserve the block language. Combine chamfer contrast with painted pixel edges rather than adding dense geometry.

## Runtime conventions

Blender: +Y muzzle-forward, +Z up. glTF/Godot: -Z muzzle-forward, +Y up. Asset root and main mesh origin: primary hand grip center. Apply scale and rotation to static meshes; identity object scale. Use named part vertex groups for editing if the geometry is joined.

Required markers: Grip_Point and Muzzle_Point. Add Support_Hand_Point for two-handed support. Preserve markers as nodes in GLB. A separately animated rigid part can have a local origin at its working center: Shotgun_Pump uses the support-hand center, with translation on local Y for later pumping. It shares the main material, but adds a second mesh draw surface. No reload animation yet.

Budget targets: pistol 150-350 triangles; rifle 300-900; shotgun 300-700. Count the complete runtime mesh set including separate moving parts. Exclude studio cameras, lights and comparison labels from exports. Avoid unnecessary covered faces when practical; do not compromise visible silhouette or attachment strength for a negligible saving.

## Delivery and checks

Save new versions without overwriting earlier assets. Include a selected-only GLB, packed atlas, side/three-quarter/isometric transparent previews, and a measured report. Check object transforms, attachment positions, forward axes, triangle count, material count, image packing and sampler. Render a common-scale orthographic family comparison to judge readability and relative size. Preview studio objects are presentation-only and must not enter runtime exports.

