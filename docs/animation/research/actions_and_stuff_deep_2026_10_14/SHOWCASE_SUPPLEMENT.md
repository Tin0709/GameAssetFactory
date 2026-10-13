# Supplemental local showcase recording: visual research

**2026-10-14 · Research only.** New user-supplied source: [Screen Recording 2026-10-14 045502.mp4](<C:/Users/ADMIN/Videos/Screen Recordings/Screen Recording 2026-10-14 045502.mp4>). No animation, rig, Blender scene, Showcase library, gameplay or live UI changes.

## Provenance and inspected scope

Fresh sequential decode found **638 frames, 30 FPS, 356 × 502**, totaling **21.2667 s** of recorded time (last frame starts 21.2333 s). Source SHA256: `52ffe805e77ce21a1d8f40716bcc81f480693d7abfe0e1066c78f71889132abc`; file size 2,524,819 bytes. Metadata and count agree: [decode report](showcase_decode_report.json).

All frame numbers here are **zero-based source frames**, time = frame / 30. Encoding FPS establishes recording cadence, **not** the original animation's native FPS or real-time playback speed. Pack version, settings, platform, input sequence, source player speed and original recording provenance are unknown. The user supplied the clip as supplemental Actions & Stuff research; the visible clip contains Minecraft-style gameplay but no independently verified version identification.

Actual pixel inspection:

- Whole clip coarse overview: every 30th frame.
- Whole clip temporal index: every sixth frame (0.2 s), 107 samples.
- Consecutive frames inspected on numbered sheets: **F0–359, F420–479, F540–637** (518 frames). These include complete alternating-step passages and selected start, turn, aerial/landing-like and perspective-switch sequences.
- F360–419 and F480–539 received the 0.2-second temporal sample inspection, not a complete consecutive-frame review.
- Selected native-resolution stills checked separately: F85, F242 and F276, plus the view-boundary sheet.
- **No audio inspected. No claim that every frame of the complete clip was visually reviewed.** Decoding all frames is distinct from inspecting all frames.

Reproduction scripts: [decode/overview](showcase_decode.py), [temporal/consecutive sheets](showcase_sheets.py). [Index manifest](showcase_index_manifest.json) records sampling and extraction windows. [Timeline CSV](showcase_timeline.csv) records observations and confidence.

**O** = directly visible configuration; **H** = interpretation; **U** = unresolved. Frame intervals describe visible sequences, not authored animation state names. There is no visible Blender action list, selected Action label, input display or reliable sprint-state UI. The clipped text overlay during the middle of the recording is presentation text, not proof of the active state.

## Timeline and perspective boundaries

| Frames / recorded time | O — visible content | H / U |
|---|---|---|
| F0–27 / 0.000–0.900 s | Front third-person character in a nearly stationary pose; background/camera orientation changes. Black suit, green tie, white smiling-face head texture and white/green shoes. | Small presentation changes do not prove a specific idle or turn-in-place controller. |
| F28–37 / 0.933–1.233 s | First-person/crosshair view without the character body. | Perspective switch, not a demonstrated locomotion transition. |
| F38–48 / 1.267–1.600 s | Rear third-person view; feet remain close while the character is nearly stationary. | Exact input onset unknown. |
| F49–74 / 1.633–2.467 s | Leg separation develops from the stance, then alternates with narrow projected steps; shoulders/head respond. | Start-to-locomotion candidate. Walking versus running cannot be established from a missing input label. |
| F75–114 / 2.500–3.800 s | Much wider alternating leg configurations and stronger raised/bent-arm silhouettes while the camera/heading turns. F85–88 show shoes separated above the shadow/ground region. | Energetic/run-like locomotion; some aerial-looking intervals. Not a clean fixed-camera gait calibration. |
| F115–179 / 3.833–5.967 s | Route crosses stepped sand. Narrower leg passages alternate with open poses; visible sole/ground separation around the rise onto terrain. | Jump, auto-step, sprint or blend ownership cannot be separated without inputs/engine state. |
| F180–212 / 6.000–7.067 s | Moving turn along the beach; narrow and wider configurations occur while arms continue alternating. | A single constant locomotion mode is not established. |
| F213–235 / 7.100–7.833 s | Prolonged elevated/airborne-looking pose; one lower leg stays extended downward while the other is less visible; arms broaden later. | Strong jump/leap candidate, but no validated takeoff/support-side event. |
| F236–249 / 7.867–8.300 s | Dust develops; character becomes very low in the image, with lower body hidden by foreground sand/particles. | Landing-like passage. Foreground occlusion prevents compression-height or sole-contact measurement. |
| F250–299 / 8.333–9.967 s | Wide alternating motion returns. Around F270–284, a stretched limb configuration persists longer than a normal passing pose. | Aerial/leap-like passage can interrupt ordinary gait; do not count the whole interval as a constant run loop. |
| F300–359 / 10.000–11.967 s | Narrower alternating motion and additional visible elevation/settling; dust near the floor. | Full consecutive review, but action ownership and contact remain uncertain. |
| F360–419 / 12.000–13.967 s | Sampled rear locomotion, turns and repeated elevation/settling. | Only sampled every six frames. |
| F420–479 / 14.000–15.967 s | Wide turning stride opens at F426–431, then narrows; later crosses grass/sand, with a visible dust/ground interaction at F463–466. | Consecutive review; terrain/camera mix prevents a constant-speed classification. |
| F480–539 / 16.000–17.967 s | Sampled narrow locomotion and elevation/settling. | Only sampled every six frames. |
| F540–545 / 18.000–18.167 s | Rear view descends from clear shoe/shadow separation toward a narrower configuration. | Consecutive boundary review; exact contact not established. |
| **F546–617 / 18.200–20.567 s** | Front third-person view with continuous alternating leg/arm motion and head inclination. | Perspective switch at F546; do not read this as an animation reset. |
| **F618–637 / 20.600–21.233 s** | First-person crosshair; later quick camera rotation and white particle puff near an animal. | Perspective switch at F618. Particle cause unknown; no player equipment/use action proven. |

