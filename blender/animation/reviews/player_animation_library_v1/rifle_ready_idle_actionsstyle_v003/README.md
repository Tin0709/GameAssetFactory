# Rifle_Ready_Idle_ActionsStyle_v003 — Pending

A NEW source-first reconstruction, built from the actual `.mcpack` graph. v002 is only a preserved comparison. **Research-only Blender review; no Godot integration.**

Open the existing `blender/animation/showcase/Animation_Showcase.blend` → **N → Animation Library → Rifle_Ready_Idle_ActionsStyle_v003**. Actual Rifle Stylized V2 attached. v001/v002 and every previous entry remain selectable; older entries stay under Show Archived.

Original source speed,30FPS,10.8s/F1–324 with closing325 excluded. Literal crossbow hold/bob plus one naturally selected4.2083s player attention gesture, sampled240Hz and at original key breakpoints. No v002 curves, generic running/idle formulas, invented look path or video-derived timing.

Review:
- [3/4](rifle_ready_idle_three_quarter_30fps_1x.mp4)
- [Front](rifle_ready_idle_front_30fps_1x.mp4)
- [Side](rifle_ready_idle_side_30fps_1x.mp4)
- [Comparison: v002 LEFT / v003 RIGHT](comparison_v002_left_v003_right_30fps.mp4)

Compared with v002: actual0.9/1.8/3.6s source rhythm replaces its authored1/4s rhythm; exact source attention keys/pauses and arm/body phase relationships replace its original look choreography. Body12degree hold and real weight/leg repositioning replace the prior planted-stance approximation. Right-arm/weapon follows source motion; left support is constrained independently, instead of forcing both full arms into one common rigid animation frame.

**What is exact and what is adapted:** read [source files, graph, reproduction and limitations](REFERENCE.md). The literal channel stream is preserved before rig constraints. Final static crossbow arm angles are calibrated around the existing rifle grip; left-hand projection,25mm head clearance and≤10.44mm sole lift are disclosed. All arms remain straight and block-shaped. Source-informed review assets remain nonproduction.

Evidence: `source_validation.json` (66independent source checks), `source_build_validation.json`, `motion_validation.json`, `registration.json`, `reopen_verification.json`, `gui_playback.json`, `media_validation.json`, `preservation.json`. Regeneration/validation/render scripts in `authoring/`; the raw source pack and full extracted source/trace cache are external.

Stop for Blender artistic review. Integrate only after explicit approval, using the existing player/weapon architecture.
