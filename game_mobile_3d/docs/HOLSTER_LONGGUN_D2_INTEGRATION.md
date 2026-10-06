PHASE D2 — authored long-gun holster integration, 2026-10-07
=========================================================

The approved `Holster_LongGun_V3_Final` is integrated into the current gameplay character. M4A1 is ready for in-game review. Shotgun shares the animation with a clearance offset and retains a brief inherited READY overlap, described below. Draw and Pistol animations were not authored.

Export and preservation
-----------------------

- Saved development source: `C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/player/cuboid/player_cuboid_weapon_animation_dev.blend`.
- New action `HolsterLongGun` is an unchanged export copy of V3_Final. All pre-existing action curve hashes were checked before/after the temporary export scene was removed and before saving. Original actions, rig hierarchy/rest/lengths, mesh and skinning were preserved.
- Export: `C:/Users/ADMIN/Desktop/GameAssetFactory/game_mobile_3d/assets/characters/player_cuboid_animated_v2.glb`.
- Exactly three exported clips: `Idle`, `Run`, `HolsterLongGun`.
- Holster duration: **0.708333313465118 s**, matching source frames 1–18 at 24 FPS. Export sampling is 96 Hz using temporary retimed copies in a temporary scene; the source scene remains 24 FPS.
- One mesh (`Player_Cuboid_Base`), one armature (`Player_Cuboid_Rig`), 11 exported bones. `WeaponCarrier` remains a non-weighted Chest child. The legacy non-deforming `WeaponSocket` is added by the existing import adapter, resulting in 12 runtime bones and one live skeleton.
- No reference rifle, camera, light, old authoring clip or Mixamo rig in the GLB.
- GLB poses compared against Blender at 69 samples: max position discrepancy **0.000000324 m**, rotation comparison **0.04753 degrees** including float precision effects.
- Existing GLB v1 Idle/Run channel times, interpolation and values are preserved exactly. Mesh POSITION, NORMAL, TEXCOORD_0, JOINTS_0 and WEIGHTS_0 arrays are also identical to v1.
- Holster GLB has no Root/Hips/Leg.L/Leg.R or scale channels. Godot synthesizes some rest tracks while importing: the dedicated post-import hook strips these from Holster only. Runtime uses an explicit seven-bone mask as an additional safeguard.
- Production `player_cuboid_v6.blend` and `blocky_character_mixamo_test.blend` SHA256 match the pre-D2 baseline. No production file was saved.

Runtime composition and attachments
-----------------------------------

`player_holster_d2_integration.gd` extends the existing V7 adapter and adds the final layer inside the same pose writer. AnimationPlayer remains a library, not another active writer. Only Spine, Chest, Arm.L, Arm.R, Neck, Head and WeaponCarrier receive Holster samples. Root/Hips/legs retain the original locomotion result. No scale tracks are sampled.

Hierarchy:

```text
Player/Visual/Model/Player_Cuboid_Rig/Skeleton3D
  WeaponAttachment        [BoneAttachment3D: WeaponSocket; READY]
  WeaponCarrierSocket     [BoneAttachment3D: WeaponCarrier; transition only]
  BackWeaponSocket        [BoneAttachment3D: Chest]
    BackWeaponMount       [cached approved Carrier endpoint in Chest space]
      equipped weapon     [STOWED]
  HipWeaponSocket_R       [existing Pistol placeholder]
```

The pre-existing equipped instance is reparented with `keep_global_transform=true` at both handoffs. Pool identity remains unchanged; no additional weapon or skeleton is created. Central attachment entry points live in `weapon_behavior.gd`, and request tokens prevent events from a prior weapon/transition mutating the new one.

At BEGIN, pose/attachment transforms are refreshed, then hand → carrier preserves the exact current world transform. A smooth **0.10 s** entry blend moves the upper body from its captured LongGunHold/locomotion pose to the authored clip. A local mount correction blends over the same period, accounting for weapon asset axes, scale and grip origin; this avoids an attachment snap.

At RELEASE, carrier → back also preserves world transform. BackWeaponMount is calibrated once to the imported clip's final local WeaponCarrier transform. The small remaining mount difference settles smoothly from release to DONE. The weapon stays on the stable Chest attachment afterwards, never on WeaponCarrier.

Upper-body exit blends into the continuously evaluated unarmed Idle/Run result over the final **0.12 s** (starting about 0.58833 s). There is no hard switch of the arms or reset of the gait clock.

Event timing
------------

Events are centralized in `HOLSTER_EVENTS`, using `(authored_frame - 1) / 17 * imported_clip_duration`:

| Event | Source frame | Nominal seconds |
|---|---:|---:|
| HOLSTER_BEGIN | 1 | 0.000000 |
| SUPPORT_HAND_RELEASE | 5 | 0.166667 |
| WEAPON_BACK_CONTACT | 15 | 0.583333 |
| HOLSTER_RELEASE | 16 | 0.625000 |
| HOLSTER_DONE | 18 | 0.708333 |

Events execute once on the first pose evaluation at/after their threshold; at 60 Hz release is observed at 0.633333 s. Blender marker import is not assumed. CONTACT and SUPPORT are exposed event notifications; they do not create separate weapon instances or attachments.

If a threat returns during real long-gun Holster, the short authored motion finishes safely, then the existing forward placeholder Draw is requested if the threat is still present. No reversal is used. Pistol stays on D0 placeholder timings and the hip socket. Existing READY-only fire/movement gates, weapon profiles and targeting code are unchanged.

