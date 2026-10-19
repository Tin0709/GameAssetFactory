Archived prior Pending iteration: the user's09:50 side/back screenshot exposed excessive forward extension of the holding set. This pose is superseded by the next shoulder-seated refinement; it was not approved. The source and review renders remain for reversal/comparison.

# Focused rifle Aim/Hold — same Pending Action

Select `Rifle_Aim_Hold_ActionsStyle_v001` in the existing **Animation_Showcase.blend → N → Animation Library**. This is a refinement of that same Pending entry, not another Action or Showcase. Blender-only research; Godot remains unchanged.

The latest user reference asks for a coordinated, concentrated upper-body pose. It supersedes the previous rifle-fit restriction that froze the source torso/head. The immutable `Crossbow_Aim_ActionsStuff_Source_Test_v001` and all previous rifle Aim source files remain unchanged.

## What changed

The torso is bladed about36.6degrees with7degrees forward lean. The head has an8degree nod and5degree cant, oriented along the rifle rather than remaining upright independently. The rifle is level with about7.4degrees yaw. Both complete arms stay rigid and straight; the right-hand grip anchor is retained, while the left palm/support is fitted around the new crossing-hand arrangement. These are explicitly authored **rifle/photo/rig adaptations**, not proprietary source angles.

The two painted hand blocks deliberately meet with about0.89mm solid seating. This is the sole newly allowed contact pair; all other nonadjacent collision guards remain. The head-base anchor stays at the transformed torso/neck top. No limb lengths, proportions, elbows, meshes, materials, weapon geometry, rest rig or scale change.

## Source and retained movement

The verified pack is Actions & Stuff1.12, SHA256 `9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d`. Relevant files are `entity/dtr.json`, `animations/f2da1071.json`, and `animation_controllers/616f2ff7.json`: crossbow base `njvelc.ltqtzr` layers `rrvlnm` then `dubgwy`; charged hold `knoyhk.gjhnog` layers `jawwtn` then `asxvzc` (`pcbwvo` is empty). Full literal reconstruction/provenance remains in [the immutable crossbow study](../../crossbow_aim_actionsstuff_source_v001/README.md).

The3.6second charged-hold study supplies the original0.9/1.8/3.6second breathing/weight clocks. A constant body calibration maps the source torso motion to the diagonal stance. Both arms and rifle share the source hold delta, preserving their contacts throughout the idle. Head idle angular excursion is30% of the source delta, with unchanged phase/time; this prevents the square head from seating too deeply into the collar after the new artistic cant. Root/Hips/legs remain source-exact. No generic idle sine curves, timing replacement or video-derived source data was introduced.

## Review and measured limits

Original speed,30FPS, F1–108 with closing109;240Hz bake. Each movie shows two continuous cycles (7.2seconds/216frames). Before/after images use the exact same high three-quarter camera and F85; camera transforms/framing changes exist only in disposable rendering processes.

- [High three-quarter movie](aim_reference_30fps_1x.mp4)
- [Front movie](aim_front_30fps_1x.mp4)
- [Side movie](aim_side_30fps_1x.mp4)
- [Matched-camera comparison](comparison.png)

The rifle's native tall stock/handle and the large square head still constrain exact optical eye alignment. At the calibration pose the diagnostic right-eye-to-sight-axis offset is about81mm; this is a comfortable held aim rather than a claim of perfect optical sighting. No gun/face intersection is used to conceal that mismatch. The actual native rifle is unchanged, without a new scope or remodeled stock. The left support has a small measured surface gap documented in `geometry_validation.json`; right grip and left fitted palm anchors remain fixed relative to the rifle.

The source boot corners' existing4.83mm floor seating is unchanged. This remains a neutral-look charged **Hold** loop. Earlier Ready→Aim→Hold→Ready sources/timing remain available through the manifest's `previous_pending_source`; this update does not claim gameplay transition integration.

## Rebuild and preservation

Compact reconstruction inputs/scripts are in `authoring/`. For an isolated rebuild, copy that directory to a scratch location and run Blender with the unchanged crossbow source file as input and `--python-exit-code 1 --python <scratch>/build.py`; outputs are written beside the script. Then open the generated source with `validate.py`. This uses the saved fitted matrices and parameters; numerical search caches and raw geometry dumps are unnecessary and remain outside Git. Do not run registration or replace an approved source as part of a rebuild.

Saved-file reopening, native playback, preservation and media decoding reports accompany this package. All prior source/review packages remain intact. The canonical Showcase imports only the replacement Pending Action; no other Actions, rigs, meshes, materials, cameras or research sequences are replaced. Existing Git LFS patterns cover the two changed `.blend` versions; no history migration, force push or tracking-pattern changes are made.
