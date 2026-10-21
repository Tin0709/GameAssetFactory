extends RefCounted
## Local active-cell spring work; one bulk texture upload serves all foliage.
const SIZE:=64
const EXTENT:=34.
const CELL:=EXTENT/SIZE
const STEP:=1./60.
const RADIUS:=1.40
const RESPONSE:=23.
const RECOVERY:=6.5
var x:=PackedFloat32Array()
var z:=PackedFloat32Array()
var vx:=PackedFloat32Array()
var vz:=PackedFloat32Array()
var marked:=PackedByteArray()
var pixels:=PackedByteArray()
var active:=PackedInt32Array()
var image:Image
var texture:ImageTexture
var accumulator:=0.
var previous:=Vector3.ZERO
var initialized:=false
var update_usec:=0

func _init()->void:
	# Packed arrays have value semantics; allocate each member explicitly.
	x.resize(SIZE*SIZE);z.resize(SIZE*SIZE);vx.resize(SIZE*SIZE);vz.resize(SIZE*SIZE)
	marked.resize(SIZE*SIZE);marked.fill(0)
	pixels.resize(SIZE*SIZE*8);pixels.fill(0)
	image=Image.create_from_data(SIZE,SIZE,false,Image.FORMAT_RGBAH,pixels)
	texture=ImageTexture.create_from_image(image)

func reset()->void:
	x.fill(0.);z.fill(0.);vx.fill(0.);vz.fill(0.);marked.fill(0);pixels.fill(0);active.clear()
	accumulator=0.;initialized=false
	upload()

func _stamp(point:Vector3)->void:
	if point.y>1.25:return
	var a:=Vector2(point.x,point.z)
	var minimum:=Vector2i(floori((a.x-RADIUS+EXTENT*.5)/CELL),floori((a.y-RADIUS+EXTENT*.5)/CELL))
	var maximum:=Vector2i(floori((a.x+RADIUS+EXTENT*.5)/CELL),floori((a.y+RADIUS+EXTENT*.5)/CELL))
	for row in range(maxi(0,minimum.y),mini(SIZE-1,maximum.y)+1):
		for col in range(maxi(0,minimum.x),mini(SIZE-1,maximum.x)+1):
			var index:=row*SIZE+col
			if marked[index]==0:marked[index]=1;active.append(index)

func advance(delta:float,point:Vector3,velocity:Vector3)->void:
	var start:=Time.get_ticks_usec()
	if not initialized:previous=point;initialized=true
	if point.distance_squared_to(previous)>16.:reset();previous=point;initialized=true
	var duration:=clampf(delta,0.,.1333333)
	accumulator+=duration
	var steps:=floori((accumulator+.0000001)/STEP)
	if steps==0:return
	accumulator-=steps*STEP
	var planar:=Vector2(velocity.x,velocity.z)
	var speed:=planar.length();var forward:=planar/maxf(speed,.00001)
	for step in steps:
		var at:=previous.lerp(point,float(step+1)/float(steps))
		_stamp(at)
		var ground_gain:=1.-smoothstep(.25,1.25,maxf(0.,at.y))
		var amplitude:=minf(1.20,.48+.115*speed)*ground_gain
		var movement_gain:=.90*speed/(speed+.4)
		var i:=active.size()-1
		while i>=0:
			var index:=active[i];var row:=index/SIZE;var col:=index%SIZE
			var root_point:=Vector2((col+.5)*CELL-EXTENT*.5,(row+.5)*CELL-EXTENT*.5)
			var away:=root_point-Vector2(at.x,at.z);var distance:=away.length()
			var q:=clampf(1.-distance/RADIUS,0.,1.);var falloff:=q*q*(3.-2.*q)
			var direction:=away/maxf(distance,.00001)*.70+forward*movement_gain
			direction=direction/maxf(direction.length(),.12)
			var desired:=direction*(amplitude*falloff)
			var omega:=lerpf(RECOVERY,RESPONSE,falloff*ground_gain)
			var decay:=exp(-omega*STEP)
			var ex:=x[index]-desired.x;var ez:=z[index]-desired.y
			var tx:=(vx[index]+omega*ex)*STEP;var tz:=(vz[index]+omega*ez)*STEP
			x[index]=desired.x+(ex+tx)*decay;z[index]=desired.y+(ez+tz)*decay
			vx[index]=(vx[index]-omega*tx)*decay;vz[index]=(vz[index]-omega*tz)*decay
			if falloff==0. and absf(x[index])+absf(z[index])+absf(vx[index])+absf(vz[index])<.00002:
				x[index]=0.;z[index]=0.;vx[index]=0.;vz[index]=0.;marked[index]=0
				active[i]=active[active.size()-1];active.resize(active.size()-1)
			pixels.encode_half(index*8,x[index]);pixels.encode_half(index*8+2,z[index])
			i-=1
	previous=point;update_usec=Time.get_ticks_usec()-start

func upload()->void:
	image.set_data(SIZE,SIZE,false,Image.FORMAT_RGBAH,pixels);texture.update(image)

func sample_at(point:Vector2)->Vector2:
	var cell:=(point+Vector2.ONE*EXTENT*.5)/CELL-Vector2.ONE*.5
	var a:=Vector2i(floori(cell.x),floori(cell.y));var f:=cell-Vector2(a)
	var result:=Vector2.ZERO
	for dy in 2:
		for dx in 2:
			var col:=clampi(a.x+dx,0,SIZE-1);var row:=clampi(a.y+dy,0,SIZE-1);var i:=row*SIZE+col
			result+=Vector2(x[i],z[i])*(f.x if dx==1 else 1.-f.x)*(f.y if dy==1 else 1.-f.y)
	return result
