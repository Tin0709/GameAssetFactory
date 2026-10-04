# Mobile visual budget

This is a visual foundation only. No gameplay, enemies, combat, progression, menus, physics, or imported assets are included.

## Baseline

- Godot 4.x, Mobile rendering method on desktop and mobile. Validated with Godot 4.7.2.
- Landscape, 1280 × 720 logical canvas, fixed 16:9 presentation. Wider/taller screens retain the composition with letterboxing. Canvas-items stretch renders 3D at the actual viewport resolution; 720p is not a fixed GPU render budget.
- Static orthographic camera, 25-unit vertical view and 65-unit far plane.
- Current scene: 39 mesh instances, 484 triangles, 8 shared opaque materials, 10 shadow casters. Shared box geometry plus one four-sided crystal mesh. Mesh count is not a measured draw-call count.
- Target 60 FPS / 16.67 ms on selected reference phones; allow a deliberately chosen 30 FPS / 33.33 ms tier after profiling. Desktop FPS does not validate a phone budget.

## Rules for future work

- Preserve large silhouettes and open central ground. Reuse low-poly meshes and material resources; batch repeated decoration with MultiMesh when repetition grows.
- Keep this foundation under 5,000 visible triangles and 60 mesh instances. These are guardrails for the test scene, not universal device limits.
- One directional sun. Use a 1024 shadow atlas, low filtering, one orthographic shadow range, and a 48-unit maximum distance. Only major walls, pillars and the altar cast shadows; rubble, grass, floor and neon do not.
- Shadows remain the main avoidable cost. Test smaller maps or disable shadows on weaker devices before adding lights. Do not increase casters without profiling.
- Ambient color supplies inexpensive fill. No sky cubemap, reflection probes, GI, SSAO, SSIL, SSR, glow, depth of field, or volumetric fog.
- Standard exponential depth fog supplies subtle atmospheric separation. Do not add transparent fog planes or particle layers. Godot supports standard depth/height fog with Mobile: https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
- Cyan crystals and runes are opaque emissive materials. They do not cast light or create a bloom halo. Preserve the accent through color contrast; no extra point lights.
- Keep materials opaque and rough, avoid alpha blending and layered decals, and minimize overdraw. No textures are needed for this baseline.
- MSAA and screen-space AA start disabled. Profile edge quality versus bandwidth on actual phones before enabling them. High-resolution displays may need 3D resolution scaling.
- Keep per-frame scripts minimal. The debug overlay refreshes text at 4 Hz; its averaged frame interval includes scheduling/VSync and is not GPU execution time.
- Before expanding content, profile GPU/CPU frame time, draw calls, memory, sustained thermals and battery on both Android and iOS. Test aspect ratios and notches; the 28/24 logical-pixel HUD inset is not a device-specific safe-area implementation.

## Validation and running

Import `project.godot` in Godot 4.x and press F6 for the open Main scene or F5 for the project. The main scene is `scenes/Main.tscn`. No plugins or Blender setup are required.

Commands from this project directory (replace `godot` with your executable):

```text
godot --headless --path . --editor --quit
godot --headless --path . --script res://scripts/validate_scene.gd
godot --path . --script res://scripts/validate_scene.gd -- --capture
```

The final command writes ignored `validation_preview.png` after two seconds. A headless run validates resources and scene structure, not GPU rendering. For Windows machines where Vulkan is unavailable, add `--rendering-method mobile --rendering-driver d3d12` to the rendered command. Specify both switches to retain Mobile when overriding the driver.

Android/iOS builds require matching Godot export templates and the relevant platform SDK/signing setup (iOS requires macOS/Xcode). No export presets or signing credentials are included, and neither phone platform has been tested yet.

## Layout

```text
game_mobile_3d/
  project.godot
  MOBILE_BUDGET.md
  scenes/Main.tscn
  scripts/debug_overlay.gd
  scripts/validate_scene.gd
  materials/*.tres
  environment/Courtyard.tres
  assets/README.md
```
