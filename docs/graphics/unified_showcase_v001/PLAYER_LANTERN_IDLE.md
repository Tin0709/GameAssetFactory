Current full-scene revalidation with the owned HDR foundation: `lantern_idle_v001/final_review_hdr_v003/review.log`, Forward Mobile/D3D12, exit0 and `LANTERN_IDLE failures=[]`. Source load, native toggle keys, emitter/mist alignment, automatic inspection, movement/combat interruption, Day hide and Night grow were exercised together. Display previews apply one linear-to-sRGB transfer to HDR screenshot exports; no exposure/color retune.

## V002 follow-up — recovered native toggle and material override

Current main-scene default now starts the lantern hidden and uses exact recovered cubic grow (.4s) / shrink (.2s) keys on LanternCenter, preserving its fixed mounting offset and overshoot. Native Kismet confirms that target and stop-opposite/play-from-start flow. Triggering from our phase light is an original adapter for native MPC.UsePlayerLight; native clock logic, Niagara toggle and audio routing remain open.

Actual component override MI_PlayerLantern supplies the bound SE1 atlas and linear emissive hue. Shared-family R/G/B channel interpretation is strongly supported but lacks a new lantern GPU-pixel proof. Native brightness20/40 ratio modifies our original gain to.4; this is not a direct HDR unit conversion. Old standalone emission mask was not equivalent to the bound packed texture. Point light and shared mist now synchronize with the displayed lamp within the same render frame.

Native Mobile review passes including actual Day/Night hide/grow and1e-5m point/mist alignment.402curve samples agree with independent Bezier evaluation within6.56e-15. Private evidence: lantern_idle_v001/toggle_v002/README.md. Prior V1 record below is historical where superseded.

# Private hip lantern and weapon-inspection idle

2026-11-08, requested for review in the existing F5 WorldMap. Source assets remain external/editor-only, SHA-pinned in Research; no proprietary mesh, atlas, clip or runtime dump enters Git/builds. Previous changes and original controller/animations remain.

## What works

The player loads the verified original static lantern mesh/atlas and emission mask, hangs it behind the hip using the recovered spine attachment chain, and drives an independently authored one-axis pendulum. The existing warm8m, no-shadow light and the warm contribution in the shared mist now follow the lamp center instead of the body center. Lamp surfaces occupy a separate render layer so a point light inside the fixture does not bleach its own cage; sun/ambient and emissive glass remain visible. This layer exclusion and emission multiply/.8 gain are original Mobile appearance policies.

After6seconds of stationary grounded idle, the original2.66666675s weapon-examination animation plays at1x on the existing32-bone rig and Sabre binding. Every imported bone name, parent and rest transform is checked; source tracks are duplicated in memory and only target paths change. Movement intent, jump, combat or manual review takes priority immediately. After completion it returns to approved Idle with an original14s repeat interval. Reset clears idle scheduling. No root/capsule displacement is introduced.

## Recovered evidence and important limits

Read-only reflection of the currently running MD2 confirmed the actual player mesh is **SM_SWT_MetalLantern**, not the skeletal cinematic lantern. Its chain includes a hidden simulated cube, a spine-attached constraint, a child-player-lantern scale3 under body scale.25, and the metal mesh's native offset. The anchor is `J_Spine` with localY -29.721083cm. The active constraint uses a soft50degree Swing1 limit with Swing2 and Twist locked; native stiffness100/damping50 and disabled parent collision are recorded privately. LanternGrow/LanternShrink timelines also exist.

This is runtime physics, NOT a recovered stored skeletal swing animation. Godot uses an original bounded pendulum, not an asserted reproduction of Chaos solver/mass/inertia/damping, collision, grow/shrink curves or all gameplay event routing. Full native toggle animation is still unresolved. The current review keeps the fixture visible; phase controls still gate its surrounding player light.

Native player illumination is a separately managed BP_PlayerLight, with warm sRGB255/201/129, point-light range800cm, spotlight disabled and point intensity6 in the read live state. Native light positioning is separate from the fixture. Moving our emitter into the fixture is the user's requested visual change, not proof that native BP_PlayerLight itself sits there. Existing Godot phase-intensity conversion/falloff remain adapters, not photometric equivalence or recovered Lumen bounce. Source defaults differ from the live state and must not be mixed.

The generic one-hand examination clip is `Player_Idle_Novelty_ExamineWeapon`; specialized2H/curved/dagger clips are preserved but not substituted for this Sabre. Native novelty selection probability, trigger delay and cooldown were not recovered; our6/14s schedule is explicitly original. No lantern sound is enabled because test audio remains muted.

## Review / evidence

F5 launches WorldMap. Use T for Night, stand still about6seconds to inspect the Sabre, then move/jump/attack to interrupt. The existing camera and controls are retained. Private `godot_lab/world_map_unified_showcase_v001/lantern_idle_v001` contains runtime reflection, source/hash manifest, previous implementation snapshots, native review script/results and front/back/inspection screenshots. Read the final result log before claiming completion or exact MD2 matching.
