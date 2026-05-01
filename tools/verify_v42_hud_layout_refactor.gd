extends SceneTree

const LevelScene := preload("res://level/level.tscn")
const EntityCatalogScript := preload("res://game/entities/catalog/entity_catalog.gd")
const TEST_MAP_PATH := "res://levels/test_map/map_data.res"

var _failures := 0
var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run()
	return true

func _run() -> void:
	var wallet := root.get_node_or_null("ResourceManager")
	if wallet != null:
		wallet.reset_to_starting_resources()

	var level = LevelScene.instantiate()
	root.add_child(level)
	_expect(level.load_map(TEST_MAP_PATH), "level loads test map")

	var hud := level.get_node_or_null("UI/HudRoot")
	_expect(hud != null, "HUD root exists")
	_expect(level.get_node_or_null("UI/HudRoot/TopBar") != null, "top bar exists")
	_expect(level.get_node_or_null("UI/HudRoot/BottomHudRoot") != null, "bottom HUD root exists")
	_expect(level.get_node_or_null("UI/HudRoot/BottomHudRoot/MinimapPanel") != null, "minimap panel exists")
	_expect(level.get_node_or_null("UI/HudRoot/BottomHudRoot/SelectionPanel") != null, "selection panel exists")
	_expect(level.get_node_or_null("UI/HudRoot/BottomHudRoot/ActionGrid") != null, "action grid exists")
	var old_panel := level.get_node_or_null("UI/CommandPanel")
	_expect(old_panel != null and not old_panel.visible, "old command panel is hidden")

	var crystals_label: Label = level.get_node("UI/HudRoot/TopBar/MarginContainer/HBoxContainer/ResourceDisplay/CrystalsLabel")
	var he3_label: Label = level.get_node("UI/HudRoot/TopBar/MarginContainer/HBoxContainer/ResourceDisplay/He3Label")
	_expect(crystals_label.text == "Crystals: 500", "top resource display shows crystals")
	_expect(he3_label.text == "He3: 0", "top resource display shows he3")

	var bottom_hud: Control = level.get_node("UI/HudRoot/BottomHudRoot")
	var minimap: Control = level.get_node("UI/HudRoot/BottomHudRoot/MinimapPanel")
	var selection_panel: Control = level.get_node("UI/HudRoot/BottomHudRoot/SelectionPanel")
	var action_grid: Control = level.get_node("UI/HudRoot/BottomHudRoot/ActionGrid")
	_expect(not (bottom_hud is PanelContainer), "bottom HUD root is not an opaque shared panel")
	_expect(bottom_hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "empty bottom HUD space ignores mouse input")
	_expect(minimap.custom_minimum_size.x >= 180.0 and minimap.custom_minimum_size.y >= 144.0, "minimap has larger minimum size")
	_expect(action_grid.custom_minimum_size.x >= 180.0 and action_grid.custom_minimum_size.y >= 144.0, "action grid has larger minimum size")
	_expect(selection_panel.custom_minimum_size.y <= 104.0, "selection panel remains compact")
	_expect(selection_panel.get_node_or_null("MarginContainer/SingleSelection") != null, "selection panel has single-selection view")
	_expect(selection_panel.get_node_or_null("MarginContainer/MultiSelection") != null, "selection panel has multi-selection view")
	_expect(selection_panel.get_node_or_null("MarginContainer/BuildingSelection") != null, "selection panel has building view")
	_expect(selection_panel.get_node_or_null("MarginContainer/SingleSelection/Details/StatusLabel") != null, "selection panel has dedicated status field")
	_expect(selection_panel.get_node_or_null("MarginContainer/SingleSelection/Details/HealthRow/HealthBar") != null, "selection panel has dedicated health field")
	_expect(selection_panel.get_node_or_null("MarginContainer/BuildingSelection/ProductionInfoBlock/BuildingProductionProgress") != null, "building view has dedicated production progress")
	_expect(selection_panel.get_node_or_null("MarginContainer/MultiSelection/TileScroll/TileRow") != null, "multi-selection view has tile row")
	_expect(selection_panel.get_node_or_null("MarginContainer/SingleSelection/Details/TeamLabel") == null, "selection panel omits debug team label")
	_expect(minimap.size.y > selection_panel.size.y, "minimap is taller than selection panel")
	_expect(action_grid.size.y > selection_panel.size.y, "action grid is taller than selection panel")
	_expect(not _controls_overlap(minimap, selection_panel), "selection panel does not overlap minimap")
	_expect(not _controls_overlap(selection_panel, action_grid), "selection panel does not overlap action grid")
	_expect(bottom_hud.size.y < root.size.y / 3.0, "bottom HUD does not consume one third of the viewport")

	var grid: GridContainer = level.get_node("UI/HudRoot/BottomHudRoot/ActionGrid/MarginContainer/GridContainer")
	_expect(grid.get_child_count() == 9, "action grid owns exactly 9 slots")
	for child in grid.get_children():
		_expect(child is Button, "action slot is a button")
	var initial_bottom_height := bottom_hud.size.y

	var hq := _find_child_by_name(level.get_node("Entities"), "TestHQ") as EntityBase
	_expect(hq != null, "player HQ spawned")
	if hq != null:
		hud.set_selected_entities([hq])
		_expect(is_equal_approx(bottom_hud.size.y, initial_bottom_height), "building selection keeps bottom HUD height fixed")
		_expect(not selection_panel.get_node("MarginContainer/SingleSelection").visible, "single-unit view is hidden for a building")
		_expect(selection_panel.get_node("MarginContainer/BuildingSelection").visible, "building view is visible for a building")
		_expect(not selection_panel.get_node("MarginContainer/MultiSelection").visible, "multi-selection view is hidden for one entity")
		var selected_label: Label = level.get_node("UI/HudRoot/BottomHudRoot/SelectionPanel/MarginContainer/BuildingSelection/BuildingInfoBlock/BuildingNameLabel")
		var status_label: Label = level.get_node("UI/HudRoot/BottomHudRoot/SelectionPanel/MarginContainer/BuildingSelection/BuildingInfoBlock/BuildingStatusLabel")
		var active_label: Label = level.get_node("UI/HudRoot/BottomHudRoot/SelectionPanel/MarginContainer/BuildingSelection/ProductionInfoBlock/BuildingProductionLabel")
		var production_bar: ProgressBar = level.get_node("UI/HudRoot/BottomHudRoot/SelectionPanel/MarginContainer/BuildingSelection/ProductionInfoBlock/BuildingProductionProgress")
		_expect(selected_label.text == "Test HQ", "selection panel shows selected building")
		_expect(status_label.text != "Status: Owned", "selection panel omits debug ownership status")
		_expect(active_label.text == "No active production", "building view shows idle production compactly")
		_expect(_grid_has_text(grid, "Train Infantry"), "action grid shows train infantry")
		_expect(_grid_has_text(grid, "Train Worker"), "action grid shows train worker")
		_expect(_grid_has_text(grid, "Set Rally Point"), "action grid shows rally command")

		var train_button := _find_grid_button(grid, "Train Infantry")
		if train_button != null:
			train_button.pressed.emit()
			_expect(wallet == null or wallet.get_amount(&"crystals") == 450, "train command spends crystals")
			_expect(crystals_label.text == "Crystals: 450", "top resource display refreshes after training")
			_expect(active_label.text == "Producing: Train Infantry", "building view shows active production")
			_expect(production_bar.visible, "building view shows progress only for active production")

	var catalog := EntityCatalogScript.new()
	var infantry := catalog.spawn_entity(&"infantry") as EntityBase
	var scout_buggy := catalog.spawn_entity(&"scout_buggy") as EntityBase
	if infantry != null:
		level.get_node("Entities").add_child(infantry)
		hud.set_selected_entities([infantry])
		_expect(selection_panel.get_node("MarginContainer/SingleSelection").visible, "single-unit view is visible for infantry")
		_expect(not selection_panel.get_node("MarginContainer/BuildingSelection").visible, "building view is hidden for infantry")
		var unit_name: Label = level.get_node("UI/HudRoot/BottomHudRoot/SelectionPanel/MarginContainer/SingleSelection/Details/SelectedEntityLabel")
		_expect(unit_name.text == "Infantry", "single-unit view shows infantry name")
	if infantry != null and scout_buggy != null:
		level.get_node("Entities").add_child(scout_buggy)
		hud.set_selected_entities([infantry, scout_buggy])
		_expect(selection_panel.get_node("MarginContainer/MultiSelection").visible, "multi-selection view is visible for multiple units")
		_expect(not selection_panel.get_node("MarginContainer/SingleSelection").visible, "single-unit view is hidden for multiple units")
		_expect(not selection_panel.get_node("MarginContainer/BuildingSelection").visible, "building view is hidden for multiple units")
		var multi_header: Label = level.get_node("UI/HudRoot/BottomHudRoot/SelectionPanel/MarginContainer/MultiSelection/MultiHeaderLabel")
		var tile_row: HBoxContainer = level.get_node("UI/HudRoot/BottomHudRoot/SelectionPanel/MarginContainer/MultiSelection/TileScroll/TileRow")
		_expect(multi_header.text.begins_with("2 units |"), "multi-selection view shows unit count")
		_expect(tile_row.get_child_count() == 2, "multi-selection view shows unit tiles")

	hud.set_selected_entities([])
	_expect(is_equal_approx(bottom_hud.size.y, initial_bottom_height), "empty selection keeps bottom HUD height fixed")
	var disabled_count := 0
	for child in grid.get_children():
		var button := child as Button
		if button != null and button.disabled and button.text == "":
			disabled_count += 1
	_expect(disabled_count == 9, "empty selection leaves 9 blank disabled slots")

	level.free()
	if _failures == 0:
		print("v42 HUD layout refactor verification passed.")
		quit(0)
	else:
		push_error("v42 HUD layout refactor verification failed with %d failure(s)." % _failures)
		quit(1)

func _find_child_by_name(parent: Node, child_name: String) -> Node:
	for child in parent.get_children():
		if child.name == child_name:
			return child
	return null

func _grid_has_text(grid: GridContainer, text: String) -> bool:
	return _find_grid_button(grid, text) != null

func _find_grid_button(grid: GridContainer, text: String) -> Button:
	for child in grid.get_children():
		var button := child as Button
		if button != null and button.text == text:
			return button
	return null

func _controls_overlap(left_control: Control, right_control: Control) -> bool:
	var left_rect := Rect2(left_control.global_position, left_control.size)
	var right_rect := Rect2(right_control.global_position, right_control.size)
	return left_rect.intersects(right_rect)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)
