# Minecraft locomotion reference — analysis for Codex

## Purpose and scope
The user wants new, original Walk and fast Run/Sprint animations for their own blocky player, closely matching the visible motion style in these two user-provided recordings. Study the motion; do not import the reference character's skin, textures, armor, or model. This is an unarmed locomotion reference, not a READY/weapon-hold reference. Existing game animations and gameplay must remain protected during the experiment.

## Sources and time convention
- `originals/Screen Recording 2026-10-07 093200.mp4`: rear elevated view; 288 x 400; 421 decoded frames at 30 fps; video frames span 0.000–14.000 seconds. The file container includes a small additional audio tail.
- `originals/Screen Recording 2026-10-07 093249.mp4`: front, lower view; 322 x 538; 271 decoded frames at 30 fps; video frames span 0.000–9.000 seconds.
- The recordings are separate takes. Do not triangulate their frames as synchronized views.
- Frame labels in sheets are zero-based source-video frames: time = frame / 30. These are NOT Blender authoring frame numbers.
- The source UI does not expose the exact movement input/state. We use "walk-like/slower" and "run/sprint-like/faster" descriptively, following the user's intended comparison.

## Useful windows
Rear: approximately 0–1.5 s standing; 1.8–6.0 s slower gait; 6.5–11.2 s faster gait; 11.5–12.7 s stopping/standing. Exclude the late pause-menu footage.
Front: 0.2–2.4 s slower gait; 3.0–7.5 s faster gait. Exclude the transition/camera change around 2.5–2.9 s and the menu after approximately 7.8 s when estimating cadence.

## Cadence estimates — not recovered source keyframes
A simple lagged pixel-difference comparison restricted mainly to the character's brown/dark pixels, plus ordered-frame inspection, suggests:
- Slower gait: full same-side cycle approximately 19–20 captured frames = 0.63–0.67 s.
- Faster gait: full same-side cycle approximately 16–17 captured frames = 0.53–0.57 s.
- A full cycle includes both alternating leg phases. These numbers are not the duration of one step.
- This measures visible periodicity, not exact foot-contact events or engine animation parameters. Compression, camera framing, finite sampling and transients limit precision. Verify with several repeated same-side poses.
- A useful INITIAL Blender experiment at 24 fps is a 16-interval walk (frames 1–17; 0.666667 s) and a 13-interval sprint (frames 1–14; 0.541667 s). These are design candidates, not source facts.
- Keep the terminal repeated pose as a curve endpoint. For repeated integer-frame preview, avoid displaying both the duplicated last pose and first pose as two successive held samples. Do not truncate the exported time interval by deleting the required endpoint.
- Do not automatically add the old project's 1.60x cadence to a newly reference-timed clip.

## What the recordings support
1. The reference reads strongly blocky. Long straight limb faces remain important to the silhouette. There is NOT enough evidence from these views to require elbow/knee joints as the first implementation step. Foreshortening and texture boundaries can resemble bending. Do not identify a specific mod or skeleton from this footage alone.
2. The slower gait is already lively/bouncy rather than a deliberately heavy realistic stroll. Do not enforce a textbook heel-to-toe walk or invent precise double-support timing from these two views.
3. Left/right leg reach and recovery alternate; the recovering leg looks higher/shorter in projection while the other leg presents a longer silhouette. Opposite arm and leg move forward together.
4. Shoulder and torso orientation change with the stride. The rear view shows alternating shoulder presentation and a slanted waist/belt; the upper body is not an upright, motionless pillar.
5. Head orientation stays comparatively calm/forward, but head POSITION visibly rises/falls with the body. "Stable gaze" must not be implemented as a world-position-locked head.
6. Faster gait changes pose, not just time scale. The forward arm presents more prominently across/in front of the torso, the opposite arm trails, and the body silhouette has stronger diagonal energy. Compare front 3.000, 3.267, 3.533 and 3.800 s.
7. There is readable rise/release and lowering between steps. Some samples show shoe-to-shadow clearance. This supports a bouncy visual rhythm; it does not recover exact physical ground-contact frames or prove a foot-IK system.
8. Arms and torso remain connected visually. The goal is a coherent stride, not adding arbitrary fixed delays to every body part. A strict 1-frame hierarchy or deliberate asymmetry is NOT measured from the source.
9. The front-facing texture is asymmetric. Do not confuse asymmetric clothing with proven asymmetric joint motion.
10. Camera perspective/scale changes around the gait changes. Do not reproduce the character becoming smaller on screen with bone scale, body squash, or world translation.

## Limits / do not invent
There is no calibrated side view, source rig, bone-angle data, world velocity, or animation script. Exact forward lean, rotations in degrees, world-space bounce in cm, stride travel in meters, knee/elbow articulation and IK implementation cannot be uniquely recovered. Identify visual observations separately from implementation choices. Do not promise frame-perfect 3D reconstruction.

## Recommended experiment
Create new unarmed Walk/Sprint Actions in a separate Blender development copy, using the existing rigid cuboid rig first. Match the overall body silhouette and cadence before micro-polish. Preserve original clips, mesh, rest pose, weights, bone hierarchy and all game files. Do not alter weapons or the READY system. If the current rig cannot achieve a specific visible pose, document the exact limitation and request approval before changing it.

Author full-body key poses for a small A/B reference study rather than adding isolated limbs in many blind passes. Use a consistent source-motion phase, then refine hips, torso/shoulder balance, opposite arm swing, recovery-leg shape and gaze orientation. Do not copy a generic human run over the existing rig.

Review front/rear at comparable framing, then actual elevated gameplay scale. Review normal-speed repeated playback and capture representative phase sheets. Separate technical checks from the user's artistic approval. Check intersections, no scale, no unwanted root drift, pose AND tangent seam continuity, and preservation of old assets. Keep both motions in-place for the game experiment; report that gait speed must be calibrated later.

## Existing project caution
Previous reports say normal READY movement uses Walk, while the existing Run V7 is used for fast Sprint (which stows the weapon). Do not silently replace Walk with Sprint or phase-lock a Run-authored armed stabilization layer to Walk. The current experimental armed-run compensation was authored against the old Run; a future replacement needs an explicit compatibility review. This task does NOT integrate into Godot.

## Codex access
Supply both original videos plus these sheets. A file path alone does not prove that a model viewed the motion. Use available video/frame tools; if only image viewing is supported, inspect ordered timestamped frames and extract more around uncertain events. Missing original sources must be reported, not guessed. No new skills/plugins are needed for this study.
