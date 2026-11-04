extends RefCounted
## Original preflight for this private reference integration; runtime checks follow.
static func evaluate(context:Dictionary)->Dictionary:
	var reason:=""
	if not bool(context.get("editor",false)):
		reason="Private reference profiles are editor-only; original graphics retained."
	elif context.get("renderer","")!="mobile":
		reason="This reference path is verified on Mobile RenderingDevice only."
	elif not bool(context.get("metadata_available",false)):
		reason="Private HDR/exposure profile unavailable; original graphics retained."
	elif not bool(context.get("reference_requested",false)):
		reason="Auto/low-device fallback keeps original graphics until handset validation."
	return {"allowed":reason.is_empty(),"reason":reason,"phone_benchmarked":false}
