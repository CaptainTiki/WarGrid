extends SceneTree

const InfantryScene := preload("res://game/entities/units/infantry/infantry.tscn")
const HostileDummyUnitScene := preload("res://game/entities/units/hostile_dummy/hostile_dummy_unit.tscn")
const CommandPanelScene := preload("res://ui/command_panel/command_panel.tscn")

var _failures := 0
var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run()
	return true

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)

	var infantry := InfantryScene.instantiate() as EntityBase
	var enemy := HostileDummyUnitScene.instantiate() as EntityBase
	world.add_child(infantry)
	world.add_child(enemy)
	infantry.global_position = Vector3.ZERO
	enemy.global_position = Vector3(3.0, 0.0, 0.0)
	enemy.team_id = 2

	var commands := infantry.get_available_commands()
	_expect(infantry.has_command(&"attack"), "scene infantry has attack command")
	_expect(commands.size() == 3, "scene infantry exposes three commands")

	var panel = CommandPanelScene.instantiate()
	root.add_child(panel)
	var selected: Array[EntityBase] = [infantry]
	panel.set_selected_entities(selected)
	_expect(panel._command_list.get_child_count() == 3, "command panel shows infantry commands")

	var combat := infantry.get_component(&"CombatComponent") as CombatComponent
	_expect(combat != null, "scene infantry has combat component")
	combat.scan_interval = 0.1
	combat.acquisition_range = 6.0
	combat.attack_range = 6.0
	combat._physics_process(0.1)
	_expect(combat.current_target == enemy, "scene infantry auto-acquires nearby enemy")

	combat.clear_attack_target(true)
	_expect(infantry.execute_command(&"attack", {"target_entity": enemy}), "scene infantry attack command accepts enemy")
	_expect(combat.current_target == enemy, "scene infantry command attack stores target")

	world.free()
	panel.free()
	if _failures == 0:
		print("v31 scene combat wiring verification passed.")
		quit(0)
	else:
		push_error("v31 scene combat wiring verification failed with %d failure(s)." % _failures)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)
