extends RefCounted
## Generic private research deformation reader. No reference keys are embedded.
## Physics owns world travel; this supplies one local skeletal base pose only.
const GAITS:=["Walk","Run","StrafeLeft","StrafeRight","CombatWalk","CombatRun","CombatStrafeLeft","CombatStrafeRight"]
var rig:Skeleton3D
var streams:Dictionary={}
var group_for_bone:Array[int]=[]
var rest:Array[Transform3D]=[]
var parents:Array[int]=[]
var group_names:Array=[]
var phase:=0.
var phase_advanced:=0.
var phase_hz:=0.
var run_weight:=0.
var last_kind:=""
var owns_pose:=false
var flight_elapsed:=0.
var landing_elapsed:=0.
var landing_duration:=1.
var landing_moving:=false
var landing_move_weight:=0.
var landing_samples:=0
var _last_stage:=""
var _attachment:Array=[]
var maximum_attachment_gap:=0.
var source_path:=""
var _arm_bones:Array[int]=[]
var _body_bone:=-1
var _last_arm_relative:Dictionary={}
var _arm_from:Dictionary={}
var _arm_elapsed:=1.
var _arm_key:=""
var _native_tracks:Dictionary={}
var _native_rest:Array[Transform3D]=[]
func setup(skeleton:Skeleton3D,path:String,target_path:String)->bool:
	if not path.is_absolute_path() or not FileAccess.file_exists(path):return false
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>32000000:return false
	file.close()
	var project:=ProjectSettings.globalize_path("res://").replace("\\","/").simplify_path().to_lower().trim_suffix("/")+"/"
	if path.replace("\\","/").simplify_path().to_lower().begins_with(project):return false
	var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("schema")!="private-hybrid-deformations/1" or data.get("research_only")!=true or data.get("production_eligible")!=false:return false
	if data.get("target_source_sha256")!=FileAccess.get_sha256(target_path):return false
	if not data.get("groups") is Array or data.groups.size()!=10 or not data.get("bone_groups") is Dictionary or not data.get("clips") is Dictionary:return false
	for name in ["Root","Hips","Spine","Chest","Neck","Head","UpperArm.L","UpperArm.R","Leg.L","Leg.R"]:
		if data.groups.count(name)!=1:return false
	var staged:Dictionary={}
	for key in ["Walk","Run","JumpStationary","JumpMoving"]:
		var row:Variant=data.clips.get(key)
		if not row is Dictionary or not row.get("samples") is Array:return false
		var duration:float=float(row.get("duration",0.));var samples:Array=row.samples
		if not is_finite(duration) or duration<=0. or duration>10. or samples.size()<2 or samples.size()>5000:return false
		var expected_duration:float=.8 if key=="Walk" else (.625 if key=="Run" else 2.6)
		if absf(duration-expected_duration)>.000001 or row.get("loop")!=(key in ["Walk","Run"]):return false
		var frames:Array=[]
		for frame:Variant in samples:
			if not frame is Array or frame.size()!=10:return false
			var values:Array[Transform3D]=[]
			for matrix:Variant in frame:
				if not matrix is Array or matrix.size()!=12:return false
				for number:Variant in matrix:
					if not (number is float or number is int) or not is_finite(float(number)):return false
				var transform:=Transform3D(Basis(Vector3(matrix[0],matrix[1],matrix[2]),Vector3(matrix[3],matrix[4],matrix[5]),Vector3(matrix[6],matrix[7],matrix[8])),Vector3(matrix[9],matrix[10],matrix[11]))
				if transform.basis.determinant()<.05:return false
				values.append(transform)
			frames.append(values)
		staged[key]={"frames":frames,"duration":duration,"loop":bool(row.get("loop",false))}
	var ids:Array[int]=[]
	for i in skeleton.get_bone_count():
		var name:=String(skeleton.get_bone_name(i))
		if not data.bone_groups.has(name):return false
		var group:int=data.groups.find(data.bone_groups[name])
		if group<0:return false
		ids.append(group)
	rig=skeleton;streams=staged;group_for_bone=ids;group_names=data.groups;source_path=path
	for i in rig.get_bone_count():rest.append(rig.get_bone_global_rest(i));parents.append(rig.get_bone_parent(i))
	if not data.get("attachments") is Array or data.attachments.size()!=2:return false
	for item:Variant in data.attachments:
		if not item is Dictionary or not item.get("bone") is String or not item.get("body") is String:return false
		if not(item.get("side") is float or item.get("side") is int) or absf(float(item.side))!=1.:return false
		for field in ["patch","lo","hi"]:
			if not item.get(field) is Array or item[field].size()!=3:return false
			for component:Variant in item[field]:
				if not(component is float or component is int) or not is_finite(float(component)):return false
		var arm:=rig.find_bone(item.bone);var body:=rig.find_bone(item.body)
		if arm<0 or body<0:return false
		if data.bone_groups[item.body]!="Chest" or data.bone_groups[item.bone]!=("UpperArm.L" if float(item.side)>0. else "UpperArm.R"):return false
		var arm_parent:=rig.get_bone_parent(arm)
		if arm_parent<0 or data.bone_groups[String(rig.get_bone_name(arm_parent))]==data.bone_groups[item.bone]:return false
		for axis in 3:
			if float(item.hi[axis])-float(item.lo[axis])<.01:return false
		_attachment.append({"arm":arm,"body":body,"side":float(item.side),"patch":Vector3(item.patch[0],item.patch[1],item.patch[2]),"lo":Vector3(item.lo[0],item.lo[1],item.lo[2]),"hi":Vector3(item.hi[0],item.hi[1],item.hi[2])})
	if _attachment.size()!=2:return false
	if _attachment[0].arm==_attachment[1].arm or _attachment[0].side==_attachment[1].side or _attachment[0].body!=_attachment[1].body:return false
	_body_bone=_attachment[0].body
	for i in rig.get_bone_count():
		_native_rest.append(rig.get_bone_rest(i))
		if group_names[group_for_bone[i]] in ["UpperArm.L","UpperArm.R"]:_arm_bones.append(i)
	return true
