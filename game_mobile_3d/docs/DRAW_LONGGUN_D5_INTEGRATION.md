# D5 — authored long-gun Draw integration

2026-10-07. `Draw_LongGun_V3_Final` now supplies M4A1 and Shotgun Draw in the existing gameplay Player. Pistol retains its placeholder. Technical integration is validated; the preserved Shotgun READY overlap remains an artistic review item.

## Export and source protection

- GLB: `C:/Users/ADMIN/Desktop/GameAssetFactory/game_mobile_3d/assets/characters/player_cuboid_animated_v3.glb`.
- Clips: `Idle`, `Run`, `HolsterLongGun`, `DrawLongGun` (exactly four).
- Draw duration: **0.5416666865348816 s** in glTF float storage; authored/runtime event duration is **13/24 = 0.5416666666666666 s**, frames 1–14 at 24 FPS.
- Clean, unchanged `DrawLongGun` Action copy: `blender/characters/player/cuboid/export/draw_d5/DrawLongGun.blend`. This is a separate export library. The development file was never saved or changed.
- Development source SHA256 before/after: `9e678b81b8ce40aa716bcc335908da819c444a9c8ff51e81d6748dbfbd28d60c`. All original Action curve digests are in `export/draw_d5/protection.json`.
- Background Blender export uses temporary rig/mesh/action data and a 4x retimed export-only Action, sampled at 96 Hz. The clean copy retains original frames, curves and metadata.
- v3 is assembled on v2's existing GLB. Mesh, skin, nodes, rest hierarchy, Idle, Run and HolsterLongGun are preserved byte-for-byte, including original sampler data. Only Draw data is appended.
- One `Player_Cuboid_Base` mesh, one `Player_Cuboid_Rig` skin, and `WeaponCarrier`. No reference rifle, cameras, lights, Mixamo data or old version Actions are exposed in the export.
- Actual source channels: rotation on Spine, Chest, Neck, Head; translation and rotation on Arm.R, Arm.L, WeaponCarrier. Zero Draw Root/Hips/Leg.L/Leg.R tracks; zero scale tracks and root motion.
- 53 exported poses compared with Blender: maximum position discrepancy **0.000000258 m**, rotation discrepancy **0.03282 degrees**, including floating-point precision. Endpoint remains the approved Hold_V2-compatible source endpoint.

## Exact events and ownership

| Event | Action frame | Runtime seconds | Operation |
|---|---:|---:|---|
| DRAW_BEGIN | 1 | 0 | Begin upper-body layer; keep stable back mount |
| WEAPON_GRAB | 5 | 0.1666666666666667 | Notification only |
| WEAPON_BACK_RELEASE | 5.25 | 0.1770833333333333 | Same weapon: BackWeaponMount → WeaponCarrierSocket |
| SUPPORT_HAND_CATCH | 10.9 | 0.4125000000000000 | Notification only; Carrier and authored settle continue |
| DRAW_READY | 14 | 0.5416666666666666 | Carrier → normal hand WeaponAttachment/WeaponSocket; DRAWING → READY |

Both ownership changes use global-transform-preserving reparenting. **Hand ownership is selected at frame 14, exactly DRAW_READY**, because the M4A1 Carrier endpoint aligns with the stable hand frame there. It is not handed to the hand at release or catch.

Events execute once on the first pose evaluation at or after their threshold. At 60 Hz, release is observed at clip time 0.1833333 s and catch at 0.4166667 s. The final update clamps clip time to 0.5416667 s; it is reached on the 33rd physics increment (0.55 s from a zero-time start). Subframe tests separately exercise the exact 5.25-frame threshold.

The source of truth is Action `event_subframes_json`, not integer display markers. Export converts `(event_frame - start_frame) / authoring_fps` into `assets/characters/draw_long_gun_events.gd`. The generated preloaded GDScript resource is the sole runtime timing table and is included in Godot exports without requiring a JSON file export filter. Provenance and original frames are retained there and in glTF animation extras; export review JSON lives beside the clean Action copy.

