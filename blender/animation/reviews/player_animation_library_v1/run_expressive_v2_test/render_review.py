"""All native review frames on unchanged cameras/light; temporary travel never saved."""
import bpy,json,sys,hashlib,runpy
from pathlib import Path
from mathutils import Vector
O=Path(__file__).resolve().parent;R=O.parents[4];sys.path.insert(0,str(R/'blender/animation/showcase'));import gaf_animation_library as ui
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();s=bpy.context.scene;r=bpy.data.objects['RN2_Test_Rig'];a=r.animation_data.action;v=json.loads((O/'validation.json').read_text());source=Path(bpy.data.filepath)
assert v['passed'] and v['source_sha256']==sha(source) and v['action_sha256']==ui.action_signature(a)
proof={'source_sha256':v['source_sha256'],'action_sha256':v['action_sha256'],'fps':30,'frames':{},'old_run_action_sha256':ui.action_signature(bpy.data.actions['Run_Expressive_Test']),'walk_source_sha256':json.loads((R/'.validation/run_expressive_v2_test/baseline.json').read_text())['approved_walk_source_sha256'],'camera_lighting':'Unchanged approved Walk review stage','travel_speed_m_s':2.1,'travel_is_temporary_only':True}
s.render.use_persistent_data=True
def render(view,folder,frames,travel=False):
 s.camera=bpy.data.objects['Showcase_'+view];cam=s.camera.location.copy();dest=O/folder/view.lower();dest.mkdir(parents=True,exist_ok=True)
 for f in frames:
  s.frame_set(f);r.location=(0,-2.1*(f-1)/30 if travel else 0,0);s.camera.location=cam+Vector((0,r.location.y,0));bpy.context.view_layer.update();p=dest/f'{f:04d}.png';s.render.filepath=str(p);bpy.ops.render.render(write_still=True);proof['frames'][p.relative_to(O).as_posix()]=sha(p)
 r.location=(0,0,0);s.camera.location=cam
for view in ['FRONT','THREE_QUARTER','SIDE']:render(view,'frames',range(1,23))
idle=json.loads((O.parent/'jump_default_v001/idle_baseline.json').read_text());r.animation_data.action=None
for bone in r.pose.bones:
 for k,val in idle[bone.name].items():setattr(bone,k,val)
r.animation_data.action=bpy.data.actions['Run_Expressive_Test'];r.animation_data.action_slot=r.animation_data.action.slots[0]
render('THREE_QUARTER','old_run_frames',range(1,19))
r.animation_data.action=a;r.animation_data.action_slot=a.slots[0]
mat=bpy.data.materials.new('TEMP_REVIEW_Grid');mat.diffuse_color=(.16,.19,.20,1);mat.use_nodes=True;mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.16,.19,.20,1)
for j in range(-24,11):
 bpy.ops.mesh.primitive_cube_add(size=1,location=(0,j*.25,.00015));o=bpy.context.object;o.name='TEMP_REVIEW_ground_marker';o.scale=(2.2,.003,.00015);o.data.materials.append(mat)
render('SIDE','travel_frames',range(1,67),True)
assert len(proof['frames'])==150 and sha(source)==v['source_sha256']
(O/'render_provenance.json').write_text(json.dumps(proof,indent=2));print('ALL150 SOURCE-BOUND REVIEW FRAMES COMPLETE')
