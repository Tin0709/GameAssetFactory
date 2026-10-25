# Original Sword animation interface — Pending playable review

Load `original_library.res` as AnimationLibrary; clip names are `Ready`, `Attack1`, `Attack2`, `Attack3`, `Guard`, `Parry`, `Roll`, `Hurt`. Use the existing `source_clip_sampler.gd` API (`position`, `rotation`, `scale`) against the13-bone runtime skeleton. All39 local position/rotation/scale tracks are present. `profile.json` carries exact durations, loop flags, source/action hashes, contacts, fixed grip, weapon mount and original provenance.

For weapon placement, compose evaluated `Arm.R` global pose × `carrier_in_right_arm` × `weapon_mount`. The mount is Blender-local→importedGLB compensation RotX(+π/2), applied once. Imported GLB local `sword_base_local=(0,0,-.1596)` and `sword_tip_local=(0,0,-.96292)` also have `blade_*` aliases. `sword_asset` points to the exact copied new Sword Sand Block V1 GLB; atlas bytes match the source. No old sword or rifle attachment is substituted.

Runtime Root equals RotX(−π/2) × evaluated Blender Root; each child is evaluated parent⁻¹ × child. `UpperArm.L/R` names alias `Arm.L/R`; all other names remain exact. Do not apply a second coordinate conversion. The fixed carrier is reconstructed from the final right arm after composition; do not apply the Rifle two-hand solver.

Ready/Guard/Parry/Hurt and attacks can supply upper-body ownership while the existing locomotion pipeline owns support. Attack contacts .30/.20/.30s are original proposed gameplay contacts. Attack1 ends in Attack2's exact entry pose; Attack2 ends in Attack3's exact entry pose. Both cut points carry original outgoing velocity. Unchained attacks require recovery blending; controller damage/state/cancellation authority remains independent from animation.

Roll(.72s) requires full-body PRS including Root. The clip completes one continuous turn with local pelvis/support compensation and returns to Ready. Physics owns world travel and collision. Never integrate Root translation into controller travel or collapse Root endpoints into a shortest-arc tween. Sample this dense clip over time.

Rebuild from repo root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 --python game_mobile_3d/scenes/dev/actions_stuff_research/sword_combat_v001/export_original.py -- --stage .validation/sword_combat_v001/animation_stage
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game_mobile_3d --script res://scenes/dev/actions_stuff_research/sword_combat_v001/build_library.gd -- ABSOLUTE_STAGE_PATH
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game_mobile_3d --script res://scenes/dev/actions_stuff_research/sword_combat_v001/validate_library.gd -- ABSOLUTE_STAGE_PATH
```

`runtime_validation.json`:6227 checks pass with40 independent native fixtures.30/60Hz complete Roll and connected combo seams pass; maximum native sword-tip world error0.575µm. This proves export/sampler parity and structural constraints, not final gameplay feel or artistic approval. Research release exclusion remains active.
