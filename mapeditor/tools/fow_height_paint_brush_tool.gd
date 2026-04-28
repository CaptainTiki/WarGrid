extends EditorBrushTool
class_name FowHeightPaintBrushTool

@export_range(0, 3, 1) var selected_fow_height := 0

func _on_stroke_begin(terrain: Terrain, _local_center: Vector3, _lowering: bool) -> void:
	terrain.begin_fow_height_paint_brush_stroke()

func _on_stroke_end(terrain: Terrain) -> void:
	terrain.finish_fow_height_paint_brush_stroke()

func _apply_stamp(terrain: Terrain, local_center: Vector3, _lowering: bool = false) -> void:
	terrain.apply_fow_height_paint_brush(local_center, brush_data.radius, selected_fow_height)
