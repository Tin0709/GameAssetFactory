# Player animation library — Blender review

Open `Open_Review.cmd` for the saved player scene and its **Player Review** sidebar.
The blend file is `player_animation_library_v1.blend`, scene
`PLAYER_ANIMATION_LIBRARY_V1`. Press **Space** to play/pause. In the sidebar
choose a group, then a clip; Front/Back/Side/3/4 change the review camera.

The current native full-arm character and resized/centered pistol, rifle and
shotgun are assembled from the R14 pass2 source used for the production R15
export. Existing upper-body Actions and lower-body NLA remain layered as
authored. The default is **Walk / Rifle**, in place on a neutral review stage.
This is an animation library, not the Godot combat controller: runtime aiming,
blends, automatic targeting and procedural turn limits are not simulated here.

There are **37 selectable reviews**: 12 idle/walk/sprint weapon variants,
8 turning variants, 6 holster/draw slices, 6 authored combat strafe directions,
4 jump pose clips and the full jump journey. Holster/draw use the game's
5.25x timing (126 FPS for the unchanged 24 FPS source slices); their duration is
about 0.365 seconds. Other groups retain their source FPS. Turn and jump
journeys retain their original demonstration context. Pose-only jump entries
are in place; use the journey for the authored block/world trajectory.

All **306 existing source Actions** plus the **6 jump V2 Actions** remain in
the saved file, including older variants, camera/travel curves and preview
bakes. The original Scene dropdown provides the historical review contexts.
These are archival versions, not additional production animations or newly
approved designs. The R15 exported runtime library has 36 named clips; that
export uses different clip names/slices and is preserved unchanged. The jump
V2 study remains **deferred in game**.

The panel is stored as `START_HERE_review_controls.py` inside the blend.
When reopening directly without the launcher, run that Text once if the
sidebar is missing. No global auto-execution/trust preference is changed.

`review_manifest.json` records source hashes, Action hashes, actor bindings
and exact review ranges/FPS. `verify_review.py` reopens and checks every
selection and the source data, then renders `review_preview.png`. Sources
and game assets are never saved over. No animation keys are redesigned.

Sources:

- `blender/characters/player/cuboid/player_combat_strafe_r14_pass2_study.blend`
- `blender/animation/studies/block_jump_v2/block_jump_v2_review.blend`
- `game_mobile_3d/assets/characters/r15/export_manifest.json`

**ARTISTIC STATUS: AWAITING HUMAN REVIEW. Blender-only setup.**
