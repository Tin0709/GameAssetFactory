# Jump set V002 — WorldMap runtime review

Requested 2026-10-10: replace the active Default V001 jump with three new authored
Actions. **SPACE** jumps; **WASD + Shift + held SPACE** repeats running jumps after
the previous contact and recovery. Releasing SPACE or sprint stops the next repeat,
while the current jump completes. Stationary/walking Space remains a single press.

| Profile / Action | Duration | Takeoff / contact | Nominal ballistic height |
|---|---|---|---|
| `Jump_Stationary_v002` | 26/30 s | 4/30 / 20/30 s | 0.58 m |
| `Jump_Walk_v002` | 28/30 s | 6/30 / 22/30 s | 0.58 m |
| `Jump_Run_v002` | 26/30 s | 4/30 / 20/30 s | 0.64 m |

Selection uses movement/sprint input at jump start and stays fixed through flight.
Each repeated jump requires floor support, completed recovery, living player and no
active smooth step. Flat running repeats every 53 physics ticks (~0.883 s at 60 Hz).
Collisions can shorten flight or delay contact over drops. Existing horizontal
acceleration, travel speeds and smooth steps are retained; preview travel speeds
are not substituted for gameplay speeds.

## Source and preservation contract

- Source: [saved library](../../../../blender/animation/reviews/player_animation_library_v1/player_animation_library_v1.blend),
  [study guide/exporter](../../../../blender/animation/reviews/player_animation_library_v1/jump_set_v002/README.md).
- `player_r15_jump_set_v002.glb` appends three 120 Hz, 22-track pose clips to the
  existing full-arm V001 asset. Its 37 older animation definitions and binary mesh,
  skin, normals, UVs, indices, materials and images are unchanged. V001 remains
  available separately. The import adapter preserves all previously imported clips.
- Only carrier **vertical support correction** is baked into Hips. Its ballistic
  arc, horizontal displacement, parent object and travel Action are excluded.
  Physics owns world travel. No new bones or scale animation.
- `source.json` records sampled parent-relative poses/events. `export_validation.json`
  protects Blender and base GLB hashes; maximum vertex reconstruction error <0.8 µm.
  Texture import parameters match the existing V001 atlas.
- The final R15 pose layer blends entry/exit over 2/4 source frames. Held gun arms,
  recoil, carrier, holster/draw and target heading remain inherited; the existing
  20° torso yaw limit is reapplied after the overlay. Earlier player scenes remain.

Validation, actual game video, limitations and status are in
[RESEARCH](../../../../docs/graphics/RESEARCH.md#animation-nhảy-block--blender-v1-và-v2-chờ-review).
These are authored review parameters, not measured reference-game physics or phone
performance. Rigid feet can still roll/slide and moving entry/exit poses are blended
into the established gait; full foot locking is not claimed.

**ARTISTIC STATUS: AWAITING HUMAN REVIEW.**
