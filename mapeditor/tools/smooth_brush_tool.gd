extends EditorBrushTool
class_name SmoothBrushTool

@export var stamp_amount_multiplier := 0.14

func _on_stroke_begin(terrain: Terrain, _local_center: Vector3, _lowering: bool) -> void:
	terrain.begin_smooth_brush_stroke()

func _on_stroke_end(terrain: Terrain) -> void:
	terrain.finish_smooth_brush_stroke()

func _apply_stamp(terrain: Terrain, local_center: Vector3, _lowering: bool = false) -> void:
	terrain.apply_smooth_brush(local_center, brush_data.radius, brush_data.strength * stamp_amount_multiplier, brush_data.falloff)
