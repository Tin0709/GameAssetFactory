extends SceneTree
var failures=[]
func _initialize():call_deferred("run")
func run():
 if RenderingServer.get_rendering_device()==null:quit(2);return
 var vp:=SubViewport.new();vp.size=Vector2i(96,64);vp.own_world_3d=true;vp.use_hdr_2d=true;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
 var world:=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color.BLACK;world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_DISABLED;world.environment.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED;world.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;world.environment.fog_enabled=true;world.environment.fog_density=0.;vp.add_child(world)
 var camera:=Camera3D.new();camera.position=Vector3(0,12,12);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=12.;camera.far=100.;vp.add_child(camera);camera.look_at(Vector3(0,2,0))
 var primitive:=PlaneMesh.new();primitive.size=Vector2(200,200)
 var arrays:=primitive.surface_get_arrays(0);var sky:=PackedFloat32Array();var sun:=PackedFloat32Array()
 for i in arrays[Mesh.ARRAY_VERTEX].size():sky.append_array(PackedFloat32Array([.05,.1,.2]));sun.append_array(PackedFloat32Array([0,0,0]))
 arrays[Mesh.ARRAY_CUSTOM1]=sky;arrays[Mesh.ARRAY_CUSTOM2]=sun
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FORMAT_CUSTOM1|Mesh.ARRAY_FORMAT_CUSTOM2|(Mesh.ARRAY_CUSTOM_RGB_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)|(Mesh.ARRAY_CUSTOM_RGB_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT))
 var surface:=MeshInstance3D.new();surface.mesh=mesh;surface.position.y=2.;vp.add_child(surface)
 var background:=MeshInstance3D.new();background.mesh=mesh;background.position.y=1.99;background.hide();vp.add_child(background)
 var materials=[]
 for path in ["res://materials/world_map_ground_v5.gdshader","res://materials/world_map_cutaway_v5.gdshader"]:
  var source:Shader=load(path);var shader:=Shader.new();shader.code=source.code.replace("shader_type spatial;","shader_type spatial;\n#define GAF_WORLD_SPATIAL_TERRAIN\n#define GAF_WORLD_DIRECT_CLOUD\nrender_mode ambient_light_disabled;")
  var m:=ShaderMaterial.new();m.shader=shader;m.set_shader_parameter("clouds_enabled",false);m.set_shader_parameter("cutaway_enabled",false);materials.append(m)
 background.material_override=materials[0]
 var mist=load("res://scripts/world_map_atmosphere_volume.gd").new();camera.add_child(mist);mist.setup();mist.material_provider=func():return materials
 mist.show();mist.noise_strength=0.
 var parameters={"volume_density":.08,"height_falloff":.12,"fog_begin":3.,"fog_color":Vector3(.5,.6,.7),"player_light_color":Vector3.ONE,"player_light_weight":0.,"scatter_energy":1.}
 var observations=[];var worst:=0.;var parity:=0.
 for size in [Vector2i(96,64),Vector2i(128,80)]:
  vp.size=size
  for perspective in [false,true]:
   camera.projection=Camera3D.PROJECTION_PERSPECTIVE if perspective else Camera3D.PROJECTION_ORTHOGONAL
   var reference:Image
   for mode in [0,1,2]:
    surface.material_override=materials[mini(mode,1)];materials[1].set_shader_parameter("albedo_tint",Color(1,1,1,.5 if mode==2 else 1.));background.visible=mode==2
    mist.publish(parameters,Vector3.ZERO,0.,0.,not perspective,8.)
    for i in 12:await process_frame
    await RenderingServer.frame_post_draw
    if not mist.effect.snapshot().ready or not mist.failure().is_empty():failures.append("Field not ready: "+str(mist.effect.snapshot()));continue
    var image:=vp.get_texture().get_image()
    if mode==0:reference=image
    for point in [Vector2(.25,.35),Vector2(.5,.5),Vector2(.75,.7)]:
     var pixel:=Vector2i(point*Vector2(size));var screen:=Vector2(pixel)+Vector2(.5,.5)
     var direction:=camera.project_ray_normal(screen);var origin:=camera.global_position if perspective else camera.project_ray_origin(screen)-direction*camera.near
     var end:Vector3=Plane(Vector3.UP,2.).intersects_ray(origin,direction)
     var tau:float=mist.integral(origin,end,.08,.12,0.,3.,4096)
     var trans:=exp(-tau);var light:=Color(.5,.6,.7).srgb_to_linear()
     var expected:=Vector3(.05,.1,.2)*trans+Vector3(light.r,light.g,light.b)*(1.-trans)
     var c:=image.get_pixelv(pixel);var error:float=0.
     var delta:Vector3=(Vector3(c.r,c.g,c.b)-expected).abs();error=maxf(delta.x,maxf(delta.y,delta.z));worst=maxf(worst,error)
     var r:=reference.get_pixelv(pixel);var difference:=Vector3(c.r-r.r,c.g-r.g,c.b-r.b).abs();var e:=maxf(difference.x,maxf(difference.y,difference.z));parity=maxf(parity,e)
     observations.append({"size":str(size),"perspective":perspective,"mode":mode,"pixel":str(pixel),"expected":str(expected),"actual":str(c),"error":error,"opaque_parity":e})
     if error>.004 or e>.002:failures.append(observations[-1])
 # Regression: inactive shared medium must restore the real native fog path.
 mist.hide();world.environment.fog_density=.12;world.environment.fog_depth_begin=0.;world.environment.fog_depth_end=40.;world.environment.fog_light_color=Color(.7,.4,.2)
 surface.material_override=materials[0];background.hide()
 for i in 12:await process_frame
 await RenderingServer.frame_post_draw
 var restored:=vp.get_texture().get_image();var original:Shader=materials[0].shader
 if original.has_meta("gaf_mist_base"):failures.append("Inactive material still wraps native fog")
 var source:=original.code
 var pattern:=RegEx.new();pattern.compile("(?s)#ifdef GAF_SHARED_MIST.*?#endif")
 var unmodified:=Shader.new();unmodified.code=pattern.sub(source,"",true);materials[0].shader=unmodified
 for i in 12:await process_frame
 await RenderingServer.frame_post_draw
 var baseline:=vp.get_texture().get_image();var restore_error:=0.
 for y in vp.size.y:
  for x in vp.size.x:
   var a:=restored.get_pixel(x,y);var b:=baseline.get_pixel(x,y)
   restore_error=maxf(restore_error,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
 if restore_error>0.:failures.append("Native fog restore differs: "+str(restore_error))
 world.environment.fog_enabled=false
 for i in 12:await process_frame
 await RenderingServer.frame_post_draw
 var clear:=vp.get_texture().get_image();var center:=Vector2i(vp.size/2)
 if baseline.get_pixelv(center).is_equal_approx(clear.get_pixelv(center)):failures.append("Native fog regression fixture has no fog signal")
 print("MIST_NATIVE_RESTORE max_error=",restore_error)
 print("MIST_SHARED_GPU max_error=",worst," parity=",parity," failures=",JSON.stringify(failures))
 var out:=OS.get_environment("GAF_MIST_RECEIPT")
 if not out.is_empty():FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify({"max_error":worst,"parity":parity,"samples":observations,"failures":failures},"\t"))
 vp.free();await process_frame;quit(0 if failures.is_empty() else 1)
