# Blockbench locomotion practice

Open `Minecraft_Locomotion_Practice.bbmodel` in Blockbench using **File → Open Model** (or drag the file into Blockbench). The project is already open in Blockbench on this machine.

This is an animation-capable **Generic Model** with six plain cuboids and exactly seven independently animatable groups:

```text
Root
├── Body
│   ├── Head
│   ├── RightArm
│   └── LeftArm
├── RightLeg
└── LeftLeg
```

The character is 32 units tall. Head: 8×8×8; body: 8×12×4; arms: **3×12×4**; legs: 4×12×4. Each limb is one rigid cube. There are no elbow, knee, hand, foot or joint bones. Both feet start at Y=0. Arms rest vertically beside the body. Colors distinguish the parts; there are no external textures or plugins required.

All bone rotations start at zero. Root pivots at the ground and moves the whole character. Body pivots at waist/hip height (Y=12), so head and arms follow torso tilt and twist while legs remain independently controllable. Arm pivots are at shoulder height (Y=24); leg pivots are at hip height (Y=12); Head pivots at the neck (Y=24).

## Your first Walk

1. Switch to **Animate**, click **+** in the Animations panel, and name your new animation `Walk`.
2. Set **Length** to 1 second, **Loop** to Loop, and snapping to 30 FPS.
3. Select the **bone group**, such as `RightLeg`, rather than its cube. Add Rotation keys at 0, 0.5 and 1 seconds. Swing legs in opposite directions around X; swing each arm opposite its same-side leg. Repeat the starting pose at 1 second to close the loop.
4. Press Play, adjust the motion, and save. Use Body for gentle torso tilt/twist; use Root position Y for a small whole-character bounce.

The delivered timeline is deliberately **empty**: zero animations and zero keyframes. No Walk, Run, Jump or Idle animation has been created.

Verified in Blockbench 5.2.2: native save/reopen, animation-capable format, supported bone keyframe channels, all seven rotation pivots and position transforms, 3-unit arms, grounded feet, and neutral restoration. Transform checks used temporary viewport transforms only; no animation or keyframe was created. Results are in `validation.json`.

This practice project is independent of the existing Blender character and previous bridge. No Blender files, rigs, Actions, Godot resources or import pipeline were created or modified for this setup.
