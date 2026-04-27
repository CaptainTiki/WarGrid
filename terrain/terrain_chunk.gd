extends Node3D
class_name TerrainChunk

const TerrainOverlayMeshBuilderScript := preload("res://terrain/terrain_overlay_mesh_builder.gd")

var data := TerrainChunkData.new()
var map_data: TerrainMapData
var mesh_instance: MeshInstance3D
var overlay_mesh_instance: MeshInstance3D
var static_body: StaticBody3D
var collision_shape: CollisionShape3D
var terrain_material: Material
var overlay_material: Material
var overlay_mode := TerrainMapData.OverlayMode.NONE
var overlay_visible := false
var overlay_normal_offset := 0.01

func setup(chunk_coord: Vector2i, new_map_data: TerrainMapData, material: Material, new_overlay_material: Material) -> void:
	data.chunk_coord = chunk_coord
	map_data = new_map_data
	terrain_material = material
	overlay_material = new_overlay_material
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		add_child(mesh_instance)
	if overlay_mesh_instance == null:
		overlay_mesh_instance = MeshInstance3D.new()
		overlay_mesh_instance.name = "OverlayMesh"
		overlay_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(overlay_mesh_instance)
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
	overlay_mesh_instance.material_override = overlay_material
	overlay_mesh_instance.visible = false
	rebuild_mesh()
	rebuild_collider()
	rebuild_overlay()

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

func set_overlay_state(enabled: bool, mode: int, normal_offset: float) -> void:
	overlay_visible = enabled
	overlay_mode = mode
	overlay_normal_offset = normal_offset
	if overlay_mesh_instance != null:
		overlay_mesh_instance.visible = overlay_visible and overlay_mode != TerrainMapData.OverlayMode.NONE

func rebuild_overlay() -> void:
	if map_data == null or overlay_mesh_instance == null:
		return
	overlay_mesh_instance.mesh = TerrainOverlayMeshBuilderScript.build_chunk_overlay_mesh(map_data, data.chunk_coord, overlay_mode, overlay_normal_offset)
	if overlay_material != null and overlay_mesh_instance.mesh.get_surface_count() > 0:
		overlay_mesh_instance.mesh.surface_set_material(0, overlay_material)
		overlay_mesh_instance.material_override = overlay_material
	overlay_mesh_instance.visible = overlay_visible and overlay_mode != TerrainMapData.OverlayMode.NONE and overlay_mesh_instance.mesh.get_surface_count() > 0

func rebuild_collider() -> void:
	if map_data == null:
		return
	collision_shape.shape = TerrainColliderBuilder.build_chunk_collision_shape(map_data, data.chunk_coord)
