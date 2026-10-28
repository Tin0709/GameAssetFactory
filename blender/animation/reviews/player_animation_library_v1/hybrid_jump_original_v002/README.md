# Jump v002 — softer body / head response, Pending

User feedback: v001 does not feel bouncy, stops sharply on landing, and lacks natural head/body give. This revision changes the receiving and recovery motion. It does not promote any Pending work or change Godot.

Run **Open Soft Jump v002 Review.cmd**. The EXISTING `Animation_Showcase.blend` opens **Jump v002 — Soft body / head (v001 A-B)**. **Left: v001. Right: v002.** Both use the same original character, cameras,0.52s preview flight and contact time. Space pauses. Front / Side / Three-quarter and the named timeline markers help inspect the receiving motion. V001 remains selectable with its original curves/status; its comparison rig only binds that unchanged Action.

New registered Pending Actions:

- `Jump_Landing_MD2_AS_SoftBounce_Original_v002_PENDING`:0.75s,60FPS,frames1–46, finite.
- `PREVIEW_ONLY_Jump_MD2_AS_SoftBounce_Context_Original_v002_PENDING`:2.4s take,frames1–144,closing145. Presentation travel stays on separate Empties.

No redundant Takeoff/Airborne Actions: the new context reuses our own original v001 functions during ascent and blends into the new receiving attitude during descent. All new landing knots/tangents are independently authored; no A&S/MD2 keys are copied.

## What caused the old stop-start feel

V001 drove every key segment through a quintic ease with zero endpoint velocity. Its45mm compression reached bottom in55ms and changed direction several times inside300ms; head/body maxima were only15ms apart. That is below one30FPS display interval. Zero velocity at a real extremum is correct; the problem was the cramped spacing and closely aligned responses, not simply the existence of extrema. The intentionally stable global head rotation also limited follow-through.

Direct pack inspection confirms A&S local landing has a substantially longer overlapping body/head response and Catmull curves, with authored local clips0.75–1s. It also has scale deformation which this rigid interpretation deliberately excludes. Source clip length is not an input lock or physical flight duration.

## Original v002 changes

| Measured original response | v001 | v002 |
|---|---:|---:|
| Landing pose duration |300ms|750ms|
| Hip compression / time to bottom |45mm /55ms|62mm /115ms|
| Maximum vertical hip compression speed |1.534m/s|0.809m/s|
| Maximum hip acceleration |85.9m/s²|28.1m/s²|
| Head peak behind torso peak |15ms|100ms|
| Head global pitch peak |4.5°|8.5°|

`response_comparison.json` labels these analytical original-curve measurements. Saved-source `measurements.json` independently evaluates actual keyed poses. Shape-preserving C1 Hermite curves continue through non-extremal landmarks rather than stopping at every sampled point. The body loads first, head follows, recovery runs longer, and one smaller settling dip diminishes naturally. Source curves are densely LINEAR-baked in Blender; they are not mathematically C1 between every finite bake segment.

Feet stay fixed during this stationary landing. The rigid leg origin absorbs up to62mm of hidden hip-junction overlap; full limbs retain original lengths, unit scale and identity ForeArm helpers. No knee/elbow, head scale or new neck geometry. Exact terrain/moving-jump behavior is outside this Blender revision.

## Evidence and boundary

2,001 saved-rig samples per Action and30/60/120Hz output checks: sampled contact/context penetration0, planted sole velocity0, scale error0, settled/context-loop pose error0. Independent2,001-sample geometry check found no nonadjacent arm/head, arm/torso or limb intersections above1mm; normal connected head/chest overlap remains. Timeline markers use nearest whole review frames; the actual hip/head extrema keys retain115ms/205ms precision.

Both A/B actors have identical elevation curves. The original preview's root collision velocity change is preserved; this is a pose/secondary-motion correction, not a claim of fully continuous world-space collision velocity or recovered native MD2 physics. The longer animation recovery is not a new gameplay input delay. Godot controller, physics, camera, graphics and all previous animations stay unchanged.

`Jump_SoftBounce_v002_AB.gif` contains72actual Blender samples over2.4s at average30Hz; identical quiet holds can be codec-merged. Authoring source: `hybrid_jump_authoring.blend` (only the two new pose Actions). Baseline, logs and regenerable frames stay in ignored `.validation/animation_showcase/hybrid_jump_original_v002`. See installation/reopen/GUI JSON for actual library preservation. **Pending human artistic review; no integration.**
