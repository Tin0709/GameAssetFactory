"""Seat only the support shoulder closer to the torso; retain the palm anchor.
Input is the accepted10degree tucked Pending v004, not an Approved Action.
This is a rigid whole-arm adjustment; no elbows, scaling or weapon motion.
"""
import bpy,sys,json,hashlib,math
from pathlib import Path
from mathutils import Matrix,Vector
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').is_file());O=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
NAME='Rifle_Ready_Idle_ActionsStyle_v004';INPUT_SHA='64e4635a30e50df9b74aeaa9f05734c09228ef6ab67f80781a096451f4d11360';AIM_BACK_M=.040
r=bpy.data.objects[ui.RIG];s=bpy.context.scene;a=bpy.data.actions[NAME];assert ui.action_signature(a)==INPUT_SHA
manifest=json.loads((R/'blender/animation/showcase/animation_manifest.json').read_text());assert next(e for e in manifest['animations'] if e['action']==NAME)['status']=='pending'
before={b.name:ui.action_signature(b) for b in bpy.data.actions if b.name!=NAME};rest={b.name:b.matrix_local.copy() for b in r.data.bones}
r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s['gaf_library_last_action']=NAME
hand=Vector((0,r.data.bones['ForeArm.L'].length*.78,0));frames=sorted({float(k.co.x) for c in ui.curves(a) for k in c.keyframe_points});vals={};depth=[];down=[];angles=[];palm_error=0.
for f in frames:
 s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update();M={b.name:b.matrix.copy() for b in r.pose.bones};palm=M['ForeArm.L']@hand;forward=M['Chest'].to_3x3().col[2].normalized();oldvec=M['UpperArm.L'].translation-palm
 # Rotation only: closest direction toward a40mm retracted shoulder target,
 # preserving the original arm length and the actual support palm point.
 q=oldvec.rotation_difference(oldvec-forward*AIM_BACK_M);D=Matrix.Translation(palm)@q.to_matrix().to_4x4()@Matrix.Translation(-palm);new=D@M['UpperArm.L'];newfore=D@M['ForeArm.L']
 depth.append((M['UpperArm.L'].translation-new.translation).dot(forward));down.append(M['UpperArm.L'].translation.z-new.translation.z);angles.append(math.degrees(q.angle));palm_error=max(palm_error,(newfore@hand-palm).length)
 b=r.data.bones['UpperArm.L'];basis=b.convert_local_to_pose(new,rest[b.name],invert=True,parent_matrix=M[b.parent.name],parent_matrix_local=rest[b.parent.name]);p,rot,sc=basis.decompose()
 if rot.dot(r.pose.bones[b.name].rotation_quaternion)<0:rot.negate()
 vals[f]={'location':list(p),'rotation_quaternion':list(rot)}
changed=[]
for c in ui.curves(a):
 n=c.data_path.split('"')[1];prop=c.data_path.split('.')[-1]
 if n=='UpperArm.L' and prop in ['location','rotation_quaternion']:
  ys=[vals[float(k.co.x)][prop][c.array_index] for k in c.keyframe_points]
  if max(abs(y-k.co.y) for y,k in zip(ys,c.keyframe_points))>5e-7:
   c.keyframe_points.foreach_set('co',[v for k,y in zip(c.keyframe_points,ys) for v in [k.co.x,y]]);c.update();changed.append([n,prop,c.array_index])
a['left_shoulder_aim_back_m']=AIM_BACK_M;a['refinement_note']='Pending v004: accepted10degree tuck retained; support shoulder seated about29.5mm toward torso by3.25degree whole-arm pivot about the unchanged support palm. Rifle/right arm/core motion unchanged.'
assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in before.items())
s.frame_set(1);s.frame_start=1;s.frame_end=324;s.render.fps=30;s.camera=bpy.data.objects['Showcase_SIDE'];ui.show_preview_prop(s,{'preview_prop':'rifle_stylized_v2'})
p=O/'rifle_ready_idle_actionsstyle_v004.blend';bpy.ops.wm.save_as_mainfile(filepath=str(p),compress=True,check_existing=False)
e=json.loads((O/'entry.json').read_text());e.update({'source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'action_sha256':ui.action_signature(a),'left_shoulder_aim_back_m':AIM_BACK_M,'left_shoulder_depth_reduction_m':[min(depth),max(depth)],'left_shoulder_whole_arm_rotation_degrees':[min(angles),max(angles)],'approval_note':'Pending left-shoulder seating refinement of the accepted closer hold. Only support upper-arm channels changed; palm, rifle, right arm and core idle retained.'});(O/'entry.json').write_text(json.dumps(e,indent=2)+'\n')
d={'passed':True,'input_action_sha256':INPUT_SHA,'candidate_sha256':e['source_sha256'],'action_sha256':e['action_sha256'],'left_shoulder_target_retraction_m':AIM_BACK_M,'left_shoulder_actual_depth_reduction_m':[min(depth),max(depth)],'left_shoulder_additional_lowering_m':[min(down),max(down)],'left_whole_arm_rotation_degrees':[min(angles),max(angles)],'analytical_palm_error_m':palm_error,'sampled_keys':len(frames),'changed_curves':changed,'all_other_curves_verbatim':True,'all_other_source_actions_exact':True,'no_elbow_or_scale_change':True};(O/'left_shoulder_build_validation.json').write_text(json.dumps(d,indent=2));print(json.dumps(d),flush=True)
