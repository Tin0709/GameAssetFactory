extends SceneTree
var failures:Array[String]=[]
func check(ok:bool,label:String):
 if not ok:failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func run():
 var scene=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();root.add_child(scene)
 var appearance=scene.get_node_or_null("SoldierAppearance")
 check(appearance!=null,"Latest Soldier appearance, secondary motion and facial system installed in existing scene")
 if appearance==null:scene.free();quit(1);return
 var fps:=60 if OS.get_cmdline_user_args().has("60") else 30
 scene.set_process(false);scene.player.set_physics_process(false);scene.player.visual.set_process(false)
 scene.rifle_fire.set_physics_process(false);scene.rifle_auto_aim.set_physics_process(false);appearance.set_process(false)
 check(appearance.hair.mesh.get_surface_count()==1 and appearance.band.mesh.get_surface_count()==1,"One cutout surface each for hair and bandana")
 check(appearance.face.get_blend_shape_count()==16,"Existing authored16facial shape keys exported")
 check(scene.player.visual.skeleton.get_bone_count()==19,"Approved animated skeleton unchanged")
 var max_hair:=0.;var max_tail:=0.;var blink_count:=0;var was_blink:=false
 for i in 12*fps:
  var t:=float(i)/fps;var moving:=t>1. and t<7.
  var velocity:=Vector3(sin(t*1.5),0,cos(t*1.5))*7.55 if moving else Vector3.ZERO
  appearance.advance_motion(1./fps,velocity,Vector3(0,1.55+(.018*sin(t*TAU*3.) if moving else 0.),0),Basis(Vector3.UP,t*.5 if moving else 3.5),t*1.6,1. if moving else 0.)
  max_hair=maxf(max_hair,appearance.hair_spring.value.length());max_tail=maxf(max_tail,appearance.tail_spring.value.length())
  appearance.advance_face(1./fps,"Aim" if t>3. and t<7. else ("Run" if moving else "Rifle Ready Idle"),0.,false)
  if t>3. and t<6. and i%maxi(1,fps/6)==0:appearance.request_expression("Fire_Recoil_Face")
  var blink:bool=appearance.channels.blink_auto>.5
  if blink and not was_blink:blink_count+=1
  was_blink=blink
  check(appearance.hair_spring.value.is_finite() and appearance.tail_spring.value.is_finite(),"Bounded finite secondary simulation")
 check(max_hair>.01 and max_tail>.02,"Walk/run/turn inputs visibly excite both secondary springs")
 check(max_hair<.30 and max_tail<.65,"Controlled hair/tail angular limits")
 check(appearance.hair_spring.value.length()<.001 and appearance.tail_spring.value.length()<.001,"Stop settles to rest with no accumulated drift")
 check(blink_count>=2,"Persistent irregular blink clock survives state switches")
 appearance.advance_face(1./fps,"Aim",0.,false)
 for i in fps:appearance.advance_face(1./fps,"Aim",0.,false)
 check(absf(appearance.channels.open_l-.73)<.001,"Repeated fire recovers to authored focused Aim")
 appearance.request_expression("Hurt_Heavy");appearance.request_expression("Fire_Recoil_Face")
 for i in maxi(1,roundi(.1*fps)):appearance.advance_face(1./fps,"Aim",0.,false)
 check(absf(appearance.channels.open_l-.12)<.01,"Higher priority authored Hurt owns face above Fire")
 scene.reset_player()
 check(appearance.tail_spring.value.length()==0. and appearance.hair_spring.value.length()==0.,"Reset clears physics history")
 print("SOLDIER_SECONDARY ",JSON.stringify({"fps":fps,"passed":failures.is_empty(),"failures":failures,"max_hair_rad":max_hair,"max_tail_rad":max_tail,"blinks":blink_count}))
 scene.free();quit(0 if failures.is_empty() else 1)
