"""Render saved-source poses. Travel mode is temporary Blender presentation only."""
import bpy,json,sys,hashlib
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[4]
sys.path.insert(0,str(ROOT/'blender/animation/showcase'));import gaf_animation_library as ui
s=bpy.context.scene;r=bpy.data.objects['WEX_Test_Rig'];a=r.animation_data.action
source_hash=hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest();action_hash=ui.action_signature(a)
stills='stills' in sys.argv;travel='travel' in sys.argv
if not stills:
 v=json.loads((OUT/'validation.json').read_text());assert v['passed'] and v['source_sha256']==source_hash and v['action_sha256']==action_hash
s.render.use_persistent_data=True
frames=[1,5,10,16,19,23,28,34] if stills else range(1,109 if travel else 37)
views=['SIDE'] if travel else ['FRONT','THREE_QUARTER','SIDE'];folder=OUT/('pose_frames' if stills else 'travel_frames' if travel else 'frames');folder.mkdir(exist_ok=True)
camera_positions={o.name:o.location.copy() for o in s.objects if o.type=='CAMERA'}
if travel:
 mat=bpy.data.materials.new('TEMP_REVIEW_Grid');mat.diffuse_color=(.16,.19,.20,1);mat.use_nodes=True;mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.16,.19,.20,1)
 for j in range(-20,11):
  bpy.ops.mesh.primitive_cube_add(size=1,location=(0,j*.25,.00015));o=bpy.context.object;o.name='TEMP_REVIEW_ground_marker';o.scale=(2.2,.003,.00015);o.data.materials.append(mat)
provenance={'source_sha256':source_hash,'action_sha256':action_hash,'fps':30,'frames':{},'travel_only_presentation':travel,'travel_speed_m_s':.9 if travel else 0,'period_frames':36,'repeat_count':3 if travel else 1,'camera_lighting':'Original approved review stage; travel adds temporary floor markers and follows actor with camera.' if travel else 'Original approved review stage unchanged.'}
for view in views:
 s.camera=bpy.data.objects['Showcase_'+view];dest=folder/view.lower();dest.mkdir(exist_ok=True)
 for f in frames:
  s.frame_set(f);r.location=(0,-.9*(f-1)/30 if travel else 0,0)
  if travel:s.camera.location=camera_positions[s.camera.name]+Vector((0,r.location.y,0))
  bpy.context.view_layer.update();p=dest/f'{f:04d}.png';s.render.filepath=str(p);bpy.ops.render.render(write_still=True)
  provenance['frames'][p.relative_to(OUT).as_posix()]=hashlib.sha256(p.read_bytes()).hexdigest()
assert hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest()==source_hash
(OUT/('pose_provenance.json' if stills else 'travel_provenance.json' if travel else 'render_provenance.json')).write_text(json.dumps(provenance,indent=2));print('SOURCE-BOUND RENDER COMPLETE',len(provenance['frames']),flush=True)
