# Arsenal two-hand rifle hold + Actions & Stuff idle v001

`Rifle_Aim_Hold_Arsenal_ActionsStyle_v001` — **Pending**, research-only, not production-eligible. Select it in the existing Animation Showcase → N → Animation Library → Play. The previous `Rifle_Aim_Hold_ActionsStyle_v001` remains unchanged and selectable. Actual Rifle Stylized V2, unchanged native character/straight arms. No Godot integration.

This is a deliberate composite: Arsenal supplies the static two-hand handling; the existing Actions & Stuff reconstruction supplies the animated rhythm. Arsenal contains no third-person full-body breathing/observation/aim transition sequence. No such missing animation is invented or attributed to Arsenal. This review is a 3.6-second stationary hold (F1–108 at30FPS, closing109 excluded); the movie shows two uninterrupted cycles at1×.

## Verified source and composition

Fresh-read archives and exact dependency hashes are in `source_reference.json` / `source_validation.json`.

- Arsenal1.1.1: `ArsenalRP/animations/arsenal/arsenal.g.animation.json`, `animation.arsenal.2_hands.third_person`: L rotation[-88+x,40+min(20,y),0], position[-1.2,0,-1.4]; R[-88+x,-9+max(-40,y),0], position[.1,0,.8]. Player arms have no scale channel. `ArsenalBP/scripts/arsenal/main.js` dispatches the pose for mainhand `arsenal:two_hands`.
- Arsenal overrides `animation.player.move.arms` with L0/R30deg. Pinned Mojang bedrock-samples v1.21.100.6 `controller.animation.player.root`, third_person state, applies move.arms before holding. Vanilla holding-right at1 contributes(-this*.5-18)=-33deg after30; the declared neutral profile therefore composes R30−33−88=−91deg and L−88deg. Y angles remain R−9/L40. This is an explicit evaluated reference profile, not a Minecraft runtime capture or proof of every engine layer/order in another installed pack stack.
- Arsenal AWM `third_person_hold`, model pivot and item binding, plus M4 placement were examined. FP ADS controller/0.1667s raise clips are first-person-only; they are not used as a third-person player animation.
- Actions & Stuff1.12: `entity/dtr.json`, `animations/f2da1071.json`, `animation_controllers/616f2ff7.json`; existing verified `rrvlnm/dubgwy/jawwtn/asxvzc`, `njvelc/knoyhk` reconstruction supplies0.9/1.8/3.6s rhythm. Remove the previous static arm hold before composing the new Arsenal pose; retain its evaluated motion deltas. Vanilla bob is replaced rather than doubled. There is no arbitrary new sinusoid or generic idle formula.

## Native rifle / rig adapters

Use the established whole-arm source-coordinate/pivot adapter (0.05625m/source-unit at the existing proportions). Retain the Arsenal arm rotations exactly in this adapter; source arm translations are retained before a22mm outward LEFT shoulder seating correction for our rigid cuboids. No elbows, limb scaling, mesh, texture, material, rest rig or weapon geometry changes.

Rifle V2 is not the source AWM. Its barrel/mount orientation and two solid hand contacts require a static fit:31.34deg yaw relative to the initial AWM/M4 orientation seed,0.92deg pitch/−0.26deg axial adjustment; right palm adapter moves only[−5.38,−8.76,−13.62]mm inside the same block hand. Do not describe this as literal AWM binding/placement or copy its .35 weapon scale onto limbs. The left palm rests against the native receiver/front support area; no support IK is claimed in Arsenal.

Head turns toward the fitted rifle, keeping the existing head micro-motion. Static nod/roll/translation corrections clear our square head and keep it seated against the collar across all phases. Exact fit values are recorded in `parameters.json`; they are native adaptations, not additional Arsenal head keyframes. This is a readable block-character held aim, not certified optical sight/eye coincidence.

The latest modest stance is unchanged: right foot forward, left foot back,0.32m lateral spacing/0.14m stagger. Feet stay planted. Body/hip/leg/forearm/scale curves remain byte-exact in the copied Action;28 head/whole-arm/weapon transform curves are newly baked at240Hz, preserving all98 other curves.

Solid Minecraft block hands cannot close fingers around a thin weapon. Explicitly bounded support/grip seating is allowed only for the intended hand/body and right hand/magazine-edge contacts (conservative component OBB depths≤8mm), rather than treating these contacts as arbitrary body intersections. Other nonadjacent intersections remain forbidden.

## Review and recovery

`comparison_aim.png`: previous Aim vs the new Arsenal-based pose, identical camera/frame. `review_views.png`: front/three-quarter/side. `aim_reference_30fps_1x.mp4`: original-speed, two continuous cycles. The old study, all earlier approvals/research, rig/assets and Godot remain preserved.

Rebuild only an unapproved working copy: open the preserved previous Aim source from `authoring/baseline_entry.json`, run `authoring/build.py` with its recorded fit files. The published validator regenerates baseline transform samples from the preserved previous Action; full generated matrix dumps/cache, raw mod sources and videos extracted from packs are not added to Git. The local raw archives remain in `local_references`. Existing *.blend LFS tracking is reused; no history migration or new tracking patterns. The new source plus changed central Showcase require approximately96MiB of new LFS-version storage/download; account quota is unavailable locally. Ordinary review/provenance files remain below25MiB.

Validation:217poses, exact loop pose, no unwanted intersections; support surface gap≈0.30mm, bounded hand seating≤7.42mm, collar contact1.07–4.76mm, feet drift<0.25µm. Saved-file selection and two native playback loops pass. All89prior Actions and6943prior protected files remain exact;2007Godot files unchanged. New native total90;22focused entries/35archived. Source and ordinary review files follow existing LFS rules; estimated new source+Showcase version storage/download96.1MiB.
