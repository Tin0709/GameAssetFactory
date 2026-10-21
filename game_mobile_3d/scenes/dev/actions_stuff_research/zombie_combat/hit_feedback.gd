extends "res://scripts/character_damage_feedback.gd"
## Same health bar/number assets, four prewarmed labels per dev zombie.
## Four slots cover the existing .65s display at 6Hz; bursts reuse oldest.
const SLOTS := 4
var numbers: Array[Label3D] = []
var ages := PackedFloat32Array()

func _ready() -> void:
	if bar_mesh == null:
		bar_mesh=QuadMesh.new();bar_mesh.size=Vector2(.66,.095)
		bar_material=ShaderMaterial.new();bar_material.shader=BAR_SHADER
	bar=MeshInstance3D.new();bar.name="OverheadHealth"
	bar.mesh=bar_mesh;bar.material_override=bar_material
	bar.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bar);bar.position.y=2.04;bar.hide()
	ages.resize(SLOTS);ages.fill(-1.)
	for i in SLOTS:
		var number:=NUMBER.new()
		number.name="PooledDamageNumber_%d"%i
		add_child(number);number.top_level=true;number.set_process(false);number.hide()
		numbers.append(number)
	set_process(false)

func show_hit(amount: int,hp: int,maximum: int,_effects: Node3D) -> void:
	bar.set_instance_shader_parameter("health_ratio",clampf(float(hp)/maxi(1,maximum),0.,1.))
	bar.set_instance_shader_parameter("bar_opacity",1.)
	bar.show();remaining=SHOW_TIME
	var slot:=ages.find(-1.)
	if slot<0:
		slot=0
		for i in SLOTS:
			if ages[i]>ages[slot]:slot=i
	var number:=numbers[slot]
	number.text=str(amount)
	number.modulate.a=1.;number.outline_modulate.a=1.
	number.global_position=global_position+Vector3(.14*(number_serial%3-1),2.23,0.)
	number_serial+=1;ages[slot]=0.;number.show();set_process(true)

func _process(delta: float) -> void:
	super._process(delta)
	var active:=remaining>0.
	for i in SLOTS:
		if ages[i]<0.:continue
		ages[i]+=delta
		if ages[i]>=NUMBER.DURATION:
			ages[i]=-1.;numbers[i].hide();continue
		active=true
		numbers[i].global_position.y+=delta*.55
		numbers[i].modulate.a=clampf((NUMBER.DURATION-ages[i])/.25,0.,1.)
		numbers[i].outline_modulate.a=numbers[i].modulate.a
	set_process(active)
