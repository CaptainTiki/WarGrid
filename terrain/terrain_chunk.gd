extends Node3D
class_name TerrainChunk

var data := TerrainChunkData.new()
var map_data: TerrainMapData
var mesh_instance: MeshInstance3D

func setup(chunk_coord: Vector2i, new_map_data: TerrainMapData, material: Material) -> void:
	data.chunk_coord = chunk_coord
	map_data = new_map_data
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		add_child(mesh_instance)
	mesh_instance.material_override = material
	rebuild()

func mark_dirty() -> void:
	data.dirty = true

func rebuild() -> void:
	if map_data == null:
		return
	mesh_instance.mesh = TerrainMeshBuilder.build_chunk_mesh(map_data, data.chunk_coord)
	data.dirty = false
