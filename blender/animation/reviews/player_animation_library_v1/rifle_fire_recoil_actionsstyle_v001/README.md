# Rifle Fire / Recoil ActionsStyle v001 — Pending

One new Blender-only Action: `Rifle_Fire_Recoil_ActionsStyle_v001`. The existing Rifle Ready ↔ Aim gameplay was explicitly accepted on 2026-10-20 and remains unchanged; its recovery hashes are in `docs/animation/baselines/rifle_ready_aim_gameplay_accepted_v003/`.

Open the existing `blender/animation/showcase/Animation_Showcase.blend`, then **N → Animation Library → Rifle_Fire_Recoil_ActionsStyle_v001**. Use Play/Pause, Restart, Loop and Front / 3/4 / Side. The actual Rifle Stylized V2 is attached. Status stays **Pending** until explicit artistic approval.

## Recoil strength refinement — 2026-10-20

User-requested **1.5× recoil amplitude** on the SAME Pending Action. All impulse, recovery, settling and delay clocks are unchanged. The 7° aiming lean, right grip, approved base and feet are unchanged. A sub-degree (maximum 0.9°) axial correction on the intact left arm maintains the existing head-contact envelope while leaving its support palm fixed. Shoulder absorption grows with the stronger impulse; the explicit seating allowance scales from 18 to 27 mm, while the original head/contact guards stay unchanged. The complete previous Pending source and reviews are backed up outside Git; no second candidate was registered. See `strength_revision_validation.json`.

## Review at original speed

Each 6-second, 30 FPS movie shows two isolated shots, then twelve consecutive shots at 6 Hz, using the same Action throughout. The 6 Hz rate is an authored rifle review choice, not an Actions & Stuff source firing-rate claim.

- [Front](recoil_front_30fps_1x.mp4)
- [Three-quarter](recoil_three_quarter_30fps_1x.mp4)
- [Side](recoil_side_30fps_1x.mp4)

The canonical shot lasts 1/6 second: playable F1–5 at 30 FPS, with identical closing sample F6 excluded from the loop. It starts from F85 of approved `Crossbow_Aim_ActionsStuff_Refined_Test_v001`, kicks quickly, then settles by approximately 0.129 s. The maximum measured rifle response is 2.528° upward / 13.082 mm backward. Spine and chest react 8.33 ms later; the restrained head response follows at 12.5 ms. The existing 7° head lean remains intact. Both complete arms stay straight, with identity ForeArm articulation and unit scales.

The original right-hand/rifle transform is maintained throughout. The left support follows the fore-end with a delayed submillimetre release (measured maximum relative excursion 0.688 mm). A palm-near recoil pivot allows the shoulder to absorb the impulse without lifting the gun into the square head. The right shoulder displacement peaks at 21.46 mm and the left at 6.61 mm. All shot offsets return to zero; they are absolute, never accumulated.

## Source and adaptation

Read [REFERENCE.md](REFERENCE.md) for the verified pack files, controller states, timing and distinction between source facts and original rifle decisions. The recoil curves are authored originally. The approved Aim reference itself contains source-derived research material, so the complete study remains **research-only / nonproduction**.

This is a short shot on a frozen approved Aim sample, not a replacement for the complete breathing/locomotion loop. A later authorized runtime adapter can evaluate its offset from F1 over the current Aim layer, retaining that layer’s breathing phase. No such runtime work is performed here.

## Internal verification and preservation

`validation.json` records 81 evaluated poses at 480 Hz, exact entry/exit and loop boundaries, 20 repeated NLA cycles without accumulation, rigid arms, grip/support, head clearance and unchanged foot vertices. The minimum head–rifle gap is 10.749 mm. Existing approved cube-to-cube contact/seating is retained, not advertised as a completely intersection-free production fit. The base’s sole corners remain 4.12 mm / 0.77 mm below its existing display floor; this task deliberately does not edit approved lower-body data.

All 22 prior Actions embedded in the authoring source and every earlier central Showcase Action/asset are preserved. The saved central file was reopened in native Blender, the approved Aim was reselected independently, and the new Pending Action played two natural loops at 30 FPS with the actual rifle visible. See `registration.json`, `native_playback_validation.json`, `preservation_validation.json` and `media_validation.json`. Existing gameplay, movement speeds, camera, grip and transitions are unchanged. No Godot Fire/Recoil integration is included.

## Reproduce

Copy `authoring/` to a temporary folder outside Git and use Blender 5.2.2:

```sh
blender --background --disable-autoexec --python /temporary/authoring/build.py -- --repo /path/to/GameAssetFactory
blender --background --disable-autoexec --python /temporary/authoring/validate.py -- --repo /path/to/GameAssetFactory
blender --background --disable-autoexec /temporary/rifle_fire_recoil_actionsstyle_v001.blend --python /temporary/authoring/render.py -- --view three_quarter
```

Use `front` and `side` for the other cameras. The pinned approved Aim source is required; proprietary pack/source material remains external. No raw pack extraction or large generated index is added to Git. Blender files use the repository’s existing LFS pattern; no tracking/history migration is needed.
