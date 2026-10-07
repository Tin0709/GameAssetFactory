# Turning locomotion reference — observation and design brief

## Source and method
- User-provided `Screen Recording 2026-10-07 102829.mp4`.
- Decoded video: 550 × 640, 30 FPS, 589 frames, 19.633333 seconds. Container/audio duration is slightly longer.
- Frames in the sheets are zero-based decoded video frames, timestamp = frame / 30.
- Full-frame overviews sample every 0.5 seconds. Cropped overview sequences sample every 0.1 seconds. Three critical windows retain consecutive 30-FPS frames.
- Crops use the SAME fixed image rectangle (90, 135, 455, 565) before resizing. They do not stabilize the head or remove body translation. Full-frame sheets retain the camera/background context.
- Review used extracted image sequences, not native continuous video perception. No source engine code, skeletal data, camera matrices, player inputs, or locomotion state telemetry were supplied.
- Names Walk/Sprint follow the user's intended slow/fast distinction. They are not verified names of source game states.

## Evidence windows
1. 0.0–1.2 s: mostly rear-facing straight slower locomotion; useful baseline.
2. 1.267–1.733 s: slow turn entry. Face side becomes visible while the back of the torso is still prominent; the projected body line becomes oblique. Stepping and arm swings continue. See 11_walk_entry_30fps.jpg.
3. 1.3–5.8 s: sustained slower heading changes with back/side/front views recurring. See 01/02/03 sheets. The camera follows the actor; exact world-space circle radius is not recoverable.
4. 5.8–6.8 s: comparatively straight segment. Around 6.8–7.1 s the character's size/framing changes; do not mistake that for body scaling or bone shortening.
5. 8.333–8.833 s: faster turn entry, with pronounced oblique body presentation while limbs continue their cycle. See 12_sprint_entry_30fps.jpg.
6. 8.4–17.7 s: repeated faster curved movement/heading changes. See 05–09 sheets, especially 12.0–13.9 s. Shape and gait keep evolving while orientation changes.
7. 17.6–18.233 s: return from a visibly oblique pose toward rear-facing, more upright posture, followed by reduced limb motion. See 13_return_30fps.jpg. Turning recovery and deceleration overlap; do not claim a measured turn-only damping constant.
8. Approximately 18.9 s onwards: pause menu; exclude from motion analysis.

## Directly visible characteristics
- Multiple intermediate heading/body poses occur during a turn; it does not read as an instantaneous rigid 90-degree swap.
- Turning does not visibly interrupt stepping to play an isolated standing-turn action in the inspected windows.
- The projected body axis and waist/shoulder lines are oblique during many turn poses. Faster turns have an energetic lean combined with the existing running pose.
- Head and torso do not always present exactly the same direction to the camera. This supports a small relative orientation allowance, not a universal fixed head-lead timing claim.
- Arms continue alternate swings; forward and rear silhouettes remain legible through changing viewpoints.
- Repeated turning preserves ongoing stride movement rather than visibly stopping at each camera-facing quadrant.
- On turn exit/deceleration the oblique pose reduces across successive frames rather than staying frozen at a maximum lean.

## What is NOT established
- No proof of a particular Minecraft resource pack, mod, procedural formula, IK solver, root-motion implementation, additive animation, or source state machine.
- No calibrated 3D banking angle, exact yaw rate, turn radius, center-of-mass curve, stride length or exact foot-plant trajectory.
- Some apparent tilt is ordinary forward lean / gait motion projected by a changing heading. Do not attribute every degree to turn banking.
- Camera motion and player heading cannot be separated exactly from these uncalibrated images. Check full-frame context.
- The clip does not isolate equally controlled left/right, abrupt 180-degree, or standing-pivot examples. Mirrored left/right candidates are an implementation requirement, not a measured pair of identical reference actions.
- No source animation-clock data: 'preserve phase' is our design requirement inspired by visual continuity, not a proven source implementation.

## Proposed recreation — NOT a claim about source code
The desired look can be approached by combining:
1. A continuing base gait cycle.
2. Smoothly changing visual travel heading.
3. A restrained turn-dependent body pose (lean, torso orientation, shoulder/arm balance).
4. Entry/exit smoothing so the turn pose responds to turning rather than switching abruptly.

For a first Blender-only study, preserve current R1 base Actions and create four full-pose, phase-aligned locomotion variants:
- Walk_TurnLeft_Reference_V1
- Walk_TurnRight_Reference_V1
- Sprint_TurnLeft_Reference_V1
- Sprint_TurnRight_Reference_V1

These are sustained turning-gait variants, NOT one-shot 90-degree turns. Their local cycles have no accumulated world heading or root travel. A separate preview path parent supplies world translation/yaw. Blend straight/left/right at the SAME normalized gait phase, never add full poses on top of one another.

A circle is a runtime/preview trajectory plus sustained turning response, not a new monolithic 'CircleWalk' clip. Keep the turn sign in character/travel coordinates, not screen-left/screen-right. It must not flip just because the character passes from rear to front view.

Keep Walk and Sprint phase/cadence sources separate. Do not drive Walk with the old Run V7 clock. R1 timing candidates are ~16/24 s and ~13/24 s; verify actual Action intervals. Do not automatically multiply the reference study by the old 1.60 playback factor.

Full-body turning locomotion may modify Hips/legs within NEW candidate Actions. The no-lower-body-keys restriction for weapon overlays does not apply to these full-body gait variants. Protect original geometry, weights, rig structure, source Actions and gameplay.

## Visual test design
- Identical path/camera/cadence A/B: A = base gait with heading change only; B = heading plus authored turn pose.
- Moving left/right bends; S-curve; continuous clockwise/counterclockwise circles; return to straight.
- Test entering/leaving turns at 0%, 25%, 50%, 75% gait phases.
- Use fixed world camera first so orbiting camera cannot masquerade as successful turning; gameplay-style following camera second.
- Inspect same-side pose and derivative continuity, ground penetration, visible foot sliding, knee/hip gaps, shoulder separation, head/body orientation, and exaggerated lean.
- Distinguish numerical checks, inspected images, continuous playback review availability, and user artistic approval.

## Scope boundary
First task is a separate Blender-only turning study. No Godot integration, no weapon-pose changes, no new joints, no new skills/plugins, no replacement of R1 bases. Integrate later only after visual review and version-specific runtime inspection.

## External implementation reference (not source-video evidence)
Godot's official AnimationTree docs describe blending and filters, and versioned BlendSpace docs describe synchronization:
- https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html
- https://docs.godotengine.org/en/4.7/classes/class_animationnodeblendspace2d.html
Inspect the ACTUAL installed Godot version before selecting API or sync mode. Generic 'sync=true' / independent time advancement is not proof of normalized phase alignment across unequal-duration clips.
