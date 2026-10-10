# Animation progress

Updated 2026-10-10, Asia/Saigon. Only explicit user review establishes artistic approval.

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
| Idle_Expressive_Test | 1–96; retain closing key 97 | **Pending user review**; seamless 3.2-second loop |

The takeoff approval was explicitly received before the airborne request. Its approved Action and saved Blender source remain unchanged; metadata and the showcase now reflect that approval.

[Jump AirPose review](../../blender/animation/reviews/player_animation_library_v1/jump_airpose_test/README.md) develops wide arm silhouettes, staggered overlap and asymmetric rigid legs. A temporary three-view video continues the approved takeoff into the separate AirPose Action. AirPose contains no root/hip travel or artificial airborne bounce; preview presentation is separate. Its original delivery contained no landing or combined production jump and made no Godot change.

Approved direction: expressive rigid block articulation, strong silhouettes, controlled asymmetry, smooth spacing and soft **“nhúng nhúng”** compression around ground support. That softness belongs to grounded preparation/absorption/recovery; flight uses restrained overlap rather than ground-contact bounce.

The user subsequently approved AirPose and requested only [Jump Landing](../../blender/animation/reviews/player_animation_library_v1/jump_landing_test/README.md): approach, staggered contact, soft absorption, restrained rebound and recovery. The approved AirPose Action/source stay unchanged. The three-Action review keeps presentation descent outside the exportable landing Action; there is no full jump trajectory or gameplay integration.

Use [the central Animation Library](../../blender/animation/showcase/README.md) and [registration workflow](ANIMATION_WORKFLOW.md). Keep the softer Landing preserved as an alternate. Full production jump integration remains a separate task.

The user described the current Landing as good and requested a separate, stronger [Impact Landing comparison](../../blender/animation/reviews/player_animation_library_v1/jump_landing_impact_test/README.md). The original Landing Action and every file in its study stay unchanged. Impact pushes absorption speed/depth, weight transfer, torso/arm reaction and a slower settle. The user subsequently explicitly approved Impact Landing and selected it as the preferred landing baseline. Its source and Action stay unchanged; original softer Landing remains preserved as an alternate.


The latest request explicitly records **Jump Takeoff, Jump AirPose and Jump Landing Impact as approved** and creates [Full Jump Expressive](../../blender/animation/reviews/player_animation_library_v1/full_jump_expressive_test/README.md), **pending**. The new 93-frame/30-FPS Action preserves grounded preparation and heavy absorption, smoothly shortens the middle air section and retains both shared pose/motion boundaries. Flight height is removed from reusable pose data and supplied only in a separate Blender review parent; the showcase stores the in-place Action. Original-speed front/three-quarter/side videos and saved-file, support, rigidity, source, showcase and playback checks accompany it. No Godot change, export or automatic approval.


**Latest presentation refinement:** the user describes Full Jump as good but wants a slightly higher Blender review. [Higher preview V002](../../blender/animation/reviews/player_animation_library_v1/full_jump_expressive_test/higher_preview_v002/README.md) increases only the separate elevation arc from **0.58 m to 0.72 m** (+14 cm), preserving all 93-frame/30-FPS poses, contact/impact timing, original preview/source/media, showcase and Godot. No skeletal motion variant is created or registered. Front/three-quarter/side and same-camera comparison videos accompany it. This request does not explicitly approve Full Jump or the revised presentation; both remain pending review.


**Current gradual recreation — Idle only:** [Idle_Expressive_Test](../../blender/animation/reviews/player_animation_library_v1/idle_expressive_test/README.md) adds quiet unequal weight transfer, planted full soles, small rigid breathing rotations, staggered shoulders/arms and restrained head counter-response. It is a new independent 96-frame/30-FPS loop, with closing key 97 outside playback. The original Idle remains preserved; original-speed matching-stage front/three-quarter/side comparisons use its native four-second motion without retiming. Register and save this Pending Action in the existing central Showcase, following the permanent every-animation registration rule now recorded in AGENTS and the workflow. Full Jump and all its review previews remain unchanged. No Walk, Godot or automatic approval.
