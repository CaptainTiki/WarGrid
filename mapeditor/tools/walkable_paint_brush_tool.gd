extends EditorBrushTool
class_name WalkablePaintBrushTool

@export var selected_walkable_value := TerrainMapData.Walkable.ALL

func _on_stroke_begin(terrain: Terrain, _local_center: Vector3, _lowering: bool) -> void:
	terrain.begin_walkable_paint_brush_stroke()

func _on_stroke_end(terrain: Terrain) -> void:
	terrain.finish_walkable_paint_brush_stroke()

func _apply_stamp(terrain: Terrain, local_center: Vector3, _lowering: bool = false) -> void:
	terrain.apply_walkable_paint_brush(local_center, brush_data.radius, selected_walkable_value)
