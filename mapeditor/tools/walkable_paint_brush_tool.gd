extends Node
class_name WalkablePaintBrushTool

@export var brush_data := TerrainBrushData.new()
@export var selected_walkable_value := TerrainMapData.Walkable.ALL
@export_range(0.1, 1.0, 0.05) var stamp_spacing_radius_fraction := 0.35

var _stroke_active := false
var _last_stamp_position := Vector3.ZERO

func begin_stroke(terrain: Terrain, local_center: Vector3) -> void:
	_stroke_active = true
	_last_stamp_position = local_center
	_apply_stamp(terrain, local_center)

func apply_stroke_sample(terrain: Terrain, local_center: Vector3) -> void:
	if terrain == null or not _stroke_active:
		return

	var spacing : float = max(brush_data.radius * stamp_spacing_radius_fraction, terrain.cell_size)
	var last_xz := Vector2(_last_stamp_position.x, _last_stamp_position.z)
	var current_xz := Vector2(local_center.x, local_center.z)
	if last_xz.distance_to(current_xz) < spacing:
		return

	_last_stamp_position = local_center
	_apply_stamp(terrain, local_center)

func end_stroke(terrain: Terrain) -> void:
	if terrain != null:
		terrain.finish_walkable_paint_brush_stroke()
	_stroke_active = false

func _apply_stamp(terrain: Terrain, local_center: Vector3) -> void:
	terrain.apply_walkable_paint_brush(
		local_center,
		brush_data.radius,
		selected_walkable_value
	)
