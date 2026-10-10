# Idle Expressive v3 — stance, breathing and expressive look-around checkpoint

2026-10-11. **Pending user review.** Independent `Idle_Expressive_Test_v3`; v2/v1 and every approved Action/source remain unchanged. This is a Blender artistic study, not Godot production validation.

Open the existing [Animation Showcase](../../../showcase/Animation_Showcase.blend), select **Idle_Expressive_Test_v3** in N → Animation Library, enable Loop and Play. [Authoring source](idle_expressive_v3_review.blend). Playback **1–240 at30FPS**, eight seconds; closing key241 excluded. Same character rest rig, rigid mesh, materials, textures, cameras and lighting.

## Current review

- [Original-speed three-quarter preview](stance_breath_three_quarter_1x.mp4), two eight-second loops.
- [Preserved v2 versus latest v3](comparison_three_quarter_checkpoint_1x.mp4), matching three-quarter camera/lighting and original speed.
- [Front / three-quarter / side stance checkpoint](stance_checkpoint.jpg).
- [Leg closeups](stance_legs_checkpoint.jpg).
- [Both stronger looks: front / three-quarter / side](lookaround_three_views.jpg).
- [Saved-source checks](validation.json), [measured stance angles](clean_stance_orientation.json), [Showcase reopen/switch checks](showcase_verification.json), [actual GUI playback](gui_playback.json) and [checkpoint preservation audit](checkpoint_verification.json).

This is the quick stance/breath checkpoint requested by “let me review.” Full polished front/side motion and matched v2 comparison videos are deferred for stance-direction review. Obsolete working renders are archived privately; none is presented as the current result. V2 remains directly selectable for comparison in the same Showcase.

## Latest requested adjustments

Additional user steering adds restrained up/down head attention only while facing forward: a5° upward glance and4° chin dip in the shorter center interval, then a gentler4°/3° pair in the later rest. Returns are smooth and the seam remains quiet; side-look range/speed, breathing, legs and rig are preserved.

Latest middle-pause correction halves the straight-ahead interval between looks from60.5 to30.25frames (about2.02 to1.01seconds), moving the second look30.25frames earlier without changing turn speed/range, four-second breathing, leg stance or eight-second loop. Quiet rest across the seam remains.

Latest explicit side-view request: character LEFT slightly forward and RIGHT slightly back (opposed 3.75° whole-leg pitch; latest requested50% increase), both15° outward yaw, as subsequently requested. Unequal mainly sideways opening remains L3°/R8°, with hip bias and torso counterbalance. Twenty-five millimetres of clearance per proximal leg from the original sideways-only base (16mm more than the5° candidate) prevents the yawed rigid blocks intersecting. Fixed lowest sole corners; no invented ankle/knee or flattened boots.

Latest user request doubles the current breathing again to4X original amplitude, not speed:24mm hip/body rise plus7.2mm rigid chest lift, with doubled breath-only shoulder/head/torso response over the same four-second period. Feet remain fixed. Latest look-around refinement doubles the attention-driven head/arm gesture range and doubles gesture speed, with delayed torso/shoulder support. The two unequal looks remain separated by calm rests; slow four-second breathing and the current planted leg pose are unchanged. Eight-second loop timing is preserved.

The latest explicit user feedback increases only the fore/aft whole-leg pitch by50%, from2.5° to3.75° each. Outward yaw is subsequently increased to15° on each leg, sideways angles remain unchanged; breathing is subsequently doubled again to4X original amplitude. The stance opens mainly laterally, rather than a full running stride. Small opposed fore/aft angles now make the legs distinguishable from the side. The support-side pelvis/torso relationship and unequal arms remain. The fixed whole-leg matrices are compensated against body movement; all sole vertices stay stationary. Corner contact is an artistic rigid-block compromise, not anatomical full-flat support.

