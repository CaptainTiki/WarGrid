extends SceneTree

const MapEditorScene := preload("res://mapeditor/map_editor.tscn")
const EntityPlacementDataScript := preload("res://game/entities/placement/entity_placement_data.gd")
const EntityPlacementDockScript := preload("res://mapeditor/docks/entity_placement_dock.gd")
const TerrainSerializerScript := preload("res://terrain/terrain_serializer.gd")

const TEMP_MAP_PATH := "res://tools/editor_v2_verify_temp.res"

var _failures := 0
var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run()
	return true

func _run() -> void:
	var editor = MapEditorScene.instantiate()
	root.add_child(editor)
	_expect(editor._active_mode == &"terrain", "editor starts in terrain mode")
	_expect(editor.right_dock_container.get_child_count() == 1, "one terrain dock is shown")

	editor._show_entities_mode()
	_expect(editor._active_mode == &"entities", "entities mode activates")
	_expect(editor.right_dock_container.get_child_count() == 1, "one entity dock is shown")
	var dock = editor.entity_dock
	_expect(dock != null, "entity dock exists")
	for button_name in ["SelectToolButton", "PlaceToolButton", "MoveToolButton", "RotateToolButton", "DeleteToolButton"]:
		_expect(dock.get_node_or_null("MarginContainer/VBoxContainer/ToolGrid/%s" % button_name) != null, "entity dock has %s" % button_name)
	for entity_id in [&"infantry", &"scout_bike", &"scout_buggy", &"test_hq", &"enemy_test_hq", &"enemy_dummy_unit"]:
		_expect(_dock_has_entity_id(dock, entity_id), "entity dock lists %s" % entity_id)

	var before_count: int = editor.terrain.map_data.entity_placements.size()
	editor._on_entity_tool_mode_changed(EntityPlacementDockScript.EntityToolMode.PLACE)
	editor._entity_settings = {
		"entity_id": &"enemy_dummy_unit",
		"team_id": 2,
		"rotation_y": 0.25,
		"health_spawn_mode": EntityPlacementDataScript.HealthSpawnMode.PERCENT,
		"health_value": 0.5,
		"tool_mode": EntityPlacementDockScript.EntityToolMode.PLACE,
	}
	editor._ensure_entity_ghost()
	_expect(editor._placement_ghost_root != null, "place mode creates a ghost preview")
	editor._create_entity_placement(editor.terrain.map_data.get_position_for_grid(Vector2i(128, 128)))
	_expect(editor.terrain.map_data.entity_placements.size() == before_count + 1, "placement is added to map data")
	var placement = editor.terrain.map_data.entity_placements[editor.terrain.map_data.entity_placements.size() - 1]
	_expect(placement.entity_id == &"enemy_dummy_unit", "placement stores entity id")
	_expect(placement.team_id == 2, "placement stores team id")
	_expect(placement.health_spawn_mode == EntityPlacementDataScript.HealthSpawnMode.PERCENT, "placement stores health mode")
	_expect(is_equal_approx(placement.health_value, 0.5), "placement stores health value")
	_expect(editor._placement_preview_root.get_child_count() == before_count + 1, "placement preview appears")
	var preview_root: Node = editor._placement_preview_root.get_child(editor._placement_preview_root.get_child_count() - 1)
	_expect(preview_root.get_node_or_null("Preview_enemy_dummy_unit") != null, "placement preview uses catalog entity scene")

	editor._on_entity_tool_mode_changed(EntityPlacementDockScript.EntityToolMode.SELECT)
	editor._select_nearest_placement(placement.position)
	_expect(editor._selected_placement_index == before_count, "select mode selects existing placement")
	editor._on_entity_settings_changed({
		"entity_id": &"enemy_dummy_unit",
		"team_id": 1,
		"rotation_y": placement.rotation_y,
		"health_spawn_mode": EntityPlacementDataScript.HealthSpawnMode.CURRENT_VALUE,
		"health_value": 12.0,
		"tool_mode": EntityPlacementDockScript.EntityToolMode.SELECT,
	})
	_expect(placement.team_id == 1, "selected placement team edits map data")
	_expect(placement.health_spawn_mode == EntityPlacementDataScript.HealthSpawnMode.CURRENT_VALUE, "selected placement health mode edits map data")
	_expect(is_equal_approx(placement.health_value, 12.0), "selected placement health value edits map data")

	var moved_position: Vector3 = editor.terrain.map_data.get_position_for_grid(Vector2i(132, 129))
	editor._on_entity_tool_mode_changed(EntityPlacementDockScript.EntityToolMode.MOVE)
	editor._move_selected_placement(moved_position)
	_expect(placement.position == moved_position, "move mode updates placement position")

	editor._on_entity_tool_mode_changed(EntityPlacementDockScript.EntityToolMode.ROTATE)
	var old_rotation: float = placement.rotation_y
	editor._rotate_selected_placement(PI * 0.5)
	_expect(not is_equal_approx(placement.rotation_y, old_rotation), "rotate mode updates placement rotation")

	_expect(TerrainSerializerScript.save(editor.terrain.map_data, TEMP_MAP_PATH, "Editor V2 Verify"), "edited map data saves")
	var reloaded_map = TerrainSerializerScript.load(TEMP_MAP_PATH)
	_expect(reloaded_map != null, "edited map data reloads")
	if reloaded_map != null:
		var reloaded_placement = reloaded_map.entity_placements[reloaded_map.entity_placements.size() - 1]
		_expect(reloaded_placement.entity_id == placement.entity_id, "reload preserves entity id")
		_expect(reloaded_placement.team_id == placement.team_id, "reload preserves team")
		_expect(reloaded_placement.position == placement.position, "reload preserves moved position")
		_expect(is_equal_approx(reloaded_placement.rotation_y, placement.rotation_y), "reload preserves rotation")
		_expect(reloaded_placement.health_spawn_mode == placement.health_spawn_mode, "reload preserves health mode")
		_expect(is_equal_approx(reloaded_placement.health_value, placement.health_value), "reload preserves health value")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_MAP_PATH))

	editor._on_entity_tool_mode_changed(EntityPlacementDockScript.EntityToolMode.DELETE)
	editor._delete_nearest_placement(placement.position)
	_expect(editor.terrain.map_data.entity_placements.size() == before_count, "placement delete removes map data")

	editor.free()
	if _failures == 0:
		print("Map editor entity dock verification passed.")
		quit(0)
	else:
		push_error("Map editor entity dock verification failed with %d failure(s)." % _failures)
		quit(1)

func _dock_has_entity_id(dock, entity_id: StringName) -> bool:
	for i in range(dock.entity_option.item_count):
		if StringName(str(dock.entity_option.get_item_metadata(i))) == entity_id:
			return true
	return false

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)
