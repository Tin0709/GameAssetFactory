# Player material adapter implementation plan

**Goal:** Complete the existing WorldMap material adapter, then compare cloud shading, recovered Valorie roughness and view-facing self-light independently.

**Design / approved scope:** The user's latest request authorizes this scoped implementation. Keep the existing material owner in `world_map_look.gd`; add a focused factory and shader, not another scene or renderer. Preserve source PBR inputs, alpha scissor, emission and original overrides. Use native Godot lighting when cloud shading is off. Classify private Valorie surfaces using the external source identity, never the duplicated resource name. Load recovered values from hash-validated private evidence; no proprietary textures, bytecode or buffers enter Git. Unsupported materials/renderers fall back. New roughness/self-light effects start OFF for independent review; the adapter/cloud repair is enabled. Existing canopy AO stays independently controlled.

**Tech:** Godot 4.7.2, Mobile, GDScript, spatial shaders. Research evidence: private `player_light_audit_v001`.

## Tasks

- [x] Watch existing rich-material coverage fail; add rejection/identity/independent-toggle tests.
- [x] Implement a strict material factory and shader variants under existing Look ownership. Correct the actor-only GGX clipping error; do not change grass/terrain BRDFs. Preserve original tint, not the legacy cloud-tinted duplicate.
- [x] Add compact independent controls in existing L panel, with original/neutral/cloud/roughness/self-light/combined presets and safe Day/source guards.
- [x] Capture locked Mobile comparisons, verify neutral and restore pixels, no-sun cloud invariance, alpha/emission and source-only scope. Validate live owners, baseline/day-night, locomotion/jump/combat, and desktop cost without phone claims.
- [x] Fresh review, address findings, document evidence/limits, commit and normal push per repository instructions.

## Review focus

Missing/changed private evidence; feature-rich unsupported material; opaque weapon versus cutout face; legacy original actor and B/F3/day-night state changes; UI controls fitting 720p and actual material ownership after refresh.

## Execution ledger

- Existing private probe was not neutral: it used the legacy tinted duplicate and clipped GGX to 1. Matching engine source confirms `saturateHalf` is an overflow guard, not [0,1] saturation. Stock generated shader with original tint gives exact 0-pixel difference in the locked Mobile frame. Preserve old probes as historical evidence, not acceptance tests.

- Fresh review found and verified fixes for automatic-cycle Day guards, independent canopy AO and unsupported flags; native61 checks and private image receipts. Git checkpoint integration follows existing main/normal-push policy.
