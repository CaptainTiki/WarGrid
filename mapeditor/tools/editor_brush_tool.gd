extends Node
class_name EditorBrushTool

@export var brush_data := TerrainBrushData.new()
@export_range(0.1, 1.0, 0.05) var stamp_spacing_radius_fraction := 0.35

var _stroke_active := false
var _last_stamp_position := Vector3.ZERO

func begin_stroke(terrain: Terrain, local_center: Vector3, lowering: bool = false) -> void:
	if terrain != null:
		_on_stroke_begin(terrain, local_center, lowering)
	_stroke_active = true
	_last_stamp_position = local_center
	_apply_stamp(terrain, local_center, lowering)

func apply_stroke_sample(terrain: Terrain, local_center: Vector3, lowering: bool = false) -> void:
	if terrain == null or not _stroke_active:
		return
	var spacing : float = max(brush_data.radius * stamp_spacing_radius_fraction, terrain.cell_size)
	if Vector2(_last_stamp_position.x, _last_stamp_position.z).distance_to(Vector2(local_center.x, local_center.z)) < spacing:
		return
	_last_stamp_position = local_center
	_apply_stamp(terrain, local_center, lowering)

func end_stroke(terrain: Terrain) -> void:
	if terrain != null:
		_on_stroke_end(terrain)
	_stroke_active = false

# ── Virtual interface ─────────────────────────────────────────────────────────

func _on_stroke_begin(terrain: Terrain, local_center: Vector3, lowering: bool) -> void:
	pass

func _on_stroke_end(terrain: Terrain) -> void:
	pass

func _apply_stamp(terrain: Terrain, local_center: Vector3, lowering: bool = false) -> void:
	pass
