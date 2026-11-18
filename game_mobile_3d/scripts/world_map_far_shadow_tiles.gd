extends RefCounted

const MAX_REQUESTS := 4
const MAX_JOBS := 2

class DecodeJob extends RefCounted:
	var expected_length: int
	var encoded_length: int
	var checksum: String
	var path: String
	var bytes := PackedByteArray()
	var error := ""
	var elapsed_us := 0
	var queued_at_us := 0
	var queue_us := 0
	var delay_ms := 0

	func run() -> void:
		var start := Time.get_ticks_usec()
		queue_us = start - queued_at_us
		if delay_ms > 0:
			OS.delay_msec(delay_ms)
		if not FileAccess.file_exists(path):
			error = "A depth tile is unavailable"
		else:
			var compressed := FileAccess.get_file_as_bytes(path)
			if compressed.size() != encoded_length:
				error = "A depth tile size differs from its manifest"
			else:
				var raw := compressed.decompress(expected_length,FileAccess.COMPRESSION_DEFLATE)
				var hasher := HashingContext.new()
				hasher.start(HashingContext.HASH_SHA256)
				if raw.size()!=expected_length or hasher.update(raw)!=OK or hasher.finish().hex_encode()!=checksum:
					error = "A depth tile failed verification"
				else:
					bytes = raw
		elapsed_us = Time.get_ticks_usec()-start

var directory := ""
var byte_length := 0
var worker_delay_ms := 0
var record_timings := false
var decode_us: Array[int] = []
var queue_us: Array[int] = []
var peak_jobs := 0
var peak_ready_bytes := 0
var stale_results := 0
var completed := 0

var _jobs := {}
var _ready := {}
var _errors := {}
var _closed := false

func _identity(key: Dictionary) -> String:
	return String(key.file) + "|" + String(key.raw_sha256) + "|" + str(int(key.packed_bytes))

func lookup(key: Dictionary) -> PackedByteArray:
	return _ready.get(_identity(key),PackedByteArray())

func error_for(key: Dictionary) -> String:
	return _errors.get(_identity(key),"")

func update(requests: Array) -> void:
	if _closed:
		return
	var wanted := {}
	for key: Dictionary in requests:
		if wanted.size() >= MAX_REQUESTS:
			break
		wanted[_identity(key)] = key
	for id: String in _ready.keys():
		if not wanted.has(id):
			_ready.erase(id)
	for id: String in _jobs.keys():
		var handle: Dictionary = _jobs[id]
		if not WorkerThreadPool.is_task_completed(handle.task):
			continue
		var joined := WorkerThreadPool.wait_for_task_completion(handle.task)
		var job: DecodeJob = handle.job
		_jobs.erase(id)
		completed += 1
		if record_timings:
			decode_us.append(job.elapsed_us)
			queue_us.append(job.queue_us)
		if not wanted.has(id):
			stale_results += 1
			continue
		if joined != OK or not job.error.is_empty():
			_errors[id] = job.error if joined == OK else "Could not collect a depth tile"
		else:
			_ready[id] = job.bytes
	peak_ready_bytes = maxi(peak_ready_bytes,_ready.size()*byte_length)
	for id: String in wanted:
		if _jobs.size() >= MAX_JOBS:
			break
		if _jobs.has(id) or _ready.has(id) or _errors.has(id):
			continue
		var key: Dictionary = wanted[id]
		var name: String = key.file
		if name != name.get_file() or not name.ends_with(".r16z"):
			_errors[id] = "Invalid depth tile name"
			continue
		var job := DecodeJob.new()
		job.path = directory.path_join(name)
		job.expected_length = byte_length
		job.encoded_length = int(key.packed_bytes)
		job.checksum = key.raw_sha256
		job.delay_ms=worker_delay_ms
		job.queued_at_us = Time.get_ticks_usec()
		var ticket := WorkerThreadPool.add_task(job.run,false,"Forest depth tile")
		_jobs[id] = {"task":ticket,"job":job}
	peak_jobs = maxi(peak_jobs,_jobs.size())

func snapshot() -> Dictionary:
	return {"pending":_jobs.size(),"ready":_ready.size(),"completed":completed}

func close() -> void:
	_closed = true
	for handle: Dictionary in _jobs.values():
		WorkerThreadPool.wait_for_task_completion(handle.task)
	_jobs.clear()
	_ready.clear()
