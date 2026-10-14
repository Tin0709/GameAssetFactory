# Snappy Fast + Jump gameplay review — 2026-10-14

Open `game_mobile_3d/scenes/dev/SnappyLocomotionFastJumpTest.tscn` in Godot and press **F6**. This separate test matches the actual current ExpressiveLocomotionTest defaults. Production remains unchanged.

| Setting | Matched value |
|---|---:|
| Walk travel speed | 3.0375 m/s |
| Run travel speed | 5.977875 m/s |
| Existing jump | 2 m height; flight-speed policy 2.15 |
| Camera projection / size | Orthographic / 11.25 |
| Camera relative offset / distance | (12,15,16) m / 25 m |
| Camera rotation degrees | (-36.315886,36.869898,0) |
| Camera far / floor follow smoothing | 72 m / 0.16 s |

The camera remains floor-relative through ordinary jumps, as in the existing test. **4** or **Follow** restores this exact camera after detail views.

Controls: WASD/arrows move; Shift runs; Space jumps; Tab switches Snappy/Expressive; 1/2/3 show front/three-quarter/side detail; 4 returns to original camera; R resets; F9 runs the review demo; F8 toggles 30/60 FPS cap. Mouse buttons provide equivalent review controls. Space is handled before GUI accept so clicking Reset cannot cancel the next jump.

## Original-speed review

- [Snappy gameplay](gameplay_snappy_1x.mp4)
- [Expressive gameplay](gameplay_expressive_1x.mp4)
- [Live A/B toggle](gameplay_style_toggle_1x.mp4)
- [Same-control side-by-side](snappy_vs_expressive_1x.mp4): Snappy left, Expressive right; full unchanged camera framing, no gait retiming.
- [Contact sheet](gameplay_contact_sheet.jpg)

Each movie contains397 frames at30 FPS (13.233 s), from actual Godot Mobile renderer output. Captures run at fixed simulation FPS for reproducibility; they do not establish phone performance. The demo includes running and stationary jumps, stops, reversal and direction changes, with no replay holds. Physics remains60 Hz.

## Implementation and evidence

The existing jump actor, physics and `Full_Jump_Expressive_v2_Test` library are reused. A test-only jump adapter extends the single Snappy pose writer. Runtime sagittal reach follows the existing faster Expressive lab policy; vertical source foot lift and rigid scale remain unchanged. Grounded contact correction uses the existing140 mm limit; stride/release translations share a130 mm budget. Bounded35 mm preparatory/landing clearance prevents the hoppy Walk plus jump preparation from putting a boot through the floor. No new jump Action or rig edits.

[30 FPS report](fast_jump30.json) and [60 FPS report](fast_jump60.json):41 checks pass each on D3D12 Mobile. Both styles jump from Idle, Walk and Run, launch/land once, return to ground, preserve the existing2 m jump, replant stationary feet, reset in flight and accept Space after focused Reset. Exact speed/camera checks pass. Maximum floor penetration is floating-point noise (~0.00000006 m), steady contact clamps0, steady planted-foot speed below0.00002 m/s and rigid-scale error below0.000001. One bounded correction limit is reached during Snappy Walk jump preparation at60 FPS; no floor penetration results. This transition remains an artistic review point, not a claim of perfect smoothness.

## Evaluation

The matched distant camera and quicker travel now reproduce the earlier test's control context. Running reaches100% of its own Action; it is not permanently diluted by Walk. Runtime cadence responds to travel and reach, with persistent gait phase through A/B and contact-aware Walk/Run handoff.

The approved Snappy Walk is unusually hoppy. Source diagnostics show ~166.7 mm hip excursion and53.6% of samples with both soles over2 mm, versus Run's123.0 mm and19.1%. Consequently Run can still read less springy than Walk despite its faster exchange and different source poses. These figures describe our exported Actions, not measured reference physics. Do not alter approved Actions to hide this during gameplay review.

Pending: user assessment of movement feel, fast jump/reversal silhouette and landing timing. Uneven terrain, mobile hardware, weapon blends and production integration are outside this flat-ground review.
