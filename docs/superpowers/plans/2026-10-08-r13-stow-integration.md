# R13 latest stow integration

> Execute inline with superpowers:executing-plans; one whole-change review at the end.

Goal: Integrate the latest saved R13 Actions and R12 hold/sway into real Godot gameplay, preserving active gait, same weapon instance, awareness, sprint priority and valid firing. Leave a muted game review open.

Spec: User R13 addendum at C:/Users/ADMIN/.codex/attachments/dcc9d0a9-9bf1-4cd0-bcb4-16bb0ae27bb6/Pasted text.txt; source player_weapon_stow_r13_upper_back_review.blend and its design.json.

Architecture: Keep the current production skeleton and sole pose writer. Export native Action samples and slim body/weapon visuals into new versioned R13 assets. The source arms stay straight, allowing exact mapping UpperArm/ForeArm to existing Arm bones. Add a final R13 layer with weapon-specific Holster/compatible Draw slices; native endpoints drive hand/carrier/back/right-hip attachments. Previous resources remain for rollback.

Constraints: Do not edit approved Blender Actions or reapply percentages/45 degrees. Pistol intentional half-width hip inset remains. Walk/Sprint clocks and lower tracks unchanged. No further art polish. Testing is silent.

- [x] Export actual saved sources: fingerprint Actions; bake collapsed-arm local bone transforms from R12/R13 at 48 Hz; export new normalized geometry and markers. Capture exact hand/carrier/stow mounts and timings.
- [x] Integrate versioned native Animation resources and visuals; preserve existing lower reference locomotion. Implement continuity across carrier handoffs and weapon-specific back/hip endpoints. Use the already-authored review-return slice for minimal Draw compatibility, explicitly record that mapping.
- [x] Validate all classes in Idle/Walk/Sprint, left/right turns, switches and awareness changes. Check no duplicate, no attachment pop, current-frame firing gate, active gait continuity, source fingerprint and runtime pose parity.
- [x] Capture/render actual game versus Blender endpoint/midpoint references; preserve rollback and report final transforms/timing/issues.
- [x] Fresh whole-change review; mute verified; artistic status awaiting review. Launch real gameplay last.

Ruling: Existing full request authorizes production integration, superseding earlier study-only stop. New asset paths and preserved scripts provide rollback; no separate worktree because the live Blender source and requested game window are in this workspace.

Ruling: Keep the right-hip attachment in Chest bone space — the saved endpoint was authored relative to Chest; following Hips would add an unapproved gait drift. The named hip socket still carries the correct character-right position.

Ruling: The old Draw is incompatible with the new endpoints; use the already-authored 66..112 return as the minimally adapted native export, explicitly labeled in the report. No Draw reauthoring or extra posing.

Added user request: F5 gameplay button for one stationary non-attacking enemy. Implemented immortal target with unchanged awareness. Test mode remains after deleting it so no new threats interrupt Holster; R resets ordinary gameplay.

Verification: native runtime 8820 checks/0 failures; movement/weapons 798; combat 78; progression 85; weapon selection 127. All pass. Sound suppression and dummy target pass. Original twelve production clips byte-identical; original Blender file hash and Actions preserved. Actual rendered game and Blender source images inspected.

Review: fresh agent r13_final_review identified two P2 issues (early enemy respawn; stale Draw exit mount after immediate weapon switch). Both reproduced RED, fixed, tested GREEN. Reload testing additionally led to instance-local Animation libraries and correct track paths. Report/game gallery at game_mobile_3d/.validation/r13/REPORT.md and review/index.html.

No commit/push/merge or additional animation polish. Changes remain in the requested live workspace for human art review.
