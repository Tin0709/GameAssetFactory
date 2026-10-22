# GAF MD2 Lighting v001 Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans for inline implementation. Research domains are separately delegated read-only.

**Goal:** Deliver the user's requested original, reversible Mobile lighting system in the existing playable lab, with five day phases, quality controls and measured native evidence.
**Architecture:** Dev-only `lighting_md2_v001/` owns palette sampling, environment/key/quality restoration, compact preview UI/statistics and a small reused-asset evaluation arrangement. The lab opts in with an export flag; actor/rifle/zombie/grass motion stay untouched. Source ZIP is read-only research, never runtime GLSL.
**Tech Stack:** Existing Godot4.7.2 Mobile, GDScript, native WorldEnvironment/DirectionalLight3D/ProceduralSkyMaterial/fog/glow; original bounded foliage shading toggle.
**Spec:** User attachment ea1441e4-9ee0-42f4-ae1c-7965e242d36e/Pasted text.txt; preserved request governs this plan. Required report `docs/graphics/MD2_LIGHTING_AND_GRAPHICS_RESEARCH.md`.

## Global constraints
- Existing `game_mobile_3d` and `ActionsStuffWalkRunTest.tscn` only; no other gameplay scene/project, WorldMap or project-default edits.
- Preserve approved Blender/native Soldier/weapon/animations, 2.70/~7.55m/s, E6Hzinfinitefire, strafe/turn/autoaim/jump/camera, zombiephysics and exact grass vertex motion.
- No proprietary GLSL copying; verify licenses and distinguish observed visuals from inferred techniques.
- Mobile only; no mandatory unsupported SSAO/SSR/SSIL/volumetricfog/GI. No claim of mobile FPS without real phones.
- Original A/B restores exact environment/sun/viewport and known project global-shadow initialization; full source files remain recoverable.

## Review focus
- Midnight wrap and rapid preset/time dragging must remain finite/continuous; test sampling and30/60transition parity.
- Original/quality toggling cannot leave changed globals or grass shading after removal; test restore and replacement lifecycle.
- GUI cannot consume gameplay release events or conflict with E/Q/C/R/V/movement/camera; inspect focus/mouse routing and regression checks.
- All five phases must keep actor/enemy readable at actual camera distance; native same-pose comparisons and contact/shadow review.
- Metrics must distinguish renderCPU/GPU/framepace, missing timings and controlled A/B pass estimates; no screenshot readbacks during benchmark.

### Task1: Evidence and baseline
- [x] Inspect actual680-entryZIP, licenses and referenced include pipelines.
- [x] Inspect genuine official MD2screenshots/trailer frames and official GodotMobiledocs.
- [x] Inspect current lab/project/assets; save protected SHA baseline and original3files under.validation.
- [x] Consolidate source evidence into required report alongside implementation results.

### Task2: Original reusable controller
**Files:** Create `game_mobile_3d/scenes/dev/actions_stuff_research/lighting_md2_v001/{palette.gd,lighting.gd}`; modify existing lab opt-in setup and exact scene flag. Add shading toggle in existing grass fragment only.
**Interface:** `Lighting.setup(lab)`, `set_time(hour,snap=false)`, `set_quality(index)`, `set_original(enabled)`, `advance(delta)`, `release()`; `Palette.sample(hour,into={})` wraps any finite hour and returns shared field dictionary.
- [x] Write `tests/test_md2_lighting.gd`: resource+sceneintegration, wrappedsampleequality, noon/nightdistinct/readable,30/60transitionparity, original/quality/release restoration, grassgeometryclockpreservation.
- [x] Run missing-controller RED, implement palette/controller with owned state and no per-frame scene/object creation, run GREEN.
- [x] Qualitytiers: Low.75/1024/VeryLow/orthogonal24m/glowoff; Medium.85/2048/Low/two-split32m/subtleglow; High1.0/2048/Medium/two-split38m/subtleglow. Bilinear3Dscale, no project saves.

