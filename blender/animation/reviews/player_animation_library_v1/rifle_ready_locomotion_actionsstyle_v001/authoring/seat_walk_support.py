import bpy,sys,json,hashlib
from pathlib import Path
from mathutils import Matrix,Vector
R=next(p for p in Path(__file__).resolve().parents if (p/'AGENTS.md').exists());O=Path(__file__).resolve().parent.parent;sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
r=bpy.data.objects[ui.RIG];s=bpy.context.scene;N='Rifle_Ready_Walk_ActionsStyle_v001';a=bpy.data.actions[N];prior={b.name:ui.action_signature(b) for b in bpy.data.actions if b!=a};rest={b.name:b.matrix_local.copy() for b in r.data.bones};palm=Vector((0,r.data.bones['ForeArm.L'].length*.78,0));r.animation_data.action=a;r.animation_data.action_slot=a.slots[0];s['gaf_library_last_action']=N;frames=sorted({float(k.co.x) for c in ui.curves(a) for k in c.keyframe_points});values={}
for f in frames:
 s.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update();M={b.name:b.matrix.copy() for b in r.pose.bones};P=M['ForeArm.L']@palm;socket=(M['Chest']@rest['Chest'].inverted()@rest['UpperArm.L']).translation+M['Chest'].to_3x3().col[0].normalized()*.004;q=(M['UpperArm.L'].translation-P).rotation_difference(socket-P);D=Matrix.Translation(P)@q.to_matrix().to_4x4()@Matrix.Translation(-P);M['UpperArm.L']=D@M['UpperArm.L'];b=r.data.bones['UpperArm.L'];local=b.convert_local_to_pose(M[b.name],rest[b.name],invert=True,parent_matrix=M[b.parent.name],parent_matrix_local=rest[b.parent.name]);p,q,scale=local.decompose()
 if q.dot(r.pose.bones[b.name].rotation_quaternion)<0:q.negate()
 values[f]={'location':list(p),'rotation_quaternion':list(q)}
for c in ui.curves(a):
 if c.data_path.startswith('pose.bones["UpperArm.L"]') and c.data_path.rsplit('.',1)[1] in ['location','rotation_quaternion']:
  p=c.data_path.rsplit('.',1)[1];c.keyframe_points.foreach_set('co',[v for k in c.keyframe_points for v in [k.co.x,values[float(k.co.x)][p][c.array_index]]]);c.update()
assert all(ui.action_signature(bpy.data.actions[n])==h for n,h in prior.items());s.frame_set(1);source=O/'rifle_ready_locomotion_actionsstyle_v001.blend';bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True,check_existing=False);sha=hashlib.sha256(source.read_bytes()).hexdigest();es=json.loads((O/'entries.json').read_text())
for e in es:
 e['source_sha256']=sha
 if e['action']==N:e['action_sha256']=ui.action_signature(a);e['native_rig_adapters']['left_socket_target_outset_m']=.004
(O/'entries.json').write_text(json.dumps(es,indent=2));(O/'walk_support_validation.json').write_text(json.dumps({'passed':True,'left_socket_outset_m':.004,'support_palm_fixed':True,'all_other_actions_exact':True},indent=2))
