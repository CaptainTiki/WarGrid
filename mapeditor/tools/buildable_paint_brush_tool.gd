extends EditorBrushTool
class_name BuildablePaintBrushTool

@export var selected_buildable_value := TerrainMapData.Buildable.OPEN

func _on_stroke_begin(terrain: Terrain, _local_center: Vector3, _lowering: bool) -> void:
	terrain.begin_buildable_paint_brush_stroke()

func _on_stroke_end(terrain: Terrain) -> void:
	terrain.finish_buildable_paint_brush_stroke()

func _apply_stamp(terrain: Terrain, local_center: Vector3, _lowering: bool = false) -> void:
	terrain.apply_buildable_paint_brush(local_center, brush_data.radius, selected_buildable_value)
