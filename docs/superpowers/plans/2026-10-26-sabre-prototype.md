# Sabre Prototype Implementation Plan

> For agentic workers: execute sequentially; use executing-plans for root work,
> with independent reconnaissance/review only until the Blender gate passes.

**Goal:** a playable player/sabre in the existing grass/lighting lab, preferring
the user-authorized original recovered MD2 data for private fidelity testing.
**Architecture:** Research-only source bundle -> transient external GLB loader ->
independent actor/mode, with an authored self-contained fallback and minimal
existing-lab opt-in hooks.
**Tech:** installed Blender 5.2.2, Python standard library, Godot 4.7.2.
**Spec:** `docs/superpowers/specs/2026-10-26-sabre-prototype-design.md`.

## Global constraints

No proprietary source files outside research; external private skin is explicitly
user-authorized and loaded in memory only. No extraction, installation, new
project, deletion, Git repair or production WorldMap changes. Preserve old files.

## Review focus

Wrong axes/unused Euler values; animation export changes evaluated deformation;
buffering loses presses or duplicate events at dt crossings; blend ownership
freezes movement/jumps; the opt-in mode alters old lab/environment behavior.

## Tasks

- [x] Capture baseline hashes and load existing project; author geometry/materials
  in `blender/characters/player/sabre_prototype_v001/`, exact reportable dimensions.
- [x] Add own sparse motion definitions and facial morphs. Validate body/sabre
  bounds, evaluated poses, rigid skinning, grip, loop seams and clip durations.
- [x] Save showcase and selection UI; export only generated inputs into new lab
  subtree. Reimport GLB and compare independent evaluated pose fixtures.
- [x] After Blender gate, implement state/movement/animation/event tests first;
  build `actor.gd`, `mode.gd`, bounded `effects.gd`, and minimal lab lifecycle hooks.
- [x] Verify same lab grass/light/camera, input/reset/jump/combo/strafe/expression,
  dt-independent event order, finite VFX budgets and native desktop playback.
- [x] Inspect captures, independent review, fix findings, fidelity report and
  launch helpers. Preserve legacy default scene and document exact controls.
- [x] Apply latest user instruction: use original 32-joint rig, source animation
  channels and original Sabre assets in an additional private source variant;
  verify data preservation and native gameplay before preferring it in launchers.
- [x] Calibrate effective Walk/Run speeds from original sole trajectories; align
  jump apex with the source takeoff clock as an explicit physics approximation.
  Preserve stride phase, braking gait and directional leg motion; validate at
  30/60Hz and capture the final playable source_v003 implementation.

## Ledger

Ruling: user's detailed implementation brief supplies the desired architecture
and grants routine authoring/integration choices; proceed without another design
approval round. Choices and fidelity limits remain explicit and reviewable.
Ruling: work in the requested directory; empty .git prevents ordinary worktree
operations. Do not reconstruct Git metadata or alter repository history.

Ruling: direct recovered skin requested later in the same task — preserve the
original appearance in Research-only files and load externally in memory; never
serialize its pixels/mesh into the project or its private-preview captures.
Ruling: source body-side lean sign and generic leg splay were corrected from
physical-direction comparisons; these were implementation errors, not new design.
Ruling: native capture labels must be selected from actual actor states, not fixed
tick counts; final evidence waits for airborne/ground-contact landing explicitly.
Ruling: user explicitly requested all available original MD2 data, including the
sword. Prefer the private original rig/clip/weapon bundle; preserve the previous
reconstruction as a fallback and defer mobile optimization. Missing engine
graphs, equip transforms and VFX behavior remain labelled reconstructions.
Ruling: latest natural-motion request authorizes a gated leg-direction postprocess
and cadence calibration; original clips and raw review remain unchanged. Native
movement/height/JumpCurve values are not recovered and must not be claimed exact.
Ruling: align original audio envelope peaks to measured fast blade landmarks;
the scheduling is a prototype reconstruction, not a recovered Wwise notify.
Ruling: user explicitly chose to stop tracking Research assets from now on while
preserving local files/history. Removed 507 index entries only, added ignore rules,
and retained previous backup commits. No asset deletion or remote operation.

Final evidence: ten independent Godot suites / 244 checks pass, source Blender
saved/reopened checks16/16 pass, full existing Python suite71 tests pass (4 skips),
and the preservation/integrity validator passes all18 checks. Native source_v003
contains21 rendered states and a748-frame60fps gameplay recording with verified
non-silent original sample playback. Source GLB SHA5f7bef39...81810110 unchanged.

F6 entry correction: the user's editor targeted the separate older
C:\Users\ADMIN\Desktop\Dev\GameAssetFactory checkout. Opened the requested
C:\Dev\GameAssetFactory project and changed only its saved Sabre entry flag so
F6 starts Valorie/Sabre directly. Retained explicit legacy CLI/button access and
added Open Sabre Editor.cmd. The old checkout was not changed. Real editor F6
was pressed and its game window showed the source player, Sabre and no zombies.
Mode-switch regression is now10 checks; portable-launcher subset24 checks pass;
runtime89 checks pass. Aggregate retained runtime evidence is247 checks and the
final integrity validator passes19 checks. The editor reserialized project.godot
line endings; normalized bytes exactly match its original hash, confirming no
project/graphics setting change.
