# SOLDIER facial system — Pending Blender review

All facial assets live in the existing `../showcase/SOLDIER_Asset_Library.blend`, inside its existing `SOLDIER_ASSET_LIBRARY` scene, view layer **Facial Expressions**. No additional permanent library, scene or Godot asset is introduced.18 expressions and10 situations are Pending. Artistic approval is still required.

## Review

Open through the normal command so the explicit repository sidebar loads:

```sh
python3 "$HOME/Desktop/Game Dev/GameAssetFactory/scripts/open_blender_viewer.py" soldier
```

The saved file selects **Facial Expressions** and Neutral. Press N → **SOLDIER Library**. The complete18-row list, Previous/Next, Play/Pause, Restart, Loop, Intensity, gaze X/Y, Auto Blink, Reset to Neutral, Situation and Front/3/4/Side/Gameplay cameras are available. Selection plays a133ms entry from the current face/body once, then repeats only canonical frames5 onward. Restart starts the canonical clip, not a captured previous reaction. One-shot reactions stop unless Loop is explicitly enabled. The source clocks remain30FPS. Raw double-click retains native Actions/simple drivers but does not execute the external sidebar; use the launcher for interactive controls. Older pre-facial Soldier windows are left intact and not reused by this revision of the launcher.

`review/SOLDIER_Expressions_Contact_Sheet.png` contains all18 actual Blender renders. `review/soldier_face_*_30fps_1x.mp4` contains the original-speed front, three-quarter and gameplay-distance reels. The combined review labels each section. Gameplay framing approximates the current research camera's7.2m vertical view at1280×720; it is a Blender readability check, not a Godot integration/performance claim.

## Verified Actions & Stuff1.12 evidence

Direct archive: `/Users/tin/Desktop/Game Dev/local_references/Actions Stuff 1.12 (resources).mcpack`, SHA256 `9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d`.

Reproducible audit: `research_source.py`; literal definitions, file locations, aliases, external dependencies and controller traces are stored in `source_evidence.json`. Traversal starts at `entity/dtr.json` → `scripts.animate`, resolves entity aliases and follows controller state animation references, reaching660 definitions. This does not execute the Bedrock engine or resolve external Persona assets.

| Evidence | Verified meaning | Limit |
| --- | --- | --- |
| `entity/dtr.json`, initialization `v.is_blinking=0`, `v.last_blink_time=0`; alias `blink` → `controller.animation.persona.blink` | Player exposes blink state and a Persona controller reference | That controller is absent from the archive; this alias is not reachable from the custom player animate roots |
| `render_controllers/464e7f72.json`, `controller.render.persona_animated_face.first_person` / `.third_person` | UV Y chooses `v.is_blinking*0.5` when `v.use_blinking_animation` is true | The referenced face geometry/texture and controller require external Bedrock/Persona definitions |
| Same controllers, alternate UV path `floor(q.life_time*7) % v.animation_frames_face / v.animation_frames_face` | Animated face texture frame cycling at7Hz | **Not** a7Hz blink frequency, nor evidence for a particular eyelid curve |
| Same controllers, `q.in_range(v.tnlxsa,0,1)?Geometry.animated_face:Geometry.dummy` | Facial geometry is independently selected by the render path | Does not establish an independently rigged eye/brow bone system |
| `animations/f2da1071.json`, player `look_at_target` → `animation.oreville_ans.cndmcx` | Head target pitch/yaw, including alternate head naming | Head gaze is not verified independent eye gaze |
| Same file, `hurt` → `animation.oreville_ans.gavocc` and relevant bob/walk/jump/holding/crossbow references | Short body/head reactions with recovery, separated motion layers | No requested player emotion/pupil/brow preset bank was identified in the reachable data |

No exact A&S blink interval, eyelid close/open curve, eye gaze or18-emotion bank can be recovered from this pack alone. We do not claim these original Soldier designs are undocumented A&S clips. The verified separation of facial rendering from body/head motion and existing source-derived body timing inform the architecture and restrained motion style. No A&S face textures or geometry were copied.

## Original expressions and timing

All18 facial designs, brows/gaze, eyelid geometry, intervals and situation arbitration are original Soldier work:

Neutral_Idle, Blink_Soft, Look_Left, Look_Right, Look_Down_Short, Alert, Focused_Aim, Fire_Recoil_Face, Enemy_Nearby, Move_Effort_Light, Run_Effort, Jump_Focus, Land_Impact, Hurt_Light, Hurt_Heavy, Low_HP_Tense, Victory_Small, Death_Stunned.

Original blink:180ms total,75ms smooth closure,20ms hold,85ms reopening. Deterministic irregular intervals2.65–4.8s (focused5.6–8.2s); the review begins at1.25s (focused2.7s) so behavior is inspectable. Explicit Blink_Soft remains inspectable with Auto Blink off. Intensity0 returns face channels to neutral; manual gaze is a separate bounded control.

