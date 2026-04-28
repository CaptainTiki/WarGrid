extends Node3D
class_name Level

@onready var terrain: Terrain = $Terrain
@onready var camera_rig: PlayerCameraRig = $PlayerCameraRig
@onready var _infantry: Infantry = $Infantry
@onready var _scout_bike: EntityBase = $ScoutBike
@onready var _scout_buggy: EntityBase = $ScoutBuggy
@onready var _test_hq: EntityBase = $TestHQ
@onready var _selection: SelectionComponent = $Components/SelectionComponent
@onready var _input: InputComponent = $Components/InputComponent
@onready var _command_panel: Node = $UI/CommandPanel

func _ready() -> void:
	_ensure_light()
	_selection.selection_changed.connect(_command_panel.set_selected_entity)
	_command_panel.command_targeting_requested.connect(_input.begin_command_targeting)

func load_map(path: String) -> bool:
	if not ResourceLoader.exists(path):
		push_error("Saved map file not found: %s" % path)
		return false
	if not terrain.load_map(path):
		return false
	terrain.set_overlay_enabled(false)
	terrain.set_overlay_mode(TerrainMapData.OverlayMode.NONE)
	camera_rig.frame_point(terrain.get_center_position())
	_setup_entities()
	return true

func _setup_entities() -> void:
	_infantry.set_terrain(terrain)
	_scout_bike.set_terrain(terrain)
	_scout_buggy.set_terrain(terrain)
	_input.setup(terrain, camera_rig, _selection)
	var center: Vector3 = terrain.get_center_position()
	_place_entity_on_terrain(_infantry, center + Vector3(5.0, 0.0, 0.0))
	_place_entity_on_terrain(_scout_bike, center + Vector3(5.0, 0.0, 5.0))
	_place_entity_on_terrain(_scout_buggy, center + Vector3(5.0, 0.0, -5.0))
	_place_entity_on_terrain(_test_hq, center + Vector3(-7.0, 0.0, 0.0))

func _place_entity_on_terrain(entity: EntityBase, local_position: Vector3) -> void:
	var height: float = terrain.get_height_at_local_position(local_position)
	entity.global_position = terrain.to_global(Vector3(local_position.x, height, local_position.z))

func _ensure_light() -> void:
	if has_node("Sun"):
		return
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	add_child(sun)
