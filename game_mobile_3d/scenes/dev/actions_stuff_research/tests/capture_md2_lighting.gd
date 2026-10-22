extends SceneTree
## Native captures use only the existing scene. No new PackedScene is created.
var viewport:SubViewport
var lab:Node3D
var out:String
func _initialize():call_deferred("run")
func draw_frames(count:int)->void:
 for i in count:
  await process_frame
  RenderingServer.force_draw(false)
func save(name:String)->void:
 await draw_frames(8)
 viewport.get_texture().get_image().save_png(out+"/"+name+".png")
func run():
 var args:=OS.get_cmdline_user_args();out=args[0]
 Engine.max_fps=60
 viewport=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 lab=load("res://scenes/dev/ActionsStuffWalkRunTest.tscn").instantiate();viewport.add_child(lab);current_scene=viewport
 lab.player.scripted_input=true
 for zombie in lab.zombie_combat.zombies:zombie.target=null;zombie.move_speed=0.
 lab._right_aim_held=true;lab._sync_rifle_controls()
 await draw_frames(45)
 var lighting=lab.md2_lighting
 paused=true
 lighting.ui.visible=false;lab.hud.get_parent().visible=false
 lighting.set_original(true);await save("00_original")
 lighting.set_original(false)
 var names:=["01_morning","02_noon","03_afternoon","04_dusk","05_night"]
 var hours:=[7.,12.,16.5,18.5,22.]
 for i in names.size():
  lighting.set_time(hours[i],true);await save(names[i])
 lighting.set_time(12.,true);lighting.ui.visible=true;lab.hud.get_parent().visible=true;lighting.ui._refresh();await save("06_controls")
 lighting.ui.visible=false;lab.hud.get_parent().visible=false;lab.grass_overview=true;lab._update_camera();await save("07_overview")
 paused=false;lab.free();viewport.free()
 for i in 4:await process_frame
 print("MD2_LIGHTING_NATIVE_STILLS ",out);quit()
