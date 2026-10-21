extends Node
## Dev-only appearance layered onto the approved render pose. Supplemental render
## palettes never modify the player's Skeleton3D, contacts, camera or rifle sockets.
const DIR="res://scenes/dev/actions_stuff_research/soldier_loadout_v001/"
const Spring=preload("res://scripts/secondary_spring.gd")
const FaceState=preload("res://scenes/dev/actions_stuff_research/soldier_loadout_v001/facial_state.gd")
var scene:Node
var actor:CharacterBody3D
var visual:Node
var presenter:Node
var data:Dictionary
var hair:MeshInstance3D
var band:MeshInstance3D
var face:MeshInstance3D
var hair_ref:SkinReference
var band_ref:SkinReference
var head_bone:int
var head_bind:Transform3D
var hair_spring:=Spring.new()
var tail_spring:=Spring.new()
var tail_tip:=Spring.new()
var face_state:RefCounted
var channels:Dictionary
var initialized:=false
var last_velocity:=Vector3.ZERO
var last_head_velocity:=Vector3.ZERO
var last_head_position:=Vector3.ZERO
var last_basis:=Basis.IDENTITY
var acceleration:=Vector3.ZERO
var angular_velocity:=Vector3.ZERO
var tail_matrices:Array[Transform3D]=[]
var last_shots:=0
var last_hp:=100
var last_kills:=0
var _grounded:=true
var _last_takeoff:=false
var _last_landed:=false
func setup(owner_scene:Node):
 scene=owner_scene;actor=scene.player;visual=actor.visual;presenter=scene.presentation
 data=JSON.parse_string(FileAccess.get_file_as_string(DIR+"appearance.json"))
 head_bone=visual.skeleton.find_bone("Head")
 var skin:Skin=visual.meshes[0].skin
 for i in skin.get_bind_count():
  if skin.get_bind_name(i)==&"Head":head_bind=skin.get_bind_pose(i)
 var material:=StandardMaterial3D.new()
 material.albedo_texture=load(DIR+"head_atlas.png");material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
 material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;material.alpha_scissor_threshold=.5;material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.roughness=1.;material.specular_mode=BaseMaterial3D.SPECULAR_DISABLED
 var hair_result:=_head_mesh("Hair",data.hair,material);hair=hair_result[0];hair_ref=hair_result[1]
 var band_result:=_head_mesh("Bandana",data.band,material);band=band_result[0];band_ref=band_result[1]
 face=_mesh("Face",data.face,false)
 var face_material:=StandardMaterial3D.new();face_material.albedo_texture=load(DIR+"face_atlas.png");face_material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
 face_material.roughness=1.;face_material.specular_mode=BaseMaterial3D.SPECULAR_DISABLED;face_material.cull_mode=BaseMaterial3D.CULL_DISABLED
 face.material_override=face_material
 face_state=FaceState.new(data.facial_model);channels=face_state.channels
 tail_matrices.resize(data.band.parts.size());tail_matrices.fill(Transform3D.IDENTITY)
 last_hp=actor.current_hp
 actor.health_changed.connect(_health_changed);actor.defeated.connect(_defeated)
 RenderingServer.frame_pre_draw.connect(_upload)
func _exit_tree():
 if RenderingServer.frame_pre_draw.is_connected(_upload):RenderingServer.frame_pre_draw.disconnect(_upload)
func _vector(v:Array)->Vector3:return Vector3(v[0],v[1],v[2])
func _mesh(label:String,d:Dictionary,skinned:bool)->MeshInstance3D:
 var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
 var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var uv:=PackedVector2Array()
 var bones:=PackedInt32Array();var weights:=PackedFloat32Array()
 for i in d.vertices.size():
  vertices.append(_vector(d.vertices[i]));normals.append(_vector(d.normals[i]));uv.append(Vector2(d.uv[i][0],d.uv[i][1]))
  if skinned:bones.append_array(PackedInt32Array([int(d.part_ids[i]),0,0,0]));weights.append_array(PackedFloat32Array([1.,0.,0.,0.]))
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uv
 var indices:=PackedInt32Array(d.indices)
 for i in range(0,indices.size(),3):var swap:=indices[i+1];indices[i+1]=indices[i+2];indices[i+2]=swap
 arrays[Mesh.ARRAY_INDEX]=indices
 if skinned:arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights
 var result:=ArrayMesh.new();var shapes:Array[Array]=[]
 if d.has("shapes"):
  result.blend_shape_mode=Mesh.BLEND_SHAPE_MODE_NORMALIZED
  for key in d.shapes:
   result.add_blend_shape(key)
   var shape:Array=[];shape.resize(Mesh.ARRAY_MAX);var points:=PackedVector3Array()
   for v in d.shapes[key]:points.append(_vector(v))
   shape[Mesh.ARRAY_VERTEX]=points;shape[Mesh.ARRAY_NORMAL]=normals;shapes.append(shape)
 result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,shapes)
 var mesh:=MeshInstance3D.new();mesh.name="Soldier"+label;mesh.mesh=result;mesh.custom_aabb=AABB(Vector3(-.7,-.4,-.7),Vector3(1.4,2.7,1.4));add_child(mesh)
 return mesh
