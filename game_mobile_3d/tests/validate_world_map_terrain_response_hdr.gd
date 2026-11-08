extends SceneTree
func _initialize():call_deferred("run")
func reference(color:Vector3,contact:float)->Vector3:
 var v:float=clampf(contact,0.,.9990000128746033);var left:float=1.-v
 var single:float=(1.+left/(2.*pow(left,.25)))*v
 var multi:float=27.576936721801758*v*pow(left,1.5)*pow(2.,-4.813464164733887*pow(v,.25))
 var ratio:float=multi/maxf(1.-single,.00001)
 var a:Vector3=color.clamp(Vector3.ZERO,Vector3.ONE*.5)
 return Vector3.ONE*single+multi*a/(Vector3.ONE-(1.-ratio)*a).max(Vector3.ONE*.00001)
func run():
 if RenderingServer.get_rendering_device()==null:
  print("TERRAIN_RESPONSE_HDR skipped: native Mobile rendering device required");quit();return
 var vp=SubViewport.new();vp.size=Vector2i(16,16);vp.own_world_3d=true;vp.use_hdr_2d=true;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color.BLACK;env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_DISABLED;env.environment.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED;env.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;vp.add_child(env)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.;camera.position=Vector3(0,0,3);vp.add_child(camera)
 var node=MeshInstance3D.new();var quad=QuadMesh.new();quad.size=Vector2(2,2);node.mesh=quad;vp.add_child(node)
 var shader=Shader.new();shader.code="shader_type spatial;render_mode cull_disabled,ambient_light_disabled;
"+FileAccess.get_file_as_string("res://materials/world_map_terrain_transport.gdshaderinc")+"
uniform vec3 test_color=vec3(.3,.2,.1);uniform float test_contact=1.;uniform float test_metal=0.;void vertex(){terrain_sky_light=vec3(.1,.2,.3);terrain_sun_bounce=vec3(.2,.15,.1);}void fragment(){ALBEDO=vec3(0);EMISSION=terrain_indirect(test_color,test_metal,.8,.6,test_contact);}";
 var m=ShaderMaterial.new();m.shader=shader;node.material_override=m;m.set_shader_parameter("terrain_ambient_scale",.7);m.set_shader_parameter("terrain_key_radiance",Vector3(.3,.4,.5))
 var rows=[];var worst:=0.
 for enabled in [false,true]:
  m.set_shader_parameter("terrain_colored_visibility",enabled)
  for color in [Vector3(.3,.2,.1),Vector3(.8,.1,.02),Vector3.ZERO]:
   m.set_shader_parameter("test_color",color)
   for contact in [0.,.3,.7,1.]:
    m.set_shader_parameter("test_contact",contact)
    for i in 4:await process_frame
    await RenderingServer.frame_post_draw
    var pixel=vp.get_texture().get_image().get_pixel(8,8);var actual=Vector3(pixel.r,pixel.g,pixel.b)
    var expected=color*(Vector3(.1,.2,.3)*.7*.8+Vector3(.2,.15,.1)*Vector3(.3,.4,.5)*.6)
    if enabled:expected*=reference(color,contact)
    var err:Vector3=(actual-expected).abs();var error:float=maxf(err.x,maxf(err.y,err.z));worst=maxf(worst,error)
    rows.append({"enabled":enabled,"color":str(color),"contact":contact,"actual":str(actual),"expected":str(expected),"error":error})
 m.set_shader_parameter("test_metal",1.)
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 var pixel=vp.get_texture().get_image().get_pixel(8,8);var metal_error:float=maxf(pixel.r,maxf(pixel.g,pixel.b));worst=maxf(worst,metal_error)
 print("TERRAIN_RESPONSE_HDR cases=",rows.size()," max_error=",worst," metal_zero=",metal_error)
 vp.free();await process_frame;quit(0 if worst<.00025 else 1)
