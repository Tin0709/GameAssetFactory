# Idle Expressive v2 — Pending comparison

`Idle_Expressive_Test_v2` refines the current Idle as a **separate independent Action**. `Idle_Expressive_Test` and every file in its study remain unchanged. All earlier Actions, rest rig, mesh, full arms/hands, weights, proportions, materials and textures are preserved. No facial rig, rig rebuild, Walk, Full Jump/preview change, Godot edit or export.

Playback: **F1–240 at 30 FPS, eight seconds**. **F241 is the matching closing key, excluded from playback.** This longer period allows two different interests with comfortable center/rest moments; it does not speed up or stretch the old 4.8-second Idle.

Open the permanent [Animation Showcase](../../../showcase/Animation_Showcase.blend), select **Idle_Expressive_Test_v2**, enable **Loop playback**, then Play. The earlier Idle remains independently selectable. Both are Pending until explicit user approval. Authoring source: `idle_expressive_v2_review.blend`; this is a study source, not another showcase.

## Review

- [Front / three-quarter / side together, original speed](idle_v2_all_views_1x.mp4)
- [Current Idle versus v2, larger three-quarter comparison](comparison_three_quarter_1x.mp4)
- [Current Idle versus v2, all three matching views](comparison_all_views_1x.mp4)
- Individual [front](front_1x.mp4), [three-quarter](three_quarter_1x.mp4), [side](side_1x.mp4)
- [Pose sheet](idle_v2_pose_sheet.jpg)

Videos show two complete v2 loops at original speed. The current Idle repeats its native 144-frame period alongside the new 240-frame period: no retiming, frozen padding or closing-key hold. Comparisons use identical cameras, lighting, materials and character. Preserved v1 render frames are reused after reproducing their evaluated geometry on the unchanged rig.

## Design and evaluation

| Phase | Frames | Intent |
| --- | --- | --- |
| Relaxed rest | 1–24 | Open comfortable stance and quiet breath |
| First look | 25–49 | Head leads a slightly lifted, stronger observation |
| Observe / body follows | 50–75 | Delayed shoulders, upper torso and load shift |
| Return / center rest | 76–124 | Head returns first; arms finish, then a quiet center moment |
| Second look | 125–146 | Shorter opposite glance, slightly lower chin |
| Second observation | 147–164 | Different pause and delayed body/arm response |
| Return / settle | 165–218 | Controlled independent recovery |
| Rest across boundary | 219–240 → 1–24 | Quiet seamless boundary, subtle breath continues |

The user-supplied [LookAround GIF](../idle_expressive_test/references/minecraft_dungeons_ii_idle_lookaround.gif) supplies pose/personality inspiration: an open base, head-led attention and body lag. Its 81 frames total 3.38 seconds; our original eight-second sequence does not claim to reconstruct its exact 3D angles or timing. The first and second glances are intentionally unequal rather than a mirrored scan.

Each foot is placed **28 mm farther outward**, widening sole-center separation from **225 mm to 281 mm**. Both rigid full soles stay flat and fixed; the extra space is an existing leg pose offset, not a rest-rig, limb-length or mesh change. Lateral hip transfer is 21 mm, with **no vertical hip bob**. This more open base supports the gentle load changes while avoiding a landing-like bounce.

Two independent, quiet four-second breathing cycles use up to **1.8 mm chest lift**, small chest/spine rotations, slightly delayed shoulders and tiny head response. There is no scaling, inflation or deformation. The head looks approximately **26° one way and 23° the other**, with differing chin/tilt and pause timing. No facial bones or shape-key controls exist; face life comes entirely from intentional head behavior. Arms remain restrained and follow their own settle timings. The right shoulder retains a small delayed relaxation through the second return to keep the turning head clear; this uses existing pose channels only.

The wider front silhouette reads less closed, and observing both directions gives the character more curiosity than the original single glance. Three-quarter shows the head-to-body overlap most clearly. Side view checks depth and support but naturally hides the stance width. Breath is deliberately small and may be hard to see at gameplay scale; it should enrich the attention changes rather than compete with them. A fixed eight-second repeating observation can still become predictable during prolonged inactivity; occasional scheduling is future controller work, not an additional animation authored here.

## Gameplay transition contract and limits

This is a **Blender-only unarmed artistic comparison, not production-ready gameplay animation**. Root and object transforms stay fixed; original bone hierarchy, rotation modes and slot conventions are retained. Both loop pose and velocity must match at the seam. Small load shifts remain inside the planted base.

The wider stance intentionally differs from v1 and locomotion. Entering/exiting it needs an authored or controller-managed unload/replant/phase-aware support transition; a simple crossfade can slide boots. Idle must be interruptible at either glance without waiting for the eight-second loop. The Action keys torso/head/arms as well as legs, so weapon-ready/aim/recoil layers need an explicit channel mask and ownership policy; unarmed checks do not prove weapon compatibility. None of these controller transitions is implemented or validated here.

Under the permanent gameplay priority, eventual approval still requires actual Godot pose/velocity blending, responsiveness, foot support/locomotion phase, weapon-layer compatibility and target-device measurements at 30 FPS. Physics owns jump travel and actual contact in future integrated work. Continue one animation at a time; no integration is authorized by this study.

## Safety and verification

Backups and initial working-tree/file hashes are under `.validation/idle_expressive_test_v2/`. The discarded shoulder-clearance pass is retained there. New registration uses the established helper with source/Action hash-bound validation and concurrent-byte guards; it never replaces an existing Action. The viewer is refreshed and saved at its existing path with Pending metadata.

`validation.json` records subframe support, rigid dimensions, nonadjacent clearance, camera bounds, loop pose/velocity, original Action signatures and appearance fingerprints. `showcase_verification.json` checks a fresh process, all entries, original slots/timing, switching and exact source geometry. `gui_playback.json` records actual GUI looping after reopening. `media_verification.json` decodes all delivered videos. `preservation_verification.json` audits original Idle, every other protected source, Full Jump/previews and Godot. These are Blender/file measurements; they establish neither artistic approval nor gameplay/device performance.

Saved-source measurements: **3,841 subframe samples**, maximum full-sole drift **0.00030 mm**, zero nonadjacent overlaps, exact closing pose, endpoint tangent difference **2.3×10⁻⁹**, finite near-seam vertex-velocity residual **0.000135 m/s**. Original v1 vertex reproduction differs by less than **0.00037 mm**. Head yaw at the two observing samples is **+25.7° / −23.3°**, torso yaw **+5.64° / −4.96°**. Hips have zero vertical range; rigid dimensions and appearance fingerprints remain unchanged. Source validation, library verification, GUI and media reports identify the same source/Action hashes.

Fresh-process Showcase verification covers **37 switches** across all ten entries, preserving the previous nine manifest entries and source hashes. Evaluated source agreement is within **0.00037 mm**, with one character/rig. The reopened interactive viewer completed **two actual loop wraps**, then paused and restarted to frame 1 with the correct range/FPS/loop setting.

The review source uses dense subframe keys to hold exact rigid support. This is authoring data, not a validated mobile export budget. Future export should choose and measure sampling/compression against the support/transition tolerances and actual runtime cost; the presence of compatible bone names alone is insufficient.
