# Animation Library Viewer

Open **Animation_Showcase.blend** (or double-click **Open_Showcase.cmd**). In the 3D Viewport, press **N** and choose **Animation Library**. Select an animation, then **Play**. **Restart** returns to its first frame. **Loop playback** repeats the playback range; turn it off to stop at the final frame. **Front / 3/4 / Side** change the preview camera. The Action Editor below remains available for native Blender inspection.

| Action | Playback | Timing | Review status |
| --- | --- | --- | --- |
| Expressive_Arm_Motion_Test | 1–24 | 30 FPS | User approved |
| Run_Expressive_Test | 1–18 | 30 FPS | User approved |
| LowerBody_Recovery_Test | 1–48 | 30 FPS | User approved |
| Jump_Takeoff_Test | 1–24 | 30 FPS | User approved |
| Jump_AirPose_Test | 1–22 | 30 FPS | User approved |
| Jump_Landing_Test | 1–44 | 30 FPS | Pending review |
| Jump_Landing_Impact_Test | 1–56 | 30 FPS | Pending comparison review |

Selection resets the full pose before binding the original Action and its Blender 5.2 slot. The run retains its frame-19 closing key, outside the 18-frame playback range. Arm/recovery are one-shots: repeating them resets to the beginning; they are not seamless cycles.

The user has approved this viewer and five existing tests, including [Jump Takeoff](../reviews/player_animation_library_v1/jump_takeoff_test/README.md) and [Jump AirPose](../reviews/player_animation_library_v1/jump_airpose_test/README.md). The new [Jump Landing](../reviews/player_animation_library_v1/jump_landing_test/README.md) is pending. There is one character/rig and the original textured review stage. Textures are packed. Original saved sources, production assets and Godot remain unchanged. This is a Blender review workspace; runtime behavior is not established here. No combined full production jump is authored.

AirPose is in place: it has no animated trajectory or midair ground-contact bounce. Its optional manifest `preview_floor_z_m` lowers only the preview floor to show flight clearly, and selection resets that floor for other clips. Character transforms and Action content remain unchanged. A separate two-Action video in its README shows continuity from approved takeoff with presentation travel kept outside the pose.

Landing uses the normal floor and identity rig transform. Its hips animate local ground absorption/recovery; world descent appears only in the temporary three-Action review linked from its README. It remains a one-shot study, not a seamless loop or integrated gameplay jump.

[Impact Landing](../reviews/player_animation_library_v1/jump_landing_impact_test/README.md) is a separate, heavier comparison. The original Landing Action and source files stay unchanged. Select either independently; both remain pending. The comparison videos retain original timing and label the soft baseline's hold after its frame 44 while the longer variant continues to frame 56.

## Persistent controls

`gaf_animation_library.py` is installed and enabled as **GameAssetFactory Animation Library** in this computer's Blender 5.2 preferences. Normal reopening needs no script execution. Automatic execution of scripts embedded in Blender files remains disabled. No executable text is embedded in the viewer.

On another machine, install this Python file once through **Preferences → Add-ons → Install from Disk**, enable the add-on and save preferences, then open the viewer. Keep the folder at its repository location for registration/refresh. The saved Actions can play without source files; refreshing checks their recorded sources. If the panel is unavailable, the native Action Editor can inspect the saved Actions; use the panel for automatic pose reset and timing.

## Register a future test

1. Save a separate study with a uniquely named, baked rig-only Action. Preserve the existing player rest rig and mesh binding. Back up the source before authoring. Registration does not save or modify that source.
2. From the repository root, run Blender in the background with the source study, registration script and six arguments: **Action name, rig object, mesh object, first playback frame, last playback frame, FPS**. For example, in PowerShell:

   ```powershell
   & 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b 'blender/animation/reviews/my_test/review.blend' --python-exit-code 1 --python 'blender/animation/showcase/register_animation.py' -- 'My_Test_V001' 'Test_Rig' 'Test_Mesh' 1 24 30
   ```

3. The helper checks compatibility, backs up the manifest and viewer under `.validation/animation_showcase/registrations/`, then adds an entry marked **pending**. It never overwrites an existing Action. Use a new versioned name for revisions. It records the source SHA256, rest-rig hash, original slot, Action content hash, frame range and timing.
4. In the viewer, click **Refresh Library**. Only named registered Actions are appended, without another character, mesh or rig. Failed validation rolls back new imports and retains the previous list. Inspect the result, then **Ctrl+S** to retain the imported Action and updated list. Preserve the helper's backup before this save.
5. Only after explicit user approval, back up the manifest/viewer, change that entry's `status` to `approved` and record the confirmation in `approval_note`. Refresh and save again. Importing or passing technical checks never grants artistic approval.

Only matching rest rigs and pose rotation modes, one OBJECT slot/layer/strip/channel bag, baked bone location/rotation/unit-scale channels and optional Cycles modifiers are supported. Constraints, NLA, drivers, other modifiers, separate world travel or a different rest rig require a separately reviewed compatible source; the helper refuses them. A changed source SHA or changed existing Action is an error, not permission to overwrite. Frame bounds and `fps` must be integers; fractional timing uses `fps` / `fps_base`. Never bulk-import the legacy Action library.

## Validation and maintenance

`verification.json` records a fresh Blender-process reopen, 18 selection transitions, original slot/range/timing checks and exact evaluated geometry agreement at integer and half frames. `refresh_verification.json` covers selective import, incompatible-rig rollback, duplicate/changed-source rejection and pending status. `registration_verification.json` covers pending registration and duplicate refusal. Actual GUI playback, pause, restart, looping and one-shot stopping were checked; evidence and protected-file hashes are in `.validation/animation_showcase/`.

Those initial reports cover the original three-entry build. The [takeoff showcase verification](../reviews/player_animation_library_v1/jump_takeoff_test/showcase_verification.json) covers the earlier four-entry viewer, when takeoff was pending. It remains historical evidence for that revision.

The [AirPose showcase verification](../reviews/player_animation_library_v1/jump_airpose_test/showcase_verification.json) covers the historical five-entry viewer when AirPose was pending. The [Landing showcase verification](../reviews/player_animation_library_v1/jump_landing_test/showcase_verification.json) covers the historical six-entry viewer, five approved references, pending Landing, 19 switching transitions and stage reset.

The current [Impact showcase verification](../reviews/player_animation_library_v1/jump_landing_impact_test/showcase_verification.json) extends that record to seven entries, including two separate pending landing studies. Use its adjacent `verify_showcase.py` for current switching/reopen checks. The six-entry report remains historical evidence and its files are preserved.

The three `preview_*.png` renders match the corresponding source-study pixels exactly. `viewer_screenshot.png` shows the saved review interface. All 1,716 protected source/runtime files retained their SHA256 hashes.

Run Blender with the saved showcase and `--background --python-exit-code 1 --python verify_showcase.py` after library code changes; its current baseline expects the initial three entries. Extend its source samples for future registrations. `test_import_safety.py` checks timing rejection, rotation-mode compatibility and detection of evaluation edits. `build_showcase.py` is the initial builder, not the refresh workflow: it refuses to overwrite an existing viewer. Follow [the project animation workflow](../../../docs/animation/ANIMATION_WORKFLOW.md) for later sessions.
