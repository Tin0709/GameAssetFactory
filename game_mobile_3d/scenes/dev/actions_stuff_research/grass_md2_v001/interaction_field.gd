extends RefCounted
## Local active-cell spring work; one bulk texture upload serves all foliage.
const SIZE:=64
const EXTENT:=34.
const CELL:=EXTENT/SIZE
const STEP:=1./60.
const RADIUS:=1.40
const RESPONSE:=23.
const RECOVERY:=7.8
const DAMPING:=.17
var x:=PackedFloat32Array()
var z:=PackedFloat32Array()
var vx:=PackedFloat32Array()
var vz:=PackedFloat32Array()
var marked:=PackedByteArray()
var contact_weights:=PackedFloat32Array()
var pixels:=PackedByteArray()
var previous_pixels:=PackedByteArray()
var active:=PackedInt32Array()
var image:Image
var texture:ImageTexture
var previous_image:Image
var previous_texture:ImageTexture
var revision:=0
var uploaded_revision:=-1
var accumulator:=0.
var previous:=Vector3.ZERO
var initialized:=false
var update_usec:=0

func _init()->void:
	# Packed arrays have value semantics; allocate each member explicitly.
	x.resize(SIZE*SIZE);z.resize(SIZE*SIZE);vx.resize(SIZE*SIZE);vz.resize(SIZE*SIZE)
	contact_weights.resize(SIZE*SIZE)
	marked.resize(SIZE*SIZE);marked.fill(0)
	pixels.resize(SIZE*SIZE*8);pixels.fill(0)
	previous_pixels=pixels
	image=Image.create_from_data(SIZE,SIZE,false,Image.FORMAT_RGBAH,pixels)
	texture=ImageTexture.create_from_image(image)
	previous_image=Image.create_from_data(SIZE,SIZE,false,Image.FORMAT_RGBAH,previous_pixels)
	previous_texture=ImageTexture.create_from_image(previous_image)

func reset()->void:
	x.fill(0.);z.fill(0.);vx.fill(0.);vz.fill(0.);contact_weights.fill(0.);marked.fill(0);pixels.fill(0);active.clear()
	previous_pixels=pixels;revision+=1
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
	# Existing editor play sessions can hot-reload this new state member.
	if contact_weights.size()!=SIZE*SIZE:contact_weights.resize(SIZE*SIZE);contact_weights.fill(0.)
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
		# Copy-on-write snapshot of the final two FIXED ticks, even at30FPS.
		# The renderer follows the same delayed interpolation as the actor.
		previous_pixels=pixels
		var at:=previous.lerp(point,float(step+1)/float(steps))
		_stamp(at)
		var ground_gain:=1.-smoothstep(.25,1.25,maxf(0.,at.y))
		var amplitude:=minf(.96,.46+.085*speed)*ground_gain
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
			# Only newly increasing contact supplies a kick. Resting contact never
			# restarts the oscillation, and repeated brushes remain velocity-bounded.
			var contact:=falloff*ground_gain
			var rise:=maxf(0.,contact-contact_weights[index]);contact_weights[index]=contact
			var kick:=direction*rise*(6.5+2.0*minf(speed/7.55,1.))
			var velocity_now:=(Vector2(vx[index],vz[index])+kick).limit_length(7.5)
			vx[index]=velocity_now.x;vz[index]=velocity_now.y
			# Closed-form underdamped spring: clear bend, soft reversals, fading energy.
			var damping:=DAMPING*omega;var frequency:=omega*sqrt(1.-DAMPING*DAMPING)
			var decay:=exp(-damping*STEP);var cosine:=cos(frequency*STEP);var sine:=sin(frequency*STEP)
			var ex:=x[index]-desired.x;var ez:=z[index]-desired.y
			var tx:=(vx[index]+damping*ex)/frequency;var tz:=(vz[index]+damping*ez)/frequency
			x[index]=desired.x+(ex*cosine+tx*sine)*decay;z[index]=desired.y+(ez*cosine+tz*sine)*decay
			vx[index]=(vx[index]*cosine-(damping*vx[index]+omega*omega*ex)/frequency*sine)*decay
			vz[index]=(vz[index]*cosine-(damping*vz[index]+omega*omega*ez)/frequency*sine)*decay
			if falloff==0. and absf(x[index])+absf(z[index])+absf(vx[index])+absf(vz[index])<.00002:
				x[index]=0.;z[index]=0.;vx[index]=0.;vz[index]=0.;contact_weights[index]=0.;marked[index]=0
				active[i]=active[active.size()-1];active.resize(active.size()-1)
			pixels.encode_half(index*8,x[index]);pixels.encode_half(index*8+2,z[index])
			i-=1
	revision+=steps
	previous=point;update_usec=Time.get_ticks_usec()-start

func upload()->void:
	if uploaded_revision==revision:return
	previous_image.set_data(SIZE,SIZE,false,Image.FORMAT_RGBAH,previous_pixels);previous_texture.update(previous_image)
	image.set_data(SIZE,SIZE,false,Image.FORMAT_RGBAH,pixels);texture.update(image)
	uploaded_revision=revision

func sample_at(point:Vector2)->Vector2:
	var cell:=(point+Vector2.ONE*EXTENT*.5)/CELL-Vector2.ONE*.5
	var a:=Vector2i(floori(cell.x),floori(cell.y));var f:=cell-Vector2(a)
	var result:=Vector2.ZERO
	for dy in 2:
		for dx in 2:
			var col:=clampi(a.x+dx,0,SIZE-1);var row:=clampi(a.y+dy,0,SIZE-1);var i:=row*SIZE+col
			result+=Vector2(x[i],z[i])*(f.x if dx==1 else 1.-f.x)*(f.y if dy==1 else 1.-f.y)
	return result
