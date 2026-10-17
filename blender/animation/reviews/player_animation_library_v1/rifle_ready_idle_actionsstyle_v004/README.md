# Rifle Ready Idle ActionsStyle v004 — shoulders and head connected

**Pending Blender review,2026-10-17.** The user likes the current style and requests both shoulders closer to the body and the floating-head gap removed. This refines the SAME v004, without new Actions, entries, rigs or meshes. The prior complete source/reviews and unsaved native session are preserved under the `upper_body_attachment_revision_20261017` experiment. Approved v003 and every other Action remain unchanged. No Godot integration.

Open the existing `blender/animation/showcase/Animation_Showcase.blend` → Animation Library → `Rifle_Ready_Idle_ActionsStyle_v004`. Rifle Stylized V2 remains visible. Side view is selected. Space plays/pauses. F1–324 at30FPS, closing325 excluded,10.8second seamless loop.

## Current corrections

- Both shoulders: the entire holding assembly moves30mm up and20mm toward the torso in the animated Chest frame (36.1mm total). The20mm inward movement cancels the prior forward seating spacer. Right-arm and rifle orientation/curves remain exact; this retains the accepted10° arm tuck and overall ready direction. Distances from both shoulder roots to their native body sockets improve34.6–36.0mm throughout649independent samples.
- Left support: the straight arm pivots about the support palm toward the closest reachable socket, with6mm of medial socket seating. Palm position/trajectory relative to the rifle is preserved. Both arms remain straight; no elbows, arm stretching or scale is introduced.
- Head/neck: remove the fixed25mm world-vertical clearance lift added in v003's rig adaptation. The head-base pivot now coincides with the animated torso-top pivot to within0.001mm. Head/neck rotations, observation pauses, source key times and head-follow behavior remain exact. The head rotates at its body attachment instead of hovering above it.

The rifle necessarily follows the holding assembly by36.1mm; its in-hand placement is unchanged. Right grip is rigid and the left support's original0.9/1.8s breathing micro-motion remains exact relative to the rifle. Torso/root/hip/leg world motion and F-curves are unchanged. The prior18mm base drop and10° tuck remain historical stages of the current pose; the latest30mm rise is relative to the previous delivered v004, not a new rest rig.

## Explicit joint seating

Rigid cubes meeting at an articulated joint need bounded overlap when rotated. Keeping the head's original source angles while attaching its base produces up to28.48mm of corner seating at head/chest. This is intentional collar contact, with a30mm absolute guard; it is not an unreported head-angle edit. Right upper-arm/chest seating is bounded at55mm (measured52.3mm), versus the original approved35.4mm envelope. This is the user-requested closer shoulder seating. All other existing anatomical limits remain, and all nonadjacent/rifle intersections are still forbidden. Forearms do not enter the torso, head does not intersect either arm/rifle, and original mesh/rest/weights/proportions are unchanged.

These new bounds apply only to this current attachment refinement. Earlier source and Ready studies retain their original limits. The previous strict clearance-only Head/Chest rule represented the hovering adapter that the user explicitly asked to remove. The independent test also requires head-base attachment, both shoulder distance improvements, original angles, weapon-contact preservation and unchanged core motion; passing a collision envelope alone is insufficient.

## Current reviews and validation

`attachment_rear_three_quarter.png` also shows the current shoulder/neck connection from the rear, matching the second user screenshot direction.

- `comparison_v004_attachment_before_after_30fps.mp4`: previous v004 left, current connected shoulders/head right, same side camera/original speed.
- `comparison_v003_left_v004_right_30fps.mp4`: approved v003 versus current v004, three-quarter view.
- `rifle_ready_idle_side_30fps_1x.mp4`, `rifle_ready_idle_three_quarter_30fps_1x.mp4`, `rifle_ready_idle_front_30fps_1x.mp4`: current original-speed views.
- `upper_body_build_validation.json`/`build_validation.json`: current build. `refinement_validation.json`: independent649-pose attachment/contacts/unaffected-motion comparison. `motion_validation.json`:649-pose joint envelopes, nonadjacent collision, rigidity, feet and loop checks.

Earlier shoulder/tuck comparison movies and their named build reports are historical reviews, not the current attachment comparison. Complete delivery backups are also preserved outside Git.

## Preservation, limits and regeneration

Both shoulder roots remain constrained by fixed arm span and the existing rifle grip; this is a closer visible seating adaptation, not a claim that every bone center is fully coincident with its original rest socket. Diagnostic exact-socket fits would require a substantial weapon reorientation and cause torso/forearm/head intersections, so the bounded36mm assembly placement preserves the accepted silhouette and hand contacts.

All82other Showcase Actions/native assets and the same48Action registrations plus2research sequences/15focused selectors/35archived selectors remain. Godot and previous v001/v002/v003 folders stay byte-exact. Prior Pending v004 and unsaved native work: `/Users/tin/Documents/ChatGPT/New project/experiments/rifle_ready_idle_actionsstyle_v004/upper_body_attachment_revision_20261017/`.

Regeneration stages are guarded by input Action hashes: `build_candidate.py` from pinned v003 → `close_hold_revision.py` → `seat_left_shoulder.py` → `attach_upper_body.py`. Back up Pending outputs first; all reject an Approved v004. The final correction cannot be applied twice. Current validators are `validate_upper_body_attachment.py` (takes previous delivered v004 source after `--`) and `validate_upper_body_geometry.py`. Older stage validators remain for historical builds.

Underlying crossbow layers, source clocks and seeded attention remain research-only/nonproduction. See the preserved v003 `REFERENCE.md` for original source files/controllers and adaptation limits. The current placement/attachment adapters do not license the proprietary source-derived motion for commercial use.
