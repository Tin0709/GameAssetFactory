# Smooth repeated travel turning —2026-10-22

The latest user reports stuttering when repeatedly changing direction. This bounded fix changes only ordinary travel-facing in the existing `ActionsStuffWalkRunTest.tscn` rifle adapter. No new scene, project, animation Action, Blender asset or production change.

## Cause and fix

The prior14rad/s clamped yaw follows direction promptly but starts/stops angular velocity abruptly. The60FPS reproduction measures840rad/s² on a Walk90° turn. A damped target alone improved90° turns but could still jump close to full speed on180° reversals, so the final adapter also limits angular acceleration.

Carry one angular-velocity state across input changes: response28/s, maximum14rad/s, acceleration180rad/s²; integrate average previous/current velocity. Wrap target error to the shortest yaw path. Full stop/reset/autoaim clears this state, preventing residual turning after tiny taps and keeping the existing Q/C/E ownership. These numbers are an original gameplay adaptation, not a claim about undocumented Actions & Stuff behavior.

## Verification

- New Walk/Run90° and180° probes pass at30/60FPS, maximum measured angular acceleration~180rad/s², arrival error<0.01rad after1s; rapid cardinal/diagonal alternation keeps ground contact and continuous rigid legs.
- All12 prior motion checks pass both rates: Shift release returns Walk, stopped gait advances zero phase, tiny-tap foot drift<0.000001m. Repeated200msWASD late-segment average heading error~6–7.1° Walk/~26.6–28.3° Run. The smoothing deliberately permits brief body lag; this is not a promise of perfect foot placement under arbitrary input spam.
- Combat Strafe30/60, Fire30 (159shots, no pool misses, zero recovered-pose error), stop/replant30 and held-E turn60 pass. E full180° remains0.600s. Right/left grip errors remain below0.000001m.
- Native Godot4.7.2 Mobile/Metal captures use actual scene physics/presentation at30FPS,1280×720 each,7s at original speed: Walk,90° turn,180° reversal, repeatedWASD Walk/Run. Both use the same1× speed, current appearance and unchanged camera. Prior adapter is selected in memory only; saved source assets are untouched. Native logs are clean. These captures/fixed-rate checks are not phone-performance benchmarks.

[Before/after clip](turn_before_after.mp4) · [180° frame sequence](reverse_contact_sheet.png)

Preserve Walk1.8/Run5.031m/s, current stronger hair/bandana/crown response, approved rifle/pose/recoil/Jump/face,6Hz/infinite E fire, camera, zombie/death settings,50-zombie controls and hidden grass. A SHA audit alongside this report confirms every other pre-existing protected Blender/game file unchanged. Existing source exclusions remain. Implementation is ready for gameplay feel review; no artistic status is promoted.
