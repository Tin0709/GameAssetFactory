# Rifle_Ready_Idle_ActionsStyle_v001 — Pending

One original custom player Action, registered and selected in the existing `blender/animation/showcase/Animation_Showcase.blend`. N → Animation Library → `Rifle_Ready_Idle_ActionsStyle_v001` → Play. Loop playback is enabled. Actual Rifle Stylized V2 is attached through the existing WeaponCarrier. The original Ready pose remains Approved and recoverable with Show Archived; all79prior Actions and35archived entries remain preserved. New library total80Action datablocks/45registrations, with12focus selectors including existing research sequences.

## Review at original speed

- [Three-quarter video](rifle_ready_idle_three_quarter_30fps_1x.mp4)
- [Front video](rifle_ready_idle_front_30fps_1x.mp4)
- [Side video](rifle_ready_idle_side_30fps_1x.mp4)
- [Ready pose](ready_three_quarter.png), [first observation](look_right_three_quarter.png), [opposite observation](look_left_three_quarter.png)

Each video is240decoded frames/30FPS/8.00seconds, with closing key241 excluded. Character appearance, rigid limbs and actual preferred rifle are unchanged. Videos use Eevee24samples/640px and stills Cycles24samples/800px.

## Original movement design

The approved `Rifle_Ready_V2_v16_Test` shoulder_support_v006 frame1 is the exact holding/stance reference. New poses, timing and curves are independently authored from that original static setup. Actions & Stuff research informs purposeful observation, quick arrival with controlled braking, head lead, delayed body response and grounded weight; no proprietary animation keys, source clips, Molang expressions or controller data were imported into this Action.

The first look reaches24.5° and settles at23° for0.74s; the opposite reaches−21.5° and settles at−20° for0.54s. Head rotation begins before torso/shoulder rotation. Torso follow is restrained3.6°/−3.1°, followed by the holding assembly; pelvis transfer is5mm/4mm with both feet planted. Independently authored asymmetric4s breathing uses1.38s inhale/2.48s exhale,3.5mm pelvis rise plus3mm chest allowance. A quiet final interval returns to Ready before the seamless boundary.

Both whole arms and rifle share one rigid holding transform, preserving the approved right grip, left support and barrel alignment throughout. The oversized square head needs clearance over the high left shoulder: the holding assembly can settle down64mm and forward8mm while attention rises, then recover after the head/body settle. A5.5mm head/Neck release preserves the approved head/chest seating envelope. These small authored clearance accommodations keep the grip intact; elbows never articulate and blocks never stretch. The original solid block-hand support gap and reviewed stock/arm seating are retained.

## Validation

481integer/half-frame poses: no new unwanted intersections, head/left-arm clearance at least1.08mm; arm/rifle relative matrix error7.15e−7, zero elbow gap/articulation, rigid vertex distance error0.000378mm, foot vertex drift0.000181mm. Loop pose error0, one-sided translation velocity difference0.00000375m/s. Entry matches approved Ready within4.77e−7matrix units. See `motion_validation.json`; exact method/adjacency/solid-contact limitations are recorded there.

All79prior Showcase Action signatures and all existing native mesh/rig/material/image/camera/text fingerprints are unchanged. Source Ready, preferred Rifle source, prior entries/statuses/research sequences and1919Godot files remain byte-exact. Native GUI playback completed two wraps and paused atF1. Saved library reopened with Pending status, exact Action signature, slot/timing/prop and preserved prior registrations. All720encoded review frames decode correctly at30FPS. See `registration.json`, `reopen_verification.json`, `gui_playback.json`, `media_validation.json` and `preservation.json`.

## Later gameplay interruption

Full-body absolute in-place Action on the existing13-bone rig; Root has no travel. Ready is the entry/loop-boundary reference. On movement input, interrupt observation immediately, retain the currently displayed head/torso/holding assembly and decay its idle offsets while the lower-body locomotion phase continues. Blend rifle and both hands through the same holding transform; do not independently crossfade the rifle away from either hand. The planted standalone lower-body channels need a locomotion mask/support handoff when used with Walk/Run. These are integration requirements, not claims of runtime validation.

Stop here for artistic approval. Once approved, integrate directly into the existing Godot player and weapon systems using the established architecture; no additional project or unnecessary gameplay test scene. No Godot file, gameplay or production asset was changed for this Blender study.

## Authoring preservation

`authoring/motion_design.py` contains the original numeric design and pure timing tests; `authoring/build_candidate.py` records the source-to-Action bake. Scripts find the repository on macOS/Windows. The bake refuses an Approved registration and requires explicit `--rebuild-pending` before overwriting this Pending source. Rebuilding requires revalidating and updating the existing registry's source/action hashes before refreshing; never rebuild an approved Action in place. Run `validate_geometry.py` in Blender with explicit candidate/output arguments for read-only verification. Existing authoring source/checkpoints are preserved separately.
