# Higher Blender review preview V002 — pending review

This is a **presentation-only** version of Full Jump Expressive. Preview elevation increases from **0.58 m to 0.72 m**, a moderate **14 cm / 24.1%** increase. The gameplay-friendly `Full_Jump_Expressive_Test` Action, original source, original preview and original videos remain unchanged. No second skeletal motion variant was needed or created.

## Open and watch

- [Higher Blender preview](full_jump_higher_preview_v002.blend): open, then press **Space** to play F1–93 at **30 FPS / 3.10 seconds**. The three-quarter camera is selected. Select `Showcase_FRONT`, `Showcase_THREE_QUARTER` or `Showcase_SIDE` as the scene camera for another view.
- [All three views at original speed](higher_preview_all_views_1x.mp4), plus separate [front](front_1x.mp4), [three-quarter](three_quarter_1x.mp4) and [side](side_1x.mp4).
- [Original versus higher, three-quarter at original speed](height_comparison_three_quarter_1x.mp4). Both use the same pose, timing, camera and stage.
- [Height comparison sheet](height_comparison.jpg), [higher pose sheet](higher_preview_pose_sheet.jpg), [decoded comparison samples](decoded_comparison_samples.jpg).

Only the Z elevation keys of the temporary parent `Review_Only_Jump_Travel` change, using a separate `PREVIEW_ONLY_FullJump_Height_V002` Action. The old height Action is also retained in this file. **Neither preview height Action belongs in a character export or the Animation Showcase library.** The showcase continues using the unchanged in-place Action; no new library entry or approval is added.

## Evaluation

The increased distance above the floor makes launch, the open airborne silhouette and descent easier to read. The arc retains one rise and descent; its apex remains F32.5, and the airborne duration does not lengthen. Keeping the original camera framing makes this a direct height comparison rather than a zoom or perspective change. All rigid arm/leg articulation, torso/head overlap and soft grounded **nhúng nhúng** character are preserved.

Last support remains F19; lead/second contact F46/F47; deepest impact absorption F51; restrained rebound F67; recovery ends F93. The modestly faster descent returns to exactly the same heavy landing behavior with no delay, extra rebound or pose reset. In the render audit, all **201 grounded view-frames** match the original pixels exactly. The higher preview still leaves the entire character in frame from all three angles.

Remaining limitations are those of the unchanged full-jump study: rigid whole legs use hip overlap and rocking support, and the long recovery is for review. This is not a physics height/gravity specification or Godot integration. Full Jump and this higher presentation remain pending explicit review; “good” feedback is not silently converted into approval.

## Checks and preservation

[Validation](validation.json) covers 1,473 subframe samples, all nine original Action signatures/slots, identical appearance/rest/weights/UVs/materials/lights/cameras, unchanged timing, a single arc, floor clearance and all three camera bounds. [GUI playback verification](gui_playback_verification.json) records fresh reopening, advancing poses/elevation, pause and reset. [Media verification](media_verification.json) checks all five 93-frame/30-FPS videos by decoding every frame and verifies exact grounded pixels. [Preservation audit](preservation_verification.json) records unchanged protected files, including the original in-place source, original preview, original media, saved showcase/library manifest and Godot.

Backups were created first under `.validation/full_jump_higher_preview_v002/`. New files are isolated in this version folder. Only animation documentation receives new links and the presentation note. The complete jump’s earlier technical reports remain historical evidence for the unchanged pose Action.
