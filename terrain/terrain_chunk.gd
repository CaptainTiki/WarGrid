extends Node3D
class_name TerrainChunk

var data := TerrainChunkData.new()
var map_data: TerrainMapData
var mesh_instance: MeshInstance3D
var terrain_material: Material

func setup(chunk_coord: Vector2i, new_map_data: TerrainMapData, material: Material) -> void:
	data.chunk_coord = chunk_coord
	map_data = new_map_data
	terrain_material = material
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		add_child(mesh_instance)
	mesh_instance.material_override = terrain_material
	rebuild()

func mark_dirty() -> void:
	data.dirty = true

func rebuild() -> void:
	if map_data == null:
		return
	mesh_instance.mesh = TerrainMeshBuilder.build_chunk_mesh(map_data, data.chunk_coord)
	if terrain_material != null and mesh_instance.mesh.get_surface_count() > 0:
		mesh_instance.mesh.surface_set_material(0, terrain_material)
		mesh_instance.material_override = terrain_material
	data.dirty = false
