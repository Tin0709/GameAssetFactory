# R14 combat strafe study implementation plan

> **For agentic workers:** Execute inline with superpowers:executing-plans. This is a Blender asset study, not production software.

**Goal:** Author mirrored, staggered combat shuffles and deliver native Blender previews for human review.
**Architecture:** Preserve the entire live R13 session, duplicate the current R12 rifle-ready actor into R14 scenes, and layer new lower-body Actions over the unchanged ready Action. Preview-only parents supply world travel. Small Spine counterrotation supplies balance without editing the approved upper Action.
**Tech Stack:** Blender 5.2 Python, existing rig and geometry, local video/HTML review.
**Spec:** User R14 pasted brief at `C:/Users/ADMIN/.codex/attachments/4aa50337-94b9-4636-b5b7-5b0430b11e54/Pasted text.txt` plus 20-degree yaw addendum in chat.

## Constraints and review focus

- 24 FPS, 20-frame cycle; Right foot leads right, Left foot leads left; delayed following foot.
- New Actions only, separate study, no Godot/export/production changes, no extra bones/IK or automatic versions.
- No Root travel, animated scale, or full-body travel-facing yaw. Chest/Hips relative yaw below 20 degrees including blends.
- Check rigid-leg floor corners, lateral overlap, hip seams, contact drift, loop pose/velocity, and upper composition.
- Preserve 228 existing Actions, 445 existing mesh objects, 198 existing rigs. Saved live-session recovery before edits.

## Task 1 — Motion and composition
- [x] Create `blender/characters/player/cuboid/create_combat_strafe_r14.py`: clone ready actor, analytic staggered foot paths, authored Bezier Actions, native A/B/C and continuous preview scenes.
- [x] Verify actual foot initiation and nonoverlapping flight intervals; dense sample ground/contact and torso relative yaw, including reversals.

## Task 2 — Evidence and review
- [x] Create `validate_combat_strafe_r14.py`: independently inspect evaluated geometry, curve continuity, protected datablocks, and composition.
- [x] Render elevated gameplay, front three-quarter, side and front comparisons; continuous Right/Stop/Left/Right; inspect evidence and decode videos.
- [x] Save `player_combat_strafe_r14_v1_study.blend`, local review page, measured report; leave native playback at 24 FPS.
- [x] Stop with ARTISTIC STATUS: AWAITING HUMAN REVIEW.

## Execution ledger

- Recovered unsaved live R13 session as `combat_strafe_r14_review/pre_r14_session_recovery.blend`.
- Ruling: use an isolated versioned Blender copy in the current workspace; a code worktree cannot isolate the live Blender session better than separate datablocks and save path.
- Ruling: verify animation numerically and visually, rather than adding implementation-mirroring unit tests for a reversible asset study.


- Completed motion, 14 rendered clips, native review scenes, saved study and measured report. Fresh read-only technical review found no blocking issues. All tracked production files unchanged. Numerical and visual evidence remains separate from artistic approval.
