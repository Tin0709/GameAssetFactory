# Walk Snappy V028 — motion matching study

2026-10-13. Separate Walk_Snappy_Test_v028, **Pending**. V027 and all older Actions remain unchanged. Blender review only.

## Actual access

The original Walking video was decoded into all304frames at30FPS,246×356,10.133s. The newer Walking recording decoded241frames; Running349frames. Detailed inspection uses every frame of originalF30–50 and consecutive contextF28–91. Running is accessible but is not used to prescribe this Walking Action; no Run Action was created.

The actual V027 Blender source was freshly exported read-only at30FPS in front/three-quarter/side views. SourceSHA256 remains 0ff3dbeff6d101dc87dbe70e6b9eb8ec2de0150d165974f5a88422556b881901; ActionSHA256 remains 8d9d809cc0078f98b1f6b6b43f6a7c8365c70bc11160e9efb9bdaaf42fbd5cb6. This is a rendered-animation comparison, not an assumed pose.

[Decode/source evidence](research/decode_report.json), [consecutiveF28–51](research/original_consecutive_028.jpg), [F48–71](research/original_consecutive_048.jpg), [F68–91](research/original_consecutive_068.jpg), [trackedF30–53](research/tracked_reference_030_053.jpg), [actual V027 motion samples](research/v027_motion_curves.json).

## Phase observations

Primary repeat: F30/1.000s through closingF50/1.667s,20frames. F30/F40/F50 are receiving/contact **candidates**, with at least±1frame uncertainty. The moving front camera does not certify exact sole contact. Our cycles are21frames/0.700s.

| Source frames | Normalized phase | Visible movement | Interpretation / uncertainty |
|---|---:|---|---|
| F30–31 |0–.05| Extended leg remains readable; head/chest begin lowering. | Receiving/weight acceptance candidate. |
| F31–33 |.05–.15| Cap/chest descend quickly; chest low nearF32, cap low intoF33. | Brief compression and head follow-through; not proven3D COM. |
| F33–35 |.15–.25| Brisk upward recovery; legs exchange through compact silhouettes. | Recovery/push/passing cluster; flight duration unknown. |
| F35–39 |.25–.45| Readable upper arc while the next leg extends; arms/item and head tilt keep reacting. | Slower upper travel contrasts with the short exchange. |
| F39–40 |.45–.50| Next extended receiving-like pose. | Placement/reversal candidate; pattern repeatsF40–50. |

The cap proxy drops roughly20pixels overF30–32, remains low intoF33, recovers overF33–35, then changes slowly throughF36–39. Frame spacing has distinct acceleration/deceleration phases. These are screen landmarks, not original keyframes or physical heights.

Raw and background-corrected curves show the same loading/recovery episode. Sparse sequential background optical flow/RANSAC only approximates camera correction. Camera/parallax changes afterF50 are excluded from the primary study. An initial long-baseline tracker drifted; shirt-hem/shoe segmentation mixed occlusion with movement and was rejected. Logo-visibility kinks nearF38/F48 are not acceleration evidence. Landmark uncertainty is about2–4pixels.

Hip/support interpretation uses alternating leg/torso silhouettes, not an inferred original rig. Some cap changes trail chest presentation by about a recorded frame, but rotation/camera effects prevent an exact delay measurement. The reference carries an item; its arm asymmetry should not be copied into our unarmed walk. [Raw/corrected curves](research/reference_v027_motion_curves.png), [phase map/limitations](research/phase_study.json).

## The three biggest differences

| Difference | V027 measured | Reference visible | Focused V028 correction |
|---|---|---|---|
| Body spacing lacks contrast | Periodic hip wave; maximum rise/fall both1.372m/s, crestphase.330. | Short low/recovery episode, then readable upper arc. | Original C2 receiving/load/recovery/upper-arc curve; same150mm height range. |
| Leg exchange is later/stretched | Passing target near.280L/.292R; prolonged vertical arrival. | Compact exchangeF33–35 followed by extended leg. | Monotone swing-only warp brings passing to.250/.750 and then decelerates into extension. |
| Events have separate clocks | Piston crest.243, common-hop.296, body.330 in first half-cycle. | Body recovery and leg exchange cluster before upper travel. | Body, common-hop and piston/passing crests share.250/.750; torso/head reactions follow that schedule. |

V027's56ms loading minimum was already near the observed1–3frame range. V028 uses70ms loading; the correction is **spacing and phase coherence**, not simply making every movement faster.

## One focused implementation

