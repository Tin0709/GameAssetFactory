# Animation system V2

Original Blender animation revision for the existing player V6 and zombie V2.
All new deliverables are in `blender/animation_v2/`. Production assets, earlier
revisions, weapon geometry, character meshes, UVs and materials are preserved.
No Godot project files were changed.

## Start here

- `blender/animation_v2/review.html`: 18 animated GIF previews and pose-sheet links.
- `player_animation_v2.blend`: modular player action library.
- `player_review_v2.blend`: same library plus explicitly named `REVIEW_*`
  composites, for inspection rather than export.
- `zombie_animation_v2.blend`: two revised zombie loops.
- `zombie_crowd_review.blend`: five instances sharing one mesh and action,
  with distinct deterministic phase/rate offsets; play frames 1–144.
- `REFERENCE_STUDY.md`: bounded local reference inspection and provenance.

In Blender's Action Editor, select the character armature and choose an action.
For a `REVIEW_Pistol_*`, `REVIEW_M4A1_*` or `REVIEW_Shotgun_*` action, enable only
its matching `*_Review` collection in the viewport and render. Those collections
start hidden. Standalone recoil actions are deltas, not absolute poses: inspect
the corresponding `REVIEW_*_Fire` action to see the composed result.
Library files open on Walk. Loops play frames 1 through N, with the identical
closing key at N+1. Do not play both closing and opening keys as separate ticks.

## Reference findings and independent design

Study was limited to `player.jem` inside the supplied Fresh Moves archive and
EMF animation infrastructure signatures/registry symbols. Fresh Moves separates
movement inputs, state gates, and per-part transforms; speed, phase, breathing
and sprint state influence multiple parts rather than a single mirrored swing.
EMF exposes entity/context variables, forward/strafe movement, limb speed/swing,
frame timing, model-part evaluation, validation and easing facilities.

We adopt these general principles: separate phase from speed, ease state
weights, use different timing for hips/chest/head/arms, layer weapon control,
and vary crowd phase. We do not claim to reproduce the pack's visible motion.
No reference formulas, expression bodies, implementation code, keyframes or
assets are present in the authoring scripts or deliverables. Our curves use
project dimensions, original amplitude/timing choices, cubic transitions and
an offline geometric reach calculation.

## Original architecture

The original ten-bone hierarchy and rest transforms remain intact. Player gains
one **non-deforming WeaponSocket** under Chest; zombie remains ten bones.
Both characters retain six cuboids, each rigidly weighted to one bone. There
are no elbow/knee bones, bending, animated scales, runtime IK or physics.

The action library contains 15 small actions: three base loops, six calibrated
weapon poses, three raise transitions and three recoil deltas. Shotgun has two
calibrated poses and a raise transition because its existing support marker is
different from the rifle's. It shares the long-gun architecture, not duplicated
full-body gait actions. Sixteen full-body demonstrations live only in the review
file and are excluded from the intended runtime library.

| Layer | Actions | Duration / use |
|---|---|---|
| Base | Player_Idle | 3.00 s loop |
| Base | Player_Walk | 1.20 s loop; nominal 0.7833 m/s |
| Base | Player_Run | 0.80 s loop; nominal 2.00 m/s |
| Weapon override | Pistol_LowReady, Pistol_Aim | Held poses |
| Weapon override | LongGun_LowReady, LongGun_Aim | M4A1 calibration |
| Weapon override | Shotgun_LowReady, Shotgun_Aim | Same concept, pump support calibration |
| Transition | Pistol_Raise, LongGun_Raise, Shotgun_Raise | 0.133 s; reverse for lowering |
| Additive | Pistol_Recoil | 0.233 s; fast rise and return |
| Additive | Rifle_Recoil | 0.167 s; small controlled kick |
| Additive | Shotgun_Recoil | 0.433 s; stronger reaction, slower recovery |
| Zombie base | Zombie_Idle, Zombie_Walk | 3.00 / 1.60 s loops |

All actions use 30 FPS authoring with linear transform interpolation between
closely sampled original curves. They are ordinary skeletal keys. No frame
handlers, drivers or contact-solving constraints are needed for playback.
Review weapon objects use one Copy Transforms constraint to follow the socket.

## Player movement

Idle has 4.5 mm weight shift, breathing translation, tiny hip rotation, torso
counter-motion, stabilized head orientation and delayed whole-arm drift. Feet
remain planted. Breathing never scales the body.

