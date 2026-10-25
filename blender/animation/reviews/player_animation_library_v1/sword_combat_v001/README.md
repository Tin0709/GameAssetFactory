# Sword Combat original v001 — Pending

Eight independently named original Actions in `sword_combat_v001.blend`, on the exact preserved Showcase13-bone rig (`cb913716…`). Full straight arms/legs, identity Neck/ForeArm technical helpers, unit scales, unchanged weights/rest matrices and identity rig-object matrix. The canonical `Sword_Combo_Original_v001` and its source remain untouched.

| Runtime name | Independent Action | Duration | Loop | Original source / contact |
|---|---|---:|---|---|
| Ready | Sword_Ready_Original_v001 | .80s | yes | Original settled stance and subtle breath |
| Attack1 | Sword_Attack1_Original_v001 | .60s | no | OUR original combo F1→19; contact .30s |
| Attack2 | Sword_Attack2_Original_v001 | .50s | no | OUR original combo F19→34; contact .20s |
| Attack3 | Sword_Attack3_Original_v001 | .90s | no | OUR original combo F34→61; contact .30s |
| Guard | Sword_Guard_Original_v001 | .80s | yes | Original diagonal guard |
| Parry | Sword_Parry_Original_v001 | .32s | no | Original receive and return to Guard |
| Roll | Sword_Roll_Original_v001 | .72s | no | Original complete rigid forward tumble |
| Hurt | Sword_Hurt_Original_v001 | .40s | no | Original asymmetric recoil and Ready recovery |

All eight are Pending in the existing Animation Showcase. Gameplay integration was authorized; this does not establish artistic approval. No Fiery or Actions & Stuff raw motion was imported. Attack poses/timing are continuous slices of the project's own original choreography; the remaining clips are authored in `authoring/build_source.py`. Source facts, original proposals, entry/exit velocities and hashes are in `design.json`.

Attack1→2→3 poses join continuously. The first two cuts retain outgoing velocity, so an unchained attack needs the runtime's recovery blend to Ready. Defense/Hurt remain upper-body overlays while locomotion owns support. Roll is a full-body clip with monotonic unwrapped Root X0→2π, pelvis pivot compensation, receiving support and a counter-rotated full right arm keeping the sword clear. Root translation is local pose compensation, never CharacterBody travel; physics owns displacement/collision. Do not run rifle support-hand reconciliation over Sword poses.

Native `geometry_validation.json` covers30/60/240Hz: all eight preserve arm rigidity/unit scale/helpers/grip and avoid body-floor/blade-head intersections. Roll additionally validates full unwrapped rotation and blade-floor clearance. The original combo's retained leg socket deviation is ≤.0737m; no inherited source choreography was silently repaired. `review/` includes representative front, three-quarter and side frames, a family sheet and a six-pose Roll sheet. These are diagnostic pixels, not an artistic approval or device-performance claim.

The runtime library/profile/export/build/independent sampler check live in `game_mobile_3d/scenes/dev/actions_stuff_research/sword_combat_v001/`. Runtime export follows the existing Rifle evaluated-basis convention; raw bake/fixtures stay under `.validation/sword_combat_v001/animation_stage/`. Central registration backups and signature audit are recorded by `registration_validation.json`.
