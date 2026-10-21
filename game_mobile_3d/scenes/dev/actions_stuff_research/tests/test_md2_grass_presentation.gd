extends SceneTree
## Real field texture/uniform presentation at sub-physics render times.
var failures:Array[String]=[]
func _initialize():call_deferred("run")
func shown(material:ShaderMaterial,col:int,row:int)->Vector2:
 var current:Texture2D=material.get_shader_parameter("interaction_field")
 var value:Color=current.get_image().get_pixel(col,row)
 var earlier:Texture2D=material.get_shader_parameter("interaction_previous")
 if earlier!=null:
  var before:Color=earlier.get_image().get_pixel(col,row)
  var alpha:float=material.get_shader_parameter("interaction_alpha")
  value=before.lerp(value,alpha)
 return Vector2(value.r,value.g)
func run():
 var actor:=CharacterBody3D.new();root.add_child(actor)
 var field=load("res://scenes/dev/actions_stuff_research/grass_md2_v001/grass_field.gd").new()
 root.add_child(field);field.setup(actor);field.set_process(false);field.set_physics_process(false)
 var col:=32;var row:=32;var probe:=Vector2(.265625,.265625)
 var worst:=0.;var moving_subframes:=0;var held_subframes:=0
 for tick in 20:
  var before:Vector2=field.interaction.sample_at(probe)
  field._physics_process(1./60.)
  var after:Vector2=field.interaction.sample_at(probe)
  var last:=Vector2.ZERO
  for k in 5:
   var alpha:=float(k)/4.
   if field.has_method("present"):field.present(alpha)
   else:field._process(1./240.)
   var actual:=shown(field.materials[0],col,row)
   worst=maxf(worst,actual.distance_to(before.lerp(after,alpha)))
   if k>0 and before.distance_to(after)>.002:
    if actual.distance_to(last)<.00001:held_subframes+=1
    else:moving_subframes+=1
   last=actual
 if worst>.0007:failures.append("Contact presentation jumps between fixed ticks instead of following the actor's interpolated timeline")
 if held_subframes>0:failures.append("Moving contact must advance on every sub-tick render, without held/doubled frames")
 field.reset()
 if field.has_method("present"):field.present(.5)
 else:field._process(1./60.)
 if shown(field.materials[0],col,row).length()>.00001:failures.append("Reset must clear BOTH render histories")
 print("MD2_GRASS_PRESENTATION ",JSON.stringify({"worst_error_rad":worst,"moving_subframes":moving_subframes,"held_subframes":held_subframes,"failures":failures}))
 field.free();actor.free();quit(0 if failures.is_empty() else 1)
