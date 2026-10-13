# Smooth piston-leg checkpoint — Pending

Latest user feedback: smoother leg motion like the supplied recording. Preserved v008 bounce timing and every non-leg curve exactly; rebuilt only straight rigid leg transforms.

Fore/aft recovery now follows a C2 continuous path with moving mid-swing guide, instead of stopping at intermediate keys. Lift rises to270mm at40%of swing and eases down continuously; old plateau/steep lowering segments removed. Stance endpoint velocity remains matched to nominal1.279488m/s travel. Swing inward tuck reduced6.5→4mm after detecting a small leg brush;0.27m planted tracks unchanged. No limb scaling/rig edit.

[Flow measurements](leg_flow_validation.json): peak sole-target speed falls23–24% (8.17→6.30m/s LEFT,8.83→6.78RIGHT), peak target acceleration falls57–59% (341→147 /400→166m/s²). Old mid-swing forward speed approached zero; new guide remains moving. These are analytic target diagnostics excluding common hop, not physical center-of-mass measurements. Contact endpoints/stride scale remain; smooth recovery overshoots about20–23mm farther forward than old swing. Peak raised sole pitch stays near0.1deg rather than a rotating kick; maximum whole recovery pitch about36–37deg.

[Front / 3/4 / side at1x](walk_snappy_three_views_1x.mp4), [previous vs smoother legs](previous_vs_leg_flow_1x.mp4), [approved Walk comparison](approved_vs_snappy_1x.mp4), [overhead](snappy_overhead_1x.mp4), [Blender source](walk_snappy_review.blend).

Evaluation: continuous lift/advance/lowering removes the visible stop-and-rush rhythm while retaining crisp receiving poses and upright high recovery. User says the smoother direction is good and next requests a stronger/smoother rebound. Preserve this version as the leg-motion checkpoint; do not promote to production or automatic Approved status.

961subframe checks pass: no floor penetration/unwanted leg overlap/unexpected support loss; grounded drift0.00176mm, rigid error0.00025mm. Same120.5mm hip range,35mm hop/80msrelease/220msreturn,36.25mm soft load,centered step yaw. Same1second loop/30FPS; closing31 excluded. Pose/tangent/second-order velocity seam pass; raw first-order estimator remains separate.110Showcase checks/save/reopen/inactive retention/GUI play/wrap/restart pass,8videos/1440frames decode.19other Actions and entries, all prior sources, approved Walk/Run/Ready, paused Rifle Idle, rig, Weapon Showcase, Godot and production remain exact. Same20-entry central Animation Showcase / same Pending Walk_Snappy_Test_v1. Flight is stylized and runtime contact/blends remain unvalidated.
