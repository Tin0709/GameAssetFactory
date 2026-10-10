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
| Jump_Landing_Test | 1–44 | **Pending user review** |
| Jump_Landing_Impact_Test | 1–56 | **Pending comparison review** |

The takeoff approval was explicitly received before the airborne request. Its approved Action and saved Blender source remain unchanged; metadata and the showcase now reflect that approval.

[Jump AirPose review](../../blender/animation/reviews/player_animation_library_v1/jump_airpose_test/README.md) develops wide arm silhouettes, staggered overlap and asymmetric rigid legs. A temporary three-view video continues the approved takeoff into the separate AirPose Action. AirPose contains no root/hip travel or artificial airborne bounce; preview presentation is separate. Its original delivery contained no landing or combined production jump and made no Godot change.

Approved direction: expressive rigid block articulation, strong silhouettes, controlled asymmetry, smooth spacing and soft **“nhúng nhúng”** compression around ground support. That softness belongs to grounded preparation/absorption/recovery; flight uses restrained overlap rather than ground-contact bounce.

The user subsequently approved AirPose and requested only [Jump Landing](../../blender/animation/reviews/player_animation_library_v1/jump_landing_test/README.md): approach, staggered contact, soft absorption, restrained rebound and recovery. The approved AirPose Action/source stay unchanged. The three-Action review keeps presentation descent outside the exportable landing Action; there is no full jump trajectory or gameplay integration.

Use [the central Animation Library](../../blender/animation/showcase/README.md) and [registration workflow](ANIMATION_WORKFLOW.md). Keep Landing pending until the user reviews it. Full production jump integration remains a separate task.

The user described the current Landing as good and requested a separate, stronger [Impact Landing comparison](../../blender/animation/reviews/player_animation_library_v1/jump_landing_impact_test/README.md). The original Landing Action and every file in its study stay unchanged. Impact pushes absorption speed/depth, weight transfer, torso/arm reaction and a slower settle. This is exploratory comparison, not approval of the variant or replacement of the soft baseline; both entries remain pending until explicit approval.
