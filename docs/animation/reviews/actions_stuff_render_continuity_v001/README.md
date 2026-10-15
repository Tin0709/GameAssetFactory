# Research player render continuity

2026-10-15: user reports stutter/shaking perceived as blur and a second ghost player during fast falls. Earlier measurements found120Hz rendering with60Hz manual bone uploads and repeated poses on half the rendered frames, plus uneven Jump frame intervals. No motion-blur/TAA/FXAA/DOF or texture/upscale effect was enabled.

The existing `ActionsStuffWalkRunTest` now resolves the approved pose/contact solver once per physics tick and snapshots its final local PRS, world feet and root. A render-only presenter interpolates between those two solved poses at the actual display fraction and uploads the existing skin/mesh RID immediately before drawing. The camera follows the same displayed root, retaining its stable jump-height dead zone. There is still exactly one original player mesh/skin; no duplicate character, trail, candidate, scene or project is created.

Full local position/rotation/scale is interpolated before composing the hierarchy, preserving parent squash/stretch/shear. Both endpoints are exact final solved source poses. Between endpoints, a display-only rigid leg translation keeps a supported sole on its interpolated world support and prevents flat-floor penetration. CPU skeleton, phase, source controllers, foot contacts, sockets, collisions and velocities are never overwritten by presentation. R rebases both snapshots, preventing teleport streaks.

This is ordinary previous/current presentation interpolation: up to one physics interval of display latency (16.7ms at existing60Hz), with no input queue or added control/physics delay. Pose timing/cadence and jump gravity/height remain unchanged. At30displayFPS, both underlying60Hz physics poses are still evaluated; no extrapolation, pose averaging, temporal AA or motion-blur filter is used. Visible weapon attachments would need the same presentation space before any future armed/production rollout; this existing research scene is unarmed and production is untouched.

## Evidence

- RED before implementation: existing scene lacked final-pose render presentation.
-1,800fractional samples across30/60Hz running, circular turning and jump/fall: exact endpoint matrices (zero error), intermediate sole minimum−0.00000006m and planted drift0.000000033m; source/physics/CPU skeleton immutable during display samples and teleport rebased.
- MetalMobile uncapped (~110FPS), capped30 and capped60 native checks: post-draw skin buffer exactly matches the intended displayed skin. Every moving render frame with an unchanged physics snapshot now changes both displayed skin and root, replacing the earlier repeated pose frames. See `validation_summary.json`.
- Existing physical Jump/Landing at30/60Hz (five modes plus reset), Idle60Hz, camera30/60Hz and unarmed2,400samples all pass. All approved source/Blender assets and production files remain unchanged.

These checks demonstrate removal of the repeated-pose presentation defect; subjective display-panel ghosting cannot be certified by GPU readback alone. The updated existing scene is ready for direct keyboard play, without another artistic review stage.
