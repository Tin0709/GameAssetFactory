# Jump + Jump Land GIF V004 — straight arms

2026-10-10. The user requested combining `Player_Jump_(Dungeons_II).gif` with
`Player_Jump_Land_(Dungeons_II).gif` in the existing Blender library, then explicitly
requested straight arms with no visible elbow joints. This guide describes the
standalone Blender study, **awaiting visual review**. The subsequent explicit request
integrates V004 for stationary, walking and running jumps in WorldMap; see the
[runtime contract and game footage](../../../../../game_mobile_3d/assets/characters/jump_gif_v004/README.md).

Open `../player_animation_library_v1.blend`; Player Review → **Jump (study only)** →
**Jump + Land / Dungeons GIF V004**. Space plays; 3/4, Side, Front and Back are
available. The same scene is `JGIF4_JUMP_LAND_REVIEW` in the Scene dropdown.

## Animation

`Jump_DungeonsII_Combined_v004` is one complete jump: anticipation, push, airborne
asymmetric legs/open arms, first contact, absorption and recovery to the original
standing pose. Both forearms remain at zero local rotation throughout, so each arm
swings as one straight shape from its shoulder. Full hands and arm lengths remain.

| Phase | Frame at 30 FPS |
|---|---:|
| Ready / anticipation | 1 / 4 |
| Last support / push | 6 |
| Jump GIF entry | 8 |
| Apex silhouette | 14 |
| Blend toward landing | 20 |
| First contact / absorb | 23 / 25 |
| Recover / idle | 28 / 32 |
| End, original neutral pose | 36 |

There are 35 timed intervals (1.166667 seconds); 36 rendered frames occupy
1.2 seconds of video. The preview repeats this complete jump three times, including
its intentional ready/recovery interval; this is not a continuous moving gait loop.
Bezier pose curves use clamped handles. The separate
`PREVIEW_ONLY_Jump_DungeonsII_Combined_v004_Travel` Action supplies a 0.62 m authored
parabolic arc and dense sole support alignment. It is not an exportable Root/pose
track or a claim about the reference game's jump physics.

## References and preservation

Byte-identical source GIFs and SHA256/source paths are in `references/`.
The first GIF has 13 frames / 0.54 s and presents compact-to-open airborne poses;
the second has 8 frames / 0.42 s and presents contact absorption/recovery. Neither
shows a ground plane for measuring jump height. Timing, angles and arc are an
authored adaptation to this character, not extracted motion capture or knowledge
of Dungeons II internals.

- All **324 prior Actions** retain their curve fingerprints. Two new Actions make
  **326 total**, with **60 sidebar choices**. V001–V003 remain selectable.
- The new actor uses the unchanged shared mesh/material/UV/weights and a copy of
  the original **13-bone** rest armature. No source meshes, rest bones or earlier
  Actions were edited. The existing full-arm/hand proportions remain intact.
- The original model has rigid legs without knees/ankles/IK. Landing absorption
  therefore comes from the torso, shoulder motion and rigid leg angle.
- Pose has no Root, Hips, scale, world travel or ballistic tracks. Preview sole
  support holds the right sole's Y center; this is not full foot locking, and rigid
  soles can roll. Runtime transition/collision/weapon checks are documented in the
  linked runtime guide; arbitrary slopes and phone performance remain unverified.
- Work was performed in the connected foreground Blender and saved into the same
  library. A pre-edit live backup, including unsaved state, is recorded in
  `manifest.json`; no source-window reload was used to install the study.

## Verification and preview

[`jump_land_1x.mp4`](jump_land_1x.mp4) shows actual sequential Cycles renders from
3/4 and Side at 1× / 30 FPS, three repetitions. [`contact_sheet.jpg`](contact_sheet.jpg)
shows twelve phases from both cameras. Rendering/encoding use only this study and a
temporary encoding scene; original scene rendering/lighting settings are retained.

`validation.json` records **567 live evaluated samples**, including between-key
samples: zero neutral endpoint error; no floor penetration; no new nonadjacent
body overlaps relative to the original neutral baseline; all four cameras frame
the actor. Both elbow bends are exactly 0°, and the maximum upper/forearm seam
corner separation is **0.358 µm**. All original protected data fingerprints match.
This is geometry/animation evidence, not artistic approval or in-game footage.
`media_validation.json` records full video decode and file hashes.

Reproduction helpers: `build_jump.py` is an additive live builder guarded against
duplicate names; `validate_jump.py` checks the live scene; `render_preview.py`
renders batches; `package_preview.py` arranges their real pixels; `encode_preview.py`
encodes in foreground Blender and removes only its own temporary scene. Do not
rerun the builder into a library already containing V004.

## Subsequent gameplay transition feedback

The saved neutral-to-neutral Action remains the complete stationary study. Moving
gameplay now retains the live gait during grounded anticipation, blends its lower
body into V004 after lift-off, and starts returning to gait on actual contact.
These are runtime composition rules, not edits to the Blender keys, character
proportions, archived Actions or preview arc. The camera holds its ground-height
anchor through flight and continues horizontal following.