Original quintic Hermite/C2 curves implement receive0/.5, load.10/.60, recover/release.15/.65, passing/crest.25/.75, upper arc through about.33/.83 and placement.43/.93. Body maximum rise becomes2.915m/s while maximum descent remains1.366m/s. Body range stays0.680–0.830m; upper-quarter time is42.5%versus36.3%in V027. These percentages are measured outcomes, not authoring targets.

The swing phase map is strictly monotone (minimum derivative.702L/.503R), with smooth endpoints and unchanged supported horizontal motion. No stepped interpolation or duplicate hold frames were added. Receiving roll follows28ms after contact without stronger side sway; original arm local curves remain exact. Chest pitch responds to body velocity; bounded close head lift and delayed pitch retain restrained follow-through.

Common-hop amplitude stays137.5mm but its release/crest timing changes. Piston lift becomes232.5mm so aligning both crests keeps combined foot clearance near the existing370mm envelope instead of increasing height. Same21frames/30FPS/.7s, closing22excluded,1.59936m/s nominal travel, receivingF1/F11.5,0.27m tracks, in-place root and rigid proportions. Earlier supporting-foot release is intentional; no reference flight percentage is claimed. Godot transition/support validation remains future work.

## Visual comparison

[Three-way original-speed video](three_way_original_speed.mp4) keeps referenceF30–92 uncut at30FPS and both candidates at1×. Different natural cadences cause phase drift. [Reference selected uncut1×](reference_selected_uncut_1x.mp4).

[Three-way phase-synchronized diagnostic](three_way_phase_sync.mp4) repeats the20-frame reference cycle against21-frame model cycles. **Only the reference is retimed to20/21=0.952× for phase synchronization**, explicitly labelled. This is separate from original-speed evidence; recorded camera differences remain at reference repeat boundaries.

Synchronized actual-frame/subframe sheets: [0–.20](synchronized_frames_1.jpg), [.25–.45](synchronized_frames_2.jpg), [.50–.70](synchronized_frames_3.jpg), [.75–.95](synchronized_frames_4.jpg). Fixed model crop/scale approximates the front angle; no per-frame registration hides camera/proportion differences.

[Three-way motion curves](three_way_motion_curves.png) label amplitude-normalized2D cap proxies versus3D head motion. This is a timing diagnostic, not a metric fit score. [V028 front/three-quarter/side1×](v028_three_views_1x.mp4), [V027 front1×](v027_front_1x.mp4), [V027 three-quarter](v027_three_quarter_1x.mp4), [V027 side](v027_side_1x.mp4), [V028 source](walk_snappy_v028_review.blend).

## Evaluation and remaining differences

V028 changes recovery/passing clustering and the upper-arc contrast while preserving pace and body range. The comparison demonstrates those specific changes; **it does not establish an artistic match**.

Reference head/torso presentation remains higher through some receiving silhouettes. Our rigid planted geometry constrains contact hip height to0.730m here. V028's recovery may still feel too abrupt or early; airborne timing remains stylized. Item-carrying arms, clothing, camera perspective and proportions differ. Review the natural-speed video before another targeted change.

## Verification and preservation

673subframe geometry/contact samples and337additional head/chest samples pass. No floor penetration, nonadjacent overlap or unexpected support loss; grounded drift0.00098mm, rigid error0.00023mm, waist gap37.5mm under75mm, head/chest gap4.83mm. Loop pose/tangents and second-order seam0.00538m/s pass retained0.006bound. Raw first-order0.01087m/s and legacy pass=False are separately retained.

The existing Showcase has21entries; all20previous Actions/manifest entries including V027 are exact. All21entries/slots/timing/props and inactive reopen pass75checks. GUI play/wrap/pause/restart passes.10H264videos decode693frames at30FPS. No geometry/drift/loop bounds relaxed; an unpublished56-micrometre crest overshoot was corrected by enforcing the amplitude envelope.

Godot, approved Walk/Run/Ready, paused Rifle Idle, Weapon Showcase, rig and earlier files are unchanged. SourceSHA256 2da9e6335be107568e9696fa39fd68d1516083f42bccade44f247bc5823329b8; V028ActionSHA256 e02b38c6f560300c2869aedd18e6a0a2eb9a000796b9498c041d75355b5b9deb.

[Motion](motion_validation.json), [timing](timing_validation.json), [head/phase](phase_review.json), [Showcase](showcase_validation.json), [registration](registration.json), [GUI](gui_playback.json), [appearance](appearance_validation.json), [media](media_validation.json), [preservation](preservation.json), [design](design.json).

**Pending artistic review. Stop here; no gameplay replacement or Run Action.**
