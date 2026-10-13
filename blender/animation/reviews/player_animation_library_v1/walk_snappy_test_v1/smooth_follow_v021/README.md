# Smoother upper-body follow — v021 — Pending checkpoint

Preserved intermediate refinement of Walk_Snappy_Test_v1. Legs,21-frame cadence/30FPS and1.59936m/s diagnostic travel match v020. Body uses20ms periodic smoothing and5.6ms extra delay; head reacts with25/26ms smoothing. The actual body absorption minimum is72.2ms after receiving; global body excursion stays308.7mm. Actual body RMS vertical velocity is4.8% lower than v020, with reduced acceleration changes. These measurements describe the evaluated animation, not physical certification.

[Three views at original speed](walk_snappy_three_views_1x.mp4), [v020 comparison](previous_vs_bounce_1x.mp4), [source](walk_snappy_review.blend), [motion](motion_validation.json), [comparison](comparison_validation.json), [Showcase validation](showcase_validation.json), [media](media_validation.json).

673 motion samples and512 comparison samples passed: legs preserved within0.000000766 matrix error, no unwanted overlap/floor penetration/support loss. All19 other Actions, rig and approved entries unchanged;110 Showcase checks and GUI playback passed. The second-order velocity seam passes; the legacy first-order estimate remains separately reported. Contact absorption is measured at the actual receiving minimum rather than the old fixed-time sample. No Godot/Running/production work. Source `89b542c8cf7ce137a6f1879428bc838628dd50d05449256c3bd7d518f2126cb2`; Action `fc1b263e845e845408f4c6d374aea9eaedc43270965bec4072f54deab1811d1c`.

User requested another slower/smoother body pass before final review. This checkpoint remains preserved; it does not represent approval.
