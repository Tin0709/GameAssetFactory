extends CanvasLayer
## Update text four times per second; frame time is averaged wall time, not GPU time.

@onready var metrics: Label = $Margin/Panel/Padding/Rows/Metrics
var elapsed: float = 0.0
var frames: int = 0

func _ready() -> void:
	_update_metrics(0.0)

func _process(delta: float) -> void:
	elapsed += delta
	frames += 1
	if elapsed >= 0.25:
		_update_metrics(elapsed * 1000.0 / float(frames))
		elapsed = 0.0
		frames = 0

func _update_metrics(frame_ms: float) -> void:
	metrics.text = "%d FPS  |  %.2f ms/frame\nRenderer: %s" % [
		Engine.get_frames_per_second(), frame_ms,
		RenderingServer.get_current_rendering_method().capitalize()]
