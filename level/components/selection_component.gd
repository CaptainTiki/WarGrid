extends Node
class_name SelectionComponent

signal selection_changed(entity: EntityBase)

var _selected: EntityBase = null

func select(entity: EntityBase) -> void:
	if _selected == entity:
		return
	if _selected != null:
		_selected.set_selected(false)
	_selected = entity
	if _selected != null:
		_selected.set_selected(true)
	selection_changed.emit(_selected)

func deselect() -> void:
	if _selected == null:
		return
	if _selected != null:
		_selected.set_selected(false)
	_selected = null
	selection_changed.emit(null)

func has_selection() -> bool:
	return _selected != null

func get_selected() -> EntityBase:
	return _selected
