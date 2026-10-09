extends Resource
## Reusable visual recipe; placement, collision and actor animation belong to the map.
@export var environment: Environment
@export var sun_settings: Dictionary = {}
@export var shadow_atlas_size: int = 2048
@export var shadow_16bit: bool = false
@export var shadow_quality: RenderingServer.ShadowQuality = RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM
@export var ground_shader: Shader
@export var plants_shader: Shader
@export var leaves_shader: Shader
@export var cutaway_shader: Shader