Walk adds controlled hip side shift/yaw, torso counter-yaw, a contact-travel
stance segment, returning swing with matching horizontal tangent, modest body
bob, and 45 mm peak swing lift. Arms lag the legs by about 5.5% of a cycle;
the right swing has slightly lower amplitude. Head orientation is stabilized
independently of the chest. Whole-leg translations maintain floor clearance.

Run increases authored stride travel to 0.8 m per step, whole-arm swing to
42 degrees, swing lift to 75 mm, and chest lean to roughly 10.5 degrees, with
hip/chest counter-rotation and a short flight crest. Nominal gait speed is a
calibration value, not a forced gameplay speed; runtime phase rate must track
actual movement. The transition demonstration integrates one continuous phase
through idle/walk/run/walk/idle, with 0.13 s state ramps.

Rigid flat feet visibly roll between corners. This is stylized rigid locomotion,
not an anatomical foot roll or a guarantee of perfect contact on uneven terrain.
The root is stationary in library loops; actual travel belongs to gameplay.

## Weapon contacts and poses

All three V4 weapon meshes are appended unchanged into the new review/library
files. Their existing Grip_Point, Support_Hand_Point and Muzzle_Point transforms
are preserved in weapon-local space. The pistol already had a support marker
34 mm forward of its grip; no pistol asset or export metadata change was needed.
The shotgun retains its separate pump mesh, with its support marker on the pump.

The right arm controls Grip_Point. The left arm meets Support_Hand_Point. A
contact center 70 mm inward from each rigid arm's end lies inside its painted
hand region. Our authoring-only sphere-intersection calculation rotates the
whole fixed-length arms to these contacts. No arm resizing or hidden elbow is
used. The resulting crossed-body posture is deliberately stylized; the large
cuboid hands obscure some receiver detail. Side and three-quarter sheets are
provided for judging this tradeoff.

Low-ready uses a modestly depressed muzzle and lower grip. Aim raises the grip
toward upper chest/face level while keeping the face visible. Long guns use a
small lateral angle to fit the fixed arm reach and keep the stock near the
body. Running review poses lower the grip by 42 mm and add restrained delayed
bob. Walking adds smaller secondary motion. Grip transforms and both arms are
transported together through the chest, preserving alignment.

The modular pose mask is **Arm.L, Arm.R, WeaponSocket**. Leave hips/legs and
base torso counter-motion outside this mask. The short authored Raise clips
keep both contacts together more accurately than a naive linear interpolation
of two unrelated arm poses.

## Recoil and future pump cycle

Recoil clips contain **local translation/Euler deltas from the matching Aim
pose**, including chest response and socket/arm changes. Each starts and ends
at zero. Rifle recoil has a 7 mm rearward chest reaction and small muzzle rise;
pistol uses 12 mm; shotgun uses 32 mm and greater rise with longer recovery.
The rifle firing demonstration repeats small impulses during an automatic burst.

These are Blender delta channels, **not verified Godot-ready additive exports**.
Before Godot import, convert rotational differences to local quaternion deltas
against the documented reference pose, or evaluate equivalent runtime offsets.
Do not import an Euler difference as an absolute quaternion pose. Trigger recoil
on shot events; do not restart a locomotion action. At high rifle fire rates,
accumulate a bounded impulse and recover continuously instead of hard-resetting
an active one-shot. Apply recoil after target orientation and weapon stance.

Shotgun pump motion remains reserved for a separate weapon-local action and
support-hand calibration. No reload system or animated pump cycle is implemented.

## Runtime contract and Godot plan

| Parameter | Meaning / intended range |
|---|---|
| normalized_speed | Clamped movement magnitude, 0–1; filtered independently of phase |
| locomotion_phase | Persistent 0–1 stride phase; integrate from traveled distance/rate |
| local_forward, local_strafe | Signed velocity in the lower-body facing basis |
| acceleration | Filtered local acceleration; small extra chest lean and weapon lag |
| turn_rate | Signed angular velocity; bounded hip/torso/head overlap |
| has_target | Valid target state, with short hysteresis to avoid stance flicker |
| is_firing | Combat state; actual shot events drive recoil impulses |
| weapon_type | Unarmed, Pistol, M4A1, Shotgun |
| recoil_amount | Bounded impulse envelope; independent of phase |
| entity_seed | Stable spawn seed for phase, rate and tiny amplitude variation |

