extends RefCounted
## Bounded developer diagnostics. Receipt clocks are not hardware timestamps.
const CAPACITY:=512
var enabled:=false
var _slots:Array[Dictionary]=[]
var _next:=0
var _total:=0
func clear()->void:_slots.clear();_next=0
func add(kind:StringName,state:Dictionary)->void:
	if not enabled:return
	_total+=1
	var row:Dictionary=state.duplicate(true)
	row.merge({"kind":str(kind),"sequence":_total,"wall_usec":Time.get_ticks_usec(),"physics_frame":Engine.get_physics_frames(),"process_frame":Engine.get_process_frames()},true)
	if _slots.size()<CAPACITY:_slots.append(row)
	else:_slots[_next]=row
	_next=(_next+1)%CAPACITY
func summary()->Dictionary:
	return {"enabled":enabled,"total":_total,"retained":_slots.size(),"capacity":CAPACITY,"scope":"Engine receipt/dispatch and simulation order; wall_usec is not device or native MD2 input time."}
func snapshot()->Dictionary:
	var rows:Array[Dictionary]=[]
	for i in _slots.size():rows.append(_slots[(_next+i)%CAPACITY if _slots.size()==CAPACITY else i].duplicate(true))
	return {"schema":"sabre-input-order/1","summary":summary(),"events":rows}