Validation and visual limits
----------------------------

- Deterministic integration suite: **9,088 checks, 0 failures**. Idle plus Run phases 0%, 25%, 50%, 75% on both M4A1 and Shotgun; imported mask/scale, pose continuity, unchanged lower body, switch/stale-token cleanup, unequip, death, interruption and READY firing verified.
- Actual physics/process suite: **58 checks, 0 failures**. Real controller movement and turns at 6.25 m/s, cadence 1.60, natural grace-timer entry, threat return, firing and weapon switching.
- D0 foundation regression: **112 checks, 0 failures**. Fixture explicitly disables authored holster, preserving its placeholder assertions while accounting for the required new Carrier bone.
- Run clock error: approximately 5.2e-17 s. Root bone travel **0 m**. Holster contribution to lower-body translation **0 m**; lower rotations match the baseline composition.
- Handoff translation discrepancy ≤ **0.000000310 m**. Quaternion angle comparison ≤ **0.05596 degrees**, consistent with float rounding after transform decomposition. No visible handoff pop observed in engine renders.
- Engine rendered all ten Idle/Run cases through **Forward Mobile / D3D12**, with clean final runtime/render logs. No mobile-device performance benchmark was performed.
- Offline triangle/box checks use actual Godot weapon meshes/transforms and rigid body boxes: **430 samples**. M4A1 has no head or deep chest intersections.
- Shotgun mount offset in Carrier space is **(0, +0.125, +0.025) m**. This clears its broader stock from the head/back without changing clip timing or M4 placement. No Shotgun head penetration remains. Receiver/stock overlap with the chest is still present at the preserved READY pose and the first **0–0.0333 s** of entry; it is clear from 0.05 s onward in sampled poses. The inherited READY pose was deliberately preserved. This is a visual limitation, not a fully collision-free Shotgun result.
- Existing rigid-hand/rifle contact overlap can remain, as in approved V3_Final; this pass did not redesign those poses.
- Initial headless editor runs warned about saving editor settings under sandbox permissions; asset import succeeded. Final gameplay and Mobile-render validation logs contain no errors/warnings. A first automatic Vulkan attempt fell back to D3D12; final validation selects Mobile/D3D12 explicitly without modifying project renderer settings.

Performance
-----------

The extension samples seven cached bone tracks only during Holster, with native BoneAttachment updates, two weapon-local interpolation operations and five event checks. Back mount calibration happens once at setup. Event/debug logs are bounded (64 events, 32 handoffs). No IK, custom per-frame bone-chain solver, physics weapon, runtime retargeting, additional live skeleton or weapon duplication. Existing movement, targeting, firing, camera and collision scripts/resources are untouched.

Changed files
-------------

Production integration files under `C:/Users/ADMIN/Desktop/GameAssetFactory/game_mobile_3d/`:

- `scenes/characters/CuboidPlayer.tscn`: only visual script/model references.
- `scripts/player_holster_d2_integration.gd` (new): filtered layer, blend and centralized events.
- `scripts/player_blocky_v7_integration.gd`: accept the required Carrier in legacy-rest compatibility checks.
- `scripts/player_weapon_socket.gd`: Carrier/back mount and continuous same-instance handoffs.
- `scripts/weapon_behavior.gd`: authored long-gun flow, token checks and finish-then-Draw interruption.
- `tools/blocky_character_post_import.gd`: strip synthesized non-authored Holster tracks.
- `assets/characters/player_cuboid_animated_v2.glb`, import settings, extracted 64px atlas/import settings (new).

Development source and reproducible export/validation artifacts are in `C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/player/cuboid/`: `export_holster_d2.py`, `validate_export_holster_d2.py`, `holster_d2_glb_validation.json`, `holster_d2_source_samples.json`, `holster_d2_protection.json` and the saved development blend. Export script stops if the currently open file is not the development file.

Test/review entry points in `C:/Users/ADMIN/Desktop/GameAssetFactory/game_mobile_3d/tests/`: `validate_holster_d2.gd`, `validate_holster_d2_live.gd`, `verify_holster_d2_asset.py`, `inspect_holster_d2_collisions.py`, `make_holster_d2_review.py`, `review_holster_d2.gd`, `review_holster_d2_controls.gd`; the D0 fixture has two compatibility changes. JSON validation reports are beside these scripts. Generated screenshots/editor cache are kept outside asset imports in `.validation/holster_d2/`.

Review
------

The standalone review harness uses the actual gameplay level/controller and equips M4A1. Automatic perimeter waves and level-up prompts are disabled in this harness only. Initial READY is held for review until H or a real threat has occurred.

- **H**: clear review threats and trigger READY → HOLSTERING → STOWED.
- **K**: existing debug enemy spawn; when it enters awareness range, forward placeholder Draw returns to READY.
- **WASD + Shift**: review Holster while running; **2 / 3** choose M4A1 / Shotgun.
- Contact sheet: `C:/Users/ADMIN/Desktop/GameAssetFactory/game_mobile_3d/.validation/holster_d2/holster_d2_review.png`.

At the final read-only Blender check, the live session had been switched to `player_cuboid_weapon_animation_dev_before_v3_20261007_021034.blend` with unsaved changes. That session was left untouched. Reading the saved development library confirms HolsterLongGun, V3_Final, V2, V1, Idle, Run and Player_Idle are present. The export/save was completed from the correct development file earlier.
