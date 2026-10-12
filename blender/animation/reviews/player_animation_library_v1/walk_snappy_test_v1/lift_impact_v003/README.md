# Snappy Walk — whole-leg lift and contact-impact study

2026-10-13 · **Pending.** Focused user-directed mechanics pass on `Walk_Snappy_Test_v1`: high whole-leg recovery, forward placement, strong smooth body compression, clear rebound and alternating torso response. Earlier Snappy sources and media remain unchanged. This is an exaggerated high-step artistic experiment for review, not a production locomotion approval.

## Inspect in the existing Showcase

Reopen [Animation_Showcase.blend](../../../../showcase/Animation_Showcase.blend), then **N → Animation Library → Walk_Snappy_Test_v1**. Same entry, 20 total. Use Front / 3/4 / Side and Play. Reopening is necessary if an older cached copy is still open; Refresh alone does not replace the cached Action. Preserve unrelated unsaved work before reopening.

[Current authoring source](walk_snappy_review.blend) · [Previous researched Snappy review](../research_refinement_v002/README.md) · [Initial Snappy review](../README.md).

## Original-speed review

- [Front](snappy_front_1x.mp4) · [Three-quarter](snappy_three_quarter_1x.mp4) · [Side](snappy_side_1x.mp4)
- [All three views](walk_snappy_three_views_1x.mp4)
- [Previous Snappy vs this lift/impact pass](previous_vs_lift_impact_1x.mp4), both at the unchanged one-second cadence.
- [Approved Walk vs this experiment](approved_vs_snappy_1x.mp4), each at original speed.

## What changed

Each unchanged rigid leg lifts in a high forward arc from the hip. It then lowers into the next receiving step; the other leg repeats. The strongest lift is 88° LEFT / 86° RIGHT relative to vertical. At the measured peak, the lowest sole corner is 0.565 m LEFT / 0.541 m RIGHT above the ground, about 31% / 30% of the character's maximum 1.812 m height. The higher edge reaches 0.790 / 0.766 m. This approximates the user's belly-height / one-third-body target while retaining a whole straight leg. It is a rotating hip arc, not a bent knee or a disconnected vertically translated block.

Receiving now lowers the body **110 mm in 80 ms**, compared with the previous much smaller dip. The full body-height range is **130 mm**, versus 35 mm previously. The downward load is fast and eased, followed by a longer, firm continuous rise into the next leg recovery. There is no extra airborne body bounce or mesh scaling. The low/high snapshots supplied by the user guide the artistic contrast; these numerical values are our own design, not measurements of their images.

The torso follows the lifted side with a delayed backward response and alternating counter-rotation. The added maximum local pitch response is 6° across Spine/Chest, yaw 4° and lateral balance 2.2°, distributed between those bones and delayed 25 ms. These are additions to the existing small torso curves, not exact net world angles. One side draws back as its leg advances, then the motion changes sides. The existing arm swing timing/amplitude remains; a 6 mm outward shoulder clearance offset prevents the stabilized square head clipping the arm during the new torso turn. Both full arms remain straight.

The gait still uses F1–30 at 30 FPS, one second per cycle, closing F31 excluded. LEFT contact is F1 / phase 0; RIGHT F16 / phase 0.5. Compression minima are F3.4 / F18.4. Peak raised soles occur near F11.41 RIGHT and F26.16 LEFT. A repeating cycle starts at a receiving pose; a separate neutral-to-first-step startup animation was not authored in this focused pass.

Contact tracks remain 0.27 m apart; hip lateral / fore-aft ranges remain 30 / 40 mm. Support duty remains 64% / 66%, with 30% total double support and no unsupported phase. Nominal virtual travel remains 1.02 m/s. Root/object stay in place, facing −Y. No cadence or gameplay speed increase was made.

## Evaluation and limits

The much higher recovery and deeper contact dip make the lower-body rhythm unmistakable. Passing, high lift and receiving now contrast strongly. With rigid full legs, the extreme side silhouette approaches a high-step/marching motion; review that amplitude before treating it as a final natural walk. This pass intentionally prioritizes the user's requested leg/body mechanics. The existing upper-body personality is retained with the requested support-linked torso response.

The contact solver retains the original supporting-edge placement. During recovery, the rigid sole envelope is checked through the high arc, with smooth swing-only clearance compensation. This fixes the intermediate floor penetration caused by blending through a near-vertical leg. Hip rise is bounded so the supporting leg remains covered at the waist; no limb is stretched and no rest rig or mesh is rebuilt.

[Motion validation](motion_validation.json) covers 961 subframe samples. Rigid lengths, straight arms, static root, rest transforms, no unwanted nonadjacent overlaps, waist coverage, ground support, loop pose/tangent continuity and camera framing pass the existing tolerances. Maximum supporting-edge drift is 0.00217 mm at nominal virtual travel; minimum sole/floor clearance across the motion is 0.128 mm. Maximum pose-only leg translation is 131.11 mm. The rigid sole rocks around a supporting edge: this is not full-sole flat contact or a guarantee against sliding under arbitrary speed, turns, terrain or runtime blending.

The seam has zero pose error; finite vertex-velocity difference is 0.00546 m/s using a 0.01-frame interval, below the unchanged 0.006 m/s guard. Matching boundary tangent difference is 0.00000128. High lift and strong compression increase acceleration elsewhere in the cycle; their artistic suitability remains Pending. The existing shared receiving phases are retained for future Walk/Run blending, but this exaggerated action needs its own actual Godot transition testing before use. No new engine/export validation is claimed.

[Showcase checks](showcase_validation.json), [GUI playback](gui_playback.json), [appearance checks](appearance_validation.json), [media checks](media_validation.json) and [preservation audit](preservation.json) record the completed review checks. All 19 other Actions and their manifest entries remain exact, including approved Walk/Run/Idle and the paused Rifle Ready Idle. Earlier sources and comparison videos are retained. The central Showcase and manifest update only this Pending entry; progress records describe the change. Backups are under `.validation/walk_lift_impact_v1/before/`.

No Running Action, rifle refinement, Godot or production gameplay changes. Stop here for the next Walking review.
