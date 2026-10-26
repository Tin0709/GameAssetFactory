PLAYER + SABRE PROTOTYPE — 26 OCTOBER 2026

Open "Open Sabre Showcase.cmd" in this folder. If the private MD2 Research
workspace is available, it prefers the original-rig/source-animation/Valorie/Sabre
study there, then the earlier exact-skin reconstruction. Otherwise it opens
Sabre_Character_Showcase.blend, the newly authored fallback in this folder.

Blender: press N in the 3D view, then choose "Sabre Source" for the original-source
study or "Sabre Prototype" for the authored fallback. Pick an Action, then
Play / pause. The source study exposes the original facial bone motion plus
optional Neutral/Focused/Blink morph overlays. The authored study additionally
offers looped blink. The complete reel button restores the NLA sequence.
Opening the .blend directly still provides the reel and named timeline markers.

Private exact-skin study:
  %USERPROFILE%\Desktop\MD2 Research\blender\prototype_sabre\
  MD2_Valorie_Sabre_Source_Showcase.blend (original rig, clips, skin and sword)
  MD2_Valorie_Sabre_Showcase.blend
Use MD2_RESEARCH_ROOT to select a restored research workspace elsewhere.

Godot: run the root "Open Sabre Prototype.cmd", or in the existing Godot project
open scenes/dev/ActionsStuffWalkRunTest.tscn and press F6 for direct Sabre entry.
The root "Open Sabre Editor.cmd" opens this current Desktop\Dev\GameAssetFactory
project. The user selected Desktop\Dev as the canonical workspace. The prototype's
"Return to original Rifle / Sword lab" button retains the old experiment.
No additional Godot project is created.

The latest private source variant uses original MD2 geometry, weights, rig,
animation channels, skin and Sabre assets, retained exclusively inside Research.
Source-unavailable ready/strafe states, facial overlays, equip placement, input
logic and effect behavior remain adapters. The earlier private skin variant uses
our eleven-bone rig and reconstructed motion. The new Godot module labels the
active data; the project contains only the independently generated fallback GLB.

22 actions:
  Idle, Walk, Run, StrafeLeft, StrafeRight
  JumpTakeoff, JumpAirborne, JumpLanding
  CombatReady, ReadyEnter, ReadyExit
  CombatWalk, CombatRun, CombatStrafeLeft, CombatStrafeRight
  Attack1, Attack2, Attack3, Recovery1, Recovery2, Recovery3, AirAttack

The 1H_Medium family is not proven to be the native Sabre assignment. The source
GLB preserves available clip channels and scale tracks; Blender/Godot evaluation
still needs comparison and does not recover Unreal's native animation graph.
Strafe, ready/movement adapters, input buffering, VFX gates, equip transforms and
facial-controller configuration are not claimed to match the original runtime.
Original Sabre audio samples are loaded from Research, with a prototype trigger
and mix. No native Wwise graph or exact sound/VFX synchronization is implied.

Authoring files:
  geometry.py — fresh fallback meshes, own atlas and two face morphs
  motion.py — sparse semantic pose reconstruction and authored adapters
  build.py — editable actions, showcase, own GLB and renders
  validate.py / roundtrip.py — saved poses/weights/grip and GLB roundtrip checks
  preview_ui.py — optional selector; no global autoexec preference is changed

Build with installed Blender5.2:
  blender --background --factory-startup --python-exit-code 1 --python build.py
  blender --background --factory-startup --python-exit-code 1 --python validate.py
  blender --background --factory-startup --python-exit-code 1 --python roundtrip.py
These builders read only this folder's authored definitions. Private skin build
scripts and source-bearing outputs stay in MD2 Research/scripts and blender.