## Composition, mounts and blending

`player_draw_d5_integration.gd` extends the existing Holster/V7 integration. AnimationPlayer remains a clip library. The same existing pose writer samples seven cached bone tracks; no second writer, skeleton, AnimationTree, retargeter or IK is introduced.

Idle/Run continue underneath. Spine/Chest/Neck/Head receive the same additive local body response used by the approved Blender overlay. Arms acquire the authored pose over 0.125 s; WeaponCarrier follows the authored trajectory. Root, Hips and legs are untouched by Draw. The hidden hand destination is prepared while the rifle remains attached to Carrier.

Back → Carrier preserves the current world transform, then reconciles the weapon's visual mounting over 0.08 s. Carrier carries it through Pull-Free, Sweep, Catch and settle. M4A1's final mount already matches the hand. Shotgun uses its existing transport clearance, plus a Draw-only **-0.01 m Carrier-X** stock clearance. During Catch → Ready its weapon-specific visual mount blends to its existing hand mount; the animation bones and event times are unchanged. This avoids carrying the previous 14.1 cm transport/hand offset into the handoff.

At Ready, the underlying Hold_V2 layer is primed to its existing full weight. The captured final upper pose blends into the continuing Hold_V2/locomotion composition over **0.10 s**. No hard Hold snap occurs at Catch. Handoff mount position error is at most **0.000000330 m** across both weapons and all phases. Measured reparent discontinuity is at most **0.000000267 m** and **0.05596 degrees** (float quaternion comparison).

No visible attachment teleport or obvious Ready arm/Chest snap was observed in the reviewed gameplay-camera frames. This is sampled visual QA, not a substitute for the user's artistic approval.

## Sprint, awareness and interruption

- Before back release: Sprint cancels Draw, invalidates the token, and leaves the weapon's back-local transform unchanged. The upper body returns to locomotion over 0.10 s.
- Rapid Sprint release during that cancellation blend: the next Draw captures the currently visible partial Reach and blends from it, avoiding an unarmed pose reset.
- After back release: Sprint lets the short forward Draw finish on Carrier; at its endpoint it immediately starts the existing ordinary Holster from the captured pose. There is no READY firing interval, animation reversal, early hand transfer, or orphaned weapon. Worst-case remaining transport is the remaining Draw plus 0.708333 s Holster.
- Sprint still overrides a valid enemy. When stowed it stays stowed. Releasing Sprint with a retained threat immediately requests real Draw; an unfinished Holster completes first.
- An enemy appearing while not sprinting requests Draw through the existing awareness service. No awareness or movement logic changed.
- Switching cancels old tokens and uses the existing three-instance pool. Unequip/death release Carrier safely. Disabling weapon behavior during either Reach or Sweep preserves the current weapon world transform and blends to its normal bypassed hold.
- STOWED, DRAWING and HOLSTERING cannot fire. SUPPORT_HAND_CATCH does not enable firing. M4A1 and Shotgun use the unchanged firing profiles after READY.

## Validation and visual limits

| Suite | Checks | Failures |
|---|---:|---:|
| D5 deterministic, source events/masks/sockets/guards/switching | 42,591 | 0 |
| D5 real controller, awareness, moving Draw, turning, firing | 585 | 0 |
| D2 Holster deterministic | 9,089 | 0 |
| D2 live controller | 50 | 0 |
| D3 sprint/awareness, updated for Carrier-owned Draw | 1,172 | 0 |
| D0 retained placeholder contract | 112 | 0 |

Both weapons were tested over Idle and Run starts at **0%, 25%, 50%, 75%**. The live controller suite also tests all four phases, direction changes during Sweep, sprint release with a valid enemy, and actual shots after Ready. Run clock error is below 6e-17 s, lower-body translation contribution is zero, and Root travel is zero. Gameplay speeds remain 4.25/6.25 m/s; the original 2.6 m/s combat cap still applies. The 90-degree turn test reaches ~1.857 m/s under that existing cap and never stops movement. Run animation scale remains **1.60**.

