# Animation reference study

Scope: only `assets/minecraft/optifine/cem/player.jem` in the supplied Fresh
Moves 3.1.1 ZIP; relevant EMF 3.3.11 animation class names, API signatures,
and variable/method registry symbol names in the supplied JAR. No assets,
expression bodies, keyframes, bytecode implementations or formulas were copied.

Fresh Moves observations: state variables feed shared motion inputs before
individual head/body/whole-limb transforms. Limb speed and phase are distinct;
sprint state affects torso and limbs; breathing is shared across body regions;
head and torso have distinct channels. The relevant channels include limb
translations as well as rotations. State gating prevents incompatible motion
from accumulating. Per-entity/time inputs can prevent identical performances.
This structural inspection does not establish exact visible timing or quality.

EMF observations: `VariableRegistry` provides float/bool suppliers and context
variables; registered names include limb speed/swing, forward/strafe movement,
frame time and frame count. `EMFAnimationHandler` validates animation lines and
evaluates against model parts. The public animation context carries active
entity render state and model root. Method-registry symbols include lerp,
easing and looped keyframe methods. These establish architecture capabilities,
not a prescription to reproduce their evaluation implementation.

Independent application: keep normalized speed separate from persistent stride
phase, blend state weights, counter-rotate torso/head, delay arm response, use
small rigid translations for contact, and layer weapon control above gait.
Use deterministic spawn phase/rate variation for zombies. Author our own curves
and contact geometry; never evaluate or distribute the reference expressions.
