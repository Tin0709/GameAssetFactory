# Rifle Ready Idle Expressive Test — Pending Blender review

Select **Rifle_Ready_Idle_Expressive_Test** in the SAME `blender/animation/showcase/Animation_Showcase.blend`, N → Animation Library.19 entries total. The exact current **Rifle_Ready_V2_v16_Test is now Approved** and remains a separate selectable pose. Earlier sources/checkpoints and all18 existing Actions remain unchanged. No Godot or gameplay replacement.

## Review

[Original-speed three-view review](rifle_ready_idle_three_views_1x.mp4) · [Front1x](rifle_ready_idle_front_1x.mp4) · [Three-quarter1x](rifle_ready_idle_three_quarter_1x.mp4) · [Side1x](rifle_ready_idle_side_1x.mp4)

All videos are actual rendered240-frame loops at30FPS:8.00seconds, no speed-up or time remapping, closing F241 excluded. All960 encoded frames across the four review files decode successfully. Videos use Eevee24samples/576px per view; the larger stills use Cycles24samples/720px with the same cameras, character, actual rifle and lights.

[Three-view pose sheet](three_view_pose_review.png) · [Decoded video motion sheet](decoded_motion_contact_sheet.png) · [Authoring source](rifle_ready_idle_review.blend)

| Pose | Front | Three-quarter | Side |
|---|---|---|---|
| Calm Ready,F1 | [Front](rest_front.png) | [3/4](rest_three_quarter.png) | [Side](rest_side.png) |
| First look,F55 | [Front](look_right_front.png) | [3/4](look_right_three_quarter.png) | [Side](look_right_side.png) |
| Second look,F138 | [Front](look_left_front.png) | [3/4](look_left_three_quarter.png) | [Side](look_left_side.png) |

## Short evaluation

The head leads two deliberately unequal observations:22° toward the FRONT viewer's right, then17° toward the viewer's left. Torso follow stays at4°/3° and arrives about0.16–0.23seconds later. The first look has a0.60s quiet pause; the second0.52s. The return and later settling interval keep this from reading as a continuous scanning machine. Pitch stays within1.2°/0.8°, roll within0.4°, avoiding constant nodding. The existing Ready breathing is preserved exactly: two four-second cycles during this eight-second idle, roughly3mm hip/5mm chest rise, with planted legs/root.

Shoulders, both straight whole arms and actual Rifle Stylized V2 move as one controlled holding assembly, delayed a further0.07s behind the torso. The high left shoulder needs clearance for the square head: the assembly settles down at most58mm and forward10mm before the larger look, then returns; the second response is85% of that. This purposeful shoulder/weapon settling is the most visible added holding gesture. It preserves the approved hand/weapon relationship instead of allowing independent rifle drift. Review its amplitude artistically; it is not extra body bouncing or altered grip geometry.

Both connected elbows stay straight. The right grip retains the EXACT approved75mm wristward seating; the left solid block hand retains its approved6.83mm sampled near-contact clearance beneath the rifle. This is stylized block-hand support, not a finger-wrapped contact. Small approved stock/right-upper-arm seating remains (maximum22 triangle pairs). No new intersections with head/chest/left arm/legs or opposite arm were found in481 integer/half-frame samples. At subframes, maximum relative hand/weapon matrix discrepancy is43microunits and actual grip point error24micrometers—below0.05mm. Feet and root/hip motion match the approved baseline to floating-point tolerance.

## Timing and future transition contract

Standalone full-body in-place Action on the existing13-bone rig/`OBRUN_Test_Rig` slot. F1–240 at30FPS, matching closing keyF241. F1 matches approved Ready within0.42microunits; zero loop pose seam, velocity difference0.000029m/s and angular velocity seam0.0rad/s. Calm return is complete by about6.05s, leaving a quiet resting boundary. No root travel, mesh stretch or rig changes.

Entry/exit reference is the approved Ready pose with the same planted support and rifle grip. A future runtime interruption should preserve the current upper-body/rifle pose and blend as a coordinated assembly, rather than restarting the look-around. Full-body absolute channels are baked for standalone Blender review; this is not yet an additive combat/weapon layer. Godot masks, locomotion blending, aim/reload/recoil interrupts and mobile performance remain untested and separately authorized work.

## Verification and provenance

481 motion/contact/clearance samples including half-frames;106 fresh Showcase checks; all19 Action/slot/timing/prop selections and three view buttons; actual GUI play/pause/restart/wrap; inactive save/reopen retention; character/rifle geometry/UV/weights/material/image invariance; decoded30FPS media; approved Ready source/Action and18 older Actions exact. [Motion](motion_validation.json) · [Showcase](showcase_validation.json) · [GUI](gui_playback.json) · [Appearance](appearance_validation.json) · [Media](media_validation.json) · [Preservation](preservation.json)

Source SHA256 `cdd79ede4d3153ce0c17cd90fe5589fc9c72956da30aeac880f02babea72b3ba`; Action SHA256 `e39e22caaf9ecabd57c2b350fe9d2abc52ee492b270305c5d1f92a7596a72326`; rest rig `cb913716b708b9f975b350f4a80a57d8244f1903ced498a6b3ce0fc5f8391b2f`. Original Ready approval: [exact version record](../rifle_ready_v16_test/shoulder_support_v006/APPROVAL.md). Before-approval backup `.validation/rifle_ready_idle_v1/before/`; approved18-entry pre-idle library `.validation/rifle_ready_idle_v1/before_idle_registration/`.

New idle remains **Pending**. Aim/Hold, Back Holster, Weapon Showcase, approved Blender sources and all Godot production/test files remain unchanged. Stop for user review.