func reset()->void:
	phase=0.;phase_advanced=0.;run_weight=0.;last_kind="";owns_pose=false;flight_elapsed=0.;landing_elapsed=0.;landing_samples=0;landing_move_weight=0.;_last_stage="";maximum_attachment_gap=0.;_arm_key="";_arm_elapsed=1.;_arm_from.clear();_last_arm_relative.clear()
func _native_worlds(actor,key:String)->Array[Transform3D]:
	if not _native_tracks.has(key):
		var animation:Animation=actor.animation_player.get_animation(actor.clips[key].action);var tracks:Array=[]
		for index in animation.get_track_count():
			var path:=animation.track_get_path(index)
			if path.get_subname_count()==0:continue
			var bone:=rig.find_bone(path.get_subname(0));var kind:=animation.track_get_type(index)
			if bone>=0 and kind in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:tracks.append({"bone":bone,"kind":kind,"index":index})
		_native_tracks[key]={"animation":animation,"tracks":tracks}
	var row:Dictionary=_native_tracks[key];var animation:Animation=row.animation;var seconds:float=actor.animation_player.current_animation_position
	var local:Array[Transform3D]=_native_rest.duplicate();var p:Array[Vector3]=[];var q:Array[Quaternion]=[];var s:Array[Vector3]=[]
	for value in local:p.append(value.origin);q.append(value.basis.get_rotation_quaternion());s.append(value.basis.get_scale())
	for channel:Dictionary in row.tracks:
		match channel.kind:
			Animation.TYPE_POSITION_3D:p[channel.bone]=animation.position_track_interpolate(channel.index,seconds)
			Animation.TYPE_ROTATION_3D:q[channel.bone]=animation.rotation_track_interpolate(channel.index,seconds)
			Animation.TYPE_SCALE_3D:s[channel.bone]=animation.scale_track_interpolate(channel.index,seconds)
	var world:Array[Transform3D]=[]
	for i in local.size():
		var value:=Transform3D(Basis(q[i])*Basis.from_scale(s[i]),p[i]);world.append(world[parents[i]]*value if parents[i]>=0 else value)
	return world
func is_gait(key:String)->bool:return key in GAITS
func period(speed:float,weight:float)->float:
	# Distance calibration:2m/s Walk /5.59m/s Run at their source cadences.
	# Physical speed is never changed by this clock.
	return lerpf(2.*.8,5.59*.625,weight)/maxf(speed,.001)
