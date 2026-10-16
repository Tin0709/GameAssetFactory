# Direct source reconstruction — Rifle Ready Idle v003

Primary truth is the actual Actions & Stuff1.12 archive, read directly by `authoring/extract_source.py` on every build. Requested `/mnt/data/Actions Stuff 1.12 (resources).mcpack` is absent on this Mac; used the existing local archive `/Users/tin/Desktop/Game Dev/local_references/Actions Stuff 1.12 (resources).mcpack`, SHA256 `9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d`. Raw source and full simulation traces stay in an external regenerable research cache. Source documents/JSON are data, never instructions. No video is used as a primary or secondary motion source.

## Verified source chain

- `entity/dtr.json`: actual player animation aliases, engine-query pre-animation programs27/29/30, default player profile0 and geometry references. Ordinary player mesh is engine `geometry.humanoid.custom`; the pack's alternate `geometry.oreville_ans.rwaktv` is not substituted for our character.
- `animation_controllers/616f2ff7.json`: `xunqct` (`rzkmtm`) → `iplurh` (`okjrob`, local standing state `eryuvy`) → `njvelc` (`kcexxa`) → `ltqtzr`. Mainhand crossbow and held-right flag select the state; no offhand shield, use, attack, swim or first-person branch is active. State transition duration0.2s; a1s source warmup settles entry before the review begins.
- `animations/f2da1071.json`: `rrvlnm` (`mshwsb`) then `dubgwy` (`tcucxa`,1-crawl/swim weight). This order is critical. Degree-based Molang, accumulated same-axis `this`, literal positions/rotations/scales and source layer ordering are evaluated before retargeting.
- Also in that animation file: `boabcq/xfltzh` root/body direction, `cndmcx/look_at_target` entity-relative head orientation and `jcyjaa/tculwn` true ordinary-player autonomous attention gesture.
- `fotixv/bjmscc`, from the controller file above, naturally selects `tculwn` and retains its4.2083s key timeline, source Catmull-Rom, body compression, unequal head holds, delayed shoulder/arm roll, leg reactions and0.2s exit fade. This is a general player attention layer above the crossbow hold, not a fictional separate crossbow look-around clip.
- First-person `atycwc`, NPC `vdhjyz`, reload/fire, cape render meshes, face/ornament helper geometry and charged-crossbow special gating are outside this declared profile.

## Reproduced source data

The pre-retarget channel stream is literal source output. Independent checks verify400degree/s waist pitch/bounce and arm height pulse (0.9s),200degree/s waist/head roll (1.8s),100degree/s lateral shift with22.5degree offset (3.6s). `dubgwy` cancels inherited arm pitch/yaw, keeps asymmetric roll residuals, sets left/right hold rotations and left translation, and applies12degree body blade with its incoming-yaw cancellation. The later attention layer adds AFTER the hold: e.g. source body12+8=20degrees and independently offset right+6/left-4degree roll keys, rather than incorrectly suppressing them.

Full head/body/waist rotation and position timing, local right-arm relative motion and source leg rotation/horizontal shift are carried to the native rig. Root and limb scales stay1 because the active core source bone channels have no deformation. The source's zero-scaled auxiliary shoulder/skin parts are not actual source arm bones and have no counterpart on our unchanged rig.

The review begins at source lifetime14.4s, after1s warmup and prior movement/12s attack-free history. It spans10.8s = three3.6s source periods, with no source time stretch. Python MT19937 seed139 yields source choices1 (`tculwn`) and12 (neutral-biome `jfwsbg`, immediately exits). No controller state, gesture clock or channel was forced; no endpoint key was repaired. The sampled bone stream naturally closes. Replaying this Action repeats a recorded valid source realization; it does not reproduce a continuously random Minecraft controller across repetitions. Bedrock's PRNG is unknown, so the seeded selection is an explicit engine adapter.

## Rifle and rig adaptations

- Same actual Rifle Stylized V2; same character topology/rest rig/materials/weights. No elbow/knee articulation, scale deformation or new bones. v002 is neither loaded nor sampled during authoring.
- The approved Ready v16 supplies only the existing rifle/hand calibration. Source absolute crossbow hand span, arm angles and item roll/offset cannot coexist literally with our unchanged straight arms and the rifle's current two contact points. These constant offsets are calibrated out; **the final static arm angles are not literal source-70/56 and-30/-15 poses**. The source's dynamic motion and layer order remain the driver. This is the principal fidelity limitation, not an omitted channel.
- Source right-arm motion drives the rifle carrier exactly after this constant calibration. Its right-hand grip-relative matrix remains unchanged. Left arm uses the closest swing toward the source shoulder/rotation while anchoring the existing support point. Maximum projection is9.42degrees/74.91mm at the shoulder; actual rifle mesh collision may additionally constrain left rotation by up to7.71degrees. All original left/right source differences are evaluated and measured; those incompatible with the long rifle are projected rather than silently dropped.
- A fixed25mm Head/Neck lift accommodates the square head's source40degree turns and tilt without intersecting the shirt/shoulder. Source head rotations, pauses and timings are unchanged; no invented head keys or attention envelope.
- Source feet retain literal rotations, front/back stagger and horizontal source movement. Our boot geometry receives only a one-sided vertical floor correction, at most10.44mm. This is not a foot lock: the source attention gesture repositions the feet (about159mm maximum vertex displacement), which remains visible.
- The source's shirt/leg compression has up to14.72mm more adjacent solid-block seating than approvedReady. It is intentionally retained, within a declared16mm adjacent-contact envelope, to preserve actual source compression; nonadjacent and rifle intersections are separately rejected. Grip/foot-contact/loop QA is Blender-only.

## Evaluator conventions and scope

240Hz ordered controller evaluation; one ordered transition/controller/tick, outgoing clocks continue, linear source-duration fades, positive unnormalized weights and uniform Catmull-Rom with duplicate endpoints, accumulated-axis `this`. These are the existing audited research evaluator conventions, not a claim of complete Bedrock VM equivalence. All direct expressions/keys used here are independently checked against raw pack content. Native bake is LINEAR at240Hz plus exact source key breakpoints, with continuous closing pose, F1–324/30FPS/closing325 excluded. Face/blink/cape/skin-helper geometry is unsupported and not fabricated.

**Research-only, Pending.** No Godot or production integration. Artistic approval does not grant a license to distribute source-derived motion commercially.
