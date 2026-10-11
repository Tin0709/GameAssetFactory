# Idle Expressive v3 — directional observation refinement

**Pending user review.** Same `Idle_Expressive_Test_v3` in the permanent [Animation Showcase](../../../showcase/Animation_Showcase.blend). V2/v1 and every earlier Action remain independent and unchanged. Playback **1–240 at30FPS** (eight seconds), closing key241 excluded. In-place, Blender5.2 slot `OBRUN_Test_Rig`.

## Current gaze sequence

Right and left refer to the viewer looking at the character from the FRONT camera. The old center-facing up/down passages have been replaced by deliberate diagonal observations:

| Phase | Frame / timing |
| --- | --- |
| Relaxed forward rest | F1–13 |
| Look viewer-right | Arrive F27, observe toF37 |
| Center pass-through | F53, no hold |
| Top-right | F67–74.5, exactly0.25seconds |
| Bottom-left | F89–96.5, exactly0.25seconds |
| Look viewer-left | F115–125 |
| Center pass-through | F143, no hold |
| Top-right | F157–164.5, exactly0.25seconds |
| Bottom-left | F179–186.5, exactly0.25seconds |
| Smoothly settle to rest | Neutral byF207; quiet seam |

The diagonal world-head yaw is+22°/−22° and pitch−7.6°/+9.4°. Side observations retain the expressive+51.7°/−46.3° range. The center keys keep pitch velocity rather than stopping. Observation holds use subframes:7.5frames at30FPS. Head position follows the breathing body; world gaze orientation stays fixed during each hold, avoiding a perpetual nod. Delayed torso/hip/shoulder/arm reactions support the two side looks. A smooth shoulder pose allowance keeps the tilted solid head corners clear:60mm outside the upward gestures, reduced to30mm during them; resting8/6mm shoulder offsets remain. No facial controls or rig changes were invented.

## Small straight-arm response

The user clarified “above halfway” as limiting the downward drop with a small gesture, not lifting the hands to waist/mid-body height. Both full arms stay straight throughout the loop; forearms retain their rest alignment with no elbow bending. Upward glances use6° whole-arm forward pitch,18°/20° spread and30mm animated shoulder drop instead of the previous60mm. The separate8/6mm resting shoulder offsets remain. Preparation is slightly offset between arms and eases back during the downward gaze. This keeps the relaxed silhouette while avoiding the rejected large hand lift. No rig, dimensions, weights or facial controls change.

## Preserved stance and breathing

Character LEFT slightly forward, RIGHT slightly back (opposed3.75° whole-leg pitch),15° outward yaw each, unequal mainly sideways opening L3°/R8°,25mm proximal clearance per leg and28mm hip support bias. Leg matrices and all sole vertices stay fixed. Rigid angled blocks contact on their lowest corners; no fake knees/ankles, flattened boots or mesh scaling.

The latest stronger breathing stays **48mm hip/body excursion plus14.4mm rigid chest lift**, one slow breath every4seconds. Hip baseline remains36mm lower to keep the waist connected to both planted leg blocks. Breathing is transform-only; body dimensions, rest rig, weights, UVs, textures, materials and lights are unchanged.

## Review

- [Current original-speed preview](stance_breath_three_quarter_1x.mp4), two eight-second loops.
- [Preserved v2 versus current v3](comparison_three_quarter_checkpoint_1x.mp4), matching camera/lighting and original speed.
- [Gaze poses from front / three-quarter / side](lookaround_three_views.jpg).
- [Three-view stance](stance_checkpoint.jpg) and [leg closeups](stance_legs_checkpoint.jpg).
- [Decoded motion samples](checkpoint_motion_samples.jpg).

The video review is a native-rendered three-quarter checkpoint and matching v2 comparison, accompanied by front/side stills. A full updated front/side motion comparison set remains deferred for the ongoing stance review; it is not claimed complete.

**Evaluation:** the gaze now has specific destinations and four short observation beats. Continuous center crossings connect the observations, while the quiet loop rest prevents an endless scanning rhythm. The head no longer repeatedly nods while facing forward, and both arms now remain straight with a small response and limited drop during upward glances. Strong breathing and the established stance remain. The rigid shoulder/head clearance remains an authoring constraint; gameplay and weapon-layer blending are still unvalidated. Artistic approval stays with the user.

## Validation and safety

[Dense saved-source geometry/loop checks](validation.json), [actual gaze/hold/pass-through checks](lookaround_refinement_verification.json), [measured stance](clean_stance_orientation.json), [fresh Showcase switching/reopen checks](showcase_verification.json), [interactive playback](gui_playback.json), [media decoding](checkpoint_media_verification.json) and [preservation audit](checkpoint_verification.json) bind to the current source/Action hashes.

Latest backups are under `.validation/idle_expressive_test_v3/before_straight_arm_revision`, preserving the rejected bent-arm candidate and its registered viewer for safety. The earlier passing directional-gaze study is preserved under `before_upward_hands_revision`. Earlier backups are under `.validation/idle_expressive_test_v3/before_directional_gaze_revision`, including the complete prior study, previous Showcase/manifest and working-tree snapshot. The foreground session is separately preserved. The first diagonal candidate failed head/shoulder clearance and is archived under `directional_gaze_failed_clearance`; it was never registered. Hash guards protect the central file from concurrent edits. Only the user-requested Pending v3 is revised; every earlier library Action/source is retained.

Unchanged native frames may be reused only after matching evaluated geometry, cameras, lighting, world, color/render settings and appearance, with original image hashes verified. Every changed hand-motion frame is rendered anew. [Reuse provenance](unchanged_frame_reuse.json) identifies the exact reused frames. Videos and reports bind to the latest saved Action/source.

## Future gameplay contract

Preserve identity root, rig/rest/slot conventions and in-place ownership. Entering/leaving the asymmetrical stance needs support transfer/replant and locomotion phase checks. Gaze must interrupt promptly on player input. Validate pose AND velocity, both attention directions, foot contacts, upper-body weapon masks and actual Godot transitions in a separately authorized task. Blender review is not production readiness or measured phone30FPS. One animation at a time; no Walk, Godot or Full Jump changes.

## Helpers

`build_test.py` authors from preserved v2, refusing an existing v3 destination. `validate_test.py` checks the saved source; `verify_directional_gaze.py` measures baked head directions, holds and moving center keys. `render_checkpoint.py` / `render_attention_views.py` render source-bound review material. `correct_pending_registration.py` / `update_corrected_showcase.py` update only this explicitly revised Pending v3, with backups and concurrent hash guards. `verify_showcase.py -- checkpoint` checks all entries and representative geometry; `verify_gui_playback.py` observes real playback across two wraps.
