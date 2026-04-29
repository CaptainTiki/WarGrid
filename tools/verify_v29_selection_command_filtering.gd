extends SceneTree

const EntityBaseScript := preload("res://game/entities/entity_base.gd")
const CommandComponentScript := preload("res://game/entities/components/command_component.gd")
const HealthComponentScript := preload("res://game/entities/components/health_component.gd")
const MoveCommandScript := preload("res://game/entities/commands/move_command.gd")
const StopCommandScript := preload("res://game/entities/commands/stop_command.gd")
const AttackCommandScript := preload("res://game/entities/commands/attack_command.gd")
const CommandPanelScene := preload("res://ui/command_panel/command_panel.tscn")
const SelectionComponentScript := preload("res://level/components/selection_component.gd")

var _failures := 0
var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run()
	return true

func _run() -> void:
	var panel = CommandPanelScene.instantiate()
	root.add_child(panel)

	var infantry = _make_entity("Infantry", 1, true, true)
	var scout_bike = _make_entity("Scout Bike", 1, true, true)
	var enemy_hq = _make_entity("Enemy Test HQ", 2, true, false)
	var enemy_unit = _make_entity("Enemy Dummy Unit", 2, true, false)
	var neutral_dummy = _make_entity("Neutral Dummy", 0, true, false)
	root.add_child(infantry)
	root.add_child(scout_bike)
	root.add_child(enemy_hq)
	root.add_child(enemy_unit)
	root.add_child(neutral_dummy)

	panel.set_selected_entities(_entity_array([enemy_hq]))
	_expect(panel._get_commandable_selection().is_empty(), "enemy-only selection has no commandable entities")
	_expect(panel._command_list.get_child_count() == 0, "enemy-only selection shows no command buttons")
	_expect(panel._team_label.text == "Team: Enemy", "enemy scan shows team")
	_expect(panel._status_label.text == "Status: Hostile", "enemy scan shows hostile status")

	panel.set_selected_entities(_entity_array([enemy_unit]))
	_expect(panel._get_commandable_selection().is_empty(), "enemy unit selection has no commandable entities")
	_expect(panel._command_list.get_child_count() == 0, "enemy unit selection shows no command buttons")
	_expect(panel._team_label.text == "Team: Enemy", "enemy unit scan shows team")
	_expect(panel._status_label.text == "Status: Hostile", "enemy unit scan shows hostile status")

	panel.set_selected_entities(_entity_array([neutral_dummy]))
	_expect(panel._get_commandable_selection().is_empty(), "neutral-only selection has no commandable entities")
	_expect(panel._command_list.get_child_count() == 0, "neutral-only selection shows no command buttons")
	_expect(panel._status_label.text == "Status: Neutral", "neutral scan shows neutral status")

	panel.set_selected_entities(_entity_array([infantry]))
	_expect(panel._get_commandable_selection().size() == 1, "owned single selection is commandable")
	_expect(panel._command_list.get_child_count() == 3, "owned single selection shows command buttons")
	_expect(panel.get_node_or_null("MarginContainer/VBoxContainer/CommandScroll") != null, "command list is inside scroll container")
	_expect(panel._status_label.text == "Status: Owned", "owned scan shows owned status")

	panel.set_selected_entities(_entity_array([infantry, scout_bike, enemy_hq]))
	_expect(panel._get_commandable_selection().size() == 2, "mixed selection ignores enemy for commandable set")
	_expect(panel._command_list.get_child_count() == 3, "mixed selection keeps common owned commands")
	_expect(panel._selection_count_label.text == "Selected: 3 | Commandable: 2 | Non-commandable: 1", "mixed selection shows counts")

	var selection = SelectionComponentScript.new()
	root.add_child(selection)
	var updates: Array = []
	selection.selection_changed.connect(func(selected_entities: Array[EntityBase]) -> void:
		updates.append(selected_entities.size())
	)
	selection.select_single(infantry)
	_expect(selection.has_selection(), "selection component selects living infantry")
	(infantry.get_health_component() as HealthComponent).apply_damage(999.0)
	_expect(not selection.has_selection(), "dead selected infantry is removed from selection")
	_expect(not updates.is_empty() and updates[updates.size() - 1] == 0, "selection changed emits after selected death")

	if _failures == 0:
		print("v29 selection command filtering verification passed.")
		quit(0)
	else:
		push_error("v29 selection command filtering verification failed with %d failure(s)." % _failures)
		quit(1)

func _make_entity(entity_name: String, team_id: int, with_health: bool, with_commands: bool):
	var entity = EntityBaseScript.new()
	entity.name = entity_name
	entity.display_name = entity_name
	entity.team_id = team_id

	var components := Node.new()
	components.name = "Components"
	entity.add_child(components)

	if with_commands:
		var command_component = CommandComponentScript.new()
		command_component.name = "CommandComponent"
		command_component.entity_parent = NodePath("../..")
		command_component.commands.append(MoveCommandScript.new())
		command_component.commands.append(StopCommandScript.new())
		command_component.commands.append(AttackCommandScript.new())
		components.add_child(command_component)

	if with_health:
		var health_component = HealthComponentScript.new()
		health_component.name = "HealthComponent"
		health_component.entity_parent = NodePath("../..")
		health_component.max_health = 100.0
		components.add_child(health_component)

	return entity

func _entity_array(values: Array) -> Array[EntityBase]:
	var entities: Array[EntityBase] = []
	for value in values:
		entities.append(value)
	return entities

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)
