extends Node3D
class_name Level

const EntityCatalogScript := preload("res://game/entities/catalog/entity_catalog.gd")
const EntityPlacementDataScript := preload("res://game/entities/placement/entity_placement_data.gd")
const RuntimeMapStateScript := preload("res://game/runtime/runtime_map_state.gd")

@onready var terrain: Terrain = $Terrain
@onready var camera_rig: PlayerCameraRig = $PlayerCameraRig
@onready var _entities_root: Node3D = $Entities
@onready var _selection: SelectionComponent = $Components/SelectionComponent
@onready var _input: InputComponent = $Components/InputComponent
@onready var _command_panel: Node = $UI/CommandPanel

var runtime_map_state: RuntimeMapState = null
var _entity_catalog := EntityCatalogScript.new()

func _ready() -> void:
	_ensure_runtime_map_state()
	_ensure_light()
	_selection.selection_changed.connect(_command_panel.set_selected_entities)
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
	_input.setup(terrain, camera_rig, _selection, $UI/SelectionRect)
	_clear_spawned_entities()
	_initialize_runtime_map_state()
	_spawn_map_entities()

func _spawn_map_entities() -> void:
	if terrain.map_data == null:
		return
	print("Spawning %d map entities..." % terrain.map_data.entity_placements.size())
	for placement in terrain.map_data.entity_placements:
		if placement == null:
			continue
		var entity := _entity_catalog.spawn_entity(placement.entity_id)
		if entity == null:
			push_warning("Unknown entity_id in map placement: %s; skipped." % placement.entity_id)
			continue
		if "team_id" in entity:
			entity.team_id = placement.team_id
		_entities_root.add_child(entity)
		if entity is Node3D:
			var entity_3d := entity as Node3D
			entity_3d.global_position = terrain.to_global(placement.position)
			entity_3d.rotation.y = placement.rotation_y
		if entity.has_method("set_terrain"):
			entity.set_terrain(terrain)
		_apply_health_spawn_mode(entity, placement)
		if runtime_map_state != null:
			runtime_map_state.register_entity_occupancy(entity)
		print("Spawned %s at %s for team %d." % [placement.entity_id, placement.position, placement.team_id])

func _apply_health_spawn_mode(entity: Node, placement: Resource) -> void:
	if entity == null or not entity.has_method("get_health_component"):
		return
	var health := entity.get_health_component() as HealthComponent
	if health == null:
		return
	match placement.health_spawn_mode:
		EntityPlacementDataScript.HealthSpawnMode.FULL:
			health.set_current_health(health.max_health)
		EntityPlacementDataScript.HealthSpawnMode.PERCENT:
			health.set_current_health(health.max_health * clampf(placement.health_value, 0.0, 1.0))
		EntityPlacementDataScript.HealthSpawnMode.CURRENT_VALUE:
			health.set_current_health(clampf(placement.health_value, 0.0, health.max_health))

func _clear_spawned_entities() -> void:
	if runtime_map_state != null:
		for child in _entities_root.get_children():
			runtime_map_state.clear_entity_occupancy(child)
	for child in _entities_root.get_children():
		child.free()

func _ensure_runtime_map_state() -> void:
	if runtime_map_state != null:
		return
	runtime_map_state = RuntimeMapStateScript.new()
	runtime_map_state.name = "RuntimeMapState"
	add_child(runtime_map_state)
	terrain.runtime_state = runtime_map_state

func _initialize_runtime_map_state() -> void:
	_ensure_runtime_map_state()
	runtime_map_state.initialize_from_map(terrain.map_data, terrain)
	terrain.runtime_state = runtime_map_state

func _ensure_light() -> void:
	if has_node("Sun"):
		return
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	add_child(sun)
