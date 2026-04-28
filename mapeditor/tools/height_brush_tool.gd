extends EditorBrushTool
class_name HeightBrushTool

@export var click_amount_multiplier := 0.5
@export var stamp_amount_multiplier := 0.14

func begin_stroke(terrain: Terrain, local_center: Vector3, lowering: bool = false) -> void:
	terrain.begin_height_brush_stroke()
	_stroke_active = true
	_last_stamp_position = local_center
	terrain.apply_height_brush(local_center, brush_data.radius, brush_data.strength * (-1.0 if lowering else 1.0) * click_amount_multiplier, brush_data.falloff)

func _on_stroke_end(terrain: Terrain) -> void:
	terrain.finish_height_brush_stroke()

func _apply_stamp(terrain: Terrain, local_center: Vector3, lowering: bool = false) -> void:
	terrain.apply_height_brush(local_center, brush_data.radius, brush_data.strength * (-1.0 if lowering else 1.0) * stamp_amount_multiplier, brush_data.falloff)
