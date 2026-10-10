# Jump + Land V004 runtime implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement task-by-task. Steps use checkboxes.

**Goal:** Use the saved straight-arm Jump + Jump Land V004 for stationary, walking
and running jumps in main WorldMap; keep the camera's jump height fixed while X/Z follow.

**Architecture:** Append one pose clip over the unchanged V003 GLB and imported
animations. A versioned player/controller reuses the existing movement, weapons,
repeat/reset and pose writer. WorldMap replaces only its player and camera vertical
tracking; terrain, graphics and historical scenes remain intact.

**Tech Stack:** foreground Blender 5.2, Python GLB append, Godot 4.7.2 Mobile, GDScript.

**Spec:** Current user requests in this chat; source/timing and straight arms are
documented in `blender/animation/reviews/player_animation_library_v1/jump_dungeons_gif_v004/README.md`.

## Global constraints

- Use V004 for all three movement states (explicit user answer).
- Keep existing horizontal speeds and 1.20 m physics apex; physics owns collision.
- F5 remains `WorldMap.tscn`; preserve every prior Action/GLB and scene study.
- No elbow bend in unarmed V004; preserve existing weapon grips/aiming layers.
- Automated tests use `--audio-driver Dummy`; user playtests retain normal audio.
- Camera holds its vertical anchor while airborne and follows X/Z normally; land
  on a different elevation settles smoothly, reset immediately resets the anchor.
- Work in the user's current project/foreground Blender so their F5 sees it;
  do not switch/reload source windows, commit, stage or merge unrelated work.

## Review focus

- Early raised contact: crossfade into landing without snapping the airborne pose.
- Long drops/ceilings: do not replay takeoff or apply air impulses.
- Held running: only repeat after supported recovery; stop on release.
- Weapon switch and death/reset: preserve existing layers and cancellation.
- Camera: stationary jump is fixed; moving jump X/Z follows; overview/reset and
  elevated landing do not retain a stale anchor.

### Task 1: Versioned V004 player and export

Files: new source `jump_dungeons_gif_v004/export_runtime.py`; new runtime
`assets/characters/jump_gif_v004/`; new `tools/jump_gif_v004_post_import.gd`,
`scripts/player_jump_gif_v004_controller.gd`, `scripts/player_jump_gif_v004_visual.gd`,
`scenes/characters/CuboidPlayerJumpGifV004.tscn`; update WorldMap player preload only.

Interface: existing `request_jump/cancel_jump`, visual `select_jump/set_jump_state`,
plus `begin_landing(from_time:float, contact:float)`; one new 120 Hz pose clip,
frame1 time0, takeoff5/30, contact22/30, end35/30 seconds.

- [x] Add runtime checks for all three profiles, 1.2m apex, straight elbows,
  source pose matching, preserved imported clips, recovery/repeat/reset and blocks.
- [x] Run against current WorldMap and observe missing V004/profile failures.
- [x] Export foreground-only using a temporary cloned rig; derive sole support
  separately, exclude carrier/arc/Root/scale; preserve base binary and 42 old clips.
- [x] Integrate versioned scene and nonperiodic contact handling; import and pass
  checks at 30/60 render FPS and 60 Hz physics.

### Task 2: Camera anchor and actual runtime review

Files: modify `scripts/world_map.gd`; new `tests/validate_jump_gif_v004.gd`,
`tests/review_jump_gif_v004.gd`; docs/asset guides and actual game clips.

Interface: `_camera_ground_y` stores the supported anchor. Horizontal follow is
exact; vertical settling uses frame-independent exponential smoothing on support.

- [x] Observe RED camera height drift during a stationary jump.
- [x] Implement hold/settle/reset anchor, retain overview and cutaway target.
- [x] Check stationary and moving camera, original terrain 1m ascent, early contact,
  ceiling/drop, release/reset/death and weapon regression with Dummy audio.
- [x] Render real Mobile WorldMap video, fully decode and inspect pixels; do not
  infer runtime quality from Blender/import alone. Document measured limits.
- [x] Request one final read-only review and fix important findings; final save
  same live Blender library and verify F5 main scene/config.

Ruling: execute inline in the existing requested workspace, without a redundant
approval gate or commits; direct user authorization and visible F5 integration
take precedence over skill defaults for handoff/worktree/commit ceremonies.

## Follow-up feedback and evidence

- User144458: moving landing legs held parallel; RED landing stride0 degrees.
- User145052: moving takeoff overwrote stride with neutral opening pose; RED
  comparison against the same underlying live gait phase failed walk/run.
- Final visual layer retains Hips/legs on grounded gait, blends to V0047/30s
  after lift-off; releases to continuous gait immediately on contact over6/30s.
  Latching avoids a second pose switch when slowing during recovery.
- Core31 and edge31 checks pass at30/60FPS. All42 older imported clips preserved;
  import43, WorldMap1052 and smooth-step100 checks pass. Dummy audio per test.
- Actual Mobile/D3D12 footage fully decoded872frames/30FPS/1280x720. Inspected
  transition sheets, seven capture sections, held runs and original1m terrace.
  Foreground Blender validation567samples still preserves324oldActions,326total;
  temporary video-encode scene removed, same live review scene restored.
- Final read-only reviewer found no material code defect; no artistic approval
  or phone-performance verification implied. See runtime README and RESEARCH.
