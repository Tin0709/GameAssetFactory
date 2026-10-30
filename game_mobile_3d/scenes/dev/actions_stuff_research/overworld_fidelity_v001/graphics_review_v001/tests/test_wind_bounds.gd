extends SceneTree
const Bounds=preload("../wind_bounds.gd")
func _initialize()->void:
	var mesh:=BoxMesh.new();mesh.size=Vector3(2.,.5,1.)
	var multimesh:=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.mesh=mesh;multimesh.instance_count=3
	multimesh.set_instance_transform(0,Transform3D.IDENTITY)
	multimesh.set_instance_transform(1,Transform3D(Basis(Vector3.UP,.4).scaled(Vector3(.5,1.2,.8)),Vector3(4,0,2)))
	multimesh.set_instance_transform(2,Transform3D(Basis(Vector3(1,0,0),Vector3(.3,1,0),Vector3(.2,.1,1)),Vector3(-2,0,3)))
	var checks:=0;var errors:Array=[];var axis:=Vector3(.3,1.,.4).normalized()
	for node_basis:Basis in [Basis.IDENTITY,Basis.from_scale(Vector3(2.,1.,.75)),Basis(Vector3(1.,0,0),Vector3(.2,1.,0),Vector3(0,.1,1.))]:
		for gain:float in [0.,.1,.7,4.]:
			var margin:float=Bounds.rotation_margin(multimesh,node_basis,gain)
			for i in multimesh.instance_count:
				for corner in 8:
					var point:=node_basis*multimesh.get_instance_transform(i).basis*mesh.get_aabb().get_endpoint(corner)
					for angle:float in [-gain*.5,gain,minf(gain,PI)]:
						var offset:=node_basis.inverse()*(point.rotated(axis,angle)-point)
						checks+=1
						if offset.length()>margin+.00001:errors.append({"gain":gain,"required":offset.length(),"margin":margin})
	print("WIND_BOUNDS ",JSON.stringify({"checks":checks,"errors":errors,"scope":"Synthetic corners/scales/shear/rotation; no proprietary fixture"}));quit(0 if errors.is_empty()else 1)
