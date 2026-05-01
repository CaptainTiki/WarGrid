extends SceneTree

const LevelScene := preload("res://level/level.tscn")
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
	_expect(level.get_node_or_null("UI/HudRoot/BottomBar") != null, "bottom bar exists")
	_expect(level.get_node_or_null("UI/HudRoot/BottomBar/MarginContainer/HBoxContainer/MinimapPanel") != null, "minimap panel exists")
	_expect(level.get_node_or_null("UI/HudRoot/BottomBar/MarginContainer/HBoxContainer/SelectionPanel") != null, "selection panel exists")
	_expect(level.get_node_or_null("UI/HudRoot/BottomBar/MarginContainer/HBoxContainer/ActionGrid") != null, "action grid exists")
	var old_panel := level.get_node_or_null("UI/CommandPanel")
	_expect(old_panel != null and not old_panel.visible, "old command panel is hidden")

	var crystals_label: Label = level.get_node("UI/HudRoot/TopBar/MarginContainer/HBoxContainer/ResourceDisplay/CrystalsLabel")
	var he3_label: Label = level.get_node("UI/HudRoot/TopBar/MarginContainer/HBoxContainer/ResourceDisplay/He3Label")
	_expect(crystals_label.text == "Crystals: 500", "top resource display shows crystals")
	_expect(he3_label.text == "He3: 0", "top resource display shows he3")

	var grid: GridContainer = level.get_node("UI/HudRoot/BottomBar/MarginContainer/HBoxContainer/ActionGrid/MarginContainer/GridContainer")
	_expect(grid.get_child_count() == 9, "action grid owns exactly 9 slots")
	for child in grid.get_children():
		_expect(child is Button, "action slot is a button")
	var bottom_bar: Control = level.get_node("UI/HudRoot/BottomBar")
	var initial_bottom_height := bottom_bar.size.y

	var hq := _find_child_by_name(level.get_node("Entities"), "TestHQ") as EntityBase
	_expect(hq != null, "player HQ spawned")
	if hq != null:
		hud.set_selected_entities([hq])
		_expect(is_equal_approx(bottom_bar.size.y, initial_bottom_height), "building selection keeps bottom HUD height fixed")
		var selected_label: Label = level.get_node("UI/HudRoot/BottomBar/MarginContainer/HBoxContainer/SelectionPanel/MarginContainer/VBoxContainer/SelectedEntityLabel")
		var active_label: Label = level.get_node("UI/HudRoot/BottomBar/MarginContainer/HBoxContainer/SelectionPanel/MarginContainer/VBoxContainer/ActiveProductionLabel")
		_expect(selected_label.text == "Test HQ", "selection panel shows selected building")
		_expect(active_label.text == "Active: Idle", "selection panel shows idle production")
		_expect(_grid_has_text(grid, "Train Infantry"), "action grid shows train infantry")
		_expect(_grid_has_text(grid, "Train Worker"), "action grid shows train worker")
		_expect(_grid_has_text(grid, "Set Rally Point"), "action grid shows rally command")

		var train_button := _find_grid_button(grid, "Train Infantry")
		if train_button != null:
			train_button.pressed.emit()
			_expect(wallet == null or wallet.get_amount(&"crystals") == 450, "train command spends crystals")
			_expect(crystals_label.text == "Crystals: 450", "top resource display refreshes after training")
			_expect(active_label.text == "Active: Train Infantry", "selection panel shows active production")

	hud.set_selected_entities([])
	_expect(is_equal_approx(bottom_bar.size.y, initial_bottom_height), "empty selection keeps bottom HUD height fixed")
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

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)