Exact perspective boundaries are visible at **F28, F38, F546 and F618**. These are observed presentation changes; the recording does not establish whether they were camera-mode inputs or edits. Other rapid scene motion is not automatically a cut.

Whole-clip index: [0–5.8 s](showcase_temporal_index_00.jpg), [6–11.8 s](showcase_temporal_index_01.jpg), [12–17.8 s](showcase_temporal_index_02.jpg), [18–21.2 s](showcase_temporal_index_03.jpg).

## Locomotion, transitions and upper body

### Start and continuous alternating motion

[O] F38–48 provides an actual near-stationary rear stance immediately before F49–74 leg separation/alternation. This is better evidence for visible start behavior than the earlier isolated front/back reference cycles. The legs enter motion without an observed edited view change at onset. However, no input trace measures responsiveness, and the clip does not establish when the user pressed movement.

[O] F75–114 and the front sequence F550–617 contain multiple consecutive alternating configurations, not merely selected extrema. In F75–84 the silhouette opens and arm presentation becomes stronger. The foot relationship passes rapidly through less distinct configurations and develops into clearer separated poses. These passages can support qualitative spacing and silhouette review.

[U] They do not provide one universal period, fixed travel speed or authenticated Walk/Run state boundary. The current clip contains turns, height changes and prolonged aerial-looking poses. Do not combine its timing with the earlier 20-frame Walk and approximately 17-frame Run estimates as though all recordings used the same version/settings/speed.

Consecutive sheets: [F49–78](showcase_rear_locomotion_00.jpg), [F79–108](showcase_rear_locomotion_01.jpg), [F109](showcase_rear_locomotion_02.jpg); [F550–579](showcase_front_exit_00.jpg), [F580–609](showcase_front_exit_01.jpg), [F610–637](showcase_front_exit_02.jpg).

### Aerial/landing-like continuity

[O] In F213–235 the character stays visibly elevated relative to the ground/shadow region through a prolonged pose family. Arms change before the following dusty low passage. F236–249 then shows dust and a low, partly hidden lower body, followed by renewed wide alternating motion from F250. There is no perspective cut between these phases.

[H] This supports a qualitative moving-aerial-to-landing-to-locomotion reading. It does not prove a particular official named landing action, its input condition, roll state, exact leg phase retention or foot support selection. The published planted-foot push-off claim remains a documented behavior, not a mechanism verified by this clip.

[O] Native F242 makes the lower-body occlusion obvious. Measuring head-to-screen-floor height here would conflate pose, camera and foreground. The apparent depth of the dip is **not** a reliable compression amplitude.

Consecutive evidence: [F180–209](showcase_turn_land_00.jpg), [F210–239](showcase_turn_land_01.jpg), [F240–269](showcase_turn_land_02.jpg). Native examples: [dust-obscured low passage F242](showcase_frame_0242.png), [stretched aerial-looking configuration F276](showcase_frame_0276.png).

### Turning, profile and upper-body evidence

[O] Moving turns reveal rear three-quarter and briefly near-profile silhouettes, including F84–88, F100–104, F250–257 and F426–431. The trunk/head orientation and limb projections vary through the turn while arm and leg motion continues. There is no observed deliberate neutral-pose hold inserted at each turning direction change.

[U] These are moving-camera perspective views, not a fixed orthographic side view. They improve shape readability but do not isolate root yaw, head/body rotation separation, pivot-foot locking, anatomical forward reach or precise pitch/roll.

[O] The arms form visibly bent/raised silhouettes in the energetic passages; hands come forward/outward while the opposite arm occupies another position. This is useful evidence of the reference's upper-body visual freedom. **Our character requires straight full arms:** copying this reference silhouette exactly would require a different visual solution on our rig. The footage does not prove the hidden rig hierarchy, elbow implementation, shoulder pivot or any knee mechanism.

[O] Front F550–617 shows the head inclining while shoulders and arms alternate. [U] A numerical head delay or joint angle is still unproven, and the custom smiling-face texture supplies no reliable facial-expression analysis.

### Equipment, control and effects

[O] Reviewed third-person passages show empty hands; no weapon/tool/item switch is demonstrated. [U] The clip therefore does not settle equipment masks, two-hand ownership, weapon grip, use interruption or offhand transition behavior.

[O] Pale dust/ground particles appear at many receiving/settling-looking moments and during travel. [U] Particle appearance is not an independent contact sensor, and timing cannot be equated to sole contact. The final white puff has no established player-action cause. No sound was inspected.

[U] Input latency, authoritative physics, actual grounded flag, landing velocity, camera bob/FOV automation and controller state remain unknown. Presentation switches and scene tracking must not be mistaken for measured animation resets.

## What this supplement resolves and leaves open

It adds actual **start-adjacent**, **moving turn**, **rear/three-quarter**, **empty-hand upper-body** and **aerial/landing-like continuity** evidence. It also shows why a generic grounded assumption or a single unchanging gait model is inappropriate for all footage.

It leaves exact contact, foot lock, support/flight percentages, planted-foot takeoff selection, physical scale, original curve timing, native rig mechanics, equipment concurrency and control responsiveness unresolved. The clearest limitation for our adaptation is the reference's bent-arm visual language against our straight-full-arm requirement. No artistic-match or gameplay-completion claim follows from this recording.

