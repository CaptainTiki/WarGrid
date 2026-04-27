extends Node3D
class_name TerrainChunk

var data := TerrainChunkData.new()
var map_data: TerrainMapData
var mesh_instance: MeshInstance3D
var static_body: StaticBody3D
var collision_shape: CollisionShape3D
var terrain_material: Material

func setup(chunk_coord: Vector2i, new_map_data: TerrainMapData, material: Material) -> void:
	data.chunk_coord = chunk_coord
	map_data = new_map_data
	terrain_material = material
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		add_child(mesh_instance)
	if static_body == null:
		static_body = StaticBody3D.new()
		static_body.name = "TerrainPickBody"
		add_child(static_body)
	static_body.add_to_group("terrain_pick_colliders")
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		static_body.add_child(collision_shape)
	mesh_instance.material_override = terrain_material
	rebuild_mesh()
	rebuild_collider()

func mark_dirty() -> void:
	data.dirty = true

func rebuild() -> void:
	rebuild_mesh()
	rebuild_collider()
	data.dirty = false

func rebuild_mesh(pretty_normals: bool = false) -> void:
	if map_data == null:
		return
	mesh_instance.mesh = TerrainMeshBuilder.build_chunk_mesh(map_data, data.chunk_coord, pretty_normals)
	if terrain_material != null and mesh_instance.mesh.get_surface_count() > 0:
		mesh_instance.mesh.surface_set_material(0, terrain_material)
		mesh_instance.material_override = terrain_material

func rebuild_collider() -> void:
	if map_data == null:
		return
	collision_shape.shape = TerrainColliderBuilder.build_chunk_collision_shape(map_data, data.chunk_coord)
