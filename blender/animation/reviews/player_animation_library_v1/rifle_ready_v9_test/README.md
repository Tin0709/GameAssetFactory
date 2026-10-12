# Rifle Ready v9 — step one, Pending

The user requested returning to a simpler starting pose: stand like the approved Idle, hold the rifle in the right hand and point it down toward the ground. The left arm stays relaxed; no two-hand ready positioning is added at this step.

Select **Rifle_Ready_V2_v9_Test** in the SAME existing `blender/animation/showcase/Animation_Showcase.blend`. The actual unchanged Rifle Stylized V2 is attached. F1–120 at30FPS, four-second restrained-breathing loop; F121 closes the loop and is excluded from playback.

The resting body, legs, head and left arm match approved Idle v3 F1. The straight right arm is carried modestly forward from its shoulder so the full-length rifle clears the ground. Its barrel follows that arm downward; the grip remains centered in the right block hand. The original fully hanging-arm probe put the rifle tip through the floor and was not registered. The current rifle lowest vertex is about0.20m above the ground at rest. No proportions, rifle scale, geometry, materials, rest rig or bones were changed.

[Front](revised_front.png) · [Three-quarter](revised_three_quarter.png) · [Side](revised_side.png) · [Previous v8 / new one-hand comparison](ready_comparison.png)

Both arms remain straight and the left hand does not contact the rifle. The rifle stays clear of the head, torso and legs at the reviewed resting frame; small stock/upper-right-arm seating and intentional solid-hand grip overlap remain. Triangle-pair contact counts do not certify penetration depth or finger-level fit. This is a Blender pose checkpoint, not a moving weapon-layer or production gameplay validation.

429 fresh reopen, Action/slot switching, prior-signature, idle-pose, ground-clearance, hand synchronization, rigid-scale, planted-leg and loop-pose checks passed. All25 earlier Actions and manifest entries are exact. [Loop velocity](loop_quality.json), [GUI play/wrap/pause/restart](gui_playback.json), [all26 Actions retained after inactive scratch save/reopen](inactive_action_retention.json), [contact diagnostics](intersection_diagnostics.json), [validation](validation.json), [protected-file audit](preservation.json).

Backups: `.validation/rifle_ready_v9/before/`. [Authoring source](rifle_ready_v9_review.blend). Source SHA256 `15c131cce633d5f140b440b5f5323fd9082f028ba99c0d441dfa965432882438`; Action SHA256 `73ca30a5b609724de29ac464071861ebab01a83e3db2ec8af8c9283d869727e1`.

All earlier Ready versions remain selectable. Aim, Back Holster, other animations, Weapon Showcase and Godot are unchanged. **Pending user review. Stop at this one-hand starting pose.**
