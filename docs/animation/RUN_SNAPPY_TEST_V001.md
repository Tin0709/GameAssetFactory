# Run Snappy V1 — stronger rebound and dramatic airborne stride

2026-10-14 · **Pending Blender artistic review** · `Run_Snappy_Test_v001` · existing Animation Showcase entry27 of28.

The user requested Running V1, then **200% more bounce** and a dramatic front/back leg spread like the supplied airborne pose. This review contains those latest changes. The [first V1 source](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/run_snappy_test_v001/run_snappy_review.blend) and its original review videos remain unchanged. All27 earlier Actions and their source versions remain preserved. Current `Walk_Snappy_V027_Refined_Test_v003` is recorded as a **provisional Walking baseline**, with no final production approval; its Action/source/backups are unchanged and its existing Pending status is retained.

## Review at original speed

- [Front / three-quarter / side — five continuous cycles](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/run_snappy_test_v001/bounce_200_v001/run_snappy_three_views_1x.mp4).
- [Actual Running reference / approved Expressive Run v3 / current Run V1](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/run_snappy_test_v001/bounce_200_v001/reference_expressive_snappy_1x.mp4).
- [First V1 / approved Expressive Run v3 / stronger current V1](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/run_snappy_test_v001/bounce_200_v001/before_expressive_bounce_1x.mp4).
- [Approved Expressive Run v3 / current V1 — side comparison](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/run_snappy_test_v001/bounce_200_v001/expressive_snappy_side_1x.mp4).

All model videos have85 uninterrupted frames at30FPS,2.833seconds. New Run: five17-frame cycles. Approved Run v3:4.25native20-frame cycles. The comparison uses original RunningF40–124 at recorded1x. Cadence drift against approved Run is deliberately retained; no artificial holds, replay pauses or video time normalization. Static [early phase sheet](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/run_snappy_test_v001/bounce_200_v001/phase_aligned_1.jpg) and [late phase sheet](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/run_snappy_test_v001/bounce_200_v001/phase_aligned_2.jpg) map reference40+17×phase (nearest recorded frame), approved Run1+20×phase, new Run1+17×phase. Reference rounding error is at most half a recording frame. Model cameras match each other; reference framing is approximate and its camera motion remains visible.

## Research used and what is original

The exact local [deep research report](C:/Users/ADMIN/Desktop/GameAssetFactory/docs/animation/ACTIONS_AND_STUFF_PLAYER_DEEP_RESEARCH.md) and [evidence index](C:/Users/ADMIN/Desktop/GameAssetFactory/docs/animation/research/actions_and_stuff_deep_2026_10_14/README.md), Run atlases/graphs, style/expansion guides, actual Running.mp4, latest provisional Walk and approved Run Actions informed this experiment. The actual349-frame/30FPS Running video was freshly decoded. F40–57 was inspected consecutively alongside the saved three repeat atlases. RecurrencesF40/57/74/91 support a17-frame stride in that excerpt. The short low/exchange group aroundF40–44 contrasts with the longer opening towardF49; the opposite receiving-like phase is nearF49.

Exact source ground contact, stance duty, flight, world-space bounce height, rig and subframe delays remain unknown. Screen proxies include camera motion and are not bone/force measurements. The new supplied image is a pose/silhouette target, not evidence for temporal curves. Our support/flight timings and all numerical amplitudes below are original design choices. No proprietary assets or keyframe data were copied.

## What creates the new rhythm

The first Run version already used a contact-led45ms absorption, fast middle leg recovery and controlled placement. It retained our approved straight-arm Run language, with larger55°/58° asymmetric arm amplitudes, coordinated hip/torso counter-motion and restrained delayed shoulder/head response.

The latest **+200%** request is interpreted as **three times total vertical excursion**, verified on evaluated hip motion: **91.000→273.000mm**, multiplier3.000001. Contact hip height0.686m and the0.642m trough remain unchanged, preserving the44mm receiving dip. The extra188.29mm event-shaped rebound begins after absorption, flows through a rounded crest and brakes back toward the next contact. Actual hip range0.642–0.915m; peak upward/downward hip speeds3.729/3.266m/s. This is an event-shaped quintic response, not a generic sinusoidal body clock or faster playback.

Whole-leg flight follows the raised body so rigid limbs do not stretch. The larger rebound now releases support earlier and creates a deliberately long airborne phase. Airborne leg pitch opens through68ms and gathers over57ms, with an original1.65 pitch magnification capped55°. Actual evaluated leg pitch ranges are L-47.4…45.9° and R-48.1…45.1°. A soft flight-only attachment correction keeps the upper legs near the hips. Stance/contact orientations stay controlled, and the original17-frame cadence,2.5m/s diagnostic travel and270mm contact tracks remain. Body/arms/head stay geometrically rigid; existing angular secondary motion is retained and the head stays close.

