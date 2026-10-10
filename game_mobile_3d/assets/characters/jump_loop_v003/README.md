# Jump LOOP V003 — WorldMap runtime review

User request, 2026-10-10: integrate the saved moving V003 loops and jump higher than
one block so the player can reach block tops. Main F5 scene remains WorldMap.

| Profile / Action | Source period | Takeoff / nominal flat contact | Physics apex |
|---|---|---|---|
| Stationary / `Jump_Stationary_v002` | 26/30 s | 4/30 / 20/30 s | 1.20 m |
| Walking / `Jump_Walk_Loop_v003` | 28/30 s | 6/30 / 22/30 s | 1.20 m |
| Running / `Jump_Run_Loop_v003` | 26/30 s | 4/30 / 20/30 s | 1.20 m |

SPACE jumps. WASD chooses travel; Shift chooses running. Holding SPACE while running
repeats only after actual floor contact and recovery. Release SPACE or Shift to stop
the next hop. A current hop finishes. Stationary/walking presses remain single jumps.

The authored moving legs play at full weight, with a single entry/exit blend. Same
Action repeats retain full blend through their matching end/start. Different Actions
blend once over 4/30 s. Physics controls horizontal travel, height, ceiling hits and
floor contact. Raised blocks contact earlier; recovery advances from the current
pose to the loop end without jumping to a contact key. Extended moving falls keep
their authored pose phase advancing without applying another upward impulse.

The 1.20 m gameplay arc is intentionally higher than the Blender preview's 0.50/0.58 m
arc. Neither carrier travel nor its ballistic arc is exported into the pose. Gameplay
speeds/acceleration and smooth-step behavior remain unchanged. Jumping onto a block
still requires approaching it at a suitable distance and a clear space above it;
the controller does not teleport or guarantee every trajectory reaches a platform.

## Source and preservation

- [Saved Blender source and guide](../../../../blender/animation/reviews/player_animation_library_v1/jump_loop_v003/README.md).
- `player_r15_jump_loop_v003.glb`: base V002 geometry, full-arm skin, UVs, materials
  and 40 older animation definitions unchanged; two new 120 Hz / 22-track clips.
  Walk has 113 samples including the closing endpoint; Run has 105. Loop playback
  does not add another held closing frame. No new bones or scale tracks.
- `export_runtime.py` reads the saved library without saving it, verifies rig rests
  against the base GLB, and protects source/base SHA256. Only separately derived
  sole support is baked; maximum vertex reconstruction error below 0.84 µm.
- Godot post-import duplicates all older imported Animations, preserving existing
  track masks and weapon timings. Atlas import parameters match V002.
- The final R15 layer recomputes support from composed sole corners. Held weapon
  arms, carrier/recoil/stow/draw layers and existing target heading remain in use;
  the 20° torso limit is reapplied. All earlier scenes and animation assets remain.

## Verification and review

`validate_jump_loop_v003.gd`: 28 checks at both 30/60 render FPS with 60 Hz physics.
Measured apex ~1.200 m; walking and running land stably on a 1 m temporary collision
fixture and an original WorldMap riser, both with smooth-step assistance disabled.
`validate_jump_loop_transitions.gd` checks profile changes and a 10 m drop; measured
stationary→run maximum per-physics leg step ~4.91°, extended-drop sweep ~57.52°.
Shared jump regression/state-selection suites check input release, reset, death,
ceilings, 40 retained imported clips, weapons and combat twist. Footwork checks
compare completed rendered poses with the new source clip, armed and unarmed.
WorldMap geometry and smooth-step suites also pass.

Actual Mobile/D3D12 video, frame metadata and checks:
`game_mobile_3d/.validation/jump_loop_v003/`. See the existing
[graphics research](../../../../docs/graphics/RESEARCH.md#animation-nhảy-block--blender-v1-và-v2-chờ-review)
for current evidence. Offline capture is not a phone performance measurement.
Rigid feet may roll/slide; no IK or exact ground locking is claimed. Review the
height/cadence and transitions in the game before treating them as final art.

**ARTISTIC STATUS: AWAITING HUMAN REVIEW.**
