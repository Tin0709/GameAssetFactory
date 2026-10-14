# Run V1 — elastic rebound and clearer running drive

2026-10-14 · **Pending artistic review** · same `Run_Snappy_Test_v001`, entry27/28.

User feedback: the previous compact run still felt like walking. Make the body rebound more like jelly, keep it smooth, and keep the feet close to the floor. This pass changes the body coordination and running posture while preserving the previous world foot motion, contacts, flight, cadence and diagnostic travel speed. No deformation or rig changes.

[Front / three-quarter / side — five continuous cycles](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/run_snappy_test_v001/elastic_drive_v001/run_snappy_three_views_1x.mp4) · [Previous compact Run / approved Expressive Run / new elastic Run](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/run_snappy_test_v001/elastic_drive_v001/before_expressive_bounce_1x.mp4) · [Actual Running reference / approved Run / new Run](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/run_snappy_test_v001/elastic_drive_v001/reference_expressive_snappy_1x.mp4) · [Approved Run / new Run, side](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/run_snappy_test_v001/elastic_drive_v001/expressive_snappy_side_1x.mp4).

All videos contain85 frames at30FPS. Run V1 shows five uninterrupted17-frame cycles, without artificial holds or replay pauses. Approved Run v3 retains its20-frame cadence and the actual Running referenceF40–124 stays at original speed. Only [phase sheet1](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/run_snappy_test_v001/elastic_drive_v001/phase_aligned_1.jpg) / [sheet2](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/run_snappy_test_v001/elastic_drive_v001/phase_aligned_2.jpg) normalize gait phases; reference sampling is rounded to its nearest frame. All model cameras retain identical existing framing.

## What changed and why

- **Elastic body recovery:** the receiving trough now arrives at46.09ms instead of51.56ms. Recovery flows into the first crest at158.07ms instead of188.54ms, followed by a restrained settling phase. Event-shaped quintic segments with10ms periodic rounding create a quick spring release and a softer return. Actual hip excursion is123.73mm versus109.67mm; receiving dip50.72mm. The stronger feeling comes mainly from the earlier recovery and coordinated follow-through, with a modest height change.
- **Running intent:** add5 degrees of hip forward lean (base4.5 degrees becomes9.5). Arm pitch arcs are12% stronger, with10% less lateral flare, so the straight arms drive in opposition rather than hanging out to the sides. The head counters2 degrees of the added lean to keep the gaze readable.
- **Jelly through coordination:** spine/chest responses use14/26ms height history and0.8/1.3degree limits. Shoulders react using25ms history, bounded to3.5mm. Head history is32ms with only2–12mm extra lift. These are authored parameters, not measured reference delays. Existing18ms torso/22ms arm-head angular filtering and smooth leg arcs remain.
- **Low, brief flight retained:** world foot paths match the previous source within0.000312mm across2177 paired samples. Support remains39% LEFT /40% RIGHT and flight62.33/56.67ms per step,21% of the stride. Maximum lower-of-two-feet clearance remains73.42mm. No shared whole-character jump lift was added.

The intended result is a more driven running silhouette and a quicker body rebound, while the feet keep the low exchange the user liked. Whether it now feels like a satisfying run needs artistic review; technical passes do not prove a match. The rigid-leg path itself is unchanged in this controlled refinement. If it still reads as walking, a separate future recovery/swing-path adjustment may be needed. Exact reference support, flight and physical heights cannot be recovered from moving-camera footage.

![Before / after body and foot motion](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/run_snappy_test_v001/elastic_drive_v001/body_before_after_curves.png)

## Validation and preservation

Saved-source2177 samples pass: no floor penetration, nonadjacent overlaps or unexpected support loss. Planted sole drift0.002298mm; rigidity error0.000296mm; head/chest clearance0.618mm; maximum waist separation59.200mm below the historical75mm bound. The separated-block waist seam is a visual tradeoff. Root/object remain static, scale stays1 and full arms stay straight.

The native Showcase save initially failed during file replacement, leaving the old file and manifest intact. The failed temporary save was preserved before retrying through a staged save with relative-path remapping disabled; the reopened central Showcase is checked below.

Loop pose difference0; second-order velocity seam0.002419m/s passes0.006. Raw first-order estimate0.098991m/s retains legacy pass=False and is reported separately; cyclic endpoint tangents also checked. The first unregistered draft is preserved in `.validation/run_snappy_elastic_drive_v001/first_candidate`: its48.925mm receiving dip fell below the retained50mm guard. The final receiving trough is2mm lower; no geometry or quality guard was relaxed.

36 targeted Showcase checks cover seven representative entries, slots, timing, props, views and inactive reopen; all28 Actions retained, all27 other Action signatures/manifest entries exact. Actual hidden GUI two-wrap/pause/restart playback passes. Eleven H264 videos decode935 frames at30FPS. All7317 protected files remain exact, including all previous Run sources, reviews and backups, provisional Walking and Godot files. Mesh geometry, UVs, weights, materials, images and rig rest are unchanged.

[Foot-contact and future blending contract](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/run_snappy_test_v001/elastic_drive_v001/phase_contract.json) · [Paired foot and body measurements](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/run_snappy_test_v001/elastic_drive_v001/bounce_validation.json) · [Geometry and loop checks](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/run_snappy_test_v001/elastic_drive_v001/motion_validation.json) · [All85 native frames](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/run_snappy_test_v001/elastic_drive_v001/all85_native_frames.jpg).

Source SHA:33a62f5ba58a5743c1bc820f53fa2c77050a7292d5580fd815d3a6a8e85dd663. Action SHA:8e835f91c686d41bb1846fb0d7ddc151dc55a9178f87e27d845fc54f972cb156.

Reopen [Animation_Showcase.blend](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/showcase/Animation_Showcase.blend) and select `Run_Snappy_Test_v001` (**Pending**). **Stopped for artistic review.**
