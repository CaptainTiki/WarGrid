extends Node3D
class_name Level

@onready var terrain: Terrain = $Terrain
@onready var camera_rig = $PlayerCameraRig

func _ready() -> void:
	_ensure_light()

func load_map(path: String) -> bool:
	if not ResourceLoader.exists(path):
		push_error("Saved map file not found: %s" % path)
		return false
	if not terrain.load_map(path):
		return false
	terrain.set_overlay_enabled(false)
	terrain.set_overlay_mode(TerrainMapData.OverlayMode.NONE)
	camera_rig.frame_point(terrain.get_center_position())
	return true

func _ensure_light() -> void:
	if has_node("Sun"):
		return
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	add_child(sun)