func _head_mesh(label:String,d:Dictionary,material:Material)->Array:
 var mesh:=_mesh(label,d,true);var rig:=Skeleton3D.new();rig.name=label+"RenderPalette";add_child(rig)
 var skin:=Skin.new();skin.set_bind_count(d.parts.size())
 for i in d.parts.size():rig.add_bone("Card"+str(i));skin.set_bind_bone(i,i);skin.set_bind_pose(i,Transform3D.IDENTITY)
 mesh.skin=skin;mesh.skeleton=mesh.get_path_to(rig);mesh.material_override=material
 return [mesh,rig.register_skin(skin)]
func reset():
 initialized=false;hair_spring.reset();tail_spring.reset();tail_tip.reset();acceleration=Vector3.ZERO;angular_velocity=Vector3.ZERO
 face_state.reset();channels=face_state.channels;last_shots=scene.rifle_fire.shots_fired;last_hp=actor.current_hp
 last_kills=scene.zombie_combat.kills if scene.zombie_combat!=null else 0
 _last_takeoff=false;_last_landed=false
func _health_changed(hp:int,maximum:int):
 if hp<last_hp:request_expression("Hurt_Heavy" if last_hp-hp>=maximum*.25 else "Hurt_Light")
 last_hp=hp
func _defeated():request_expression("Death_Stunned")
func request_expression(key:String):face_state.request(key)
func advance_face(delta:float,state:String,low_hp:float,dead:bool):
 channels=face_state.advance(delta,state,low_hp,dead)
 for side in ["L","R"]:
  var small:=side.to_lower();var opened:float=channels["open_"+small]
  var blink:=clampf(channels.blink+channels.blink_auto,0.,1.);var effective:=opened*(1.-blink)
  _shape("Close_"+side,1.-effective);_shape("GazeX_"+side,channels.gaze_x)
  _shape("GazeUp_"+side,maxf(0.,channels.gaze_y)*effective);_shape("GazeDown_"+side,maxf(0.,-channels.gaze_y)*effective)
  _shape("PupilSmall_"+side,(1.-channels.pupil_scale)*effective)
  _shape("BrowLift_"+side,channels["brow_"+small]);_shape("BrowTilt_"+side,channels["tilt_"+small]);_shape("Lid_"+side,pow(blink,3))
func _shape(key:String,value:float):face.set_blend_shape_value(face.find_blend_shape_by_name(key),value)
func advance_motion(delta:float,velocity:Vector3,head_position:Vector3,head_basis:Basis,phase:float,move_weight:float):
 if delta<=0.:return
 if not initialized or delta>.15 or head_position.distance_to(last_head_position)>1.5:
  last_velocity=velocity;last_head_position=head_position;last_head_velocity=velocity;last_basis=head_basis;initialized=true;return
 var head_velocity:Vector3=(head_position-last_head_position)/delta
 var raw:=((head_velocity-last_head_velocity)/delta).limit_length(45.)
 acceleration=acceleration.lerp(raw,1.-exp(-18.*delta))
 var rotation_delta:Quaternion=(last_basis.orthonormalized().inverse()*head_basis.orthonormalized()).get_rotation_quaternion()
 var rotation_speed:Vector3=rotation_delta.get_axis()*wrapf(rotation_delta.get_angle(),-PI,PI)/delta
 angular_velocity=angular_velocity.lerp(rotation_speed.limit_length(12.),1.-exp(-14.*delta))
 var local_accel:=head_basis.inverse()*acceleration
 var speed:=Vector2(velocity.x,velocity.z).length()
 var rhythm:=sin(phase*TAU)*move_weight;var bounce:=sin(phase*TAU*2.)*move_weight
 var hair_target:=Vector3(local_accel.z*.0018+rhythm*.020,-angular_velocity.y*.012,-local_accel.x*.0017+bounce*.009)
 var tail_target:=Vector3(-local_accel.z*.003-speed*.009-bounce*.045,-angular_velocity.y*.024,local_accel.x*.003+rhythm*.028)
 hair_spring.advance(delta,hair_target,4.2,.64,Vector3(.10,.075,.08))
 tail_spring.advance(delta,tail_target,3.1,.55,Vector3(.28,.18,.20))
 tail_tip.advance(delta,tail_spring.value*.52,3.8,.58,Vector3(.14,.10,.10))
 last_velocity=velocity;last_head_position=head_position;last_head_velocity=head_velocity;last_basis=head_basis
