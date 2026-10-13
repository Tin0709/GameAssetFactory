# Stronger softened-hop checkpoint — Pending

User requested stronger and smoother rebound after liking the smoother piston legs. Common hop35→50mm (+43%); release80→100ms, return220→200ms, same contact boundary. The higher lift accelerates more gently on release: analytic hop peak acceleration31.57→28.87m/s². Same soft36.25mm load,270mm piston recovery, close tracks, wide stride and torso/head/arm/root curves.

[Comparison validation](bounce_comparison_validation.json):4096phase samples confirm exact piston targets;241pose comparisons confirm all displayed poses differ only by common hop translation within2e-6mixed matrix components. [Motion](motion_validation.json), [Showcase](showcase_validation.json), [appearance](appearance_validation.json), [GUI playback](gui_playback.json), [media](media_validation.json) pass.19otherActions/entries and previous sources preserved; no rig/Godot/production/WeaponShowcase/pausedRifleIdle changes.

[Front / 3/4 / side at1x](walk_snappy_three_views_1x.mp4), [previous vs stronger hop](previous_vs_bounce_1x.mp4), [approved Walk comparison](approved_vs_snappy_1x.mp4), [overhead](snappy_overhead_1x.mp4), [Blender source](walk_snappy_review.blend).

Evaluation: more visible lift with a softer crest, continuous piston recovery retained. Same1second/30FPS loop, current Pending status. User next explicitly asks for50%stronger and quicker body up/down. Preserve this intermediate checkpoint before applying that increase. Stylized flight/runtime transition compatibility still requires later Godot validation.
