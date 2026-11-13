extends Node3D
## Transient private reference asset; original constrained pendulum presentation.
const FILE="godot_lab/world_map_unified_showcase_v001/lantern_idle_v001/profile_v002.private.json"
const SHA="68b5d9f8d321aa313b5340798a598f325fa5c532aab8e0ba1e6d3f13f79e7499"
## Upper center of the handle on the verified SM_SWT_MetalLantern.
const HANDLE_LOCAL := Vector3(.15625, .5625, -.15625)
var actor:Node3D
var profile:Dictionary={}
var spine:=-1
var mesh_root:Node3D
var lantern_center:Node3D
var follow_phase:=true
var lit:=false
var toggle_kind:="shrink"
var toggle_time:=INF
var visual_scale:=0.
var center:=Vector3.ZERO
var previous:=Vector3.ZERO
var previous_velocity:=Vector3.ZERO
var initialized:=false
var angle:=0.
var angular_velocity:=0.
var ready_private:=false
var _emission_materials: Array[StandardMaterial3D] = []
var _base_emission_energy := 0.
func setup(body:Node3D)->void:
 actor=body;top_level=true;process_priority=-5
 if not OS.has_feature("editor")or not actor.using_original_source:return
 var research:=OS.get_environment("MD2_RESEARCH_ROOT")
 if research.is_empty():research="C:/Users/ADMIN/Desktop/MD2 Research"
 var path:=research.path_join(FILE)
 if not FileAccess.file_exists(path)or FileAccess.get_sha256(path)!=SHA:return
 var data=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not data is Dictionary or data.get("schema")!="private-player-lantern-idle/2":return
 for row in data.files.values():
  if not row is Dictionary or not FileAccess.file_exists(row.path)or FileAccess.get_sha256(row.path)!=row.sha256:return
 for kind in ["grow","shrink"]:
  var keys=data.get(kind,[])
  if not keys is Array or keys.size()<2 or keys.size()>16:return
  var previous_time:=-1.
  for key in keys:
   if not key is Dictionary or key.get("InterpMode")!=2 or key.get("TangentWeightMode")!=0:return
   for channel in ["Time","Value","ArriveTangent","LeaveTangent"]:
    var n=key.get(channel)
    if not(n is float or n is int)or not is_finite(n):return
   if key.Time<=previous_time or key.Time>2.:return
   previous_time=key.Time
 profile=data;spine=actor.skeleton.find_bone("J_Spine")
 if spine<0:return
 mesh_root=actor.load_private_model(profile.files.mesh.path)
 if mesh_root==null:return
 lantern_center=Node3D.new();lantern_center.name="LanternCenter";add_child(lantern_center)
 lantern_center.add_child(mesh_root)
 mesh_root.scale=Vector3.ONE*profile.mesh_scale
 # Place the origin of both the swing and grow/shrink at the handle. The
 # native simulated body offset is not a hook location on the visual mesh.
 mesh_root.position = -(mesh_root.basis * HANDLE_LOCAL)
 var packed_image:=Image.load_from_file(profile.files.packed.path)
 var packed:=ImageTexture.create_from_image(packed_image)
 var emission_image:=Image.create(packed_image.get_width(),packed_image.get_height(),false,Image.FORMAT_RGB8)
 for y in emission_image.get_height():
  for x in emission_image.get_width():
   var value:=packed_image.get_pixel(x,y).b
   # Emission textures are sampled as source-color; encode the data mask once.
   emission_image.set_pixel(x,y,Color(value,value,value).linear_to_srgb())
 var mask:=ImageTexture.create_from_image(emission_image)
 _base_emission_energy = .8 * float(profile.emissive_brightness) / float(profile.generic_emissive_brightness)
 for mesh:MeshInstance3D in mesh_root.find_children("*","MeshInstance3D",true,false):
  mesh.layers=2 # Receive sun/ambient, exclude the fixture-centered point light.
  for i in mesh.mesh.get_surface_count():
   var source=mesh.get_active_material(i)
   if source is StandardMaterial3D:
    var material:StandardMaterial3D=source.duplicate();material.emission_enabled=true
    material.emission=Color(profile.emissive_linear[0],profile.emissive_linear[1],profile.emissive_linear[2]).linear_to_srgb();material.emission_texture=mask
    material.metallic=1.;material.metallic_texture=packed;material.metallic_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
    material.roughness=1.;material.roughness_texture=packed;material.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_GREEN
    material.emission_operator=BaseMaterial3D.EMISSION_OP_MULTIPLY
    material.emission_energy_multiplier=_base_emission_energy
    _emission_materials.append(material)
    mesh.set_surface_override_material(i,material)
   center=mesh_root.position+mesh_root.basis*(mesh.transform*mesh.get_aabb().get_center())
 _load_inspect();ready_private=true;_apply_toggle(0.)

func set_emission_gain(gain: float) -> void:
 for material in _emission_materials:
  material.emission_energy_multiplier = _base_emission_energy * gain
