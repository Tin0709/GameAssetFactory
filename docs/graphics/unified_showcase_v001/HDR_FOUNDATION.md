# Mobile HDR highlight foundation

2026-11-08. Existing F5 WorldMap, private Forest showcase. L → **Air · preserve HDR highlights (higher bandwidth)** defaults ON on the current supported Mobile research setup. OFF restores packed rendering. B/Previous/unsupported context and scene exit restore the viewport flag owned by this adapter. No project-wide renderer setting, source asset, scene, light intensity or animation was replaced.

## Corrected implementation limits

The previous local-exposure compositor accepted only RGB10A2. An actual seven-color Mobile/D3D12 fixture proves that buffer stores half scene radiance and saturates at physical2. HDR2D requests RGBA16F scene buffers, preserving values above2; the compositor now accepts both formats and rebuilds on changes. Its obsolete unit-range gain clamp remains only on the packed path. The existing physical middle gray/toe is preserved across the format change by converting its encoded units, not by fitting a new exposure.

The old Day-palette availability rule rejected any HDR viewport. That silently removed the reviewed palette when HDR activated. It now allows the supported showcase-owned HDR context while preserving the old guard elsewhere. The rejected pale Day diagnostic is retained privately; it is not the accepted configuration.

The quarter-resolution bloom, shared mist, player/terrain materials, lantern, source clips and7m/s controller remain. This preserves more useful lighting data for subsequent bloom/tonemapping work; it is not a reconstruction of MD2's final HDR grading or Lumen.

## Evidence / cost

Private `godot_lab/world_map_unified_showcase_v001/hdr_foundation_v001/README.md` contains the red/green failure, raw buffer probes, proper display-space screenshots, restoration and gameplay tests. Seven unlit RGB swatches match the expected half-float values in21/21 float32 bit patterns. With the actual production exposure effect, a16-unit red input retains13.546875 at its output instead of saturating near one encoded unit. Day/Night packed OFF→restore images are exact within each frozen comparison.

At720p, the effect's owned allocation rises from4,384,800 to8,071,200bytes, in addition to engine HDR/MSAA buffers. The number of custom raster stages is unchanged. Shared RTX4070TiSUPER viewport GPU medians .366–.368ms packed / .382ms HDR do not isolate direct RD pass costs. Wall-frame measurements are scheduling dependent. No phone power/thermal/FPS certification; weak-device configuration should retain the packed fallback until measured.

HDR framebuffer exports are linear RGBH. PNG previews require one linear→sRGB conversion; raw HDR PNGs look artificially dark. Preserve raw binary/format metadata and use the corrected display images for review.

Engine evidence: [Godot4.7.2 Mobile pass ordering](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/servers/rendering/renderer_rd/forward_mobile/render_forward_mobile.cpp), [buffer format selection](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/servers/rendering/renderer_rd/storage_rd/render_scene_buffers_rd.h). Native MD2 research/reference files remain private. Overall visual acceptance and the active graphics goal remain open.
