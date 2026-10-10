# V003 jump integration plan

> **For agentic workers:** Use superpowers:executing-plans for inline execution. Steps use checkbox syntax.

**Goal:** Play the two saved V003 moving jumps in F5 WorldMap and clear a 1 m block with a 1.2 m physics jump.

**Architecture:** Append authored pose clips to the current full-arm GLB, preserving old imported clips. Physics owns height and horizontal collision; the final visual layer owns pose and sole support. Keep the blend active across held running repeats.

**Tech Stack:** Blender Python, GLB, Godot Mobile/GDScript.

**Spec:** User request 2026-10-10; source contract in `blender/animation/reviews/player_animation_library_v1/jump_loop_v003/README.md`.

## Constraints and review focus

Preserve source .blend, all old clips, weapon grips, 20 degree combat twist, WorldMap terrain and graphics. SPACE jumps; running plus held SPACE repeats. Automated audio Dummy only. Artistic and phone performance approval remain pending.

Check real 1 m ascent with smooth stepping disabled, early contact on raised ground, low ceilings, repeated cycle seams, release/reset/death and weapon compatibility.

## Tasks

- [ ] Add and run failing WorldMap tests for new Action selection, >1 m apex and collision ascent.
- [ ] Add `jump_loop_v003/export_runtime.py`, new GLB/import adapter and versioned player scene; verify 40 old clips and source hashes unchanged.
- [ ] Add V003 controller/visual layers: 1.2 m arc, continuous authored pose, single entry/exit blend, smooth contact phase adjustment and final sole support.
- [ ] Point WorldMap to the versioned player; run jump, weapon, ceiling, step and map tests with Dummy audio.
- [ ] Capture actual Mobile gameplay with repeated jumps and 1 m block ascent, inspect pixels, review changes and update existing graphics/source documentation.

No commit or production Blender changes are requested.
