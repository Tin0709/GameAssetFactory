# Godot ownership and transition contracts

The current animation research runs in the existing [ActionsStuffWalkRunTest scene](../../../game_mobile_3d/scenes/dev/ActionsStuffWalkRunTest.tscn), opened with F6 in the existing project. F5 still uses the production main scene. Preserve this boundary. Knowledge work does not authorize a new scene, runtime rewrite, asset export or production replacement. Previously granted integration authorization remains valid within its recorded scope; do not invent another artistic gate for an already accepted integration.

## Current pose pipeline

The inheritance chain is [rifle_visual.gd](../../../game_mobile_3d/scenes/dev/actions_stuff_research/rifle_ready_v001/rifle_visual.gd) → [jump_locomotion_visual.gd](../../../game_mobile_3d/scenes/dev/actions_stuff_research/jump_locomotion_visual.gd) → [walk_run_visual.gd](../../../game_mobile_3d/scenes/dev/actions_stuff_research/walk_run_visual.gd) → [expressive_locomotion_visual.gd](../../../game_mobile_3d/scenes/dev/expressive_locomotion_visual.gd). Retain one inherited input/gait update and one composed skeleton pose writer. Source samplers supply transforms; they must not compete with another active AnimationPlayer or restart clips every frame.

[Source direction control](../../../game_mobile_3d/scenes/dev/actions_stuff_research/source_direction_controller.gd) retains the audited pre_animation27→29→30 order, directional weights and common gait clock. The [direction sampler](../../../game_mobile_3d/scenes/dev/actions_stuff_research/source_direction_sampler.gd) preserves evaluated position, rotation and source scale. Separate literal source facts from scene-owned query calibration, negative-weight assumptions, heading and contact adapters.

Maintain phase across speed, direction, stance and weapon changes. The current rifle ground cursor follows actual distance and freezes at zero travel. The jump bridge shares `PHASE_KEYS` while retaining intentional source takeoff/landing handoffs. Idle observation/lifetime clocks remain independent. Real capsule physics owns takeoff, flight, collision and landing; a Blender preview arc is not runtime jump height or a fixed flight schedule.

## Contacts, Aim and Recoil

Support uses actual rigid sole corners, bounded 140mm correction and early release at 110mm horizontal reach. The inherited 35° yaw tolerance has a rifle-specific moving-start release at 12°. Current tiny grounded taps below .18m retain contacts instead of triggering the longer alternating replant. These are declared gameplay adapters, not claims about the source engine's foot solver.

Aim traverses a reversible .24s upper-body layer. Ground root/legs and physical Jump/Landing remain authoritative. The complete straight-arm/rifle assembly retains the evaluated right grip and living left-support target after blending and inertialization.

Before the next base-pose update, restore the previous recoil and auto-aim overlays. Then apply approved evaluated reference-relative deltas once. Recoil must not feed back into gait, feet, inertialization or subsequent shots. [rifle_presenter.gd](../../../game_mobile_3d/scenes/dev/actions_stuff_research/rifle_ready_v001/rifle_presenter.gd) carries gun and hands on the same interpolated render pose; it reconciles intermediate poses without re-solving authoritative physics endpoints.

## Snapshot and release boundary

As recorded on 2026-10-23, this dev scene uses Walk **2.16m/s**, Run **6.0372m/s**, movement/playback **1.2×**, camera size **14.5**, held-E 180° acquisition **.60s**, and fully raised Aim fire **6Hz**. These are current lab settings, not universal animation-style constants. See [pace/camera evidence](../reviews/pace_camera_v001/README.md), [turn adapter](../../../game_mobile_3d/scenes/dev/actions_stuff_research/turn_in_place_v001/rifle_turn.gd) and [fire coordinator](../../../game_mobile_3d/scenes/dev/actions_stuff_research/rifle_ready_v001/continuous_fire.gd).

The older [Animation Runtime V2](../../../game_mobile_3d/docs/ANIMATION_RUNTIME_V2.md) describes the separate production WeaponSocket architecture; do not substitute it for this research pipeline. Keep the existing [research export exclusion](../../../game_mobile_3d/scenes/dev/actions_stuff_research/README.md), including its recovery-mode limitation. Desktop checks do not establish measured phone performance or commercial eligibility.
