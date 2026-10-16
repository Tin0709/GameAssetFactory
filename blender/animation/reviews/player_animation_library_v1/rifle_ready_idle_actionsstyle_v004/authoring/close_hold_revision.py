"""User screenshot correction: rotate the intact holding assembly toward the body.
Existing approved v003 and all other Actions remain byte/curve exact.
Input is the preserved prior Pending v004 authoring file, not v003.
"""
import bpy,sys,json,math,hashlib
from pathlib import Path
from mathutils import Matrix
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').is_file());O=Path(__file__).resolve().parent.parent
ANGLE=10.0
sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
N='Rifle_Ready_Idle_ActionsStyle_v004';r=bpy.data.objects[ui.RIG];s=bpy.context.scene;a=bpy.data.actions[N]
assert ui.action_signature(a)=='c8349c746f1c0befe0b90eeb22f018ebae15a26ada0f3c227ccc581815403d96'
manifest=json.loads((R/'blender/animation/showcase/animation_manifest.json').read_text());assert next(e for e in manifest['animations'] if e['action']==N)['status']=='pending'
before={x.name:ui.action_signature(x) for x in bpy.data.actions if x.name!=N}
r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s['gaf_library_last_action']=N
rest={b.name:b.matrix_local.copy() for b in r.data.bones};frames=sorted({float(k.co.x) for c in ui.curves(a) for k in c.keyframe_points});values={};palm_forward=[];palm_lower=[];max_shoulder=0.
for f in frames:
 s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update();old={b.name:b.matrix.copy() for b in r.pose.bones};M={n:m.copy() for n,m in old.items()}
 left=old['UpperArm.L'].translation;right=old['UpperArm.R'].translation;axis=(left-right).normalized();pivot=(left+right)*.5
 D=Matrix.Translation(pivot)@Matrix.Rotation(math.radians(ANGLE),4,axis)@Matrix.Translation(-pivot)
 for n in ['UpperArm.L','ForeArm.L','UpperArm.R','ForeArm.R','WeaponCarrier']:M[n]=D@old[n]
 for side in ['L','R']:
  n='UpperArm.'+side;max_shoulder=max(max_shoulder,(M[n].translation-old[n].translation).length)
  p=r.data.bones['ForeArm.'+side].tail_local;oldp=old['ForeArm.'+side]@rest['ForeArm.'+side].inverted()@p;newp=M['ForeArm.'+side]@rest['ForeArm.'+side].inverted()@p
  forward=old['Chest'].to_3x3().col[2].normalized();palm_forward.append((oldp-newp).dot(forward));palm_lower.append(oldp.z-newp.z)
 row={}
 for n in ['UpperArm.L','UpperArm.R','WeaponCarrier']:
  b=r.data.bones[n];args={} if not b.parent else {'parent_matrix':M[b.parent.name],'parent_matrix_local':rest[b.parent.name]}
  basis=b.convert_local_to_pose(M[n],rest[n],invert=True,**args);pos,q,scale=basis.decompose()
  if q.dot(r.pose.bones[n].rotation_quaternion)<0:q.negate()
  row[n]={'location':list(pos),'rotation_quaternion':list(q)}
 values[f]=row
changed=[]
for c in ui.curves(a):
 n=c.data_path.split('"')[1];p=c.data_path.split('.')[-1]
 if n in ['UpperArm.L','UpperArm.R','WeaponCarrier'] and p in ['location','rotation_quaternion']:
  ys=[values[float(k.co.x)][n][p][c.array_index] for k in c.keyframe_points]
  if max(abs(y-k.co.y) for y,k in zip(ys,c.keyframe_points))>5e-7:
   c.keyframe_points.foreach_set('co',[v for k,y in zip(c.keyframe_points,ys) for v in [k.co.x,y]]);c.update();changed.append([n,p,c.array_index])
a['closer_hold_degrees']=ANGLE;a['refinement_note']='Screenshot clarification: intact arms/rifle rotated10degrees toward torso about the two shoulder pivots. Earlier subtle support breathing retained.'
assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in before.items())
s.frame_set(1);s.frame_start=1;s.frame_end=324;s.render.fps=30;s.camera=bpy.data.objects['Showcase_SIDE'];ui.show_preview_prop(s,{'preview_prop':'rifle_stylized_v2'})
p=O/'rifle_ready_idle_actionsstyle_v004.blend';bpy.ops.wm.save_as_mainfile(filepath=str(p),compress=True,check_existing=False)
e=json.loads((O/'entry.json').read_text());e.update({'source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'action_sha256':ui.action_signature(a),'closer_hold_degrees':ANGLE,'approval_note':'Pending screenshot correction:10degree shoulder-pivot tuck of the intact holding assembly; existing support breathing and source timing preserved.'});(O/'entry.json').write_text(json.dumps(e,indent=2)+'\n')
d={'passed':True,'degrees_toward_body':ANGLE,'frames':len(frames),'shoulder_pivot_position_error_m':max_shoulder,'palm_forward_reach_reduction_m':[min(palm_forward),max(palm_forward)],'palm_additional_drop_m':[min(palm_lower),max(palm_lower)],'changed_curves':changed,'source_timing_unchanged':True,'support_relative_motion_preserved_by_rigid_transform':True,'all_other_actions_exact':True,'action_sha256':e['action_sha256'],'candidate_sha256':e['source_sha256']};(O/'closer_hold_build_validation.json').write_text(json.dumps(d,indent=2));print(json.dumps(d),flush=True)
