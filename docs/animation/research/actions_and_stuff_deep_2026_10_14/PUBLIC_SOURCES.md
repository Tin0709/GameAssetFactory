# Actions & Stuff: verified public evidence

Accessed **2026-10-14**. Research only. Read the existing [2026-10-13 study](../../ACTIONS_AND_STUFF_LOCOMOTION_STUDY.md) first; this file extends its public-source evidence. No animation, rig, library, production or Godot edits.

**D** = explicit official documentation; **R** = publisher/reviewer description; **C** = community self-report; **I** = our inference; **U** = unresolved. Official descriptions verify intended/documented behavior, not independent gameplay tests. All access below was web text; **no remote video pixels or audio were inspected in this subtask**. The older study's selectively watched trailer remains older evidence, not a new viewing claim. Do not merge release-specific features into the unknown version of the supplied local clips.

## Official source notes

### S01 — Content Guide and overview

[D] Oreville positions the pack as a vanilla-style visual overhaul spanning animation, textures, items, armour and audio. Its index currently lists **1.12**, making a study restricted to 1.10 incomplete as a current feature inventory. The embedded trailer link establishes provenance only; it was not watched here. [Content Guide](https://guides.orevillestudios.com/Actions-Stuff-Content-Guide-23fd70150598804aab49f4d6f3f9974a)

Access: overview and index text. Limit: marketing scope, no numerical animation specification. The studio [product route](https://orevillestudios.com/actions-&-stuff) returns a redirect page to the guide.

### S02 — General / formerly linked Animation Overview

[D] First- and third-person coverage includes directional locomotion, jump/land/swim, idles, tools, weapons, utilities, eating and climbing. The same overview describes animation-synchronized footsteps, item-specific animated models, particles and environmental presentation. These establish a coordinated presentation scope; they do not establish that every action supports every simultaneous combination. [General](https://guides.orevillestudios.com/General-23fd70150598811aa3a8d653e02b1322)

Access: complete short page. The older [Animations URL](https://guides.orevillestudios.com/Animations-23fd70150598811aa3a8d653e02b1322) resolves to the same titled/content page; treat as an alias, not independent corroboration. No footfall latency, contact solver, camera-shake prescription or sound recording was supplied.

### S03 — 1.10: transition intent, controls and feedback

[D] The movement overhaul documents planted-foot jump push-off and landing-to-run blending without a leg reset. Attacking enters a ten-second combat mode with forward-facing body and sideways strafing; backward walk and sneaking sidesteps improve. Stationary camera-driven rotation becomes smoother with partial head/body yaw separation.

Stationary falls use a heavy landing that movement can interrupt; moving landings use a lighter one-handed pose. Sprinting from a fall of at least four blocks selects a roll; falls of at least eight blocks emit impact dust. Airborne crouch selects directional flips; sitting exits through jump or movement. Narrow-surface balancing responds to speed.

Equipment/presentation notes include optional tool geometry, first-person armour visibility and item-swap audio. Step pitch variation and sounds for new actions are documented. Fixes address stale spear charge state, lingering spyglass use, spear interruption on doors, compass-related climbing and speed-run triggering. [1.10](https://guides.orevillestudios.com/1-10-341d7015059880c68287ce0877d3a123)

Access: Player Movement, actions, settings, audio and relevant fixes. Limit: behavior descriptions; no blend durations, cancellation priority graph, support thresholds or continuous-input measurements.

### S04 — 1.6: variants and motion-aware interruption

[D] Mounted animation varies by vehicle; horses include stationary idle and a sword/axe battle pose, while happy-ghast mounting chooses among three poses. Elytra crouch triggers alternating barrel-roll direction, with continuous flight motion and wind trails. Speed-potion running adds a dedicated animation and dust. Falling with a water bucket uses different variants depending on offhand occupancy. Respawn animation eases out when movement starts. First-person diving is described for jumps exceeding four blocks.

The notes explicitly acknowledge hardcoded boat-paddle and camel limitations. They also document a bow/crossbow eye fix. [1.6](https://guides.orevillestudios.com/1-6-284d70150598807a8682eda71a1155f2)

Access: player riding, flight, speed, bucket, respawn, diving and relevant fixes. Limit: the source describes a feature's introduction; later defaults/conditions may differ. Four-block first-person dive wording should not be silently generalized to all current water entries.

### S05 — 1.11: state cleanup is part of fluidity

[D] Fixes cover a player stuck in bow-release state after switching to spear/trident; transition from uncharged spear to another item; offhand raising during drinking; morph shield/spear clipping and offhand position. Holding jump and then sprinting previously reset the leap midair; the notes say this reset is fixed. A mobile camel rider-position fix shows device/context-specific corrections.

A public particle compatibility controller is introduced for add-on creators. Sulfur Cube squash/stretch, airborne tumbling and hit-driven spin are **mob-specific**, not proof of the ordinary player's gait mechanics. [1.11](https://guides.orevillestudios.com/1-11-381d70150598800cb925e0917df0e363)

Access: relevant Bugs Fixed and Creators; mob sections only to distinguish scope. Limit: bug statements identify cases, not the internal state graph or independent verification of their resolution.

### S06 — Creator guide: public equipment API, not a full locomotion disclosure

[D] Vanilla item-category tags select supported tool/trident animations; Oreville tags cover additional categories such as bow, crossbow, shield, lantern, torch, drink and spyglass. First-person custom item support requires attachables; most first-person animations additionally need a custom-position variable.

The guide provides separate mainhand/offhand variables for hand visibility, raised-hand presentation and custom holding/first-person positioning. It exposes pack detection so an attachable can select compatible behavior. An always-animated dummy controller can be overridden for player particles. [Creators](https://guides.orevillestudios.com/Creators-23fd7015059881aa8dd8cecb7f948f58)

Access: entire short technical guide, including snippets. This is genuine public implementation evidence for the compatibility surface. It does **not** reveal the core locomotion phase clock, joint curves, IK, foot-locking, locomotion controller, upper-body blend masks or action arbitration. The word “presets” in its introduction is not a complete enumerated internal animation library.

### S07 — 1.12: current configuration changes the experience

[D] A Special Movement Animations setting toggles barrel rolls, running rolls, superhero landings, water-entry actions, speed running, flips, sitting and bucket clutch; rolling is disabled by default. The release also documents three randomized cushion-sitting poses. Fixes address small-skin/morph mount height and false balancing/diving triggers involving wool stairs/slabs. [1.12](https://guides.orevillestudios.com/1-12-3f1d701505988092ad6bc9ae1e56b682)

Access: highlights/settings, cushion player poses and relevant fixes. Limit: settings mean two users can legitimately see different action coverage; this is not a new timing measurement. Do not assume historical 1.10 roll behavior is enabled by default in the current release.

### S08 — Minecraft's editorial play account

[R] The Mojang-published article, dated **2025-06-02**, describes Steve's walk as visibly bouncy, a breathing idle, and a flint-and-steel animation. This supports the reception of a lively character presentation, not a particular bounce curve, foot-contact duration or current version. [Let's Play: Actions & Stuff](https://www.minecraft.net/en-us/article/let-s-play--actions---stuff)

Access: article text. Static screenshots and prose cannot establish subframe dynamics. Its playful editorial wording should not become a biomechanics specification.

## What the evidence changes in our understanding

[I] The relevant unit of study is an **action system**: movement context selects a pose family; action entry/exit must retain meaningful ongoing motion; equipment can change presentation; user settings affect which families appear; audio/VFX reinforce events. This is an analytical synthesis of S01–S07, not a claim that Oreville implements one particular architecture.

The strongest research questions now concern **boundaries and concurrent actions**, rather than another percentage adjustment to a single gait:

| Question to investigate in lawful footage or an authorized game session | What public evidence can establish | What remains U |
|---|---|---|
| Does takeoff retain the current support side? | S03 states the design intent. | Foot selection, phase sensitivity, uneven-ground behavior. |
| Does a moving landing retain momentum and leg continuity? | S03 describes continuity; S05 identifies an input-order failure case. | Numerical phase mapping, tangents, latency, all interruption combinations. |
| What happens when a held/used item changes mid-action? | S05 names state-cleanup defects; S06 exposes compatibility controls. | Internal masks, priorities, blending and all offhand combinations. |
| How do direction, gaze and combat coexist? | S03 documents context-dependent directional presentation. | Turn thresholds, rotational limits, pivot/replant strategy. |
| Which motion events drive sounds/particles? | S02–S04 establish authored coordination and action effects. | Event timestamps, audio mix, particle attachment errors. |
| What part of the appeal comes from the camera? | No controlled camera-isolation result in this source set. | Shake, bob, FOV changes, follow lag and visual stability. |
| Which defaults apply to the reference? | S07 establishes current configurability. | Supplied clips' version, settings, skin, held-item and platform. |

[I] A technically continuous clip can still feel excessively busy; responsiveness, silhouette readability and optional intensity are separate review dimensions. No implementation is proposed or authorized by this file.

## Small qualitative community sample

Convenience sample: **two accessible Reddit discussions, six selected comments**, chosen for contrasting reception and practical context. No population claim, sentiment percentage or diagnosis; identities, hardware claims and current pack configurations were not verified. Comments are primary evidence of what those commenters report, not primary evidence about the product's implementation.

- C01, [“Is Actions and Stuff worth it?”](https://www.reddit.com/r/MinecraftBedrockers/comments/1kf6f3k/is_actions_and_stuff_worth_it/): Akuma_no_masuta likes the refreshing animation but reports poor Xbox performance; Sanguine_Templar wants the player animation separately from the cartoon-like textures; FidgetsAndFish replies that settings permit their preferred use. Accessed page shows relative ages around one year; no exact comment date is asserted.
- C02, [“is actions and stuff worth it it’s 10 dollars”](https://www.reddit.com/r/minecraftbedrock/comments/1snfcko/is_actions_and_stuff_worth_it_its_10_dollars/): piggiedippin enjoys the visual life but distinguishes it from gameplay utility; OMC_Gurrend finds it unfamiliar as a vanilla-oriented player; FullyAutomaticHyena reports texture/model conflicts with Kingdoms. Page shows relative ages around six months; these compatibility reports were not reproduced.

A third discussion, [“my opinion fr”](https://www.reddit.com/r/MinecraftMemes/comments/1ldxbjb/my_opinion_fr/), appeared in search with contrasting opinions about exaggerated motion. Full open returned page metadata/partial content, and targeted content retrieval errored; exclude it from the six-comment sample. A [separate over-animation discussion](https://www.reddit.com/r/Minecraft/comments/1wfffua/unpopular_opinion_i_really_dont_like_animation/) timed out. Search excerpts are discovery evidence, not full-thread inspection.

## Interview/developer search and access limits

Targeted searches combined “Actions & Stuff” or “Oreville” with animator, interview, behind the scenes, developer, animation controller, Molang and Blockbench. **No verified, directly relevant animator interview or core-system breakdown was found in this bounded search.** This is not proof that none exists.

- The official changelogs and creator guide are the strongest accessible developer-authored discussion found.
- Search hits included a third-party 4KS interview discussing compatibility with A&S, unrelated interview noise, social-media mirrors, Java-port discussions and download/rehosting sites. None established Oreville's core player-animation implementation.
- Do not treat a mirror's biography, an unofficial port, a redistributed pack or a generic Bedrock capability as evidence of the original authoring pipeline.
- Private Discord conversations, source files, animation JSON, original keyframes, paid pack internals and unavailable social posts were not accessed.
- Remote media were neither downloaded nor inspected. No screenshots, trailer frame measurements, audio analysis, proprietary assets or reverse-engineered curves were produced here.

Machine-readable provenance and search/access limits: [source_register_public.json](source_register_public.json).

