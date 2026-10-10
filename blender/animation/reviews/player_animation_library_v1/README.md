# Player animation library — Blender review

Open `Open_Review.cmd` for the saved player scene and its **Player Review** sidebar.
The blend file is `player_animation_library_v1.blend`, scene
`PLAYER_ANIMATION_LIBRARY_V1`. Press **Space** to play/pause. In the sidebar
choose a group, then a clip; Front/Back/Side/3/4 change the review camera.

The current native full-arm character and resized/centered pistol, rifle and
shotgun are assembled from the R14 pass2 source used for the production R15
export. Existing upper-body Actions and lower-body NLA remain layered as
authored. The saved review now opens **Jump Default V001 / Flat Ground**;
**Walk / Rifle** and all earlier selections remain available.
This is an animation library, not the Godot combat controller: runtime aiming,
blends, automatic targeting and procedural turn limits are not simulated here.

There are **54 selectable reviews**: 12 idle/walk/sprint weapon variants,
8 turning variants, 6 holster/draw slices, 18 armed combat strafe combinations,
4 jump pose clips, the full jump journey, 4 short jump journey slices and the
new [flat-ground Jump Default V001](jump_default_v001/README.md). In
**Combat Strafe**, choose **Weapon** (Pistol/Rifle/Shotgun), then one of six
authored directions. The original lower-body Actions are layered with each
weapon's existing ready pose; these are Blender compositions, not new gameplay
clips. In **Jump (study only)**, choose **Jump up/down / lead A** or
**opposite lead** for actual block/world travel. Pose-only entries remain available.
Short slices loop with a preview reset; they are not seamless locomotion loops.
Holster/draw use the game's
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
and game assets are never saved over. Existing animation keys are not redesigned.
The new flat jump adds a pose Action and separate preview-carrier Action
(314 Actions total), in its own scene at 30 FPS; old clips retain their FPS.
The latest fresh-open audit passes all 54 selections, verifies evaluated ready
arm/carrier channels for all 18 armed strafes and vertical/horizontal travel in
the jump journey slices. Additional rendered checks are `strafe_pistol_preview.png`,
`strafe_shotgun_preview.png` and `jump_preview.png`. `additional_reviews.py` is
used by both the original builder and the additive `extend_review.py` updater.

Sources:

- `blender/characters/player/cuboid/player_combat_strafe_r14_pass2_study.blend`
- `blender/animation/studies/block_jump_v2/block_jump_v2_review.blend`
- `game_mobile_3d/assets/characters/r15/export_manifest.json`

**ARTISTIC STATUS: AWAITING HUMAN REVIEW. Blender-only setup.**
