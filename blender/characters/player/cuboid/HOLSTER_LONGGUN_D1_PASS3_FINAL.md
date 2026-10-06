# Holster_LongGun_V3_Final — D1 Pass 3

Saved in `player_cuboid_weapon_animation_dev.blend`. Duplicated from the actual V2 action; V1/V2 remain intact. Exact range **1–18 at 24 FPS**, duration **0.708333 seconds**. Ready and final Stowed transforms are retained. No Godot export/integration or gameplay changes were made.

## Exact creative changes from V2

| Part | V3 refinement |
|---|---|
| Chest intent | Prepare at 2.2 reduces pitch a further 0.28°, a subtle relaxation before the strong pull. |
| Arm.L | New pressure-reduction pose at 3.35 (−0.55°, +0.15°, +0.35° in local XYZ); held through 4.7. Release moves 5.3 → 5.4; linger 6.2 → 6.4; relaxed recovery 17.1 → 17.0. |
| Arm.R | Small per-axis corrections of 0.2°–2.5° around the pull/sweep/guide. Shoulder-turn guide moves 10.6 → 10.35; back guide 12.9 → 12.65 and 14.3 → 14.05. Release 15.5 → 15.7; late recovery 17.4 → 17.55. |
| WeaponCarrier | Sparse clearance offsets, up to 4.03 cm combined, fade back to the unchanged Stowed endpoint. Shoulder guide times 10.5 → 10.55 and 11.5 → 11.65 give controlled deceleration and fractional lag behind the arm. |
| Chest follow-through | Recovery 14.4 → 14.55 and 16.4 → 16.65, preserving residual motion after placement. Frame-18 Chest remains (0.22°, −0.30°, 0.05°). |
| Spine | Existing subtle peak delayed 11.8 → 12.0. Local yaw remains approximately 1.3° maximum; no additional large torso motion. |
| Neck | Tiny stabilization at 3.4; shoulder response delayed 10.9 → 11.15 with additional (−0.08°, +0.15°, −0.03°), maximum local yaw approximately 1.35°. |
| Head | Response 12.1 → 12.35, adding (−0.03°, +0.10°, 0°); maximum local yaw approximately 0.5°. Generally forward, not tracking the gun. |
| Exit | Retains V2's small, different relaxed arm poses. Left arrives earlier and right later; no particular Run stride is encoded. Neck/Head return to zero local rotation at 18. |

The original shoulder-side motion story is preserved. No extra pause, random noise, new articulation, IK, mesh edits or bone changes.

## Shoulder pass, curves and settle

The rifle still pulls inward, travels outside the shoulder, rises, changes direction under right-arm control and descends toward the back. Clearance offsets are local refinements of that arc rather than a new trajectory. Curves remain Bezier with AUTO_CLAMPED handles, sparse authored poses and staggered timing: **31 curves / 303 scalar-channel key points**, compared with V2's 31 / 300.

At 137 equally spaced 1/8-frame samples:

- Peak carrier angular speed: **649.0°/s in V2 → 619.7°/s in V3**.
- Peak carrier translation speed: **8.25 → 8.74 m/s**, concentrated in the fast shoulder arc.
- Maximum carrier orientation step: **3.23° per 1/8 frame**; maximum right-arm step is **10.17° per 1/8 frame**, so the right-arm hero sweep remains brisk.
- Velocity-vector differences across 0.05-frame windows around authored keys peak at **0.351 m/s**, consistent with a smooth accelerating curve rather than a discontinuous position jump. These sampled checks do not replace human playback judgment.

Settle at 14.8 is reduced from **1.44 cm / 1.00°** to **0.94 cm / 0.65°**. The rifle reaches secure alignment by **16.15**. Final Stowed matrix differs from V2 by less than **1.8×10⁻⁷** per component. Rear 3/4 and side renders show the actual M4A1 on the back without moving the approved endpoint.

## Clipping before / after

Using the same arm-interior triangle/box test at 137 samples:

| Metric | V2 | V3 |
|---|---:|---:|
| Samples with right-arm intersection | 87 | 82 |
| Sum of intersecting weapon triangles | 4063 | 2762 |
| Maximum penetration into the reduced arm test box | 8.56 cm | 8.36 cm |
| Head/deep-chest hit samples | 0 | 0 |

