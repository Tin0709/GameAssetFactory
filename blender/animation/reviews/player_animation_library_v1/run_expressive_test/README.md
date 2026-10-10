# Run Expressive Test

2026-10-10. **Original in-place Blender run test; awaiting user review.** The preceding `Expressive_Arm_Motion_Test` is explicitly approved **as a proof of capability**. That approval does not automatically approve this run or its lower-body solution.

Primary references: [Animation Style Guide](../../../../../docs/animation/ANIMATION_STYLE_GUIDE.md) and the [approved arm proof](../expressive_arm_motion_test/README.md). Carry-over principles are independent shoulder-driven arcs, negative space between arms and torso, rigid segment geometry, torso opposition and a restrained readable head. New keys are authored for locomotion; no proprietary motion is copied.

## Review files

- [Run video — front, three-quarter and side](run_expressive_1x.mp4), 30 FPS, actual sequential Blender renders, six cycles at **1x speed**.
- [Native Blender study](run_expressive_review.blend): scene `RUN_EXPRESSIVE_REVIEW`, rig `RUN_Test_Rig`, Action **`Run_Expressive_Test`**. Press Space to play; the scene opens on a flight pose. This separate scene is not an entry in the historical Player Review sidebar.
- [Key pose sheet](run_pose_sheet.jpg), with front / three-quarter / side rows.
- Complete frame sheets: [front](front_all_frames.jpg), [three-quarter](three_quarter_all_frames.jpg), [side](side_all_frames.jpg).
- [Existing sprint versus new run](baseline_comparison.jpg), using the same camera, stage, lighting and actor scale. These are phase-spaced poses, not simultaneous footage of two gameplay controllers.

## Current baseline and differences

The source library's unarmed Walk and Sprint compositions were copied into the review scene with their existing upper-body Actions and lower-body NLA intact. Only the new copies were repositioned for the common camera. They are a **Blender source baseline**, not a new measurement of live Godot locomotion. Current WorldMap still loads the V004 player, whose visual script inherits the V003/R15 stack; those runtime files remain unchanged.

The [baseline measurements](baseline_metrics.json) sample the actual evaluated bone directions, not names or animation labels:

| Measure | Existing walk | Existing sprint | New run |
|---|---:|---:|---:|
| Full cycle | 0.667 s | 0.542 s | **0.600 s** |
| Maximum fore/aft leg split | 83.0° | 112.1° | **102.6°** |
| Right upper-arm outward angle range | 0.0–15.2° | 0.0–15.0° | **13.3–36.4°** |
| Head yaw excursion, peak-to-peak | 9.0° | 11.4° | **4.0°** |

The old sprint already has a large backward kick. The improvement is **controlled articulation and readability**, not a claim that every motion is larger or faster. The new run has a stronger split than walk, more open arm silhouettes through the cycle, opposite arm/leg action, and a faster recovery swing distinct from its support phase. It is slightly slower than the old sprint. The head remains comparatively quiet while the chest supports the motion.

## Cycle design

**18 playback frames at 30 FPS**, with a matching closing key at **F19**. Playback and rendered media use F1–18 only; F19 establishes the periodic boundary and is not an extra held frame. The Action spans 0.60 seconds including that boundary. Cycles modifiers repeat the curve values; closing position and tangent match.

| Phase | Frames / behavior |
|---|---|
| Right contact and support | F1–7.12: right leg rolls from +25° to −25°, left leg recovers. |
| First flight | F7.12–10: neither foot supports the body; backward release and forward reach create the stride split. |
| Left contact and support | F10–16.12: opposite phase of the same lower-body pattern. |
| Second flight | F16.12–19: transitions into the next right contact with no neutral reset. |

Each leg supports for 34% of a full cycle; the two flight intervals total 32%. The free leg reaches approximately −58° behind and +46° ahead during release/recovery. Those are authoring inputs, not reconstructed reference-game values.

The arms have different amplitudes (right slightly stronger), move opposite their respective legs, and lag the step phase slightly. Spread increases toward the swing extremes and reduces at passing. Forearms remain aligned as in the approved block-arm proof. Spine/chest twist is periodic and tied to the step; head compensation has a small phase delay. There is no random wobble or torso yaw applied to the support feet.

The existing rig has whole rigid legs. To avoid scraping during passing, the Action uses **existing leg-location channels** to retract the whole leg upward into the torso, without shortening or scaling its geometry. Maximum retraction is **88.7 mm** at passing; support compression peaks at about 55 mm. This changes the exposed length during overlap, while the complete cuboid retains its dimensions. No knee, ankle, constraint, new bone, pivot correction or rest-rig change was introduced.

## Iteration and visual evaluation