### Task3: Preview and asset evaluation
**Files:** Create samefolder `preview_ui.gd`, `review_props.gd`, `metrics.gd`; no new scene. UI compact top-right and collapsible.
- [x] Five preset buttons7,12,16.5,18.5,22;24hslider; pausedinitialauto; ratecontrol; Original; qualityselect; independentfog/glow toggles;2–4Hzmetrics; Loptionalnonconflictingcollapse.
- [x] Reuse existing GLBs for small stone/dirt/flower/tree arrangement with bounded selected shadows and stable ground contact, away from main spawn contacts. No altered source assets.
- [x] Check UI and controls through actual lab. Preserve old25%HUD.

### Task4: Native verification and delivery
**Files:** same existingtests directory native capture/profiling script; review output `docs/graphics/reviews/md2_lighting_v001/`; required researchreport.
- [x] Capture Original+fivephases, same gameplaycamera/pose/scene/windphase and nativeMobileoutput; inspect montage and adjust only lighting if needed.
- [x] Short original-speed smooth daytransition clip. No retiming or promotionalcamera replacement.
- [x] Warm nativeLow/Med/Highbenchmarks with wind,playerpassage,actualEcombat; rendererCPU/GPU,framepace,visible/shadowstats. Controlled same-pose shadow/glow A/B estimates if meaningful.
- [x] Run essentialexistingFire/Strafe/camera/grass checks, SHAaudit allprotectedfiles and standalone fresh review.
- [x] One focused fresh final code review; fix materialissues, report limits. Open the EXISTING lab with normal audio; stop for visualreview.

## Execution decisions
- User explicitly requests BOTH research and implementation, no research-only stop. Perform this concrete authorized design in-place rather than insert redundant approval gates. Current asset-heavy workingtree is intentional; no copied project/worktree.
- Current architecture has explicit state-sampling and opt-in hooks. Preserve all other approved source files; no broadened combat/controller redesign.

## Verification ledger
- Task1 complete: actualZIP+licenses/GLSLincludeaudit,4.7Mobiledocs and officialMD2pixelresearch; protected baseline8,939files.
- Task2/3 complete:20lighting contracts GREEN after genuine missingmoduleRED and lifecycle/inputreviewsRED. Optional fragment shading only; all grass vertex logic retained.
- Final review: twoImportantfindings (releasedcontrols couldmutate; RMBupoverGUIcouldstick); bothreproducedRED thenfixedGREEN, noCritical/minordeferred.
- Native benchmark done:300samples/tier, activecombat/grass,0poolmisses, peak2ragdolls; rawperformanceJSON. GPUN/AonMetal, two-splitdrawcounterN/A, shadowprimitivesavailable. IntentionalRresetspike~64msreported.
- Native fivephase stills inspected, night/duskfillraised for readability. Finalstillrefreshpendingafter depthprecisionrestoration/UIheadercorrection.
- Clip first manualfixedFPSrun hit native skinallocation startup errors, not gameplaybonechanges. Capturehelper now warms native storage before reconnecting approved presenter callbacks. Cleanrecapturepending; do not publish erroneousfirstlog.
- Scope decisions: no decorativebeams/extraaccentlights in clearing; no nativeGI/reflectionwork for matteassets; nophoneFPSclaims; noWorldMaporprojectdefaults.

- Task4 complete checks:20lighting/29grass, Fire30/60,Strafe,camera allclean; native finalstills/capture clean;300frame10sMP4decodedentirely. Finalstills usecorrect16bitrestoration; latestUIheaderandreadableNight/Duskfillincluded.
- PreservationGREEN:8,939pre-existingfiles, exactly3authorizedchanges,0missing/unexpected, allBlender/project/WorldMap/approvedgameplayexact; grassvertexSHA47dc06ab122d3b579c80cf19a149715a97419e0590318c7157a12ab5af16df57.
- Final whole-feature reviewcomplete; bothImportantissuesverifiedRED→GREEN, noCritical/deferredminors. Capture startupfixedonlyinhelper; approvedpresenters unchanged.
