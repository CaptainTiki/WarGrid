class_name TerrainMaterialController

const _Albedo0 := preload("res://assets/textures/terrain/grass.png")
const _Albedo1 := preload("res://assets/textures/terrain/dirt.png")
const _Albedo2 := preload("res://assets/textures/terrain/rock.png")
const _Albedo3 := preload("res://assets/textures/terrain/sand.png")

var terrain_material: ShaderMaterial
var overlay_material: StandardMaterial3D
var _shader_material: ShaderMaterial
var _splat_texture: ImageTexture

func setup(material_texture_scale: float) -> void:
	terrain_material = _create_terrain_material(material_texture_scale)
	overlay_material = _create_overlay_material()

func update_splat_texture(splat_map: Image) -> void:
	if splat_map == null or _shader_material == null:
		return
	if _splat_texture == null or _splat_texture.get_width() != splat_map.get_width() or _splat_texture.get_height() != splat_map.get_height():
		_splat_texture = ImageTexture.create_from_image(splat_map)
	else:
		_splat_texture.update(splat_map)
	_shader_material.set_shader_parameter("splat_texture", _splat_texture)

func _create_terrain_material(material_texture_scale: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_name = "TerrainSplatMaterial"
	material.shader = _create_terrain_shader()
	_shader_material = material
	material.set_shader_parameter("material_0_albedo", _Albedo0)
	material.set_shader_parameter("material_1_albedo", _Albedo1)
	material.set_shader_parameter("material_2_albedo", _Albedo2)
	material.set_shader_parameter("material_3_albedo", _Albedo3)
	material.set_shader_parameter("material_texture_scale", material_texture_scale)
	return material

func _create_terrain_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;

uniform sampler2D splat_texture : filter_linear, repeat_disable;
uniform sampler2D material_0_albedo : source_color, filter_linear, repeat_enable;
uniform sampler2D material_1_albedo : source_color, filter_linear, repeat_enable;
uniform sampler2D material_2_albedo : source_color, filter_linear, repeat_enable;
uniform sampler2D material_3_albedo : source_color, filter_linear, repeat_enable;
uniform float material_texture_scale = 8.0;

void fragment() {
	vec4 weights = texture(splat_texture, UV);
	float total_weight = max(weights.r + weights.g + weights.b + weights.a, 0.0001);
	weights /= total_weight;
	vec2 tiled_uv = UV * material_texture_scale;
	vec3 blended = texture(material_0_albedo, tiled_uv).rgb * weights.r;
	blended += texture(material_1_albedo, tiled_uv).rgb * weights.g;
	blended += texture(material_2_albedo, tiled_uv).rgb * weights.b;
	blended += texture(material_3_albedo, tiled_uv).rgb * weights.a;
	ALBEDO = blended;
	ROUGHNESS = 0.9;
}
"""
	return shader

func _create_overlay_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "TerrainGameplayOverlayMaterial"
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	return material
