extends Node
class_name SelectionComponent

signal selection_changed(selected_entities: Array[EntityBase])

var _selected_entities: Array[EntityBase] = []

func select(entity: EntityBase) -> void:
	select_single(entity)

func deselect() -> void:
	clear_selection()

func select_single(entity: EntityBase) -> void:
	if entity == null:
		clear_selection()
		return
	select_many([entity])

func select_many(entities: Array[EntityBase]) -> void:
	var unique_entities: Array[EntityBase] = []
	for entity in entities:
		if is_instance_valid(entity) and entity != null and not unique_entities.has(entity):
			unique_entities.append(entity)

	prune_invalid_selection()
	var changed := unique_entities.size() != _selected_entities.size()
	for entity in _selected_entities:
		if not unique_entities.has(entity):
			entity.set_selected(false)
			changed = true
	for entity in unique_entities:
		if not _selected_entities.has(entity):
			entity.set_selected(true)
			changed = true

	if not changed:
		return
	_selected_entities = unique_entities
	_emit_selection_changed()

func clear_selection() -> void:
	prune_invalid_selection()
	if _selected_entities.is_empty():
		return
	for entity in _selected_entities:
		entity.set_selected(false)
	_selected_entities.clear()
	_emit_selection_changed()

func add_to_selection(entity: EntityBase) -> void:
	prune_invalid_selection()
	if entity == null or _selected_entities.has(entity):
		return
	var next_selection := _selected_entities.duplicate()
	next_selection.append(entity)
	select_many(next_selection)

func remove_from_selection(entity: EntityBase) -> void:
	prune_invalid_selection()
	if entity == null or not _selected_entities.has(entity):
		return
	var next_selection := _selected_entities.duplicate()
	next_selection.erase(entity)
	select_many(next_selection)

func is_selected(entity: EntityBase) -> bool:
	prune_invalid_selection()
	return _selected_entities.has(entity)

func has_selection() -> bool:
	prune_invalid_selection()
	return not _selected_entities.is_empty()

func get_selected() -> EntityBase:
	return get_primary_selected_entity()

func get_selected_entities() -> Array[EntityBase]:
	prune_invalid_selection()
	return _selected_entities.duplicate()

func get_primary_selected_entity() -> EntityBase:
	prune_invalid_selection()
	if _selected_entities.is_empty():
		return null
	return _selected_entities[0]

func prune_invalid_selection() -> void:
	var changed := false
	for i in range(_selected_entities.size() - 1, -1, -1):
		if not is_instance_valid(_selected_entities[i]) or _selected_entities[i] == null:
			_selected_entities.remove_at(i)
			changed = true
	if changed:
		_emit_selection_changed()

func _emit_selection_changed() -> void:
	var selected_entities: Array[EntityBase] = []
	for entity in _selected_entities:
		if is_instance_valid(entity) and entity != null:
			selected_entities.append(entity)
	selection_changed.emit(selected_entities)
