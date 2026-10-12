**Godot locomotion integration lab — 2026-10-12, Pending gameplay review:** Run_Expressive_v3_Test remains the explicitly approved preferred Run; approved Idle v3 and current refined Walk/source Actions remain unchanged. The separately authorized Godot test is `game_mobile_3d/scenes/dev/ExpressiveLocomotionTest.tscn` (F6; F5 still WorldMap). It uses a read-only three-clip export on the existing full-arm runtime rig, shared LEFT=0/RIGHT=.5 phase, distance-driven cadence, immediate Idle interruption and individual stop replants. Latest user steering rejects the all-2x trial: default travel/gait is now1.5x (Walk1.35m/s, Run3.465m/s), while Idle breathing/observations remain normal1x. T cycles1/1.5/2x movement comparisons; archived earlier candidates/videos are preserved. Acceleration can shorten support; deceleration cannot re-ground a released foot. Fresh41-check runs pass at30/60FPS and comparison paces, with actual original-speed three-view Godot video. Sharp pivots still release bounded anchors (up to8.6cm residual); rifle layers are smoke-tested only, not combat-certified. No phone benchmark, terrain validation or production readiness is claimed. Production player/WorldMap/weapons/jump, all Blender sources/Actions/Showcase/manifest remain unchanged; no new Blender Action was authored. Full Jump v2 stays Pending and is not integrated. Review/controls/evidence: `docs/animation/reviews/godot_locomotion_v1/README.md`. This explicit integration request supersedes historical Godot prohibitions for this isolated lab only; do not promote to production without user approval.

**Latest Full Jump v2 steering —2026-10-12, Pending:** continue the same separate pending comparison with higher arms,8deg added sideways airborne opening per leg (about15cm extra sole-center spacing), and28mm deeper landing absorption (148mm versus120mm). Added pelvis/torso/arm reaction remains controlled; original receiving frames46/47, peak absorption51, rebound67 and recovery93 remain. Fixed planted landing base; no foot yaw or added bounce. All evaluated motion fromF65 onward matches the original. Arm-only working checkpoint/library is archived under `.validation/full_jump_expressive_v2_test/before_wider_legs_heavier_landing/`. Original Full Jump, previews,14 prior Actions and Godot remain unchanged. Run v3 remains approved preferred; this Full Jump v2 remains Pending. This user steering supersedes the arm-only scope below.

**Latest approval and Full Jump arm refinement — 2026-10-12:** the user explicitly approved `Run_Expressive_v3_Test` as the **preferred run baseline**. Its source SHA256 `f7244760901f5055e39fa5e3d9c9203506598c6c4492ce553536b8c26b9d0eeb` and Action SHA256 `4983a96d54648229d71fd7aff87ec9090498d6bb72bc1568f02d63cf8a209342` remain unchanged. Preserve original Run and v2 as comparison alternatives. New authorized work is separate `Full_Jump_Expressive_v2_Test`, Pending: arm-only lift, hands slightly above head at airborne peak, same93frames/30FPS and unchanged non-arm channels/heavy landing fromF45 onward. Preserve original Full Jump and both original/higher review previews. Register in the same existing Showcase;0.72m presentation elevation remains separate from the in-place Action. No rig, Godot or export change. Review: `blender/animation/reviews/player_animation_library_v1/full_jump_expressive_v2_test/README.md`. Historical Pending Run v3 / Run-only / Walk-only notes below are superseded. Artistic approval still requires future actual Godot transition, weapon-layer and30FPS mobile validation before production readiness.

**Latest Run comparison refinement — 2026-10-12, Pending:** user requested a slightly faster run and stronger arm swings while preserving current v2. Separate `Run_Expressive_v3_Test` is registered in the SAME existing Showcase; F1–20 at30FPS, closing21 excluded, 0.667s cycle: cadence +10%, straight whole-arm pitch excursion +20%. Existing v2 source, Action, reviews and entry remain unchanged. Exact v2 non-arm curve values/handles are retimed, preserving0.27m leg tracks,26mm lateral /50mm fore-aft /43mm vertical hip ranges and controlled body roll. Saved toe-out is L3°/R5° (earlier prose saying both3° was inaccurate); v3 retains those actual values. LEFT contactF1 / RIGHTF11, support42%/43%,15% flight, nominal controller travel2.31m/s kept separate. All thirteen earlier entries/actions and approved Idle/Walk remain unchanged. New Action stays Pending; no rig rebuild, Godot change, export or automatic approval. Review: `blender/animation/reviews/player_animation_library_v1/run_expressive_v3_test/README.md`. This is the latest authorized refinement; older active-task notes are historical. Godot transition/weapon/mobile30FPS validation remains future separately authorized work.

