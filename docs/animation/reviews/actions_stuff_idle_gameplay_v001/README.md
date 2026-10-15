# Approved Actions & Stuff Idle — existing research gameplay

User approved `Idle_ActionsStuff_Source_Test_v001` on2026-10-15. The same saved Animation Showcase records Approved;79Action and all native asset fingerprints are unchanged. Authoring source `.blend`, other entries/review statuses and immutable accepted gameplay baseline are preserved.

The existing `res://scenes/dev/ActionsStuffWalkRunTest.tscn` now composes the actual approved `tculwn/jcyjaa` source gesture over accepted Walk/Run/directional channels. Source240Hz decisions/clock,4.2083s authored Catmull clip, .2s outgoing fade and .35s rearm are retained. Existing lifetime bob/holding/look are evaluated once. Exact source translations/rotations and identity scales of this gesture are sampled before the single pose writer; existing grounded contact/inertial handoff remains the native rig's gameplay adaptation. No extra breathing, blinking, keyframe variant or recorded9s sequence playback.

Movement intent interrupts LookAround on its first physics tick, including blocked WASD and standing Jump; source exit fade allows the visible pose to settle while controls respond immediately. Jump/actual landing retain pose ownership, full scales and physics-driven vertical travel. Idle begins again after the source quiet dwell. The optional source RNG is explicitly whitelisted to the ONE approved gesture, with prior movement/attack-free context matching the Blender study; other unapproved autonomous gestures are not introduced. Idle's local ordinary-player profile0 does not mutate accepted ground/jump profile2.

WASD Walk, Shift Run, Space Jump, R Reset and right-drag/wheel camera controls retain existing response/speeds/physics. Camera comfort was separately requested in this same task: independent X/Z tracking, stable normal-jump vertical frame and damped large-elevation follow. See `docs/gameplay/CAMERA_DESIGN.md`; no WorldMap or production camera changes.

## Necessary technical checks

- Source parity:8,286controller samples/542composite poses/119key samples; active native matrix maximum error0.42µm, inactive0.25µm;275accepted directional cases retained.
- Actual scene at30/60physicsHz: source dwell and live gesture, first-tick movement interrupt/fade, Walk/Run, stop-to-Idle and Jump ownership/recovery; feet on floor and no head reset. Max Idle head step9.66°/4.85° respectively.
- Existing Jump/Landing five modes plus reset at30/60Hz pass; unarmed arms2,400samples and directional facing pass. Four literal source regression suites pass.
- Camera synthetic30/60Hz: zero normal-jump vertical movement, large-elevation zone/ground settle, horizontal follow and original angle/distance/size. Native MetalMobile30FPS real input capture also confirms stable camera Y at actual jump peak and entire character/feet visible. Arbitrary production terrain/mobile aspect ratios are future level-specific validation.
- Saved Showcase reopened: Approved and exact Action hash verified. All79Action/native before-after fingerprints match; only the Idle manifest entry's approval metadata changed.

No new project, scene, candidate or artistic gate. Research subtree/exportguard remains excluded from normal commercial export. Play this existing scene usingF6; F5/WorldMap remains unchanged. Immutable pre-Idle accepted baseline stays at `docs/animation/baselines/actions_stuff_gameplay_accepted_v001`.
