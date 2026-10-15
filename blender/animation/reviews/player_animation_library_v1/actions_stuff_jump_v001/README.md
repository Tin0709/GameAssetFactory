# Actions & Stuff Jump / Landing source study v001

Pending · research only · Blender reconstruction · 2026-10-15.

Open the existing `blender/animation/showcase/Animation_Showcase.blend`. In **N → Animation Library**, select **Actions & Stuff Jump / Landing v001** for the primary review. Play/Pause, Restart and Front / 3/4 / Side work from that panel. The take is15seconds, frames1–450 at30FPS and original animation speed; looping starts off. **Return to Animation Library** restores the ordinary Action selectors. **Show Archived** retains the35older registrations.

The six independently selectable source phases are all Pending:

| Action | Source alias / ID suffix | Authored duration |
|---|---|---:|
|Jump_ActionsStuff_Source_Test_v001|jump / mykcsi|1.1667s|
|SprintJump_A_ActionsStuff_Source_Test_v001|wxzmsp / bevrbk|1.5833s|
|SprintJump_B_ActionsStuff_Source_Test_v001|rnmred / nvxqkp|1.5833s|
|Landing_Stationary_ActionsStuff_Source_Test_v001|ydsari / xvdslp|1s|
|Landing_Moving_ActionsStuff_Source_Test_v001|srluww / jmjgft|.75s|
|Fall_ActionsStuff_Source_Test_v001|fall / dwzzez|3.5s, source holds its last frame|

These are literal isolated source phases, not six gameplay candidates or six complete jump animations. They preserve all relevant rotation/translation/scale keys, exact authored seconds and Catmull-Rom interpolation. Dense240Hz linear native bakes retain authored breakpoints; the stored fractional-frame endpoint remains inspectable.30FPS review sampling quantizes display frames, not the source key times. Source-authored root squash and asymmetric leg stretch are retained; elbows/knees are not introduced.

## Primary contextual review

| Time | Scenario |
|---|---|
|0–3s|Stationary ordinary jump at1.2s, local stationary landing at1.8s|
|3–6s|Walk; ordinary jump at4s; local moving landing at4.6s; continue Walk|
|6–8.6s|Sprint; Jump A at7.2s; moving landing at7.8s|
|8.6–12s|Sprint; Jump B at9.6s; moving landing at10.2s|
|12–15s|Release and source idle/recovery layers|

Both arms use the actual unarmed holding flags0/0 in this new contextual profile. The earlier immutable source studies retain their original recorded profiles. The context preserves concurrent locomotion, sprint onset/stop, local landing→jump→fall layer order, independent lifetime bob, head/root coordination, source fades and actual gait overrides .05/.55 after sprint jump exits. Landing is not an exclusive replacement for Jump/Fall; those layers can overlap. Moving landing mainly animates body/head and leaves other layers responsible for limbs. Ordinary Jump has no authored grounded preparation state; early compression occurs after airborne detection. No missing anticipation pose was invented.

Videos in `media/`: front, three-quarter and side;640px,30FPS,1x. The authoring file is `jump_actions_stuff_review.blend`; the existing Showcase is the main review interface.

## Reference and reconstruction limits

The archive is `/Users/tin/Desktop/Game Dev/local_references/Actions Stuff 1.12 (resources).mcpack`, SHA2569d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d. Its filename says1.12; its internal manifest header version is1.1.60. We use this exact supplied package. Exact player files are `entity/dtr.json`, `animations/f2da1071.json`, and `animation_controllers/616f2ff7.json`. `source_audit/AUDIT.md` documents exact aliases/controllers, curves, phase transitions and evidence.

- **Physics is separate:** the pack does not supply the physical jump trajectory. The presentation Empty uses a declared1m apex/.6s parabola and supplies matching virtual position/velocity queries. Horizontal display is held in place. This is a preview input profile, not recovered Minecraft physics, not Godot integration and not a source clip retime. `q.is_jumping` is supplied for the first.05s as an explicit harness convention; exact engine input semantics remain unmeasured.
- **Floor and contact:** one constant native floor offset, −69.06mm, keeps this take above its display floor. There is no IK, per-frame foot clamp or source-pose repair. The grounded flag describes supplied engine queries; it does not prove either animated sole is planted. Lowest-sole clearance over all grounded samples spans.5–277.6mm, including authored Run flight. Idle can visibly hover above this constant display floor. This research has not certified world-space foot contacts/sliding or gameplay continuity.
- **Rig conversion:** unchanged native character appearance/rest rig, corrected source XYZ rotation convention, explicit source hierarchy and native parent compensation. Source head translations and root/leg scale are retained. Entity-relative head rotation under nonuniform root scale uses a native TRS equivalent; exact proprietary engine handling is unmeasured. No existing rig/mesh/material or source Action is changed.
- **Interpolation:** literal sampler matches inspected primary Blockbench/THREE Catmull code across4,575 samples, max component error1.42e−14. Context controller/pose sampling is240Hz; its internal event/curve timing is a dense approximation and does not insert every transient authored breakpoint separately. Six isolated phases do retain exact authored breakpoints. Bedrock controller stepping order/outgoing clocks/negative weight semantics remain declared conventions, not measured engine parity.
- **Scope:** ordinary alive local third-person, dry normal player. Remote landing differs and is not substituted. Special roll/heavy landing/water/parkour variants exist but are outside the normal Walk/Run jump study. Repeated sprint alternation and stop-on-contact are covered by behavioral tests; the visual take shows the four scenarios above, not every possible interruption.

All source-derived material stays private research-only and production-ineligible. No Jump/Landing data has been exported to Godot. The separately requested unarmed Walk/Run arm fix updates the existing Godot research scene only; it does not change these source reconstructions or production gameplay.

## Validation and preservation

13 source/evaluator tests;10 new native scale-policy tests plus7 existing focus regressions; independent source audit and fresh-file selection/slot/timing/scale-reset/camera checks. All65pre-existing Blender Action signatures, rigs, meshes, materials, images, texts and object links are preserved. All37previous Action registrations and the Approved directional sequence retain their metadata/playback. The library now has43Action registrations,2research sequences,10focused selectors and35archived registrations.

Six literal phase native TRS reconstruction errors are below3e−7; contextual pose reconstruction is below4e−7 at bake samples. Fresh saved evaluation results and any between-key approximation limits are in the validation files. These numerical checks support reconstruction fidelity within the declared profile, not automatic artistic approval or commercial licensing.

Reversible backups and build/capture logs are under `/Users/tin/Documents/ChatGPT/New project/experiments/actions_stuff_jump_source_v001/backup/`. The saved `simulation_trace.json.gz` contains the complete prescribed query/controller/PRS trace; read it with Python `gzip.open`. Source helpers and frozen interpreter dependencies accompany the study. Use the existing Showcase to review; do not run build scripts against approved files.

Primary format semantics: [Microsoft animation overview](https://learn.microsoft.com/en-us/minecraft/creator/documents/animations/animationsoverview?view=minecraft-bedrock-stable), [animation controllers](https://learn.microsoft.com/en-us/minecraft/creator/documents/animations/animationcontroller?view=minecraft-bedrock-stable). Interpolation primary-code evidence is linked in the source audit.

Fresh-file numerical evaluation:1,245literal samples, maxmatrix1.4916e−5, maxheadtranslation0.01216mm;902context samples, maxmatrix8.34465e−7, headtranslation0.000835mm, ForeArm basisidentity, XY0. All9nativeH264videos fullydecoded at640×640/30FPS with correct presentation timestamps;1,640decodedframes total. Primary context videos each450frames/15s.
