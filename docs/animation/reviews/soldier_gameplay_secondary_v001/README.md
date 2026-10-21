# Latest SOLDIER appearance, secondary motion and face in gameplay

The existing `res://scenes/dev/ActionsStuffWalkRunTest.tscn` now displays the current worn/ripped Soldier,61flat hair cards and the enlarged red bandana/tails, with the existing Sand Block rifle. No additional Godot scene/project or Blender Action. Backpack stays standalone. Original proportions/slim hands and all approved animation/weapon poses remain intact.

## Secondary motion and latest user refinements

- Hair and hanging tails use the existing closed-form damped spring helper, with **2× response** requested by the user. The fitted hair cap, head wrap and knot remain fixed. Hair cards hinge at their top edges; both tail pairs have separate upper/lower hinges with delayed secondary response. No rigid-body nodes, collision graph or per-hit objects are added.
- Velocity, capped/smoothed head acceleration, heading changes and the actual continuous gait phase excite the springs. Signed relative airflow distinguishes forward/back/side travel. Takeoff trails downward; upward relative air on descent raises the loose ends, followed by damped recovery at landing. Rear-head inward stops limit cloth folding into the skull. Rest pose is restored each display frame before applying bounded offsets, so no accumulated deformation.
- The latest user request changes held-E body acquisition to **180° /0.60s**. This supersedes the previous0.30s tuning. The shared rate applies standing, moving and airborne; Q/C/source observation turns stay unchanged. Actual rifle alignment and the existing Aim-ready gate still own shot timing; firing is not artificially delayed until the torso finishes if the gun can already reach the target.

## Existing facial design reused

The exported84vertex/42triangle face retains all16native shape keys and the original pixel atlas, including the eye/brow cover over the underlying painted face. No mouth/nose or skull deformation. Authored parameters/timing are exported directly from `blender/characters/soldier/facial/expression_model.py`; this is the original SOLDIER face system, not an undocumented Actions & Stuff emotion bank.

Gameplay selects the reviewed Ready, Walk, Run and Focused Aim expressions; each actual shot adds the authored Fire pulse. Existing jump/landing queries trigger their expressions on the physics clock, so30Hz drawing cannot lose a one-tick event. Existing health/defeat signals support Hurt/Low HP/Death, with the authored priority ordering. The lab's existing zero-damage zombie attacks remain unchanged; health reactions are connected without introducing new player damage rules. Nearby enemies may trigger Alert; clearing the encounter triggers the existing small Victory when no longer aiming. Q/C adds gentle eye following without changing the approved7° head lean. All18named facial presets remain callable, including explicit Blink_Soft.

One persistent, irregular blink clock survives state changes. Same-priority event requests use four fixed envelope slots and maximum composition, never additive stacking or recovery resets. Face state transitions use a short exponential response. No sampled Blender review-body clips are exported or substituted into gameplay.

## Rendering, preservation and checks

The original ten source inverse binds drive the merged body/clothes454triangles on the unchanged approved gameplay skeleton. Supplemental hair/bandana render palettes and face share the SAME interpolated Head transform as the existing body/rifle presenter; they never write player bones, sockets, contacts, root position or camera. Current visible character totals **662triangles**, six draw surfaces and five512pixel atlas textures. Head/cloth use hard alpha scissor0.5, two-sided cards and nearest filtering; new textures are pinned lossless to preserve palette/cutouts.

Loadout comparison at30/60FPS: exact skeleton pose equality, zero source inverse-bind error, barrel-axis error below1.4e-7 and support surface gap below5.54mm. The existing fire, auto-aim and Combat Strafe checks pass; the latest0.60s turn is measured at both30/60physics rates. Secondary tests cover bounded response, rest/reset recovery, repeated fire, priority suppression, persistent blinking, explicit blink and opposite ascent/fall behavior. Final auto-aim/strafe regressions also pass after the0.60s change. All protected Blender files/Actions, weapon assets, production WorldMap and shared player/combat scripts are byte-exact; only the authorized research adapters and associated checks/exports change.

Native Metal/Mobile30/60FPS captures show walk/run, direction changes, jump/landing, rear-tail lift and front Aim/fire expression/recovery. Final real-time native medians were33.4/16.7ms and p95 about36.4/17.6ms on an M2 Pro; capture overhead is included. These are desktop checks, not a phone benchmark. `Soldier_Gameplay_30fps_1x.mp4` is actual Godot pixels at original speed. Capture-only zoom/orbit changes are not saved into the existing wider gameplay camera.

All new runtime data remains under the existing release-excluded Actions & Stuff research folder. Blender source files, approval metadata and Actions remain unchanged. Original startup scene stays WorldMap; F6 on ActionsStuffWalkRunTest or launch that existing scene directly. Controls remain WASD, Shift, Space, held E Aim+6Hz infinite Fire, RMB Aim/orbit, Q/C standing turn and R reset.
