# Three reference jumps V002 — Blender review

Added 2026-10-10 to the existing `../player_animation_library_v1.blend`.
Open `../Open_Review.cmd`, select **Player Review → Jump (study only)**, then:

| Sidebar entry / Action | Range at 30 FPS | Last support / contact | Preview flight |
|---|---|---|---|
| Jump / Stationary V002 · `Jump_Stationary_v002` | F1–27 / 0.867 s | F5 / F21 | 0.58 m nominal arc, no forward travel |
| Jump / Walking V002 · `Jump_Walk_v002` | F1–29 / 0.933 s | F7 / F23 | 0.58 m nominal arc, 2 m/s |
| Jump / Running V002 · `Jump_Run_v002` | F1–27 / 0.867 s | F5 / F21 | 0.64 m nominal arc, 4 m/s |

Space plays/pauses; **3/4, Front, Back, Side** select cameras. Each is a separate
scene with timeline phase markers. Moving previews reset at the end; they are
single jumps with stride entry/exit, not seamless gait loops. The saved view opens
Stationary at its air pose. Old Default V001 and every previous review remain.

## Source observations and authored choices

The three user recordings are copied without alteration to `references/`;
[`references.json`](references.json) records original paths, SHA256, FPS and size.
Their overview/detail sheets preserve recording frame numbers, not Blender frames.
All three are 30 FPS recordings: stationary 10.733 s, walking 16.3 s, running 12.5 s.

Observed: compact jump silhouette, low arms near the body, a held uneven leg stride
in the air, and greater ground travel when running. Stationary is more upright;
walking has a modest stride; running has a wider stride and stronger forward lean.
This follows the new videos, preserving the older lifted-arm Default study.
Camera following/bob prevents exact height, velocity, joint-angle or first-contact
measurements. Our timing, 0.58/0.64 m arcs, 2/4 m/s flight speeds, 3/4 camera and
exact pose angles are **review parameters**, not measured game physics.

## Asset contract

- Three new pose Actions and three separate `PREVIEW_ONLY_*_Travel` Actions:
  320 total, preserving all 314 previous Action curve hashes and old scene timing.
  `manifest.json` contains names, slots, cameras, markers and preservation hashes.
- Same full-arm character mesh/materials/UV/weights and 14-bone rest rig. No new
  knees, ankles, scale animation, Root/Hips channels, constraints or IK. Landings
  absorb through torso/arms and stride, within the rigid-leg model's limits.
- The 8 mm outward shoulder pose offset is local to these studies. Stationary
  restores the original 32 mm shoulder inset and exact neutral endpoints. Walk/run
  use stride endpoints; they are **not** exact samples of the old locomotion Actions.
- The carrier supplies height and forward travel only for Blender review. It keeps
  one supporting sole's center stable before takeoff and after landing; rigid toe/
  heel corners can roll. This is not full-foot IK or proven runtime foot locking.
  Nominal flight height is above a line joining launch/contact support heights.
- Original scope was Blender-only. The subsequent explicit user request now integrates
  these three Actions into main WorldMap/SPACE and enables held-Space repeats while
  running. See [runtime contract](../../../../../game_mobile_3d/assets/characters/jump_set_v002/README.md)
  and RESEARCH for real-game evidence. Default V001 remains separately preserved.
  Integration does not establish artistic approval, foot locking or phone performance.

## Review and verification

Watch [`stationary`](jump_stationary_1x.mp4), [`walking`](jump_walk_1x.mp4),
[`running`](jump_run_1x.mp4): 3/4 and side together, motion at 1×/30 FPS, three takes
with labelled review holds. Contact sheets are `<kind>_contact_sheet.jpg`.

`validate_set.py` evaluates saved scenes at 1/128-frame intervals: floor clearance,
airborne separation, support-center drift and carrier trajectory. Quarter-frame SAT
checks compare the 21 nonadjacent rigid cuboid pairs against original neutral; no
new overlap is allowed beyond 10 µm numeric tolerance. Existing ~3.875 mm
Chest/ForeArm seam overlap is retained, adjacent joints excluded. `validation.json`
records measured errors and camera bounds, not just pass/fail. Ground interpolation
may leave up to 0.3 mm additional gap at a toe/heel corner switch; it is not penetration.

Run the parent `verify_review.py --skip-renders` on the saved library for all 57
selections and original source hashes. Render/package/encode scripts here produce
the previews without saving render changes over the library. `media_validation.json`
records full MP4 decode checks. Intermediate renders/backups are under ignored
`.validation/jump_set_v002/`; `build_set.py` is additive and refuses duplicate scenes.

**Awaiting human review. Creating these studies does not establish artistic approval.**

Runtime export: `export_runtime.py` opens this saved library read-only in background Blender.
It adds the three pose clips to a separate V002 GLB without saving this `.blend`.