**Run v2 study — 2026-10-12, Pending:** separate `Run_Expressive_v2_Test` in the same existing Showcase; F1–22 at30FPS, closing F23 excluded,0.733s cycle. Approved refined Walk remains byte-identical. Run preserves0.27m tracks with3° toe-out,26mm lateral /50mm fore-aft /43mm vertical hip ranges, straight independent arms and restrained head. Support42%L/43%R;15% total flight. Shared phase0LEFT /0.5RIGHT receiving matches WalkF1/F19 to RunF1/F12. Nominal2.1m/s controller travel remains separate; no rig rebuild, Godot, export, Idle/Walk edit or automatic approval. Source, original-speed three-view reviews, old-Run and Walk comparisons, contact/loop evidence and transition limits: `blender/animation/reviews/player_animation_library_v1/run_expressive_v2_test/README.md`.

**Latest approval and active animation — 2026-10-12:** the user explicitly approved the CURRENT refined `Walk_Expressive_Test`: source SHA256 `4f0e61f3c6fbca14cbb3b7896a34ab8f0b011a50ebef11922bdfd5c4b75fad20`, Action SHA256 `15f8e76ac8ca19051bc2865ffeacc145ac2e003ec1eed8672cd8ecb72e6f20ef`. This is the preferred Walk baseline: 0.27 m tracks, 38 mm lateral / 36 mm fore-aft / 22 mm vertical hip ranges, controlled side-roll and straight opposing arms. Preserve its exact Action/source and all earlier checkpoints. Blender artistic approval only; actual Godot transition/mobile validation remains outstanding. The only newly authorized animation is separate `Run_Expressive_v2_Test`, Pending, using approved Idle v3, current Walk and original Run. No rig rebuild, approved Action edits, Godot change or export. Historical Pending/Walk-only scopes below are superseded by this explicit request.

**Latest Walk refinement — Pending,2026-10-11:** lateral hip travel and dynamic pelvis/spine/chest side-roll are halved against the previous delivered walk. Current hip ranges:38mm sideways,36mm fore/aft,22mm vertical. Foot tracks are0.27m apart,10mm inward per leg from0.29m;5° toe angles, support/stride timing and straight opposing arms remain. Previous complete source/reviews/Showcase are safely preserved in `.validation/walk_expressive_test/before_quieter_sway/`. Review only; no new approval or Godot change.

# Animation progress


**Walk Expressive study — 2026-10-11, Pending:** `Walk_Expressive_Test` is independently registered in the existing Showcase: playback1–36 at30FPS, closing37 excluded,1.2s seamless loop, original `OBRUN_Test_Rig` slot. Preferred idle remains explicitly approved `Idle_Expressive_Test_v3`; no idle Action/source was edited. Walk uses restrained support-driven torso/hip motion, straight opposing arms, steady forward head, unequal60%/62% support and22% double support without flight. Latest user-requested Pending refinement strengthens support-led pelvis sway/turn and lets the rigid torso follow the stepping legs:76mm hip side range, ±3.6° pelvic yaw and5.2° lateral balance range, partial delayed upper-body counter-motion, unchanged22mm vertical receiving range and foot/support timing. First successful walk and Showcase archived before refinement; no rubber deformation or extra character Action. Subsequent user steering adds36mm local fore/aft waist travel, synchronized to each receiving/reaching step and combined with lateral sway into a subtle diagonal path. Hip-sway candidate and central library separately archived before this edit; root/controller ownership and contacts remain unchanged. Latest front-view correction narrows the walking tracks from0.36m to0.32m (20mm inward per leg), preserving diagonal waist motion, stride timing, toe angles and upper-body articulation. Complete preceding candidate, native review frames and central file archived in `before_narrow_tracks/`. Final stronger narrowing uses0.29m tracks, approximately half the visible gap in the0.36m stance the user was viewing; intermediate0.32m source/Showcase is preserved in `before_half_gap/`. Lateral rigid-leg lean is reduced to−0.5°/+0.75° for thigh clearance;5° toe angles and diagonal upper-body motion remain. Reopened viewport must display the current source before another visual review. Nominal speed0.9m/s belongs to controller/temporary review travel; root/object remain identity in the reusable Action. Dense support/rigidity/intersection/pose-and-velocity checks passed. Dynamic5° toe-out/0.27m tracks need a support-aware replant to/from idle15°/~0.40m; generic crossfade is not a stable-foot transition. Future Walk↔Run needs lead-foot/phase alignment; weapon masks, interruption, actual Godot gameplay and phone30FPS remain separately authorized validation. Preserve all eleven earlier Actions, idle alternatives, Run, Full Jump and Godot. Review/evidence: `blender/animation/reviews/player_animation_library_v1/walk_expressive_test/README.md`. Only Walk is being developed; no automatic approval.


