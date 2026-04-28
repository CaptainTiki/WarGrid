extends EditorBrushTool
class_name MaterialPaintBrushTool

@export_range(0, 3, 1) var selected_material_channel := 0
@export var stamp_amount_multiplier := 0.18

func _on_stroke_begin(terrain: Terrain, _local_center: Vector3, _lowering: bool) -> void:
	terrain.begin_material_paint_brush_stroke()

func _on_stroke_end(terrain: Terrain) -> void:
	terrain.finish_material_paint_brush_stroke()

func _apply_stamp(terrain: Terrain, local_center: Vector3, _lowering: bool = false) -> void:
	terrain.apply_material_paint_brush(local_center, brush_data.radius, brush_data.strength * stamp_amount_multiplier, brush_data.falloff, selected_material_channel)
