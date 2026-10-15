# Actions & Stuff Player Idle v001 — Pending research

Open the existing `blender/animation/showcase/Animation_Showcase.blend`, then choose **Idle_ActionsStuff_Source_Test_v001** in **N → Animation Library → Actions & Stuff**. Press Play; Front / 3/4 / Side remain available. One new Pending Action, F1–270 at30FPS, nine seconds. Older entries remain under Show Archived. The authoring file is `idle_actions_stuff_source_v001.blend`; it is a minimal source study with one character Action, not another Showcase.

[Front, original speed](media/idle_front_30fps_1x.mp4) · [3/4](media/idle_three_quarter_30fps_1x.mp4) · [Side](media/idle_side_30fps_1x.mp4).

The user accepted actual Godot Walk/Run/Directional/Jump/Landing gameplay on2026-10-15. Its recovery archive and per-file hashes are in `docs/animation/baselines/actions_stuff_gameplay_accepted_v001/`. This Idle study does not change any Godot file. Blender approval is required before integrating Idle into the same existing research scene.

## What the source actually does

This study uses the verified1.12 pack SHA256 `9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d`. Player aliases/controllers are traced from `entity/dtr.json`, `animations/f2da1071.json` and `animation_controllers/616f2ff7.json`.

- **Ambient:** `bob → animation.oreville_ans.tdrcwc` continues on entity lifetime. Molang trigonometry uses degrees: slow122.5deg/s and fast245deg/s. The whole ambient cycle is144/49seconds (about2.9388), with small waist sway/bounce, head tilt and mirrored shoulder/arm response. Both straight legs share subtle lateral/roll motion. There is no authored chest-expansion breathing or invented leg stepping in this layer.
- **Autonomous attention:** `bjmscc → controller.animation.oreville_ans.fotixv` waits for prior movement, sufficient attack-free history and more than3seconds of eligible stillness. Its actual twelve-way random chooser selects `tculwn → animation.oreville_ans.jcyjaa` in this reproducible take. The4.2083-second gesture has sideways head attention, delayed torso/arm response, weight shift and native leg adjustments. Its literal Catmull-Rom/pre/post keys remain. It exits through a0.2-second source fade and0.35-second rearm state.
- **Gaze:** `hsfnbp → look_at_target/cndmcx` remains active with entity-relative head rotation. Caller yaw and pitch are fixed0, so visible large head turns come from the authored autonomous gesture. Source `agyfrv` standing body realignment is evaluated, with no invented camera motion.
- **Continuity:** the source ground locomotion controller retains its0.22-second Walk/Run fades and persistent gait phase. Movement/head changes interrupt long Idle through its actual conditions; tests cover those paths. The study does not bake new Walk or Run variants.

The declared input history is an already existing, previously moved player, at12seconds age with at least12seconds since attack, standing unarmed with aligned look. It is **not** a guaranteed gesture3seconds after a never-moved spawn. Python MT19937 seed2 yields the real chooser's first1..12 draw of1; Bedrock's random algorithm is unknown. No state, clip clock or keyframe is forced to select the gesture.

Primary timeline: study0s starts the eligible waiting state;3.00833s starts the attention clip;7.21667s begins source fade/recovery;7.56667s rearms; the remainder is ambient. Source evaluation begins at entity lifetime12+1/240seconds, an explicitly recorded fixed-step convention. This nine-second composite is finite and **not a seamless9-second loop**. Looping playback replays the research take; it must not be sold as the complete stochastic Idle controller or a universal production idle loop.

## Profile, face and retarget limits

The new Idle uses the pack's **ordinary default player, v.tnlxsa=0**. Source manifest/language data identify2 as **Rana: Frog Girl**, which was the previous research evaluator's fixed profile. The accepted Godot baseline remains unchanged. This distinction is documented rather than silently changing accepted gameplay or carrying morph-specific random branches into the new Idle. The audited attention gesture's normal and egjh9 body channels are identical.

The pack supports facial expressions/blinks through separate face bones, geometry, textures and render/capture logic. The existing13-bone fixed-atlas character has no eyelids/eye-driver mesh or matching face controls. Those real source facial channels are documented in `head_face_audit/REPORT.md` and `rig_limitation_evidence.json`; they are **not rendered** in this unchanged-rig study. No fake blink, skin repaint, new face rig or head squash was substituted. The unused external `controller.animation.persona.blink` alias must not be mistaken for the actual reachable player blinking controller.

`idle_retarget.py` preserves the previously used coordinate/degree/matrix adapter, source-root-parented legs, native rest hierarchy, whole rigid arms and entity-relative head. ForeArm helpers stay identity. Local position/rotation are fully keyed; scale is identity because the displayed ordinary body clips do not author body/limb scale. No knees, elbows, pose repair, foot locking or extra breathing curves.

A single constant presentation floor is set to-0.0101444m, below the lowest native source sole. Lowest-foot clearance across the take is about0.5–10.14mm. It preserves source leg curves, rather than inventing source IK or flattening every frame. The archive does not supply closed-engine PRNG, exact VM precision/ordering, negative-weight semantics or final geometry-capture behavior. The evaluator preserves declared positive-only unnormalized mixing, uniform Catmull duplicate endpoints, one ordered transition per controller/substep, continuing outgoing clocks and linear source-duration fades. External vanilla arm/leg layers at weight0.001 are not implemented in the pack and are not invented. Detailed boundaries are in `source_audit/IDLE_RUNTIME_SCOPE.md`.

## Validation and preservation

The literal payload matches584 source clips and80 controllers. Ten source behavior tests cover prior-movement and recent-action gates, natural random selection, source duration/fade/rearm, head/movement interruption, attack reset, exact channel keys, accumulated-axis this, ambient period/amplitude and serialization. The primary2161-row trace exactly regenerates. Baking uses240Hz plus exact projected source key breakpoints; sub-tick key probes freeze controller decisions and advance channel clocks/lifetime only.

Fresh authoring/library reopen checks compare1139 native evaluated poses against the source reconstruction, verify straight forearms and identity scales, inspect all old selectors/slots/statuses, archived recovery and source/library playback timing. Original78 Action signatures, rest rigs, meshes, materials, images, texts, cameras and prior sequence registrations are fingerprinted and preserved. No existing source file, approved Action, Godot runtime, WorldMap, production asset or installed panel code is modified. The existing Showcase receives only the one new Action and its Pending registration/focus entry. Backups and full build/verification scripts remain at `/Users/tin/Documents/ChatGPT/New project/experiments/actions_stuff_idle_source_v001/`.

This is proprietary source-derived **private research only**, not a commercially licensed production animation. Stop here for Blender artistic review; integrate into `ActionsStuffWalkRunTest` only after explicit Idle approval.