An earlier strong-bounce candidate passed geometry but its clearance-triggered leg gates created narrow velocity spikes near release/arrival. It is preserved under `.validation/run_snappy_bounce_200_v001/candidate_001`. The delivered version distributes opening/gathering over gait phases, preserving the wide pose while reducing peak fore/aft sole speed from30.96/31.31 to7.47/7.58m/s. This repair followed actual evaluated sole curves and native frame inspection; [the before/after curve check](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/run_snappy_test_v001/bounce_200_v001/leg_spread_timing_validation.json) records the result.

![Contact-driven timing and leg spacing](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/run_snappy_test_v001/bounce_200_v001/timing_curves.png)

## Contacts and future Walk ↔ Run work

| Event | Full-stride phase | Blender frame | Time from LEFT contact |
|---|---:|---:|---:|
| LEFT receiving |0 |1 |0ms |
| LEFT load minimum |0.08 |2.36 |45.33ms |
| LEFT release |0.168377 |3.8624 |95.41ms |
| RIGHT receiving |0.5 |9.5 |283.33ms |
| RIGHT load minimum |0.58 |10.86 |328.67ms |
| RIGHT release |0.668377 |12.3624 |378.75ms |
| Closing key, excluded |1 |18 |566.67ms |

Each designed flight lasts187.92ms. These are our authored support intervals, not measured Actions & Stuff physics. [Machine-readable phase/ownership contract](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/run_snappy_test_v001/bounce_200_v001/phase_contract.json) records contacts, releases and flight. Root/object remain static; controller retains world travel and collision authority. Future integration must avoid applying visual hop again to the capsule. Shared LEFT0/RIGHT0.5 phase helps planning but cannot alone prevent sliding across different stride/body/stance poses. No Godot transition implementation, export or gameplay replacement was made.

## Short artistic evaluation

The new poses show a clear lift away from the floor, broad alternating airborne legs and a much stronger elastic rebound. Compared with the approved Expressive Run, it is more exaggerated and separates receiving, opening and gathering more clearly. Compared with the actual reference, our torso/head remain comparatively restrained, our limbs retain a straight athletic silhouette, and this requested large bounce has substantially longer designed flight. It is a bold review experiment, not a claim of reference matching or natural production readiness. The rigid-leg rig cannot reproduce knee/elbow silhouettes; no rig rebuild or deformation was introduced. Judge the uninterrupted1x playback, especially whether the long flight feels appealing or too floaty.

[All85 native model frames](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/run_snappy_test_v001/bounce_200_v001/all85_native_frames.jpg) · [Native frame strip1](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/run_snappy_test_v001/bounce_200_v001/native30_sequence_1.jpg) · [strip2](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/run_snappy_test_v001/bounce_200_v001/native30_sequence_2.jpg) · [strip3](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/run_snappy_test_v001/bounce_200_v001/native30_sequence_3.jpg).

## Verification and preservation

- 2177 saved-source geometry samples: no floor penetration or nonadjacent intersections; minimum head/chest clearance1.804mm. Maximum waist separation50.682mm remains below the historical75mm bound; the separated-block seam is still an artistic limitation.
- Planted sole-corner drift0.000350mm at designed travel; support-height error0.002126mm. Rigidity error0.000300mm, straight arms retained, no scale tracks, exact rig-rest signature.
- Loop endpoint pose difference0.00000000m; second-order velocity seam0.005037m/s passes the historical0.006 bound at0.01frame spacing. Raw first-order estimate0.037167m/s remains reported separately with legacy pass=False; it is not relabelled as a pass. Cyclic channel endpoint tangents are independently checked.
- All28 entries switch/retain timing/slots/props/views; 100 checks, inactive save/reopen and actual GUI loop/pause/restart pass. Geometry, UVs, weights, materials/images are unchanged. Eleven H264 videos decode935 frames at30FPS.
- All27 older Action signatures/manifest entries and6830 protected existing files remain exact, including current provisional Walk, approved Runs, original Run V1 source/reviews, paused Rifle Idle, research and tracked Godot files. Current source SHA:0909c313684275f83194cea6992949bdc2b3abc48280cf2a1bfc10e7dac5535e; Action SHA:ab3828b1552e1dba6d9549a81a57bf01a388a794f1fde01d4d76266e1f0f101b.

Reopen [Animation_Showcase.blend](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/showcase/Animation_Showcase.blend) to load the saved current version, then select `Run_Snappy_Test_v001` (**Pending**). No existing foreground Blender session was reloaded. **Stopped for artistic review.**
