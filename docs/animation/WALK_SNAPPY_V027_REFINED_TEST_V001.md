# Preferred V027 refinement — v001

2026-10-14 · **Pending artistic review** · `Walk_Snappy_V027_Refined_Test_v001`.

The user selected **Walk_Snappy_Test_v1 (retained V027)** as the best current direction. This experiment is copied directly from that Action, not from V028 or OneStep. The original stays unchanged and selectable. Preferred direction is recorded without promoting an experimental Action to production approval.

## Review at original speed

[Preferred V027 versus new refinement](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v001/v027_vs_refinement_1x.mp4) · [Side A/B](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v001/side_AB_1x.mp4) · [Front / three-quarter / side](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v001/refinement_three_views_1x.mp4).

[Actual Actions & Stuff reference / V027 / refinement](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v001/reference_v027_refinement_1x.mp4).

All videos show **six continuous alternating model steps**, 63 frames at30 FPS /2.1seconds, with no holds or replay pauses. The reference is actual Walking frames30–92 at recorded1x speed. Its approximately20-frame cycle versus our21-frame cycle causes visible native phase drift; no video retiming hides it. Matching model cameras, lights, floor and crops are used. Original V027 was freshly rendered read-only.

## What was learned and applied

The local Player Deep Research, evidence README/atlases/annotations/graphs, style and expansion guides, V028 and OneStep/LegTiming studies remain the research basis. The repeated reference compact/exchange family around F33–35,53–55 and73–75 supports testing an earlier exchange rather than simply faster playback. Exact source foot release, contact, 3D paths, interpolation and rig controls cannot be recovered reliably from the recording. The **20ms lead is our experimental hypothesis**, not a measured Oreville keyframe value.

Retiming the whole leg from the later study would also move V027's preferred vertical hop and soft landing. Instead, this refinement advances its existing spatial leg motion, then restores the original lowest-sole height at each current frame. This keeps the preferred vertical rhythm while testing an earlier fore/aft exchange.

### Changes and preservation

- Leg.L/Leg.R movement is sampled from V027 with a C2 phase lead: introduced over5–45ms after the opposite receiving event, held at20ms through180ms, then removed smoothly by350ms. The forward exchange is earlier; braking occupies more time before unchanged placement. The clock remains monotone.
- Leg pitch/orientation and small existing lateral leg variations follow that same source sampling. This is not an isolated Y-curve translation or a completely unchanged3D recovery path. No new poses, knee controls, scale animation or rig edits were authored.
- **All hip/torso/head/arm/root curves are exact copies**, with zero evaluated non-leg world-matrix difference across449 paired samples. Same body bounce, head response, shoulders and arm swing.
- **Actual lowest-sole Z is preserved at the same time** for both feet, including V027's existing hop, vertical release, crest and soft arrival. Maximum measured difference is0.000238mm; no change in sampled airborne/support masks. This is a preservation of the existing hopping style, not a grounded-walk claim.
- A Y compensation of at most31.987mm preserves nominal ground travel while the original vertical support persists. It fades over40ms after release. Restoring lowest-sole Z requires at most100.5mm of vertical correction relative to the retimed matrix. That correction **cancels shifted vertical motion**, rather than adding bounce; it is rebaked only into leg transforms.
- Full-stride cadence remains700ms /21 frames, step interval350ms, diagnostic travel1.59936m/s, playbackF1–21 with closingF22 excluded. Contacts remainF1/F11.5. Original270mm piston target,137.5mm common hop and150mm body range remain the baseline design; their actual sole-height result is preserved.

## Measured timing and spacing

Both measurements use the same1.5625ms grid. Passing is defined as the sole centre crossing the hip sagittal position; it is a diagnostic landmark rather than certified anatomical contact.

| Event | Preferred V027 | Refinement |
|---|---:|---:|
| Left passing after opposite receiving |196.88ms |176.56ms |
| Right passing after opposite receiving |206.25ms |185.94ms |
| Left peak forward sole speed |6.1767m/s |6.1765m/s |
| Right peak forward sole speed |6.6611m/s |6.6606m/s |
| Next placement / cadence |350ms /700ms |unchanged |

Peak speed is essentially unchanged. Source forward-reach extrema remain within0.03mm; the Y contact compensation reduces the rearward maximum by about4.6mm left /6.0mm right. This small spatial exception is disclosed rather than claiming exact stride extrema.

![Timing and preserved vertical rhythm](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v001/timing_curves.png)

## Visual evaluation and limits

Native30FPS sequences show the leg getting through the body sooner and opening earlier, without changing the preferred up/down silhouette. The refinement is deliberately modest: it preserves the bounce the user likes and gives the forward exchange a clearer lead into the same placement beat. It does not solve all differences from the reference: the torso/head remain V027's performance, the rigid piston waist seam is still visible, and the existing intentional airborne sections remain.

The largest native-frame sole-centre displacement is about216.1mm versus223.2mm in V027 (interpolated evaluated curves at30FPS). Those are large existing fast-swing spacings, not a fluidity certificate. All actual native frames of a stride were inspected in [side strip1](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v001/native30_side_1.jpg), [strip2](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v001/native30_side_2.jpg) and [strip3](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v001/native30_side_3.jpg). Judge the satisfying quality using the1x A/B video; no numerical check establishes a reference match.

Static diagnostic phase sheets map referenceF30+i to both modelF1+1.05i. Only these stills normalize time; videos remain native.

![Receive / recovery / exchange](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v001/phase_aligned_1.jpg)

![Open / braking / placement](C:/Users/ADMIN/Desktop/GameAssetFactory/blender/animation/reviews/player_animation_library_v1/walk_v027_refined_v001/phase_aligned_2.jpg)

## Verification and preservation

-1345 geometry samples: no floor penetration or nonadjacent intersections; rigid-distance error0.000252mm; nominal-travel ground anchor drift0.002461mm. Same head/chest gap3.32mm and inherited waist gap up to59.73mm. Preserved waist separation is an artistic limitation, even under the historical75mm bound.
- Loop pose error0.000153mm. Historical0.01-frame second-order velocity seam0.004254m/s passes unchanged0.006 bound. Raw first-order0.012535m/s remains a reported legacy failure. Internal350ms derivative probe0.006205m/s also exceeds0.006, **identically in V027 and the new test**; it is documented as inherited, not reported as a pass or repaired through forbidden body changes. The loop-seam threshold itself was not relaxed.
- All24 older Actions and manifest entries are exact;25 selectable entries pass88 switching/timing/slot/prop/view/inactive-reopen checks. Actual GUI playback completes two loops, pauses and restarts atF1.
- Rig rest, proportions, geometry, UVs, weights, materials and images are exact. All6340 protected existing files remain byte-identical, including approved animations, research, previous reviews and Godot. Nine H264 videos decode at30FPS,567frames total.

Source SHA256:f23745e76cf472ad7606512cec399cf521db070cd795c257ad43e64f8092ddc1. Action SHA256:8ca1695f08e3775e11df4c772112ca42765775161075563727cb3e6fbb3de5e6. Machine-readable reports and input hashes are in this directory.

No Godot/runtime, production Walk/Run, approved Action or paused Rifle Idle changes. Arbitrary gameplay speed/turning/start-stop/weapon blends are not certified by this Blender test. No separate Foot Recovery Path experiment or Run Action was begun. **Stopped for artistic review.**