The triangle-contact total decreases **32.0%**. This is a reproducible geometric proxy, not a percentage of visible screen clipping. Arm tests shrink the surface by 2.5 cm and exclude the distal 20 cm intended for grip contact; head tests use a 1 cm boundary, chest tests a 3.5 cm surface margin.

**Remaining contact:** the approved initial Ready pose is preserved and still has stock/arm overlap. Some receiver/stock contact also remains during the pull and back guide. Gameplay, front, side and rear pose reviews prioritize a readable apparent grip over mathematically zero intersection. The action is a final integration candidate for visual approval, not a collision-free anatomical grip. No head-interior or deep-chest penetration was detected in the sampled transition or overlay tests.

## Idle / Run composition

Read-only pose composition was rendered over:

- **Player_Idle**, normal cadence.
- **Player_Run_Blocky_V7_Final** at **1.60×** source playback, start phases **0, 4, 8, 12 source frames**.

Each case includes all 18 transition frames plus a four-frame test blend-out toward the current locomotion upper-body pose. Only the base Root/Hips/legs are sampled during the holster; the upper body comes from V3. The locomotion source time advances continuously, so the test does not depend on one frozen stride.

All five compositions produce zero sampled head/deep-chest hits. Lower body remains active, the shoulder-side path reads at reduced gameplay image size, and the exit moves toward current locomotion without matching a particular Run frame. No locomotion keys were edited, no NLA tracks were added, and no locomotion was baked into Holster. The four-frame blend is a Blender test, not a change to Godot/D0 blend timing; runtime filtering/handoff remains to be integrated and verified separately.

## Markers

| Marker | Final Blender marker frame | Fractional event reference |
|---|---:|---:|
| HOLSTER_BEGIN | 1 | 1 |
| SUPPORT_HAND_RELEASE | 5 | 5.4 |
| WEAPON_BACK_CONTACT | 15 | 14.8 |
| HOLSTER_RELEASE | 16 | 15.7 |
| HOLSTER_DONE | 18 | 18 |

Both timeline and V3 action markers are present. Blender markers use integer frames; precise visual-event references are stored in `event_subframes_json` for later integration.

## Preservation and preview

- Root / Hips / Leg.L / Leg.R: **0 keys each**; standing-preview Root travel **0 m**.
- Scale keys: **0**, sampled pose scale error **0**.
- WeaponCarrier stays non-deforming under Chest, with no mesh weights.
- All original mesh coordinates/topology/weights, deform rest matrices, parents and lengths match the protection baseline.
- Twelve protected actions, including **Holster_LongGun_V1/V2**, Player_Idle and Run V1–V7_Final, retain their exact curve hashes. Production `.blend` checksums also match the earlier baseline.

Connected Blender is saved in Object Mode with Player_Cuboid_Rig selected, **Holster_LongGun_V3_Final** active, frame 1, preview **1–18 / 24 FPS**. Press Space over the viewport. The bottom editor is now the **Action Editor**: its action selector offers an easy V2/V3 comparison. A comparison README is also stored as a Blender Text datablock.

Review artifacts in `holster_d1_v3_review`:

- `compare_V2_V3_24fps.gif` / `compare_V2_V3_half_speed.gif` — side-by-side repeated comparison.
- `idle_overlay_24fps.gif` — Idle composition and test blend-out.
- `run_four_phases_1_60x_24fps.gif` / `run_four_phases_1_60x_half_speed.gif` — four-phase Run comparison.
- `contact_sheet.png` — gameplay/front/side/rear key poses.

GIF timing is quantized to 10 ms and includes an endpoint display frame; the `.blend` retains exact 0.708333-second clip timing. Repeating previews reset a one-shot holster from Stowed to Ready; that reset is not an animation loop defect.

**Status:** creative V3 final candidate saved and ready for visual sign-off and the next Godot integration step. Remaining grip-region contact is documented above. No export, D0/gameplay edits, V4, Draw, pistol, recoil or reload was created.
