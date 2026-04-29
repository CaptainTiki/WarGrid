extends Resource
class_name TerrainMapResource

# Map metadata
@export var map_name: String = "Untitled Map"
@export var chunk_size_meters: int = 32
@export var cell_size: float = 1.0
@export var playable_chunks: Vector2i = Vector2i(2, 2)
@export var border_chunks: int = 2

# Authored terrain height data
@export var base_heights: PackedFloat32Array

# Authored terrain material blend data
@export var splat_map: Image

# Authored playable-area gameplay data
@export var walkable_data: PackedByteArray
@export var buildable_data: PackedByteArray
@export var fow_height_data: PackedByteArray

# Authored scenario entity placement data
@export var entity_placements: Array[Resource] = []