**Latest explicit approval and active task — 2026-10-11:** the user approved the current `Idle_Expressive_Test_v3` as the **preferred idle baseline** (straight full arms, limited downward drop, diagonal observations, stronger four-second breathing and the final asymmetric planted stance). Its Action/source remain unchanged; preserve v2/v1 as comparison alternatives. Earlier Pending notes below describe historical delivery states and are superseded by this approval. New authorized work is only `Walk_Expressive_Test`, an independent in-place loop registered Pending in the same existing Showcase when complete. Carry forward the idle posture/support language, controlled straight-arm articulation, stable forward gaze and subtle receiving softness; verify nominal-speed contacts, both lead feet, pose/velocity seam, slots and save/reopen/playback. Start/stop/replant and Walk↔Run phase compatibility need future actual Godot validation. No Run refinement, rig rebuild, Full Jump, Godot integration or export is authorized.



**Latest straight-arm clarification — 2026-10-11, Pending:** the user clarified that “above halfway” means **limit the downward drop and keep the gesture small**, not raise the hands to waist/mid-body height. Both full arms remain straight throughout the loop; remove the rejected elbow bend. During upward glances use only a small shoulder-driven response: 6° whole-arm forward pitch, 18°/20° spread and a 30mm animated shoulder-drop allowance instead of60mm (separate resting8/6mm offsets remain). Head directions, four0.25s holds, moving center crossings, stronger4s breathing and planted legs remain unchanged. Same Pending `Idle_Expressive_Test_v3` in the existing Showcase. The rejected bent-arm candidate and viewer are safely archived under `.validation/idle_expressive_test_v3/before_straight_arm_revision`; prior ten Actions/entries, v2/v1, Full Jump and Godot remain unchanged.



**Latest Idle v3 directional-gaze correction — 2026-10-11, Pending:** replaces the previous forward-facing nodding passages. From the FRONT viewer's perspective: right → center without a hold → top-right (0.25s) → bottom-left (0.25s) → left → center without a hold → top-right (0.25s) → bottom-left (0.25s), then settle to quiet rest across the loop seam. Each diagonal hold spans exactly7.5frames at30FPS. Center keys F53/F143 retain angular motion. Gaze is deliberate head articulation, not facial deformation. Existing48mm hip rise/14.4mm chest lift over4s, planted asymmetric leg matrices and eight-second loop remain. Delayed torso/arm support is aligned to the side looks; a smooth shoulder pose allowance clears the rigid head corners (60mm outside upward glances, reduced to30mm during them by the latest clarification), with no rig rebuild. Same Pending `Idle_Expressive_Test_v3` in the existing Animation Showcase; previous nodding candidate archived. Prior ten Actions/entries, v2/v1, Full Jump and Godot remain unchanged. This latest instruction supersedes earlier center-pause/vertical-glance timing below; historical records are retained.



Updated 2026-10-11, Asia/Saigon. Only explicit user review establishes artistic approval. Blender approval is artistic validation; production readiness additionally requires actual Godot gameplay and transition validation.



| Animation / workspace | Frames at 30 FPS | Status |

| --- | --- | --- |

| Animation Showcase | — | User approved and working |

| Expressive_Arm_Motion_Test | 1–24 | User approved |

| Run_Expressive_Test | 1–18; retain closing key 19 | User approved |

| LowerBody_Recovery_Test | 1–48 | User approved |

| Jump_Takeoff_Test | 1–24 | **User approved**: expressive motion and soft, subtle compression before takeoff |

| Jump_AirPose_Test | 1–22 | **User approved**: happy with its expressive airborne motion |

| Jump_Landing_Test | 1–44 | Preserved softer alternate; no explicit approval recorded |

| Jump_Landing_Impact_Test | 1–56 | **User approved; preferred landing baseline** |

| Full_Jump_Expressive_Test | 1–93 | **Pending user review** |

| Full_Jump_Expressive_v2_Test | 1–93 | **Pending user review**; higher arms, wider airborne legs and stronger soft landing; original preserved |

