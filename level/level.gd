extends Node3D
class_name Level

@onready var terrain: Terrain = $Terrain
@onready var camera_rig: PlayerCameraRig = $PlayerCameraRig
@onready var _infantry: Infantry = $Infantry
@onready var _selection: SelectionComponent = $Components/SelectionComponent
@onready var _input: InputComponent = $Components/InputComponent

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
	_setup_units()
	return true

func _setup_units() -> void:
	_infantry.set_terrain(terrain)
	_input.setup(terrain, camera_rig, _selection)
	var center: Vector3 = terrain.get_center_position()
	var height: float = terrain.get_height_at_local_position(center)
	_infantry.global_position = terrain.to_global(Vector3(center.x, height, center.z))

func _ensure_light() -> void:
	if has_node("Sun"):
		return
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	add_child(sun)
