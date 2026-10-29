extends RefCounted
## Independent masked appearance resolver, not a recovered native implementation.
static func resolve(base:Dictionary,overrides:Array)->Dictionary:
	var result:=base.duplicate(true)
	var groups:Dictionary={}
	for row:Dictionary in overrides:
		var weight:=clampf(float(row.get("weight",0.)),0.,1.)
		if not is_finite(weight)or weight<=0.:continue
		var priority:int=int(row.get("priority",0))
		if not groups.has(priority):groups[priority]=[]
		groups[priority].append(row)
	var priorities:Array=groups.keys();priorities.sort();priorities.reverse()
	for key:Variant in base:
		var remaining:=1.;var value:Variant=null
		for priority:int in priorities:
			var entries:Array=groups[priority];var total:=0.;var blended:Variant=null
			for row:Dictionary in entries:
				if not row.get("fields",{}).has(key):continue
				var w:=clampf(float(row.weight),0.,1.);var v:Variant=row.fields[key]
				if v is float or v is int or v is Vector3 or v is Color:
					blended=v*w if blended==null else blended+v*w
				else:blended=v
				total+=w
			if total<=0.:continue
			var coverage:=minf(total,1.);var allocation:=coverage*remaining
			if blended is float or blended is Vector3 or blended is Color:
				var weighted:Variant=blended/total*allocation;value=weighted if value==null else value+weighted
			elif allocation>.5:value=blended
			remaining*=1.-coverage
		if base[key] is float or base[key] is int or base[key] is Vector3 or base[key] is Color:
			result[key]=base[key] if value==null else value+base[key]*remaining
		elif value!=null:result[key]=value
	return result
static func advance(state:Dictionary,target:Dictionary,velocity:Dictionary,delta_s:float,settle_s:float)->Dictionary:
	var out:=state.duplicate(true);var speed:=velocity.duplicate(true)
	var dt:=maxf(0.,delta_s);var rate:=4.7438645/maxf(.001,settle_s);var decay:=exp(-rate*dt)
	for key:Variant in target:
		var goal:Variant=target[key]
		if not state.has(key):out[key]=goal;continue
		if goal is float or goal is Vector3 or goal is Color:
			var offset:Variant=state[key]-goal
			var v:Variant=speed.get(key,offset*0.)
			var term:Variant=v+rate*offset
			out[key]=goal+(offset+term*dt)*decay;speed[key]=(v-rate*term*dt)*decay
		else:out[key]=goal
	return {"state":out,"velocity":speed}
