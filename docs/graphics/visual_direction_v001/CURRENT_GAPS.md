# Current Overworld visual gaps

Assessment date: 2026-11-08. These are art observations from archived GAF renders,
not a new runtime capture, measured MD2 image match or renderer diagnosis.
The project was clean at checkpoint `7e5a1702` before this documentation work.

Private source images:

- `MD2 Research/godot_lab/world_map_terrain_sky_v001/FINAL_REVIEW/spawn_on.png`.
- The same directory's `west_on.png`.
- `world_map_grove_v001/worldmap_grove_benchmark.private.jpg`: older comparative
  board; its MD2 panel is an artistic reference with different scene geometry.

The latest terrain-sky cross-run equality failure is unresolved. These frames
are adequate for qualitative composition discussion, not final technical image
acceptance. No native/reference pixels are copied into this planning package.

| Priority | Visible observation | Proposed next change | Evidence needed |
|---|---|---|---|
| 1 | Spawn has an open centre and several similarly prominent small trees, but no strong destination; planting reads as separate islands | Compose one hero oak/trail bend with supporting tree masses and a calm play pocket | Same-camera blockout with a clear player-route-landmark reading |
| 2 | Many grass patches have comparable density, height rhythm and bright tips; small flower colors recur broadly | Establish calm/transition/dense zones and a restrained floral hierarchy | Wide view plus walking clip; visible ground still connects plants |
| 3 | Local root/contact work exists, yet broader grass-bank boundaries still read as patches laid onto the floor | Make soil wear, root color, grass banks and path edge share a continuous authored pattern | Root/path close views and normal gameplay distance; no dark rings or square seams |
| 4 | Directional lighting is present and readable, but it does not yet organize one memorable light/shade composition | Place crowns and the hero feature to shape light pools; assess local fill after composition | Fixed exposure/grade A/B; shaded character remains legible |
| 5 | Western stone terraces form strong repeated stairs and parallel strips that can dominate the frame | Keep a small stone/terrace anchor at the slice edge; use vegetation/background framing to reduce its dominance | Whole frame still reads as woodland meadow, not quarry steps |
| 6 | Ground, flowers and foliage often occupy similar attention bands; many pale tips compete | Quiet background contrast, concentrate accents and preserve larger pixel-color groupings | Thumbnail, grayscale diagnostic and full-color frame agree on focal order |
| 7 | Wind and interpolation have scoped tests, but the new art composition has not been judged in sustained play | Review breeze, reveal, shadow coherence and player passage along one fixed route | Normal-speed gameplay clip; no jitter, alpha sparkle or recovery popping |

Do not infer that every stone surface is too dark or that another global grade
will solve these observations. The recent fill/contact systems already address
specific lighting deficits. The missing step is their coordination with shape,
placement and visual hierarchy.

## Technical issues carried forward

- Resolve or explicitly exclude experimental F12 from the slice reference
  baseline; do not quietly treat its final cache as visually closed.
- Latest combined clean timing and all handset/thermal qualification are absent.
- Main WorldMap currently disables combat/spawn. Movement-only evidence cannot
  establish full combat readability or shipping gameplay performance.
- Source asset manifests retain Pending/review and channel contracts. Preserve
  them; verify selected asset eligibility before any device build.

The [slice plan](OVERWORLD_GOLD_SLICE_PLAN.md) addresses the first four visual
priorities before new effects or broad asset production.
