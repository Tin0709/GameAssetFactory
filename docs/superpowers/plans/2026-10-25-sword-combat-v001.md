# Sword Combat v001 Implementation Plan

> Execute in the established checkout on `codex/sword-combat-v001`. Use the subagent-driven-development workflow for independent animation and VFX units, with the parent owning integration and final validation. No commits or publication are required.

**Goal:** A complete playable original Sword vertical slice alongside the approved Rifle in the existing ActionsStuffWalkRunTest scene.

**Architecture:** One scene-owned combat state machine determines damage and defensive events. The existing pose/contact pipeline remains authoritative for locomotion; a derived Sword visual composes original upper-body clips, grounded attack steps and an original roll, then captures the existing interpolated presenter. Fixed pools render weapon-following arcs, sparks, dust and contact bursts; only confirmed hits trigger hit-stop, shake, stagger and impact audio.

**Tech:** Existing Godot Mobile project, GDScript, original Blender Actions and the user's Sword Sand Block V1 GLB.

**Spec:** User's full Sword vertical-slice request and follow-up requiring the newly authored Blender sword. Integration is explicitly authorized; this is a playable Pending review, not artistic approval or release of research locomotion.

## Constraints and design decisions

- Preserve WorldMap, project main scene, source packs, every approved Action, Rifle clips/cadence/recoil, camera controls, jump physics, movement speeds and native zombie corpse behavior. Backups and baseline hashes under `.validation/sword_combat_v001/`.
- Never import Fiery tracks into gameplay. Private Fiery JSON/script analysis remains outside repository. Existing independently authored Sword_Combo_Original_v001 supplies the original connected poses; new split actions and defense/roll actions are independently named Pending. Actual source combo is 1→2→1→3; requested gameplay is deliberately original 1→2→3.
- Same checkout/project requested; create a feature branch, no extra worktree/project/scene. Approved source files are read-only. New dev Sword assets remain behind the existing research release exclusion.
- Tab switches weapon; E or left mouse attacks in Sword, right mouse holds guard with a short parry window on entry, F dodges along WASD (or facing); Space jump, Shift run, Q/C turn, wheel zoom, R reset remain. Rifle E/right mouse keep current semantics; middle mouse provides Sword camera orbit.
- One buffered attack (0.22s), three distinct active windows, one hit per enemy per attack, capped nearest-first target budget and world-geometry LOS. Whiffs get swing/trail only. No global Engine.time_scale changes.
- State gates own motion/cancels; physics owns travel and wall collision. Grounded roll has original full-body rigid motion and timed invulnerability; jump cancels only recoverable combat states. Weapon switches clear pending melee hits/defense and retain locomotion phase.
- Poise, timed parry, guard cone/cost/recovery and finite practice vitality are scene-local and adjustable. Enemy attacks feed the defensive controller even though the previous lab used zero player damage. Rifle remains invulnerable practice mode.
- No per-hit nodes/materials/tweens/dynamic lights; bounded effects, audio voices and trail histories. Quality and intensity tunable. Real 100-zombie benchmark is separate from fixed-FPS correctness; no phone performance claim.

## Review focus

Hit windows crossing coarse frames must not miss or duplicate damage; buffered input must expire; active attacks must not ghost after switch/reset; directions and walls must constrain dodge/hits; crowds and cleanup must keep fixed pool sizes; two-handed rifle contact reconciliation must never alter Sword poses.

## Tasks

- [ ] **1 Animation + weapon.** Independently author/export Ready, Attack1/2/3, Guard, Parry, Roll and Hurt, exact runtime rest basis and fixed sword grip; use the existing new Sword GLB. Register new Actions Pending in the existing Showcase, preserve previous signatures. Produce `sword_combat_v001/original_library.res` and `profile.json`. Validate 30/60 samples, straight limbs/unit scale and original provenance.
- [ ] **2 Pooled VFX/audio.** Standalone `effects.gd`: setup, trail endpoints, swing, confirmed impact, defense and dust; low/medium/high budgets, no lights. Original MD2-inspired warm gold/white impacts and cool parry contrasts; finisher reads more strongly. Reuse licensed existing game audio with fixed polyphony; synthesize missing cues originally if necessary. Test pool saturation/reset.
- [ ] **3 Controller + enemy hooks.** Fail-first real-scene tests for Sword equip, combo/buffer/whiff/hit deduplication, guard/parry, roll invulnerability/walls, poise break, interruption and resets. Implement adjustable state machine, event-only feedback, scene-local enemy wrapper and practice vitality.
- [ ] **4 Pose/input/presentation integration.** Derived visual and presenter, existing locomotion/jump phase and rifle bypass, exact Sword hand attachment and rendering. Same scene opt-in and input routing; visible concise controls/status and parameters. Test Rifle switch-back and airborne/moving transitions.
- [ ] **5 Playable validation/polish.** Run headless correctness at30/60, existing Rifle/locomotion/combat tests, original-speed native gameplay and actual rendered frames. Exercise multi-target, repeated attacks, interruptions, 100-zombie pool/performance and corpse cleanup. Fix material issues before completion.
- [ ] **6 Deliver.** Record source facts versus original parameters/provenance, controls/launch, measured limitations and preservation audit. Open the existing Godot scene with normal audio for review.
