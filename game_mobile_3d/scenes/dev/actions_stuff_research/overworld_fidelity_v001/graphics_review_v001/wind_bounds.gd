extends RefCounted
## Original conservative bound for a rotation about each instance origin.
## The old margin remains reserved for the existing contact deformation.
static func norm_bound(b:Basis)->float:
	var lengths:=Vector3(b.x.length(),b.y.length(),b.z.length())
	var perpendicular:=absf(b.x.dot(b.y))<.000001*lengths.x*lengths.y and absf(b.x.dot(b.z))<.000001*lengths.x*lengths.z and absf(b.y.dot(b.z))<.000001*lengths.y*lengths.z
	return maxf(lengths.x,maxf(lengths.y,lengths.z)) if perpendicular else sqrt(b.x.length_squared()+b.y.length_squared()+b.z.length_squared())
static func rotation_margin(multimesh:MultiMesh,node_basis:Basis,gain:float)->float:
	if multimesh==null or multimesh.mesh==null:return 0.
	var box:=multimesh.mesh.get_aabb();var radius:=0.
	for corner in 8:radius=maxf(radius,box.get_endpoint(corner).length())
	var scale_bound:=0.
	for i in multimesh.instance_count:scale_bound=maxf(scale_bound,norm_bound(multimesh.get_instance_transform(i).basis))
	# Convert the world-space rotation displacement bound back to node-local
	# AABB units. Frobenius bounds cover shear; orthogonal bases stay tighter.
	var conversion:=norm_bound(node_basis)*norm_bound(node_basis.inverse())
	return 2.*radius*scale_bound*conversion*sin(minf(absf(gain),PI)*.5)