Forward Mobile / D3D12 renders use the actual gameplay camera, including full-view moving/turning sequences. Contact sheets provide labelled crops of those same camera renders. Final runtime test/render logs have no new script errors. Early editor imports encountered sandbox restrictions saving editor preferences, and an initial render could not create its shader cache; using a workspace-local APPDATA fixed runtime cache access. Source/asset import and final game execution succeeded.

Offline triangle/box diagnostics cover **640 runtime poses**. M4A1 has no head or deep-chest intersections. After the Shotgun Draw-only clearance change, neither weapon has a sampled head intersection. **Shotgun still has stock/receiver overlap with the chest from approximately 0.475 s through its preserved READY pose.** This corresponds to the documented pre-existing Shotgun READY fit; Hold_V2 and the hand offset remain unchanged. The collision report intentionally retains `passed: false` for that visual limitation. Technical integration passing does not mean the Shotgun is collision-free. Rigid hand/gun contact from the approved source also remains for human review.

No mobile-device frame-time benchmark was performed. Added runtime work is seven cached bone samples during Draw, five event checks, native attachment refreshes and small weapon-local interpolations. Entry/exit poses are cached at transitions, and event/handoff logs are bounded. No new enemy scan, bone-chain solver, weapon physics, mesh duplication or skeleton duplication is added.

## Files and reproduction

Production changes under `game_mobile_3d/`:

- `scenes/characters/CuboidPlayer.tscn`: visual script and model references only.
- `scripts/player_draw_d5_integration.gd` and UID: Draw layer, blends and metadata events.
- `scripts/player_weapon_socket.gd`: global-preserving Draw transfers and visual mounts; existing Holster transport untouched.
- `scripts/weapon_behavior.gd`: long-gun authored Draw dispatch, gates, sprint handling and interruption cleanup.
- `tools/blocky_character_post_import.gd`: applies existing strict transition filtering to Draw too.
- `assets/characters/player_cuboid_animated_v3.glb`, import settings, extracted atlas/import settings.
- `assets/characters/draw_long_gun_events.gd` and UID: generated timing resource.

Export/review files under `blender/characters/player/cuboid/`: `export_draw_d5.py`, `validate_export_draw_d5.py`, and `export/draw_d5/` containing the clean Action library, raw Draw GLB, metadata, protection hashes, source samples and export validation report.

Tests under `game_mobile_3d/tests/`: `validate_draw_d5.gd`, `validate_draw_d5_live.gd`, `inspect_draw_d5_collisions.py`, `search_draw_d5_mount.py`, `make_draw_d5_review.py`, `review_draw_d5.gd`, generated UIDs and `draw_d5_*validation.json` reports. D0's fixture explicitly disables authored Draw as it already disabled Holster; D3's interruption expectations now reflect Carrier transport. Existing D2/D3 reports were regenerated.

Use the installed Godot binary with `--headless --path game_mobile_3d --fixed-fps 60 --script res://tests/validate_draw_d5.gd` (or the live/D0/D2/D3 script). For rendering, omit `--headless`, add `--rendering-method mobile --rendering-driver d3d12`, and append `-- --capture`. Render artifacts remain under `.validation/draw_d5/` and `.validation/draw_d5_live/`.

## Interactive review

Entry: `res://tests/review_draw_d5.gd`. It loads the actual gameplay level/controller/camera with M4A1 **STOWED**. A durable, non-attacking enemy is available outside awareness; **T** brings it in/out to trigger real Draw. **WASD** moves; **Shift** sprints/stows; releasing Shift with the threat present draws again. **1/2/3** use the existing Pistol/M4A1/Shotgun selection.

Automatic waves and level-up prompts are disabled only in the standalone review harness. The initial stowed condition and T-triggered STOWED → DRAWING → READY path are smoke-tested. The game is left open at the initial stowed review state.