1. A first version established alternating contact, airborne splits and the approved open arm treatment. Its toe-off clearance switched too abruptly, producing a measured contact-height pop.
2. Clearance now ramps smoothly into and out of recovery. Periodic Bezier tangents replace the initial piecewise-linear wrap. A 0.4 mm support margin covers the small interpolation undershoot at the rigid heel/toe roll.
3. The first stride split was barely greater than the existing walk. Increasing the **flight** release/reach produced the final 102.6° split while retaining the established contact sweep and travel-speed relationship.
4. Final front, three-quarter and side sequences were inspected across every rendered frame. Front view shows alternating silhouettes and continued arm separation; three-quarter view shows attached shoulder arcs; side view most clearly distinguishes support, passing and flight. The face stays readable. No conspicuous hand/torso intersections or detached limbs appear in these views.

**Assessment:** the full body now supports the expressive arm language more convincingly than the earlier arm-only proof. The open shoulders, stride split, flight and quicker free-leg recovery give the sequence more energy than the source walk. Against the old sprint, the main gains are separation and control. This remains an artistic assessment pending the user's run review, not a quantified claim of similarity to Minecraft Dungeons II.

**Remaining limitations:** legs are deliberately bilateral for consistent support; character asymmetry lives mainly in the arms. Whole-block boots roll across heel/toe edges, and there is no anatomical knee fold or ankle push-off. The 88.7 mm retraction is visible as a stylized hip overlap at passing. It avoids deformation but still limits how natural compression can become. Weapon grips, starts/stops, speed changes, turns, slopes and controller blending are untested here.

**Before jump/landing:** targeted lower-body refinement is warranted—especially contact sequencing, pelvis compression, release of the leg retraction and recovery into an ongoing stride. Test those with the current rig first. A knee/ankle redesign is not justified by this run alone and would require a separate decision about the block silhouette and compatibility. No jump or landing production work was started.

## Contact and preservation checks

[Saved-file verification](saved_file_verification.json) ran in a fresh, read-only Blender process. [Full validation](validation.json) samples **577 times**, including between authored keys:

- Original **327 Actions** preserved (including the approved arm test); **328 total** after adding only `Run_Expressive_Test`.
- Original mesh datablock, material/texture pixels, UVs, weights, rest matrices, hierarchy and previous animation data preserved. No unexpected original-data changes. The approved source `.blend` hash is unchanged.
- Maximum rigid-segment distance error **0.233 micrometers**, consistent with floating-point calculation; no scale animation.
- No sampled floor penetration; contact height within **0.401 mm** of the plane.
- Maximum stance contact-edge fore/aft drift **0.344 mm** after applying the diagnostic constant travel speed **2.9001 m/s**. Heel and toe edges are measured separately through the rigid roll. This is not a claim that all sole vertices remain planted or that an in-place clip is locked to stationary world ground.
- No nonadjacent body-part intersections at the checked eighth-frame samples. Adjacent shoulder/hip attachment overlap is intentional; all-frame rendered review checks its appearance.
- Exact closing pose; repeated evaluated vertices agree below **0.3 micrometers**. Curve endpoint/tangent checks pass. The closing key is excluded from playback to avoid a duplicated frame.
- The head's pitch excursion is about **2.8°** and yaw about **4.0°** peak-to-peak. Hip-height excursion is about 95 mm, including the flight/support motion.
- [Media verification](media_verification.json): 108 decoded frames at 30 FPS, 1920×720, all compared with their corresponding rendered composite. The video contains no synthetic pose interpolation or dropped closing-frame shortcut.

The diagnostic speed is a property of this authored test, **not a change to the game's movement speed**. A future controller must synchronize travel/cadence or adapt the contact treatment. In-place root X/Y remain fixed; vertical support is authored on Hips, and world travel is excluded from the Action.

## Safety, backups and reuse

Before changes, both the approved saved file and the live Blender state were backed up: [disk backup](../../../../../.validation/run_expressive_test/approved_arm_disk_before_run.blend), [live backup](../../../../../.validation/run_expressive_test/live_before_run.blend), [backup manifest](../../../../../.validation/run_expressive_test/backup_manifest.json). The new review scene and copied rig live only in `run_expressive_review.blend`. Original library, approved arm `.blend`, production GLBs, Godot scenes/controllers, other Actions and unrelated assets were not replaced.

Godot compatibility of the **existing game** is preserved by leaving it unchanged. This new run has not been exported or tested in Godot/mobile. Future export must retain Hips/Leg translation as well as rotation, the neutral shoulder inset, the F19 boundary and the 0.60 s duration; importing only rotation would lose the tested contact behavior. No phone performance claim is made.

Scripts: `build_run.py` builds/animates only the isolated test and renders selected views; `compare_baseline.py` samples the source compositions; `validate_run.py` and `verify_saved.py` verify evaluated/saved data; `package_review.py` and `encode_review.py` package actual render frames. Run the builder only from the backed-up approved source after creating new backup paths; it rejects an existing `Run_Expressive_Test`. Do not overwrite earlier study files or backups.
