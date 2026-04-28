extends EditorBrushTool
class_name FlattenBrushTool

@export var stamp_amount_multiplier := 0.14

var _target_height := 0.0

func _on_stroke_begin(terrain: Terrain, local_center: Vector3, _lowering: bool) -> void:
	_target_height = terrain.map_data.get_height(terrain.map_data.local_to_grid(local_center))
	terrain.begin_flatten_brush_stroke(_target_height)

func _on_stroke_end(terrain: Terrain) -> void:
	terrain.finish_flatten_brush_stroke()

func _apply_stamp(terrain: Terrain, local_center: Vector3, _lowering: bool = false) -> void:
	terrain.apply_flatten_brush(local_center, brush_data.radius, brush_data.strength * stamp_amount_multiplier, brush_data.falloff, _target_height)