func _sample(key:String,seconds:float)->Array[Transform3D]:
	var row:Dictionary=streams[key];var frames:Array=row.frames;var duration:float=row.duration
	var t:=fposmod(seconds,duration) if row.loop else clampf(seconds,0.,duration)
	var cursor:=t/duration*float(frames.size()-1);var left:=mini(int(cursor),frames.size()-2);var weight:=cursor-left
	var a:Array=frames[left];var b:Array=frames[left+1];var out:Array[Transform3D]=[]
	# Dense affine interpolation preserves inherited squash/shear before the
	# skeleton's local conversion; no cumulative pose integration.
	for i in a.size():out.append(Transform3D(Basis(a[i].basis.x.lerp(b[i].basis.x,weight),a[i].basis.y.lerp(b[i].basis.y,weight),a[i].basis.z.lerp(b[i].basis.z,weight)),a[i].origin.lerp(b[i].origin,weight)))
	return out
func _ground_deforms(cursor:float,weight:float)->Array[Transform3D]:
	var walk:=_sample("Walk",cursor*.8);var run:=_sample("Run",cursor*.625);var out:Array[Transform3D]=[]
	for i in walk.size():out.append(walk[i].interpolate_with(run[i],weight))
	return out
func _locals(deforms:Array[Transform3D])->Array[Transform3D]:
	var worlds:Array[Transform3D]=[];var local:Array[Transform3D]=[]
	for i in rest.size():
		var world:=deforms[group_for_bone[i]]*rest[i];worlds.append(world)
		local.append(worlds[parents[i]].affine_inverse()*world if parents[i]>=0 else world)
	return local
func outgoing_pose(delta:float,cursor:Dictionary,speed:float)->Array[Transform3D]:
	cursor.phase=fposmod(float(cursor.phase)+delta/period(speed,float(cursor.weight)),1.)
	return _locals(_ground_deforms(float(cursor.phase),float(cursor.weight)))
func apply(actor,key:String,delta:float)->void:
	phase_advanced=0.;phase_hz=0.;owns_pose=false
	if not actor.review_clip.is_empty():_last_stage="";return
	var stage:String=actor._jump_stage
	var speed:float=actor.current_speed
	var moving:bool=actor._move_requested and speed>.001
	# Contact/flight clocks belong to physical state, even while MD2 combat
	# temporarily owns the visible pose. Never resume a stale previous landing.
	if stage=="JumpLanding":
		if _last_stage!="JumpLanding":landing_move_weight=1. if moving else 0.;landing_duration=.75 if moving else 1.
		landing_elapsed=maxf(float(actor._jump_time),0.);landing_moving=moving
		if not moving:landing_duration=1.
		landing_move_weight=move_toward(landing_move_weight,1. if moving else 0.,delta/.10)
	elif stage in ["JumpTakeoff","JumpAirborne"]:
		if _last_stage not in ["JumpTakeoff","JumpAirborne"]:flight_elapsed=0. if stage=="JumpTakeoff" else .35
		else:flight_elapsed+=delta
	if actor._grounded and moving and not actor.combo.active():
		run_weight=move_toward(run_weight,1. if actor._run_requested else 0.,delta/.22)
		phase_advanced=delta/period(speed,run_weight);phase=fposmod(phase+phase_advanced,1.)
		phase_hz=1./period(speed,run_weight)
	var deforms:Array[Transform3D]=[]
	if not actor.combo.active() and is_gait(key):
		deforms=_ground_deforms(phase,run_weight);last_kind="Run" if actor._run_requested else "Walk"
	elif not actor.combo.active() and key in ["JumpTakeoff","JumpAirborne","JumpLanding"]:
		if stage=="JumpLanding":
			var motion_weight:=landing_move_weight*landing_move_weight*(3.-2.*landing_move_weight)
			landing_samples+=1;last_kind="LandingMoving" if landing_moving else "LandingStationary"
			deforms=_sample("JumpStationary",.92+landing_elapsed)
			var moving_source:=_sample("JumpMoving",.92+landing_elapsed)
			for i in deforms.size():deforms[i]=deforms[i].interpolate_with(moving_source[i],motion_weight)
			if motion_weight>0.:
				var ground:=_ground_deforms(phase,run_weight)
				var chest:=group_names.find("Chest");var root_group:=group_names.find("Root")
				var body_delta:=deforms[chest]*ground[chest].affine_inverse();var root_delta:=deforms[root_group]*ground[root_group].affine_inverse()
				for group in ["UpperArm.L","UpperArm.R"]:
					var index:=group_names.find(group);deforms[index]=deforms[index].interpolate_with(body_delta*ground[index],motion_weight)
				for group in ["Leg.L","Leg.R"]:
					var index:=group_names.find(group);deforms[index]=deforms[index].interpolate_with(root_delta*ground[index],motion_weight)
		else:
			# Fit the source preview flight to the accepted physical apex interval.
			# Actual collision still ends flight; no presentation arc moves the body.
			var physical_flight:float=2.*sqrt(2.*actor.jump_height/actor.gravity)
			deforms=_sample("JumpMoving" if moving else "JumpStationary",clampf(.4+flight_elapsed*.52/physical_flight,.4,.92));last_kind="Flight"
	_last_stage=stage
	if deforms.is_empty():return
	var local:=_locals(deforms)
	if key in ["JumpTakeoff","JumpAirborne","JumpLanding"]:
		var worlds:Array[Transform3D]=[]
		for i in local.size():worlds.append(worlds[parents[i]]*local[i] if parents[i]>=0 else local[i])
		if key in ["JumpTakeoff","JumpAirborne"]:
			var native:=_native_worlds(actor,key);var body_delta:=worlds[_body_bone]*native[_body_bone].affine_inverse()
			for bone in _arm_bones:worlds[bone]=body_delta*native[bone]
		if _arm_key!=key:
			_arm_key=key;_arm_elapsed=0.;_arm_from=_last_arm_relative.duplicate()
		_arm_elapsed+=delta
		var weight:=clampf(_arm_elapsed/.08,0.,1.);weight=weight*weight*(3.-2.*weight)
		var inverse:=worlds[_body_bone].affine_inverse()
		for bone in _arm_bones:
			if _arm_from.has(bone) and weight<1.:worlds[bone]=worlds[_body_bone]*Transform3D(_arm_from[bone]).interpolate_with(inverse*worlds[bone],weight)
		for i in local.size():local[i]=worlds[parents[i]].affine_inverse()*worlds[i] if parents[i]>=0 else worlds[i]
	else:_arm_key="";_arm_from.clear()
	for i in local.size():rig.set_bone_pose(i,local[i])
	rig.force_update_all_bone_transforms();owns_pose=true
