# Jump Default V001 — flat-ground Blender review

Created 2026-10-10 from the user's ordinary-jump video and written brief. **Awaiting user review; Blender only.** This does not enable jumping in Godot.

Open [the player library](../player_animation_library_v1.blend), then **Player Review → Jump (study only) → Jump Default V001 / Flat Ground**. Press **Space** to play; **Side / 3/4 / Front / Back** switch cameras. If the panel is missing, use [Open_Review.cmd](../Open_Review.cmd), or run the embedded `START_HERE_review_controls.py`. The saved selection is the new scene at its apex, F12. The 3/4 camera is an authored review camera, not the exact Godot camera.

- Scene: `JUMP_DEFAULT_V001_REVIEW`; rig: `JD1_Player_Rig`; mesh: `JD1_Player_Mesh`.
- Pose Action: **`Jump_Default_v001`**, slot **`OBJD1_Player_Rig`**. 30 FPS, F1–25, **0.80 seconds** between endpoints, one shot without a Cycles modifier.
- Independent carrier: `JD1_PREVIEW_ONLY_Carrier`; Action `PREVIEW_ONLY_Jump_Default_v001_Travel`, its own slot. No horizontal travel or jump height in the pose/root channels.
- Source: the library's full-arm unarmed R12 actor from R14 pass2, used by R15. Same mesh/materials, rest bones and limb lengths. Front is −Y, up +Z. `Leg.R` leads forward; `Leg.L` stays lower/back. These correspond to the screen-left high leg and screen-right low leg in our front-facing view, not a claim about Mojang's bone names.

| Frame | Phase |
|---|---|
| 1 / 3 | Existing idle / brief torso-and-arm anticipation |
| 5 / 6 | Last supported push / fully airborne |
| 9 / 12 | Asymmetric air pose / continuous apex |
| 16 / 19 | Descent / first contact |
| 21 / 22 | Torso absorption / arm-head follow-through |
| 25 | Original idle restored |

Standing height **H=1.80 m**, sole floor **Z=0**. Carrier height is **0.63 m (0.35H)** at F12, with an exact quadratic Bézier parabola between F5 and F19. This is our preview design, not measured Dungeons physics. New keys at F2/F24 open/close shoulder clearance; the main timing milestones are unchanged.

## Rig limits and preservation

The 14-bone rig has actual upper/lower arms, but rigid whole legs, no knees/ankles, no IK or drivers. Grounded pelvis and soles stay fixed; landing weight comes from the torso and arms. No crouch is faked by pushing feet through the floor. The air pose uses a 48° forward lead hip and −14° trailing hip.

An **8 mm outward shoulder pose adjustment** during F2–24 clears the square arm corners beside the head. It uses existing UpperArm location channels, preserving geometry/rest data and returning to the original **32 mm inset** at F1/F25. Existing idle Chest/ForeArm overlap of about 3.875 mm remains part of the source model; this study does not remodel it. Adjacent rigid elbow/shoulder seams are not treated as separate-body collision pairs.

All **312 previous Actions** remain unchanged; two new Actions bring the total to **314**. The panel has **54 choices**. For a future export, detach the rig from the preview carrier while preserving its baseline transform and export the pose alone; merely hiding the carrier is insufficient. No runtime export was made.

## Previews and evidence

- [3/4 video, 1×](jump_gameplay_1x.mp4) and [side video, 1×](jump_side_1x.mp4): 30 FPS, three repetitions with half-second idle holds, no sound, blur, dust or camera movement. Only the video repeats; the Action is one shot.
- [Eight-pose contact sheet](contact_sheet.png), [small actor check](small_actor_check.png), [apex 3/4](apex_gameplay.png), [apex side](apex_side.png).
- Both H.264 videos decoded completely: 165 frames each, 960×1024, 30 FPS, 5.5 s. Inspected decoded anticipation, air, contact and absorption frames in both views, plus the small-actor sheet. Distinct airborne silhouette and fixed soles read clearly; landing compression is necessarily modest with rigid legs. See [media validation](media_validation.json).
- [Evaluated audit](validation.json): 97 samples at ¼-frame spacing; fixed grounded soles, positive airborne clearance, matching endpoint poses, exact carrier curve, camera framing and no additional nonadjacent cuboid penetration beyond the existing idle baseline (10 µm numerical margin). Original Action/source hashes and rest rig pass. [Library audit](../verification.json) checks all 54 selections and camera switching.
- Reproduce with `validate_jump.py` in background Blender using the saved library. `render_previews.py` renders both cameras; `package_previews.py` (Python/Pillow) makes labeled frames/sheets; `encode_previews.py` (background Blender factory startup) encodes H.264. Temporary frames are under repo `.validation/jump_default_v001/`.

Reference video is **30 FPS, 516 frames, 17.2 s**; inspected ordinary jump at **10.33–11.00 s**. Dust hides exact contact and the clip does not reveal original joints. Preserved inputs/hashes: [references](references/manifest.json). The differently named current-character image mentioned inside the brief was not attached; identity was taken from the existing Blender actor. Runtime blending, collision/controller timing, export and phone performance are **not tested**.

This checkout is `main` (single worktree); changes are already in its working tree. No merge, commit or push was performed.