Situation bases: Idle→Neutral, Walk→Light Effort, Run→Run Effort, Ready→observant relaxed face, Aim/Fire/Hurt→Focused Aim, Low Health→Tense. Focused situations keep gaze stable. Hurt demo shows Light then Heavy and recovers to Aim. Jump demo has takeoff then Landing. Sustained low-health tension can be applied beneath events.

Priority: Death100 > Hurt Heavy80 > Hurt Light60 > Land40 > Jump30 > Fire20 > persistent state. Event duration/attack/hold in seconds: Fire1/6/.025/.0167; Jump.38/.055/.10; Land.33/.035/.045; Hurt Light.46/.045/.09; Hurt Heavy.70/.065/.14; Death1.15/.09/.60. Higher weights blend over the current lower composite continuously; full high-priority weight owns the face. Same-priority duplicates use max, not sums. Recovery reveals the current base/event rather than a stale captured pose. Auto Blink fades beneath event priority instead of disappearing abruptly at event onset. Fire pulses are6Hz and never accumulate.

## Reusable architecture

- `SF_Face_Mesh`:84vertices,21quads/42triangles, one512atlas/material, Head weights1.0. Rectangular eyes/cropped pupils, stepped brows and thin closed-lid lines; the head remains rigid. No mouth/nose or head deformation.
- A reversible overlay covers painted eyes only on the review copy. The original body, textures/materials, hair, clothes, slim arms and rest rig remain exact. New body/hair/clothing objects share the original mesh data; a copied10-bone rig isolates preview Actions. No original character/equipment object is replaced.
- `SF_Face_Control`: bounded face channels plus intensity/manual gaze/Auto Blink.16native simple shape-key drivers; no arbitrary Python driver namespace or per-frame object creation.
- Layer A: `SOLDIER_Face_Preset_*`,18 original facial Actions. Layer B: `SOLDIER_Face_Situation_*`,10 context Actions. The3 live Actions are reused on selection, and3 additional Actions are clearly labelled review edit/body/weapon, not animation candidates. All34 new Actions carry Pending/Soldier facial metadata.
- `expression_model.py` is Blender-independent state logic; `face_blender.py` bakes parameters; `facial_ui.py` handles artist controls. Existing library UI only receives a facial routing hook. Saved canonical Actions work without bootstrap.
- Face mesh never writes head transforms. Optional2.8° yaw/2.5° downward head coordination for Look presets is applied once to the copied body's Head. Approved Aim7° lean remains in sampled pose. Gaze controls do not rotate the head a second time.
- Body compatibility samples are evaluated read-only from existing source Actions (`body_preview_samples.json`, with each source SHA/path). They are preview-only, not replacement Actions. Jump1.2s and Landing1s play unretimed; the reel has0.3s anticipation,1.2s Jump,1s Landing,0.3s recovery. Scene segment transitions crossfade140ms. Short preset body clips receive a160ms seam adapter; no source curves change. Actual Sand Block rifle and the established rigid-arm orientation adapter are used for weapon situations.
- Isolated **Facial Expressions** view layer in the existing main scene; skin/backpack buttons still select their original views. Render enable follows active asset so F12 shows the selected review.

## Validation and preservation

`test_expression_model.py`: names, bounded channels, blink, gaze, context recovery, duplicate6Hz requests, event onset/recovery continuity and steady situation seams. `test_facial_ui.py`: actual Blender operators, one-time entry vs loop wrap, Neutral during Hurt, Aim loop,432extreme geometry/gaze/intensity/blink samples, cameras, asset routing and action/handler counts. `verify_facial.py`: native save/reopen/drivers, rigid cover, identity and registration. Launcher tests cover old-window revision handling. `preservation_native.json` compares original objects/geometry/UV/weights/rig rests/materials/images/authored transforms to the backup. `preservation_files.json` compares8,666pre-existing Blender/Godot files; intentional Soldier library/UI/catalog/docs edits are listed, Godot must remain exact.

## Limits / future use

This is a Blender artistic review, not a shipped gameplay facial controller or a phone benchmark. At full isometric distance the largest eye/brow/squint changes read best; subtle gaze is intentionally quiet. Auto Blink is deterministic per clip; a later gameplay port should keep a persistent blink clock across states. A runtime adapter would carry the same bounded channels/priority rules into the approved existing skeleton without baking body motion into the facial layer. No Godot import/controller/export is part of this task. Source-derived body samples/review bakes remain research-only; original facial designs are separately identified. Do not export the entire library as a production asset. No new armor was invented when the current registry contained Skin and Backpack only; every pre-existing asset was preserved.
