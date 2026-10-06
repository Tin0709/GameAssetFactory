# LongGunHold_V2 — C2 visual redesign

New `assets/characters/LongGunHold_V2.tres` is a category pose for M4A1/Shotgun
in the existing V2 filtered animation compositor. `WeaponHold.tres` is preserved
byte-for-byte (SHA-256 1c8a7817e672c0a8f52b9a457f92a5a31e7637bdc426fee06bd6674e7273a151).
Pistol continues to use that original generic pose, with zero long-gun weight.
No PistolHold clip is introduced. Disable `long_gun_carry_v2` on Visual to roll
back to C1 without changing any animation resource.

## Pose

Arm.R, Arm.L and WeaponSocket use absolute local animation pose tracks. Chest
uses a rotational delta added over the existing locomotion result; it is not
replaced with a static Chest pose. Position/rotation tracks are constant and
looping; there are no scale or lower-body tracks.

- Right arm: forward and inward, about 29 degrees below horizontal. Shoulder
  moves 1.5 cm down and 3.5 cm forward relative to rest. It frames the rifle's
  rear receiver/control region rather than aiming at a fake anatomical grip.
- Left arm: different inward angle, about 30 degrees below horizontal. Shoulder
  moves 3.5 cm down and 14.5 cm forward. Its end is approximately 3.4 cm lower and
  15 cm farther forward than the right end, giving an asymmetric support silhouette.
- Chest: model-space pitch +2 degrees (forward), yaw -4 degrees. The constant
  bias is multiplied onto the current Chest rotation, retaining the original
  time-varying motion. Spine is not adjusted. Neck/Head have no new tracks or
  corrections; their existing motion remains, inheriting the small Chest bias.
- Long-gun socket local position under Chest changes from C1
  (0.193352, 0.105469, 0.230917) to (0.150000, 0.068260, 0.211637).
  Its frame points the barrel forward with 7 degrees downward pitch, without
  the previous sideways skew. Thus the attachment origin is 3.7 cm lower before
  the Chest bias, and the M4A1 grip is authored at model height 0.985 m.

These are animation pose changes, not rest-pose, bone-length or mesh edits.
The weapon remains attached via Chest -> WeaponSocket -> WeaponAttachment.
M4A1 and Shotgun keep their existing child instance offsets/scales and all markers.
Shotgun required no additional model-specific offset in the reviewed views.
Pistol's socket and carry pose are unchanged after transition settling.

Category transitions and equip/unequip use 0.13 seconds. They do not touch the
Run clock. Controlled arms/socket inherit torso movement; the rendered four-cycle
test measures approximately 7.1 degrees of arm rotation in skeleton space,
confirming the upper body is not a frozen statue.

## Validation and visual limits

M4A1 and Shotgun Idle/Run were inspected from gameplay elevated 3/4, front 3/4
and side. Primary gameplay captures retain the scene camera transform and size;
close and alternate-angle cameras exist only inside the review harness.

The receiver/stock sits below the face, the right arm frames the rear of the
weapon and the left arm supports farther forward. Face stays visible. Sampled
views show no distracting face or deep chest penetration. Small shoulder seam
intersections and imperfect rigid-arm grip contact remain; this is a stylized
carry pose, not ADS. Final aesthetic approval remains with the human review.

93 C2 checks passed in headless and rendered modes, including M4A1 diagonal Run,
moving switches/turns, armed start/stop, all three moving-fire profiles, Pistol
exclusion, unaffected lower bones, additive Chest rhythm and four continuous
Run cycles with zero animated Root translation. The existing 36 locomotion and
798 movement/weapon checks also pass. Run scale remains 1.60; Run/Walk speeds
remain 6.25/4.25 m/s. Existing moving fire remains gated at <=3 m/s and was tested
at the original combat speed 2.6 m/s.

Production/test Blender files and the imported character GLB retain their prior
SHA-256 hashes. Idle/Run data, Hips/Legs, timing, collision and gameplay camera
are unchanged. No new recoil, shoot, ADS, reload, elbows, IK or Blender edits.
Final normal-access rendered tests have no engine errors/warnings; sandbox-only
user-cache permission messages do not occur in that run.

Runtime adds one cached pose sampler, category weight, three pose blends and
one additive Chest rotation within the existing sole writer. No second skeleton,
hand solver, retargeting or raycasts. Mobile-device performance is unmeasured.

## Files and review

Runtime: `scripts/player_animation_v2.gd`, `scenes/characters/CuboidPlayer.tscn`.
New: `assets/characters/LongGunHold_V2.tres`,
`tools/create_long_gun_hold_c2.gd`, `tools/inspect_long_gun_c2.gd`,
`tests/review_long_gun_c2.gd`, `tests/validate_long_gun_c2.gd`, this report.
C1 regression test explicitly disables C2 to preserve its historical baseline.
Evidence: `tests/carry_c2_*.png`, `tests/long_gun_c2_validation.json`, C2 logs,
and refreshed movement/weapon validation metrics.

The interactive review harness starts with M4A1 equipped, original gameplay
camera, and automatic enemy spawning/progression temporarily disabled so review
cannot be interrupted by death/upgrades. It uses the actual gameplay scene and
controller; no enemy/gameplay files are changed. WASD/Shift, 0 unequip, 1/2/3
weapon selection and manual debug enemy spawning remain available.

Stop at C2. Review the new carry silhouette and transitions before further work.