| Idle_Expressive_Test | 1–144; retain closing key 145 | **Pending user review**; seamless 4.8-second look-around loop |

| Idle_Expressive_Test_v2 | 1–240; retain closing key 241 | **Pending user review**; separate eight-second two-sided observation, wider planted stance and quiet rigid breathing |

| Idle_Expressive_Test_v3 | 1–240; retain closing key 241 | **User approved; preferred idle baseline** — 2026-10-11; v2/v1 preserved |
| Walk_Expressive_Test | 1–36; retain closing key 37 | **User approved — current refined version**, 2026-10-12; exact source/Action hashes recorded above |
| Run_Expressive_v2_Test | 1–22; retain closing key 23 | **Pending user review**; separate 0.733-second run; original Run preserved |

| Run_Expressive_v3_Test | 1–20; retain closing key21 | **User approved; preferred run baseline** —2026-10-12; original Run and v2 preserved |



The takeoff approval was explicitly received before the airborne request. Its approved Action and saved Blender source remain unchanged; metadata and the showcase now reflect that approval.



**Idle v3 stance and 4X-original breathing checkpoint — 2026-10-11, Pending:** [study](../../blender/animation/reviews/player_animation_library_v1/idle_expressive_test_v3/README.md). Latest explicit side-view request: character LEFT slightly forward and RIGHT slightly back (opposed 3.75° whole-leg pitch; latest requested50% increase), both15° outward yaw, as subsequently requested. Unequal mainly sideways opening remains L3°/R8°, with hip bias and torso counterbalance. Twenty-five millimetres of clearance per proximal leg from the original sideways-only base (16mm more than the5° candidate) prevents the yawed rigid blocks intersecting. Fixed lowest sole corners; no invented ankle/knee or flattened boots. Current breathing doubles the previous4X version to8X original amplitude:48mm hip/body excursion plus14.4mm rigid chest lift over the same four-second period; a36mm lower hip baseline keeps the rigid waist connected. Feet remain fixed. Latest look-around refinement doubles the attention-driven head/arm gesture range and doubles gesture speed, with delayed torso/shoulder support. The two unequal looks remain separated by calm rests; slow four-second breathing and the current planted leg pose are unchanged. Eight-second loop timing is preserved. Latest middle-pause correction halves the straight-ahead interval between looks from60.5 to30.25frames (about2.02 to1.01seconds), moving the second look30.25frames earlier without changing turn speed/range, four-second breathing, leg stance or eight-second loop. Quiet rest across the seam remains. Additional user steering adds restrained up/down head attention only while facing forward: a5° upward glance and4° chin dip in the shorter center interval, then a gentler4°/3° pair in the later rest. Returns are smooth and the seam remains quiet; side-look range/speed, breathing, legs and rig are preserved. Latest user steering doubles the current breathing again to8X original amplitude:48mm hip/body excursion and14.4mm rigid chest lift over the unchanged four-second rhythm. The hip baseline is lowered36mm so the stronger excursion remains connected to both solid leg blocks; resting shoulders are lowered8mm left/6mm right to preserve head clearance. Leg matrices, side-look range/speed, the halved middle pause and forward-facing up/down glances remain. These are pose changes only; no rig or mesh edit. Pending stance/breath review checkpoint in the same central Showcase. Three-view stance stills and an original-speed three-quarter motion preview are linked from the study README. The previous polished-video candidate is archived; a full updated comparison video set is deferred for the requested stance review. V2/v1, approved Actions, source assets and Godot remain unchanged. Playback1–240 at30FPS; closing241 excluded. Gameplay transitions, weapon layers and measured mobile30FPS remain future separately authorized validation.



**Separate Idle v2 comparison — 2026-10-11:** the user requested [Idle_Expressive_Test_v2](../../blender/animation/reviews/player_animation_library_v1/idle_expressive_test_v2/README.md), preserving the entire current Idle/source/review unchanged. Two unequal head-led observations with center/rest pauses, subtle rigid chest/shoulder breath and a 28 mm outward placement per fixed foot give a more open curious stance. New independent Action, Pending in the same Showcase; eight seconds/30 FPS, closing key 241 excluded. No facial deformation, rig rebuild, Walk, Full Jump/preview edit, Godot change or automatic approval. Original-speed matched-stage comparisons are linked from the study.



