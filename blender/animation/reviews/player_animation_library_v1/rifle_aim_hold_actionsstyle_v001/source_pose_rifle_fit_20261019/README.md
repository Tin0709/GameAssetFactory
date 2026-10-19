# Rifle Aim/Hold — source-style rifle grip refinement

Same `Rifle_Aim_Hold_ActionsStyle_v001`, Pending Blender review, in the existing Animation Showcase. No additional candidate or Godot change. The immutable `Crossbow_Aim_ActionsStuff_Source_Test_v001` remains separately selectable and unchanged. All previous Pending sources/reviews, including the earlier Ready→Aim→Hold→Ready sequence, remain preserved at the manifest `previous_pending_source`.

## Review

This requested refinement adapts the latest charged-crossbow HOLD pose to the two user rifle images. Open `blender/animation/showcase/Animation_Showcase.blend`, Animation Library → `Rifle_Aim_Hold_ActionsStyle_v001` → Play. One3.6s loop,30FPS, F1–108/closing109 excluded. Movies show two continuous original-speed cycles, with front, side and both three-quarter views. The opposite three-quarter view exposes the rifle/grip most clearly. This current entry reviews the fitted HOLD; the older7.2s Ready/raise/lower presentation has not been erased or misrepresented as a source clip.

## What changed

The actual Rifle Stylized V2 is level with no cant and15deg yaw; the fitted initial grip is[-0.245,-0.500,1.266]m. Compared with the source study's item mount, it is about29mm nearer the centerline,152mm forward and22mm higher. The source-style stock/receiver stays below and beside the face, with two clear contacts: original right-hand trigger/grip position retained, left hand now supports the fore-end. The rifle model, rest rig, skin, proportions and textures are unchanged. The photos guide the hold silhouette, not an added sniper/scope model.

Both arms stay straight as complete rigid blocks. The left contact is adapted within its existing hand block, about29mm farther along the palm than the old reference point, with10deg whole-arm axial alignment. Source crossbow hand spacing could not reach the rifle's previous support contact; that244mm mismatch is replaced by an actual new rifle support contact, not hidden by detaching the hand. Shoulder positions/whole-arm angles are fitted to the rifle and square-head clearance. These are explicit rifle/rig adaptations, not claimed literal crossbow arm angles.

The final fit also seats the intact holding set24mm lower, keeping both contacts and every source clock intact while clearing the square head through the entire breathing cycle. Detailed fit parameters/root deltas are in `parameters.json` and `fit_stats.json`. Body/head/neck/root/leg transforms remain numerically identical to the source study (max core matrix error3.58e-7); head calibration is0deg, so original head motion is preserved. Source0.9/1.8/3.6s breathing, rebound, roll and weight rhythms drive the fitted arms/rifle. No generic idle oscillation or time stretch is added.

## Checks and limits

217integer/half-frame poses: exact rigid forearms/unit scale, support contact and gun-to-hand stability, zero loop seam, connected shoulder surface contact, no unwanted head/arm/rifle/magazine intersections. Maximum left support surface gap2.88mm; minimum head/rifle gap31.28mm. Source leg motion, including the existing4.83mm native boot-corner floor seating, is preserved rather than corrected as an unrelated change. These are Blender checks; this is not gameplay integration or mobile certification. Saved-file reopening, native playback and preservation reports accompany the review.

Primary motion provenance remains the existing SHA-pinned1.12 pack and its verified `njvelc.ltqtzr` (`rrvlnm` then `dubgwy`) / `knoyhk.gjhnog` (`jawwtn` then `asxvzc`) charged-hold graph. Exact provenance and image references are in `source_reference.json`. Full raw pack extraction and fitting diagnostics stay in the external research cache. Research-only/nonproduction because source-derived motion remains present.