Latest user request doubles the attention-driven head and arm gesture range and halves gesture durations. First head-led look begins F25, observes F37–50, returns by F64.5; second begins F94.75, observes F105.25–114.25, returns by F129.25. Body/arms follow independently and settle by F141.25. Calm rest gaps and the eight-second loop remain. Target head yaw is approximately +51.7°/−46.3°. Torso/shoulder attention follows the larger gesture; the slow four-second breathing and fixed legs are unchanged. No facial controls or blink were invented. A 4.5mm outward right-shoulder pose offset preserves head/arm clearance during the stronger breath; rest bones and geometry are unchanged.

**Evaluation:** the larger, quicker head-led looks and delayed hands make attention easier to read, while the shorter center pause keeps the two observations connected. The twice-doubled slow rise/settle and chest/shoulder response make breathing more readable without increasing its frequency. Unequal lateral angles, a small left-forward/right-back relationship and restrained outward rotation address the latest pose request. Artistically this remains Pending. Rigid corner contacts and future stance entry/exit need gameplay evaluation; static support checks cannot prove natural crossfades into a moving gait.

## Validation and safety

Dense saved-source validation samples3,841 poses at1/16-frame intervals. All sole vertices remain fixed within0.000302mm, minimum floor clearance is0.3998mm, cuboid dimensions remain unchanged and no sampled nonadjacent blocks intersect. Closing pose error is zero; channel tangent mismatch is9.2e-09 and the finite vertex velocity difference across the seam is0.298mm/s at a1/16-frame interval. Original ten Action signatures, v2 evaluated geometry, rest bones, skin weights, UVs, materials, packed images and lights match preserved baselines. The current library has eleven independent entries, with v3 still Pending. [Gesture refinement checks](lookaround_refinement_verification.json) confirm2X attention range and half-duration gestures while preserving prior leg matrices and breathing curves.

The checkpoint Showcase verifier checks every entry and16 transitions, comparing first/middle/last saved-source geometry samples after each switch, including v2/v3 and the partial arm test. Actual interactive playback is observed across two wraps after reopening, then paused/restarted. The audit checks all6,822 protected original files, including every v2/v1 study, Full Jump and Godot file. Hashes bind each report and media preview to the current saved source/Action.

Backups, working-tree snapshots and concurrent-file hash guards are under `.validation/idle_expressive_test_v3/`, especially `before_short_center_revision`, `before_short_center_registration` and `before_short_center_showcase_save`, preserving the previous passing2X-look version and matching registered viewer. The initial5° yaw candidate failed upper-leg intersection checks and is preserved in `failed_yaw_clearance`; the latest15° candidate uses25mm proximal clearance per leg from the sideways-only base. Earlier v3 candidates are also archived. Only the current explicitly revised Pending v3 is replaced; all ten earlier central Actions/entries remain exact.

## Future gameplay contract

- Preserve in-place identity root, same rest bones, rotation modes and Blender5.2 slot conventions. Controller physics owns travel.
- Validate support transfer/replant and actual locomotion phase when leaving this asymmetric stance; do not assume a blind crossfade keeps contacts planted.
- Observation/rest must interrupt promptly on input. Check pose AND velocity, both lead directions and both observing phases in Godot.
- Define chest/head/arm masks and weapon grip ownership before layering. Empty-handed Blender review proves no weapon-layer compatibility.
- Blender artistic approval is distinct from Godot gameplay/transition readiness and measured target-phone30FPS. Continue one animation at a time; no Walk, Godot or Full Jump work is authorized here.

## Helpers

`build_test.py` starts from preserved v2 and refuses an existing v3 destination. `validate_test.py` checks the saved source. `render_checkpoint.py` creates the current three-view stills and three-quarter motion with source/Action provenance. `correct_pending_registration.py` / `update_corrected_showcase.py` update only the explicitly revised Pending v3 under backups and concurrent hash guards. `verify_showcase.py -- checkpoint` selects the documented representative geometry scope; `verify_gui_playback.py` observes interactive playback. Full-render helpers remain available for the later polished review package.
