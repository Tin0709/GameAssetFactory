extends RefCounted
## A clear one-block riser in the original source map; no added terrain.
static func find(level: Node) -> Dictionary:
	for column:Vector2i in level.columns:
		var high:float=level.columns[column]
		var target:Vector3=level.source_to_world(Vector3i(column.x,0,column.y))
		if absf(target.x)>40.0 or absf(target.z)>40.0:continue
		for direction:Vector2i in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]:
			var low:float=level.columns.get(column-direction,-INF)
			if not is_equal_approx(high-low,1.0):continue
			var clear:=true
			# The capsule is 0.6m wide and travels down cell centres. Two full
			# upper cells provide room to land and decelerate after the riser.
			for along in range(-3,2):
				var cell:=column+direction*along
				var expected:float=low if along<0 else high
				clear=clear and is_equal_approx(level.columns.get(cell,-INF),expected) and level.clear_standing_space(cell,expected)
			if not clear:continue
			var travel:=Vector3(direction.x,0,direction.y)
			target.y=high+float(level.runtime.offset[1])
			var start:=target-travel*2.8;start.y=low+float(level.runtime.offset[1])+.02
			var action:="move_right" if direction.x>0 else ("move_left" if direction.x<0 else ("move_backward" if direction.y>0 else "move_forward"))
			return {"start":start,"target":target,"direction":travel,"action":action,"column":column}
	return {}
