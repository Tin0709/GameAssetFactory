extends RefCounted
## Original rigid contact adapter, NOT recovered MD2 IK. No scale/rotation,
## new joints, capsule displacement, source keys or animation clock writes.
const LEG_HORIZONTAL_LIMIT:=.065
const LEG_VERTICAL_LIMIT:=.065
const REACH:=LEG_HORIZONTAL_LIMIT
const PELVIS_LIMIT:=.085
const CONTACT_ENTER:=.045
const CONTACT_EXIT:=.085
var enabled:=true
var actor:CharacterBody3D
var geometry:RefCounted
var rig:Skeleton3D
var base_visual:=Vector3.ZERO
var pelvis:=0.
var states:Array[Dictionary]=[]
var _saved:Dictionary={}
var _previous_raw:Array=[]
var _previous_final:Array=[]
var _previous_contacts:Array=[false,false]
var _previous_near:Array=[false,false]
var _last_serial:=-1
var _last_root:=Vector3.ZERO
var _last_pelvis_speed:=0.
var _metrics:Dictionary={}
var last:Dictionary={}

func setup(body:CharacterBody3D,sole_geometry:RefCounted)->void:
	actor=body;geometry=sole_geometry;rig=actor.skeleton;base_visual=actor.visual.position
	clear();reset_metrics()

func restore()->void:
	for bone:int in _saved:rig.set_bone_pose(bone,_saved[bone])
	_saved.clear()
	actor.visual.position=base_visual
	rig.force_update_all_bone_transforms()

func clear()->void:
	if actor!=null:restore();_last_root=actor.global_position
	pelvis=0.;states=[{"planted":false},{"planted":false}]
	_previous_raw=[];_previous_final=[];_previous_contacts=[false,false];_previous_near=[false,false];_last_serial=-1;_last_pelvis_speed=0.

func set_enabled(value:bool)->void:
	clear();enabled=value;reset_metrics()

func reset_metrics()->void:
	_metrics={"samples":0,"contact_samples":0,"slip_sum_sq":0.,"slip_distance_m":0.,"contact_seconds":0.,"near_ground_samples":0,"near_ground_sum_sq":0.,"penetration_sum_m":0.,"penetration_max_m":0.,"body_correction_accel_sum_sq":0.,"body_correction_accel_max":0.,"release_count":0,"ray_queries":0}

func _samples(side:int)->Dictionary:
	var points:Array[Vector3]=[];var center:=Vector3.ZERO;var seen:Dictionary={}
	for entry:Dictionary in geometry._sole_points[side]:
		var p:Vector3=rig.global_transform*(rig.get_bone_global_pose(entry.bone)*Transform3D(entry.bind)*Vector3(entry.point))
		var key:=Vector3(roundf(p.x*100000.),roundf(p.y*100000.),roundf(p.z*100000.))
		if seen.has(key):continue
		seen[key]=true;points.append(p);center+=p
	if not points.is_empty():center/=float(points.size())
	return {"center":center,"points":points}

func _ground(sample:Dictionary)->Dictionary:
	var lift:=-INF;var hits:=0
	var space:=actor.get_world_3d().direct_space_state
	for p:Vector3 in sample.points:
		var q:=PhysicsRayQueryParameters3D.create(Vector3(p.x,maxf(p.y+.25,actor.global_position.y+.3),p.z),Vector3(p.x,actor.global_position.y-.3,p.z),actor.collision_mask,[actor.get_rid()])
		var hit:=space.intersect_ray(q);_metrics.ray_queries+=1
		if hit.is_empty() or Vector3(hit.normal).y<.65 or float(hit.position.y)>actor.global_position.y+.15:continue
		lift=maxf(lift,float(hit.position.y)-p.y);hits+=1
	return {"valid":hits>=3,"lift":lift if hits>0 else 0.,"hits":hits}

