# Rifle_Ready_Idle_ActionsStyle_v002 — Pending Blender review

One new8-second/30FPS looping custom rifle-ready candidate, in the existing Animation Showcase. **Not approved; no Godot integration.** Actual unchanged Rifle Stylized V2, original character/rig/materials, rigid whole arms and planted legs.

Open `blender/animation/showcase/Animation_Showcase.blend` → N → Animation Library → `Rifle_Ready_Idle_ActionsStyle_v002`. `v001` remains immediately selectable in the same focused list for direct comparison. Play/Pause, Restart, Loop and Front /3/4 /Side controls use the existing panel.

Review at1x/30FPS:
- [v002 three-quarter](rifle_ready_idle_three_quarter_30fps_1x.mp4)
- [v002 front](rifle_ready_idle_front_30fps_1x.mp4)
- [v002 side](rifle_ready_idle_side_30fps_1x.mp4)
- [Side-by-side: v001 left, v002 right](comparison_v001_left_v002_right_30fps.mp4)

Compared with v001, v002 uses the verified **third-person crossbow** hold/layering as its primary reference: an11degree bladed ready stance, jointly braced shoulders, matching arm/weapon response, more active1s rebound within4s weight drift, and head-led left/right observation with pauses. The slower relaxed4s breathe of v001 is retained only in its unchanged Action; v002 has its own authored curves.

The rifle-to-both-arm relation and right-hand grip/left support are identical to approvedReady. The holding frame pivots with the body rather than replacing rifle placement. Source's absolute crossbow arm angles and weapon tilt cannot be applied literally while preserving these fixed rifle contact points and straight arms; this is explicitly a **constrained crossbow-informed adaptation**, not an exact crossbow reconstruction. See [actual source/controller findings and adaptation limits](REFERENCE.md).

F1–240 playback, F241 closing key excluded, original8s loop. Original scan poses/times/curves and periodic support functions; no proprietary temporal keys, reload/fire/shield/first-person clip or recorded crossbow video playback. Meshes/rest/weights and weapon model unchanged. No additional character Action besides v002.

Validation evidence: `motion_validation.json` (481geometry/half-frame samples, feet/grip/loop), `registration.json`, `reopen_verification.json`, `gui_playback.json`, `media_validation.json`, `preservation.json`. Authoring and read-only geometry verifier are in `authoring/`; raw source pack/excerpts and disposable working backups are external.

Future integration requires explicit artistic approval of this candidate and direct use of the existing player/weapon architecture. Blender-only validation does not establish runtime interruption, locomotion transitions, mobile performance or production licensing.
