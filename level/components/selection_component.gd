extends Node
class_name SelectionComponent

var _selected = null

func select(unit) -> void:
	if _selected == unit:
		return
	if _selected != null:
		_selected.set_selected(false)
	_selected = unit
	if _selected != null:
		_selected.set_selected(true)

func deselect() -> void:
	if _selected != null:
		_selected.set_selected(false)
	_selected = null

func has_selection() -> bool:
	return _selected != null

func get_selected():
	return _selected