**Permanent user priority, 2026-10-11:** seamless, responsive, natural Godot integration is the highest animation-development priority. Design for pose/velocity continuity, support/locomotion phase, consistent rig/transforms, interruptions, physics-aware takeoff/contact, weapon layers and measured mobile 30 FPS. Every approved animation must eventually pass gameplay/transition validation; Blender alone cannot establish production readiness. Continue one animation at a time. Idle v2 records wider-stance entry/exit support and weapon masking as unvalidated future integration work.



[Jump AirPose review](../../blender/animation/reviews/player_animation_library_v1/jump_airpose_test/README.md) develops wide arm silhouettes, staggered overlap and asymmetric rigid legs. A temporary three-view video continues the approved takeoff into the separate AirPose Action. AirPose contains no root/hip travel or artificial airborne bounce; preview presentation is separate. Its original delivery contained no landing or combined production jump and made no Godot change.



Approved direction: expressive rigid block articulation, strong silhouettes, controlled asymmetry, smooth spacing and soft **“nhúng nhúng”** compression around ground support. That softness belongs to grounded preparation/absorption/recovery; flight uses restrained overlap rather than ground-contact bounce.



The user subsequently approved AirPose and requested only [Jump Landing](../../blender/animation/reviews/player_animation_library_v1/jump_landing_test/README.md): approach, staggered contact, soft absorption, restrained rebound and recovery. The approved AirPose Action/source stay unchanged. The three-Action review keeps presentation descent outside the exportable landing Action; there is no full jump trajectory or gameplay integration.



Use [the central Animation Library](../../blender/animation/showcase/README.md) and [registration workflow](ANIMATION_WORKFLOW.md). Keep the softer Landing preserved as an alternate. Full production jump integration remains a separate task.



The user described the current Landing as good and requested a separate, stronger [Impact Landing comparison](../../blender/animation/reviews/player_animation_library_v1/jump_landing_impact_test/README.md). The original Landing Action and every file in its study stay unchanged. Impact pushes absorption speed/depth, weight transfer, torso/arm reaction and a slower settle. The user subsequently explicitly approved Impact Landing and selected it as the preferred landing baseline. Its source and Action stay unchanged; original softer Landing remains preserved as an alternate.





The latest request explicitly records **Jump Takeoff, Jump AirPose and Jump Landing Impact as approved** and creates [Full Jump Expressive](../../blender/animation/reviews/player_animation_library_v1/full_jump_expressive_test/README.md), **pending**. The new 93-frame/30-FPS Action preserves grounded preparation and heavy absorption, smoothly shortens the middle air section and retains both shared pose/motion boundaries. Flight height is removed from reusable pose data and supplied only in a separate Blender review parent; the showcase stores the in-place Action. Original-speed front/three-quarter/side videos and saved-file, support, rigidity, source, showcase and playback checks accompany it. No Godot change, export or automatic approval.





**Latest presentation refinement:** the user describes Full Jump as good but wants a slightly higher Blender review. [Higher preview V002](../../blender/animation/reviews/player_animation_library_v1/full_jump_expressive_test/higher_preview_v002/README.md) increases only the separate elevation arc from **0.58 m to 0.72 m** (+14 cm), preserving all 93-frame/30-FPS poses, contact/impact timing, original preview/source/media, showcase and Godot. No skeletal motion variant is created or registered. Front/three-quarter/side and same-camera comparison videos accompany it. This request does not explicitly approve Full Jump or the revised presentation; both remain pending review.





**Original gradual recreation — Idle v1, preserved historical record:** [Idle_Expressive_Test](../../blender/animation/reviews/player_animation_library_v1/idle_expressive_test/README.md) adds quiet unequal weight transfer, planted full soles, small rigid breathing rotations, staggered shoulders/arms and restrained head counter-response. It is a new independent 144-frame/30-FPS look-around loop, with closing key 145 outside playback. The original Idle remains preserved; original-speed matching-stage front/three-quarter/side comparisons use its native four-second motion without retiming. This Pending Action is registered and saved in the existing central Showcase, following the permanent every-animation registration rule now recorded in AGENTS and the workflow. Full Jump and all its review previews remain unchanged. No Walk, Godot or automatic approval.



**In-task artistic steering:** the user supplied an animated Minecraft Dungeons II Player Idle LookAround reference (81 frames, 3.38 s) and requested personality in this same Pending Idle. The revised 4.8-second loop gives one head-led glance, an observing pause, delayed torso/shoulder/hip/arm response and a quiet return. The earlier breathing pass is backed up as a discarded working iteration; no approved Action is overwritten and no separate LookAround Action is created.

