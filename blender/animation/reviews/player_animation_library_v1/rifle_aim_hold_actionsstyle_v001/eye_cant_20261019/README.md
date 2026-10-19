# Rifle Aim / Hold — inward cant and right-foot-forward stance, Pending

Same `Rifle_Aim_Hold_ActionsStyle_v001` in the existing `Animation_Showcase.blend`, still Pending for Blender review. Both latest user requests are combined in this one refinement.

The rifle and rigid right arm cant 10° inward toward the character's right eye. A small10mm lateral/5mm lower grip clearance fit keeps the square head clear. The barrel stays parallel to the right arm; its original hand-local grip remains exact. The complete straight left support arm follows the new rifle contact; its static shoulder changes less than1mm. Hands retain their reviewed tiny contact rather than separating. No elbows, limb stretching, geometry or material changes.

The **character's right foot (`Leg.R`, negative rig X) is forward**, and the left foot is back. Sole-center lateral spacing remains0.32m; fore/aft stagger is0.14m in the6.9° stance frame. Both legs retain3° outward tilt/5° toe-out, with4.5° opposed fore/aft tilt. Feet stay fixed throughout the loop while the existing hips/upper-body idle continues. Rigid cuboid legs have no ankles; lowest sole corners contact the ground. This is a deliberately modest aiming stance, not the wide reference example.

Only33 curves changed: both upper-arm/carrier location/quaternion channels and both leg location/Euler channels. All93 other curves, evaluated head/torso/hips, source0.9/1.8/3.6s clocks, scales and unarticulated forearms remain exact. These are declared user-directed rifle/rig adaptations, not new literal crossbow source keyframes.

The eye/handle sight-line diagnostic improves by at least30mm across the loop; the rifle still does not claim perfect optical ADS. Actual head/rifle surface clearance remains about10mm or greater. The closer fit follows the explicit inward-cant request; an8mm minimum clearance guard replaces the earlier20mm study-fit guard. No head/rifle intersections are allowed.

Select `Rifle_Aim_Hold_ActionsStyle_v001` in the Animation Library and Play:30FPS, F1–108, excluded closing109,3.6s loop. `comparison_aim.png` shows matched front/three-quarter before and after. `aim_reference_30fps_1x.mp4` contains two continuous cycles; front, side and three-quarter stills are included.

The previous grounded stance and every earlier Pending iteration remain complete in their unchanged sources; see `previous_pending_source` in `entry.json`. All approved Actions, other Showcase entries, native assets and Godot remain untouched. Research-only/nonproduction; no Godot integration.

To rebuild, open the source pinned in `authoring/baseline_entry.json` and run `authoring/build.py`. Validate this candidate with `authoring/validate.py`; baseline matrices are regenerated in memory from that preserved source, without committing a full generated transform dump. Review render: `authoring/render.py -- reference`.

Validation:217half-frame poses pass; zero unintended intersections, no hip gaps, exact loop pose; sole-vertex drift≤0.25µm. Head/rifle surface gap≥9.91mm; right-foot forward projection along the rifle direction≈159.5mm. Saved/reopened selectors and two native playback loops pass; the30FPS movie decodes216frames. All88 other Actions and6913prior protected files, including2007Godot files, remain exact.