func _load_inspect()->void:
 var scene=actor.load_private_model(profile.files.inspect.path)
 if scene==null:return
 var rig:Skeleton3D;var player:AnimationPlayer
 for node in scene.find_children("*","",true,false):
  if node is Skeleton3D:rig=node
  elif node is AnimationPlayer:player=node
 var valid:bool=rig!=null and player!=null and rig.get_bone_count()==actor.skeleton.get_bone_count()
 if valid:
  for i in rig.get_bone_count():
   if rig.get_bone_name(i)!=actor.skeleton.get_bone_name(i)or rig.get_bone_parent(i)!=actor.skeleton.get_bone_parent(i)or not rig.get_bone_rest(i).is_equal_approx(actor.skeleton.get_bone_rest(i)):valid=false
 var clip:Animation
 if valid:
  for name in player.get_animation_list():
   if name!="RESET":clip=player.get_animation(name).duplicate(true)
  valid=clip!=null and absf(clip.length-2.66666675)<.001
 if valid:
  var target:NodePath=actor.animation_player.get_node(actor.animation_player.root_node).get_path_to(actor.skeleton)
  for track in clip.get_track_count():
   var old:=clip.track_get_path(track)
   if old.get_subname_count()!=1 or actor.skeleton.find_bone(old.get_subname(0))<0:valid=false;break
   clip.track_set_path(track,NodePath(str(target)+":"+str(old.get_subname(0))))
 if valid:
  clip.loop_mode=Animation.LOOP_NONE
  var library:=AnimationLibrary.new();library.add_animation("InspectWeapon",clip)
  actor.animation_player.add_animation_library("private_idle",library)
  actor.clips.InspectWeapon={"action":"private_idle/InspectWeapon","duration":clip.length,"loop":false,"category":"novelty","source_name":"Player_Idle_Novelty_ExamineWeapon","vfx_window":[0.,0.]}
 scene.free()
static func curve_value(keys:Array,time:float)->float:
 if time<=float(keys[0].Time):return float(keys[0].Value)
 for i in keys.size()-1:
  var a:Dictionary=keys[i];var b:Dictionary=keys[i+1]
  if time>float(b.Time):continue
  var dt:=float(b.Time)-float(a.Time);var t:float=(time-float(a.Time))/dt
  return (2.*t*t*t-3.*t*t+1.)*float(a.Value)+(t*t*t-2.*t*t+t)*dt*float(a.LeaveTangent)+(-2.*t*t*t+3.*t*t)*float(b.Value)+(t*t*t-t*t)*dt*float(b.ArriveTangent)
 return float(keys[-1].Value)
func set_lit(value:bool)->void:
 if value==lit:return
 lit=value;toggle_kind="grow" if value else "shrink";toggle_time=0.
func _apply_toggle(delta:float)->void:
 if not is_inf(toggle_time):toggle_time+=delta
 visual_scale=curve_value(profile[toggle_kind],toggle_time)
 lantern_center.visible=visual_scale>.000001
 lantern_center.scale=Vector3.ONE*visual_scale
func emitter_position()->Vector3:return global_transform*(lantern_center.transform*center)
func _process(delta:float)->void:
 if not ready_private or delta<=0.:return
 if follow_phase:
  var world=actor.get_parent().get_parent()
  var showcase=world.get("showcase")
  if showcase!=null and showcase._player_light!=null:set_lit(showcase._player_light.visible)
 _apply_toggle(delta)
 var bone:Transform3D=actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(spine)
 if actor.render_presenter!=null and actor.render_presenter.display_world.size()>spine:bone=actor.render_presenter.display_world[spine]
 var offset:Array=profile.spine_offset;var pivot:=bone*Vector3(offset[0],offset[1],offset[2])
 var basis:Basis=actor.visual.global_basis.orthonormalized()
 if not initialized or pivot.distance_to(previous)>2.:
  previous=pivot;previous_velocity=Vector3.ZERO;angle=0.;angular_velocity=0.;initialized=true
 var velocity:Vector3=(pivot-previous)/delta
 var force:Vector3=basis.inverse()*((velocity-previous_velocity)/delta).limit_length(30.)
 var left:=minf(delta,.1)
 while left>0.:
  var dt:=minf(left,1./120.)
  # Original pendulum solver; Chaos stiffness/damping units are not copied.
  angular_velocity+=(-9.8/.3*sin(angle)-9.*angular_velocity-force.z/.3)*dt
  angle+=angular_velocity*dt
  var limit:=deg_to_rad(float(profile.swing_limit_degrees))
  if absf(angle)>limit:angle=clampf(angle,-limit,limit);angular_velocity=0.
  left-=dt
 global_transform=Transform3D(basis*Basis(Vector3.RIGHT,angle),pivot)
 previous=pivot;previous_velocity=velocity
 var world=actor.get_parent().get_parent()
 var showcase=world.get("showcase")
 if showcase!=null:showcase.sync_lantern_emitter(emitter_position())
