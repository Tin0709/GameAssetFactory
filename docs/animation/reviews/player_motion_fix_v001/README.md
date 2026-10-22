**Later travel-turn refinement:** The constant14rad/s update described below is superseded by [smooth repeated turning](../smooth_travel_turn_v001/README.md). All other fixes remain.

# Player locomotion and secondary motion fix —2026-10-22

Current existing `res://scenes/dev/ActionsStuffWalkRunTest.tscn` only. New defaults temporarily restore original1× travel: Walk1.80m/s, Run5.031m/s. The existing multiplier remains available; no production player, Blender Action, geometry, rig or source data is changed.

## Cause and changes

- The immutable source controller enters Run above0.7 and exits below0.6. Our nominal Walk query converges to0.6103515625, so the literal research state can remain Run forever after sprinting. The rifle gameplay adapter now derives its0.14s Walk/Run blend from actual calibrated travel speed, leaving the literal controller/program intact.
- The shared ground gait cursor now advances by actual distance using the existing Walk/Run stride calibration. It stops with the capsule, preserving phase instead of resetting. Ground phase is shared with the existing jump runtime; source takeoff/landing phase overrides remain authoritative. A small floating-point guard prevents sub-ulp backward ground increments at30FPS.
- A short grounded movement packet under0.18m retains its current contacts instead of triggering the inherited0.44s alternating recovery steps. Longer stops, source idle foot shifts and intentional stationary turning keep their existing path. This removes foot rocking after tiny taps without freezing approved Idle motion.
- Ordinary movement-facing now follows changing travel at14rad/s, replacing4.5rad/s. This reduces the prolonged sideways/reversed body mismatch during repeated WASD inputs. Existing stationary Q/C, E auto-aim0.6s180° pivot and unrestricted Combat Strafe remain on their existing paths. This is a gameplay adaptation, not a newly claimed Actions & Stuff technique or Action.
- Hair/bandana response changes from2× to4× the original gain. Direct same-input comparison against the prior appearance script gives exactly2× hair/tail spring vectors at both30/60FPS. A bounded extra spring moves only existing free crown/roof cards with gait bounce and travel airflow. Fixed cap, wrap/knot, face, head and rig remain unchanged; all secondary motion settles and resets.

## Verification and media

12 new scene checks pass at30/60: Shift release reaches Walk within0.3s, stopped taps advance no phase and keep contact points stable across8directions, and repeated WASD200ms segments retain coherent facing. Late-segment average heading error is~0° Walk/~1.8–2.2° Run; the crown spring peaks~0.269–0.271rad under the probe. These measurements do not establish perfect foot placement for arbitrary inputs or artistic approval.

Ready/Aim (including jump/landing), Fire/Recoil, Combat Strafe, stop/replant and hair/face regressions pass at30/60FPS. Q/C and the0.6s E pivot, full50-zombie stress cleanup and current bullet/death-slide/pass-through checks pass. Existing speed assertions now validate the exposed scene calibration; the new regression pins the temporary1× default. No phone-performance claim is made.

Native Mobile/Metal1280×720 per panel, fixed30FPS, original playback speed:

- [Movement comparison](movement_before_after.mp4):9.2s, same original1× travel in both panels, Walk→Run→Shift release, single-frame taps and repeated WASD Walk/Run.
- [Hair/bandana comparison](hair_before_after.mp4):3s, same running input and close camera. The baseline uses only in-memory prior dev scripts, not modified saved assets. Final close framing is applied in a capture-only pre-draw callback after the gameplay camera; gameplay camera code is unchanged.

Native Shift-release sample: prior run weight1.0 versus current0.0 at the same physical Walk speed. Native frames, controller samples and logs were inspected. Final captures have no renderer/script errors; earlier capture-only crop/cleanup issues were corrected in the helper. Preservation audit is alongside this report. All source-derived assets remain in the dev/research exclusion. Ready for the user's gameplay review.