func _process(delta:float):
 if presenter.display_world.is_empty():return
 var head:Transform3D=presenter.display_world[head_bone]*head_bind
 advance_motion(delta,actor.velocity,head.origin+head.basis*Vector3(0,1.58,0),head.basis,visual.gait_phase,visual.rifle_move_weight)
 if scene.rifle_fire.shots_fired!=last_shots:request_expression("Fire_Recoil_Face");last_shots=scene.rifle_fire.shots_fired
 var q:Dictionary=actor.last_jump_query
 var takeoff:bool=q.get("takeoff",false);var landed:bool=q.get("landed",false)
 if takeoff and not _last_takeoff:request_expression("Jump_Focus")
 if landed and not _last_landed:request_expression("Land_Impact")
 _last_takeoff=takeoff;_last_landed=landed
 var state:="Rifle Ready Idle"
 if visual.move_requested:state="Run" if visual.gait_run_weight>.5 else "Walk"
 if visual.rifle_aim_weight>.15:state="Aim"
 if scene.zombie_combat!=null:
  var kills:int=scene.zombie_combat.kills
  if kills>last_kills and scene.zombie_combat.living_count()==0:request_expression("Victory_Small")
  last_kills=kills
 var low_hp:=clampf((.35-float(actor.current_hp)/maxi(1,actor.max_hp))/.35,0.,1.)
 advance_face(delta,state,low_hp,actor.is_dead)
 # Eyes follow intentional standing look gently; approved Head lean is untouched.
 if state=="Rifle Ready Idle" and absf(visual.turn_axis)>.01:
  channels.gaze_x=lerpf(channels.gaze_x,visual.turn_axis*.65,1.-exp(-12.*delta))
  _shape("GazeX_L",channels.gaze_x);_shape("GazeX_R",channels.gaze_x)
func _pivoted(p:Vector3,angles:Vector3)->Transform3D:
 var basis:=Basis.from_euler(angles);return Transform3D(basis,p-basis*p)
func _upload():
 if not is_instance_valid(presenter) or presenter.display_world.is_empty():return
 var frame:Transform3D=presenter.display_world[head_bone]*head_bind
 for mesh in [hair,band,face]:RenderingServer.instance_set_transform(mesh.get_instance(),frame)
 for i in data.hair.parts.size():
  var part:Dictionary=data.hair.parts[i];var angles:=Vector3.ZERO
  if not part.fixed:
   var factor:=.45 if "bang" in part.name else .75+float(i%4)*.08
   angles=hair_spring.value*factor
  RenderingServer.skeleton_bone_set_transform(hair_ref.get_skeleton(),i,_pivoted(_vector(part.pivot),angles))
 for i in data.band.parts.size():
  var part:Dictionary=data.band.parts[i];var transform:=Transform3D.IDENTITY
  if not part.fixed:
   var sign_side:=1. if "Tail.L" in part.name else -1.
   var angles:=tail_spring.value;angles.z+=sign_side*tail_spring.value.x*.12
   if "segment 2" in part.name:
    transform=tail_matrices[i-1]*_pivoted(_vector(part.pivot),tail_tip.value)
   else:transform=_pivoted(_vector(part.pivot),angles)
  tail_matrices[i]=transform
  RenderingServer.skeleton_bone_set_transform(band_ref.get_skeleton(),i,transform)
