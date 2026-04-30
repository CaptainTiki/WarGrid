extends RefCounted
class_name OccupancyGrid

var occupied_cells: Dictionary = {}

func is_occupied(cell: Vector2i) -> bool:
	return occupied_cells.has(cell)

func get_owner(cell: Vector2i) -> Node:
	return occupied_cells.get(cell) as Node

func occupy_cells(cells: Array[Vector2i], owner: Node) -> bool:
	if owner == null:
		return false
	for cell in cells:
		var existing := get_owner(cell)
		if existing != null and is_instance_valid(existing) and existing != owner:
			push_warning("Occupancy cell %s is already occupied by %s." % [cell, existing.name])
			return false
	for cell in cells:
		occupied_cells[cell] = owner
	return true

func clear_cells(cells: Array[Vector2i], owner: Node = null) -> void:
	for cell in cells:
		if not occupied_cells.has(cell):
			continue
		if owner != null and get_owner(cell) != owner:
			continue
		occupied_cells.erase(cell)

func clear_owner(owner: Node) -> void:
	if owner == null:
		return
	for cell in occupied_cells.keys():
		if get_owner(cell) == owner:
			occupied_cells.erase(cell)

func clear() -> void:
	occupied_cells.clear()
