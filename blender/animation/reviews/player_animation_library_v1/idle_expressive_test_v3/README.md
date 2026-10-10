# Idle Expressive v3 — stance and stronger breathing checkpoint

2026-10-11. **Pending user review.** Independent `Idle_Expressive_Test_v3`; v2/v1 and every approved Action/source remain unchanged. This is a Blender artistic study, not Godot production validation.

Open the existing [Animation Showcase](../../../showcase/Animation_Showcase.blend), select **Idle_Expressive_Test_v3** in N → Animation Library, enable Loop and Play. [Authoring source](idle_expressive_v3_review.blend). Playback **1–240 at30FPS**, eight seconds; closing key241 excluded. Same character rest rig, rigid mesh, materials, textures, cameras and lighting.

## Current review

- [Original-speed three-quarter preview](stance_breath_three_quarter_1x.mp4), two eight-second loops.
- [Preserved v2 versus latest v3](comparison_three_quarter_checkpoint_1x.mp4), matching three-quarter camera/lighting and original speed.
- [Front / three-quarter / side stance checkpoint](stance_checkpoint.jpg).
- [Leg closeups](stance_legs_checkpoint.jpg).
- [Saved-source checks](validation.json), [measured stance angles](clean_stance_orientation.json), [Showcase reopen/switch checks](showcase_verification.json), [actual GUI playback](gui_playback.json) and [checkpoint preservation audit](checkpoint_verification.json).

This is the quick stance/breath checkpoint requested by “let me review.” Full polished front/side motion and matched v2 comparison videos are deferred for stance-direction review. Obsolete working renders are archived privately; none is presented as the current result. V2 remains directly selectable for comparison in the same Showcase.

## Latest requested adjustments

Latest explicit side-view request: character LEFT slightly forward and RIGHT slightly back (opposed 3.75° whole-leg pitch; latest requested50% increase), both15° outward yaw, as subsequently requested. Unequal mainly sideways opening remains L3°/R8°, with hip bias and torso counterbalance. Twenty-five millimetres of clearance per proximal leg from the original sideways-only base (16mm more than the5° candidate) prevents the yawed rigid blocks intersecting. Fixed lowest sole corners; no invented ankle/knee or flattened boots.

Latest user request doubles breathing amplitude, not speed: 12mm hip/body rise plus 3.6mm rigid chest lift, with doubled breath-only shoulder/head/torso response over the same four-second period. Feet remain fixed; two unequal looks and eight-second loop timing are unchanged.

The latest explicit user feedback increases only the fore/aft whole-leg pitch by50%, from2.5° to3.75° each. Outward yaw is subsequently increased to15° on each leg, sideways angles and2X breathing remain unchanged. The stance opens mainly laterally, rather than a full running stride. Small opposed fore/aft angles now make the legs distinguishable from the side. The support-side pelvis/torso relationship and unequal arms remain. The fixed whole-leg matrices are compensated against body movement; all sole vertices stay stationary. Corner contact is an artistic rigid-block compromise, not anatomical full-flat support.

Both observation moments retain v2 timing: first head-led look begins F25, observes F49–75, returns by F104; second begins F125, observes F146–164, returns by F194. Body/arms settle by F218. Quiet rest spans the seamless boundary. World head yaw remains approximately +25.7°/−23.3°. No facial controls or blink were invented.

**Evaluation:** doubled slow rise/settle and chest/shoulder response make breathing more readable without increasing its frequency. Unequal lateral angles, a small left-forward/right-back relationship and restrained outward rotation address the latest pose request. Artistically this remains Pending. Rigid corner contacts and future stance entry/exit need gameplay evaluation; static support checks cannot prove natural crossfades into a moving gait.

## Validation and safety

Dense saved-source validation samples3,841 poses at1/16-frame intervals. All sole vertices remain fixed within0.000304mm, minimum floor clearance is0.3998mm, cuboid dimensions remain unchanged and no sampled nonadjacent blocks intersect. Closing pose error is zero; channel tangent mismatch is4.6e-9 and the finite vertex velocity difference across the seam is0.172mm/s at a1/16-frame interval. Original ten Action signatures, v2 evaluated geometry, rest bones, skin weights, UVs, materials, packed images and lights match preserved baselines. The current library has eleven independent entries, with v3 still Pending.

The checkpoint Showcase verifier checks every entry and16 transitions, comparing first/middle/last saved-source geometry samples after each switch, including v2/v3 and the partial arm test. Actual interactive playback is observed across two wraps after reopening, then paused/restarted. The audit checks all6,822 protected original files, including every v2/v1 study, Full Jump and Godot file. Hashes bind each report and media preview to the current saved source/Action.

Backups, working-tree snapshots and concurrent-file hash guards are under `.validation/idle_expressive_test_v3/`, especially `before_outward15_revision`, `before_outward15_registration` and `before_outward15_showcase_save`, preserving the prior2X-breathing candidate and viewer. The initial5° yaw candidate failed upper-leg intersection checks and is preserved in `failed_yaw_clearance`; the latest15° candidate uses25mm proximal clearance per leg from the sideways-only base. Earlier v3 candidates are also archived. Only the current explicitly revised Pending v3 is replaced; all ten earlier central Actions/entries remain exact.

## Future gameplay contract

- Preserve in-place identity root, same rest bones, rotation modes and Blender5.2 slot conventions. Controller physics owns travel.
- Validate support transfer/replant and actual locomotion phase when leaving this asymmetric stance; do not assume a blind crossfade keeps contacts planted.
- Observation/rest must interrupt promptly on input. Check pose AND velocity, both lead directions and both observing phases in Godot.
- Define chest/head/arm masks and weapon grip ownership before layering. Empty-handed Blender review proves no weapon-layer compatibility.
- Blender artistic approval is distinct from Godot gameplay/transition readiness and measured target-phone30FPS. Continue one animation at a time; no Walk, Godot or Full Jump work is authorized here.

## Helpers

`build_test.py` starts from preserved v2 and refuses an existing v3 destination. `validate_test.py` checks the saved source. `render_checkpoint.py` creates the current three-view stills and three-quarter motion with source/Action provenance. `correct_pending_registration.py` / `update_corrected_showcase.py` update only the explicitly revised Pending v3 under backups and concurrent hash guards. `verify_showcase.py -- checkpoint` selects the documented representative geometry scope; `verify_gui_playback.py` observes interactive playback. Full-render helpers remain available for the later polished review package.