func apply(delta:float,grounded:bool,raw_review:bool,allow_plant:bool,serial:int)->void:
	if delta<=0.:return
	# Air and raw review are exact bypasses. Never carry an old anchor into flight.
	if not grounded or raw_review:
		clear();last={"enabled":enabled,"contacts":[false,false],"pelvis_m":0.,"airborne_bypass":not grounded};return
	if actor.global_position.distance_to(_last_root)>.8 or serial!=_last_serial:
		states=[{"planted":false},{"planted":false}];_previous_contacts=[false,false]
	_last_root=actor.global_position;_last_serial=serial
	var raw:Array=[];var grounds:Array=[];var targets:Array=[]
	var body_goal:=0.;var minimum:=-INF;var maximum:=INF
	for side in 2:
		raw.append(_samples(side));grounds.append(_ground(raw[side]))
		if grounds[side].valid and float(grounds[side].lift)>-CONTACT_ENTER:
			minimum=maxf(minimum,float(grounds[side].lift)-LEG_VERTICAL_LIMIT)
			maximum=minf(maximum,float(grounds[side].lift)+LEG_VERTICAL_LIMIT)
	# Prefer zero body motion whenever the rigid-leg budget can reach. This
	# avoids injecting a second gait bob into already-authored hip animation.
	if minimum<=maximum:body_goal=clampf(0.,minimum,maximum)
	else:body_goal=minimum
	body_goal=clampf(body_goal,-.04,PELVIS_LIMIT)
	var previous_pelvis:=pelvis
	pelvis=lerpf(pelvis,body_goal,1.-exp(-12.*delta)) if enabled else 0.
	actor.visual.position=base_visual+Vector3.UP*pelvis
	var contacts:Array=[];var near:Array=[];var raw_centers:Array=[]
	for side in 2:
		var s:Dictionary=states[side];var center:Vector3=raw[side].center;raw_centers.append(center)
		var rising:=_previous_raw.size()==2 and (center.y-Vector3(_previous_raw[side]).y)/delta>.85
		var valid:bool=grounds[side].valid and float(grounds[side].lift)>-CONTACT_EXIT
		near.append(valid and not rising and float(grounds[side].lift)>-CONTACT_ENTER)
		var forward:Vector3=actor.visual.global_basis.z.normalized()
		var reach:=0.
		if s.planted:reach=Vector2(center.x-Vector3(s.anchor).x,center.z-Vector3(s.anchor).z).length()
		var turning:bool=s.planted and forward.dot(s.get("heading",forward))<cos(deg_to_rad(15.))
		var released:bool=s.planted and (not valid or rising or reach>REACH or turning or not allow_plant)
		if released:s.planted=false;_metrics.release_count+=1
		if not s.planted and not released and valid and not rising and allow_plant and float(grounds[side].lift)>-CONTACT_ENTER:
			var old_offset:Vector3=s.get("correction",Vector3.ZERO)
			s.planted=true;s.anchor=center+Vector3(old_offset.x,0.,old_offset.z);s.heading=forward
		contacts.append(bool(s.planted))
		var correction:=Vector3.ZERO
		if s.planted:
			var error:Vector3=Vector3(s.anchor)-center;error.y=0.
			correction=error.limit_length(LEG_HORIZONTAL_LIMIT)
		var old:Vector3=s.get("correction",Vector3.ZERO)
		# A valid plant is a world-space constraint, not a filtered pursuit of
		# its anchor. Filter only the release back to the authored trajectory.
		var horizontal:=Vector2(correction.x,correction.z) if s.planted else Vector2(old.x,old.z).lerp(Vector2.ZERO,1.-exp(-35.*delta))
		correction.x=horizontal.x;correction.z=horizontal.y
		# Ground support must follow the FINAL horizontal footprint. At a step
		# edge its raw animation footprint may already be on a different slab.
		var support:Dictionary=grounds[side]
		if enabled and horizontal.length_squared()>.00000001:
			var shifted:Array[Vector3]=[]
			for p:Vector3 in raw[side].points:shifted.append(p+Vector3(correction.x,0.,correction.z))
			support=_ground({"points":shifted})
		if support.valid and (s.planted or float(support.lift)>0.):
			correction.y=clampf(float(support.lift)-pelvis+.001,-LEG_VERTICAL_LIMIT,LEG_VERTICAL_LIMIT)
		else:correction.y=clampf(-pelvis,-LEG_VERTICAL_LIMIT,LEG_VERTICAL_LIMIT)
		s.correction=correction;targets.append(correction if enabled else Vector3.ZERO)
	for side in 2:
		var bone:int=geometry.legs[side];var pose:=rig.get_bone_pose(bone);_saved[bone]=pose
		var parent:=rig.get_bone_parent(bone)
		var parent_world:Basis=rig.global_basis*rig.get_bone_global_pose(parent).basis
		pose.origin+=parent_world.inverse()*Vector3(targets[side]);rig.set_bone_pose(bone,pose)
	rig.force_update_all_bone_transforms()
	var final_centers:Array=[];var penetration:=0.
	for side in 2:
		var corrected:=_samples(side);final_centers.append(corrected.center)
		var support:=_ground(corrected)
		if support.valid:penetration=maxf(penetration,maxf(0.,float(support.lift)))
		if contacts[side] and _previous_contacts[side] and _previous_final.size()==2:
			var d:Vector3=Vector3(corrected.center)-Vector3(_previous_final[side]);d.y=0.
			_metrics.contact_samples+=1;_metrics.slip_sum_sq+=d.length_squared()/(delta*delta)
			_metrics.slip_distance_m+=d.length();_metrics.contact_seconds+=delta
		if near[side] and _previous_near[side] and _previous_final.size()==2:
			var d:Vector3=Vector3(corrected.center)-Vector3(_previous_final[side]);d.y=0.
			_metrics.near_ground_samples+=1;_metrics.near_ground_sum_sq+=d.length_squared()/(delta*delta)
	var speed:float=(pelvis-previous_pelvis)/delta
	var accel:float=absf(speed-_last_pelvis_speed)/delta;_last_pelvis_speed=speed
	_metrics.samples+=1;_metrics.penetration_sum_m+=penetration;_metrics.penetration_max_m=maxf(_metrics.penetration_max_m,penetration)
	_metrics.body_correction_accel_sum_sq+=accel*accel;_metrics.body_correction_accel_max=maxf(_metrics.body_correction_accel_max,accel)
	_previous_raw=raw_centers;_previous_final=final_centers;_previous_contacts=contacts;_previous_near=near
	last={"enabled":enabled,"contacts":contacts,"pelvis_m":pelvis,"correction_m":targets,"penetration_m":penetration,"airborne_bypass":false}

func snapshot()->Dictionary:
	var result:=_metrics.duplicate(true);result.merge(last)
	result["slip_rms_m_s"]=sqrt(float(_metrics.slip_sum_sq)/maxi(1,_metrics.contact_samples))
	result["near_ground_travel_rms_m_s"]=sqrt(float(_metrics.near_ground_sum_sq)/maxi(1,_metrics.near_ground_samples))
	result["penetration_mean_m"]=float(_metrics.penetration_sum_m)/maxi(1,_metrics.samples)
	result["body_correction_accel_rms_m_s2"]=sqrt(float(_metrics.body_correction_accel_sum_sq)/maxi(1,_metrics.samples))
	result["scope"]="Original bounded rigid-contact adapter. Contacts are geometric candidates, not native MD2 masks. Slip excludes lifts/replants; body acceleration measures only the added correction. Tall/steep terrain can exceed reach."
	return result
