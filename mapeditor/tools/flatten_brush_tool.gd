extends Node
class_name FlattenBrushTool

@export var brush_data := TerrainBrushData.new()
@export_range(0.1, 1.0, 0.05) var stamp_spacing_radius_fraction := 0.35
@export var stamp_amount_multiplier := 0.14

var _stroke_active := false
var _last_stamp_position := Vector3.ZERO
var _target_height := 0.0

func begin_stroke(terrain: Terrain, local_center: Vector3) -> void:
	if terrain != null:
		# Capture the height at the brush center as the target
		_target_height = terrain.map_data.get_height(terrain.map_data.local_to_grid(local_center))
		terrain.begin_flatten_brush_stroke(_target_height)
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
		terrain.finish_flatten_brush_stroke()
	_stroke_active = false

func _apply_stamp(terrain: Terrain, local_center: Vector3) -> void:
	terrain.apply_flatten_brush(
		local_center,
		brush_data.radius,
		brush_data.strength * stamp_amount_multiplier,
		brush_data.falloff,
		_target_height
	)
