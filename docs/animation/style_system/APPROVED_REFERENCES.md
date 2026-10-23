# Approved references and provenance

Approval has several independent meanings. Record the **stored registry state**, the **documented user acceptance and scope**, and the **source/provenance restrictions** separately. A technical pass, preferred model, gameplay authorization or original contribution does not silently change another field. This is a 2026-10-23 snapshot; query the live manifest before future work.

The [player manifest](../../../blender/animation/showcase/animation_manifest.json) currently contains **57 Action registrations: 21 Approved and 36 Pending**, plus two review sequences. Read it for exact source paths, SHA-256, original slots, playback bounds and FPS. Native files may also retain archived Actions; list counts are not native Action counts.

| Reference | Stored state | Documented acceptance | Provenance/use boundary |
|---|---|---|---|
| Expressive arm, original Run, LowerBody Recovery, Takeoff, AirPose, Impact Landing | Approved | Exploratory/artistic references accepted | Authored project examples; gameplay readiness is separate |
| Idle Expressive v3, refined Walk Expressive, Run Expressive v3 | Approved | Preferred expressive baselines | Preserve exact sources/Actions; transitions still need relevant runtime evidence |
| Rifle Ready V2 v16 / shoulder_support_v006 | Approved | Preferred Ready checkpoint | Earlier authored holding reference; not automatic replacement permission |
| Snappy Walk V027 Refined v003 / lower_step and Run v001 / elastic_drive | Approved | 2026-10-14 artistic test baselines | No blanket production promotion |
| A&S source Idle; Ready Idle v003/v004; Ready Walk/Run v001; latest Walk v0012/Run v002 | Approved | Research visual/integration acceptance recorded | Source-derived; research-only, production_eligible=false |
| Refined Crossbow Aim v001 | Approved | 2026-10-19 research Aim integration authorized | Source-derived base; research-only |
| Rifle Fire/Recoil v001, latest 1.5× | Approved | 2026-10-20 continuous-fire integration accepted | Custom recoil impulse **contains source-derived Aim base**; entire clip remains research-only |
| A&S Directional Input v001 sequence | Approved | Research controller accepted | Source-derived, nonproduction |
| A&S Jump/Landing v001 sequence and six source Actions | Pending | Workflow/Progress record 2026-10-15 user acceptance and dev integration | Report status drift; do not repair or promote metadata implicitly |
| Mobs Original Idle/Walk; source Idle/Walk | Pending in delivery evidence | Current live state requires scene registry | Original and proprietary-source categories remain distinct |
| Zombie Attack Player A&S Reference v001 | Reference Only | Existing dev use explicitly authorized later | .75s exact endpoint F23.5; no commercial clearance |

The preferred current rifle sources are [Ready Idle v004](../../../blender/animation/reviews/player_animation_library_v1/rifle_ready_idle_actionsstyle_v004/README.md), [Walk v0012 / Walk-matched Run v002](../../../blender/animation/reviews/player_animation_library_v1/rifle_ready_locomotion_sway_v002/README.md), [refined Aim](../../../blender/animation/reviews/player_animation_library_v1/crossbow_aim_refined_v001/README.md), and [Recoil1.5×](../../../blender/animation/reviews/player_animation_library_v1/rifle_fire_recoil_actionsstyle_v001/README.md). Keep their long source clocks:10.8/7.2/90/3.6/⅙s. Recoil uses approved Aim F85; its `original_custom_animation:true` does not remove `contains_source_derived_aim_base:true`.

Pending alternatives include the softer Landing, both Full Jump studies, earlier Idle/Run versions, most Snappy experiments, five Blockbench imports, literal Crossbow Aim and Arsenal Aim composite. Preserve them as comparisons.

For [Mobs](../../../blender/animation/showcase/mobs_library/README.md), current authority is saved `mobs_registry`; sidecars are historical evidence. No verified skeletal source zombie Hurt was found in the traced zombie graph. The findings entry is not an Action; later runtime Hurt response is explicitly original adaptation.

The [weapon manifest](../../../blender/weapons/showcase/weapon_manifest.json) has Rifle Stylized V2 Preferred, Pistol Sand Block V1 Approved, five Pending and sixteen archived. The [Soldier registry](../../../blender/characters/soldier/showcase/registry.json) keeps its skin/accessories/facial system Pending. A later authorized dev loadout does not promote library status or license third-party motion.

Use the dated [Workflow](../ANIMATION_WORKFLOW.md) and [Progress](../ANIMATION_PROGRESS.md) to interpret older contradictory prose. Preserve explicit prior authorization within scope. Knowledge maintenance never grants new distribution rights, status changes or production approval.