func keep_shoulders_attached()->void:
	for item:Dictionary in _attachment if owns_pose else []:
		var arm:int=item.arm;var body:int=item.body;var body_skin:=rig.get_bone_global_pose(body)*rest[body].affine_inverse()
		var arm_world:=rig.get_bone_global_pose(arm);var patch:Vector3=arm_world*rest[arm].affine_inverse()*Vector3(item.patch)
		var local:=body_skin.affine_inverse()*patch;var lo:Vector3=item.lo;var hi:Vector3=item.hi
		var target:=Vector3(hi.x-.002 if item.side>0. else lo.x+.002,clampf(local.y,lo.y+.003,hi.y-.003),clampf(local.z,lo.z+.003,hi.z-.003))
		arm_world.origin+=body_skin*target-patch
		var parent:=rig.get_bone_global_pose(parents[arm]) if parents[arm]>=0 else Transform3D.IDENTITY
		rig.set_bone_pose(arm,parent.affine_inverse()*arm_world);rig.force_update_all_bone_transforms()
		var actual:Vector3=body_skin.affine_inverse()*(rig.get_bone_global_pose(arm)*rest[arm].affine_inverse()*Vector3(item.patch))
		maximum_attachment_gap=maxf(maximum_attachment_gap,actual.distance_to(target))
	if _body_bone>=0:
		var inverse:=rig.get_bone_global_pose(_body_bone).affine_inverse()
		for bone in _arm_bones:_last_arm_relative[bone]=inverse*rig.get_bone_global_pose(bone)
func diagnostics()->Dictionary:
	return {"source":source_path,"last_kind":last_kind,"phase":phase,"phase_hz":phase_hz,"run_weight":run_weight,"phase_advance":phase_advanced,"landing_elapsed":landing_elapsed,"landing_duration":landing_duration,"maximum_attachment_error_m":maximum_attachment_gap,"scope":"Private source-derived retarget; physics/collision and MD2 combat preserved. Run independent lifetime ambient omitted from periodic core."}