Planned AnimationTree order:

1. Base idle/walk/run BlendSpace1D, with synchronized walk/run phase and
   0.10–0.16 s speed-weight changes. Suggested starting value: 0.13 s.
2. Directional lower-body adjustment using local velocity. Rotate the hip/leg
   stride plane toward velocity; keep torso target orientation independent.
   For backward travel reverse the travel direction; for strafe rotate the
   stride plane toward lateral velocity. Diagonals use the same continuous
   direction, not eight duplicated full-body clips.
3. Select calibrated weapon poses and smoothly traverse ready/aim over
   0.08–0.15 s; use the authored 0.133 s Raise when fixed contacts matter.
   Filter the override to the two arms and socket. Preserve chest gait below it.
4. Target yaw/pitch: rotate the chest and carried system together, then apply
   bounded head stabilization. Root/lower body must not be forcibly aligned to
   target or movement while firing. Limit torso twist and gradually turn hips
   when outside a comfortable range, without snapping the weapon.
5. Apply recoil as a correctly converted additive layer/OneShot or a bounded
   procedural impulse. Then add small acceleration, turn and weapon lag offsets.

Direction control, target solving, acceleration response, phase synchronization,
real shot events and state hysteresis are **planned runtime work**, not integrated
or gameplay-validated here. Directional support is architectural; there are no
baked strafe/backward clips. Never call play/seek from scratch every frame. Keep
one phase accumulator across small speed changes and initialize clip time only
on an actual transition that requires it. Use shortest-path angular interpolation.

For the player, a small closed-form reach adjustment can accompany procedural
weapon changes if required, with cached vectors and no per-frame allocations.
Most normal locomotion/stance combinations already preserve both contacts
through the shared chest transform. Do not run multi-joint IK for crowds.

## Zombie polish and variation

Zombie_Idle/Walk retain forward raised arms and straight legs. They add hunch,
19 mm walking hip drift, shoulder roll, counter-yaw, partly stabilized delayed
head wobble, and independent raised-arm drift. Left/right contact duty differs
slightly (56% / 53%) for an uneven shamble; all limb shapes remain rigid.

The crowd review uses five phase offsets (0, .19, .43, .67, .84) and gait rates
(.97, 1.03, 1, .95, 1.05), sharing mesh/action data. Godot should derive similar
values once from a stable spawn seed, retain phase for each entity, and optionally
scale sway by a small bounded amount. No random sampling is needed every frame.
Distance LOD can reduce evaluation frequency; no added bones, cloth or physics.

## Validation and limits

`player_validation.json` and `zombie_validation.json` record loop closure,
deformed-edge rigidity, minimum height and half-frame samples. Base geometry,
UV, skin weights, materials and packed character textures are compared before
and after authoring. `source_preservation.json` records unchanged input hashes.

`layer_validation.json` checks quarter-frame weapon contact, actual base/stance
composition, recoil composition against Aim, zero recoil endpoints and nominal
stance travel. Maximum reviewed raise error is about **2.23 mm** between keys;
maximum tested recoil composition error is **0.12 mm**. Held poses over all
three gait layers retain contact within floating-point tolerance. Stance proxy
drift at nominal speeds is approximately **0.00016 m/s walk**, **0.00346 m/s run**.
This measures the bottom-face center, not the heel/toe turnover point.

The GIFs and eight-pose sheets include player/zombie loops, all three weapons
walking/running, raise transitions, and firing. Side sheets expose fixed-length
limbs, stride silhouettes, stock position and hand occlusion. They are review
renders; final timing, directional locomotion, automatic-fire impulse blending,
quaternion additive import and mobile performance still require Godot validation.

## Reproduce

Run with Blender 5.2 in background mode:

```text
blender --background --python blender/animation_v2/build_animation_v2.py
blender --background --python blender/animation_v2/validate_layers.py
blender --background --python blender/animation_v2/build_crowd_review.py
blender --background --python blender/animation_v2/render_review.py -- Player
blender --background --python blender/animation_v2/render_review.py -- Zombie
python blender/animation_v2/package_review.py
```

Builders write only this new revision directory. They never save to source asset
paths. The review pack can be regenerated without touching production files.
