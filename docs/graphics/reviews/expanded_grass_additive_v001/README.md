# Existing lab:100×100 grass + additive zombies

User-authorized same-scene update, ready for gameplay review. No new scene/project; productionWorldMap and all Blender/source assets remain unchanged.

-10,000 terrain blocks, full surface planted with14,831clumps:8,053short/6,778tall,8existing meshes,392regional MultiMeshes/twofamilymaterials.
-104m shared contact coverage,196² histories, ~0.53m cells, sparse local spring work. Roots/wind/source textures/material lighting preserved.
-Latest steering: contact gain1.50→2.25,1.5× stronger before the unchanged continuous bend bound; .14damping and1.28wind unchanged.
-Spawn+N adds0–50per click. Existing actors/corpses/targets/shots/statistics remain;0is a no-op. R is the explicit full reset to last applied count. Existing native deaths remain uncapped and clean up after2.5s.

`performance_30.log` and `performance_60.log`:465checks each, failures[]. Real UI20→40→60,100accumulated near a corner, .75m spawn clearance,60deaths/420parts, appending13during death without retiring bodies, normal cleanup and reset. `grass_contracts.log`:29pass; `combat_60.log`:23pass; `fire_30.log`:159shots/no pool misses, approved grip/recoil/aim preserved. `presentation100.log`:196² histories,76moving subframes/0held, max0.000299rad error.

Native Mobile/Metal1280×720 AppleM2Pro: full map `overview100.png`, normal `gameplay_60.png`, `all60_death.png` and fixed30FPS original-speed `grass_contact_1x.mp4`. Close contact captures compare gains1.50/2.25 with the same contact/wind state; normal gameplay camera remains14.5. `native_result.json` is fixed-delta capture proof, not a realtime benchmark.

`performance_result.json` is a separate ordinary-render-loop run: capped/vsynced60, physical clock60Hz, no fixed-FPS override or capture/readback/force_draw in120frame sample windows. Normal20/60, whole-map60 and first2s of60deaths have medians16.65–16.70ms and p9517.11–17.73ms on this Mac. Grass active solver p95.061–.076ms; GPU duration unavailable. These short desktop observations do not establish phone performance, uncapped capacity or large-population limits. Creation/reset spikes are outside these sample windows; append is synchronous/event-driven as requested.

Preservation audit is in `preservation.json`. User play launch uses normal audio and the same saved scene, not the capture helper. No artistic/source-status promotion is implied.
