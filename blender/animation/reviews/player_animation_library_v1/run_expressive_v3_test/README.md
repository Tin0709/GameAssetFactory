# Run Expressive v3 comparison refinement

**Pending user review — 2026-10-12.** Separate `Run_Expressive_v3_Test`; the complete previous `Run_Expressive_v2_Test` source, Action, reviews and Showcase entry remain unchanged. No new approval is implied.

This refinement makes the cadence **10% faster** and increases straight-arm forward/backward swing excursion **20%**. The existing close leg tracks, support logic, diagonal waist response, controlled sideways balance and restrained head motion are preserved at the same normalized gait phase. Larger arm arcs add energy without widening the legs or increasing torso wobble.

| Property | Preserved Run v2 | New Run v3 |
| --- | --- | --- |
| Playback at 30 FPS | 1–22; closing 23 excluded | 1–20; closing 21 excluded |
| Cycle duration | 0.7333 seconds | 0.6667 seconds |
| Whole-arm pitch excursion | Left 78° / Right 84° | Left 93.6° / Right 100.8° |
| Foot-track spacing | 0.27 m | 0.27 m |
| Hip lateral / fore-aft / vertical range | 26 / 50 / 43 mm | 26 / 50 / 43 mm |
| Receiving contact LEFT / RIGHT | F1 / F12 | F1 / F11 |
| Nominal matching controller speed | 2.10 m/s | 2.31 m/s |
| Support duty LEFT / RIGHT | 42% / 43% | 42% / 43% |
| Total flight | 15% | 15% |

The source inspection found v2's saved toe angles are **3° left / 5° right**, although earlier summary prose described both as 3°. V3 preserves the actual saved angles, with no outward-stance change. Both full arms stay straight. Forearms, rig, rest transforms, body proportions, materials, UVs and textures remain untouched.

## Review

- [Original-speed front / three-quarter / side](run_v3_three_views_1x.mp4)
- [Preserved v2 vs new v3 — matching three-quarter camera, original speed](run_v2_vs_run_v3_1x.mp4)
- [Front](run_v3_front_1x.mp4), [three-quarter](run_v3_three_quarter_1x.mp4), [side](run_v3_side_1x.mp4)
- [Temporary nominal-speed contact travel](run_v3_contact_travel_1x.mp4)
- [Three-view pose sheet](run_v3_pose_sheet.jpg)
- [Saved authoring source](run_expressive_v3_review.blend)

Each review uses unchanged v2/approved Walk cameras, lighting and character appearance. The comparison plays each native cycle at 30 FPS: ten v2 cycles and eleven v3 cycles over 220 frames. No video speed alteration is used. Closing keys are excluded from playback.

## Gameplay and support contract

The reusable Action remains in-place with identity root/object transforms. Controller travel owns forward −Y displacement. Its matching nominal speed rises to 2.31 m/s because cadence increases while stride distance stays 1.54 m. Temporary grid/travel exists only in the render process and is never saved or registered as a character Action.

Normalized phase 0 is LEFT receiving contact, phase 0.5 RIGHT. Match Walk F1/F19, Run v2 F1/F12 and Run v3 F1/F11. V3 releases LEFT at F9.4 and RIGHT at F19.6; flight lasts until the next receiving contact at F11/F21. Source rig, original `OBRUN_Test_Rig` Action slot, transform modes and independent Action structure are retained.

Future Godot integration still needs contact-aware phase/speed blending, velocity continuity during speed changes, both lead-foot interruptions, idle replant, slopes/turns, weapon-layer masks and measured 30 FPS mobile testing. Blender review does not establish production readiness. Rigid full legs still roll between sole edges rather than articulate nonexistent knees or ankles; test that behavior against gameplay terrain.

## Validation and preservation

- [Saved-source dense contact, floor, rigidity, intersection, loop and asset checks](validation.json)
- [441-phase comparison: unchanged non-arm matrices and 20% arm excursion](refinement_comparison.json)
- [Fresh Showcase reopen, all fourteen Actions, slots/ranges and geometry switching](showcase_verification.json)
- [Actual GUI looping, pause and restart](gui_playback.json)
- [Source-bound renders](render_provenance.json), [original-speed packaging](package_provenance.json), [decoded videos](media_verification.json)
- [Final preservation audit](final_verification.json)

Backups of current source, central Showcase, manifest and workflow documentation are in `.validation/run_expressive_v3_test/`; registration also uses the existing central backup workflow. The earlier rebaked working candidate is preserved there. Final lower-body tracks retain v2's original curve values/handles with time coordinates retimed; this avoids unnecessary contact-gate resampling. Only upper-arm rotation curves introduce new posing.

Select `Run_Expressive_v3_Test` in the **same existing** `blender/animation/showcase/Animation_Showcase.blend`. V2 remains selectable immediately above it for comparison. All thirteen previous entries and their approval statuses remain unchanged. No Godot, export, rig rebuild, Idle/Walk or Full Jump change.
