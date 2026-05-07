@tool
extends Node3D

@export_group("Fire")
@export var emitting: bool = true:
	set(value):
		emitting = value
		_apply_settings()

@export_group("Flicker")
@export var light_flicker: bool = true:
	set(value):
		light_flicker = value
		_apply_settings()
@export_range(0.0, 2.0, 0.01) var flicker_strength: float = 1.0:
	set(value):
		flicker_strength = maxf(value, 0.0)
		_apply_settings()

@export_group("Light Driver")
@export_range(0.0, 16.0, 0.05) var light_peak_energy: float = 5.4
@export_range(0.0, 16.0, 0.05) var light_peak_range: float = 5.6
@export var light_hot_color: Color = Color(1.0, 0.82, 0.38, 1.0)
@export_range(0.1, 24.0, 0.1) var spark_flash_rate: float = 8.0
@export_range(0.0, 1.0, 0.01) var spark_flash_chance: float = 0.42
@export_range(0.005, 0.2, 0.001) var spark_flash_width: float = 0.055
@export_range(0.0, 2.5, 0.01) var spark_flash_strength: float = 1.0

@export_group("Embers")
@export_range(0.1, 3.0, 0.01) var ember_size: float = 1.0:
	set(value):
		ember_size = maxf(value, 0.1)
		_apply_ember_settings()

var _flames: Array[MeshInstance3D] = []
var _flame_materials: Array[ShaderMaterial] = []
var _base_flame_scales: Array[Vector3] = []
var _base_flame_positions: Array[Vector3] = []
var _base_flame_mesh_heights: Array[float] = []
var _base_intensities: Array[float] = []
var _embers: GPUParticles3D
var _ember_process_material: ParticleProcessMaterial
var _ember_quad_mesh: QuadMesh
var _glow_light: OmniLight3D
var _smoke_plume: Node
var _ground_glow: MeshInstance3D

var _base_ember_ratio: float = 1.0
var _base_ember_scale_min: float = 1.0
var _base_ember_scale_max: float = 1.0
var _base_ember_quad_size: Vector2 = Vector2.ONE
var _base_light_energy: float = 1.0
var _base_light_range: float = 1.0
var _base_light_color: Color = Color(1.0, 0.56, 0.24, 1.0)
var _base_ground_glow_scale: Vector3 = Vector3.ONE
var _base_state_ready: bool = false


func _ready() -> void:
	_cache_nodes()
	_capture_base_state()
	_apply_settings()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not emitting or not light_flicker or flicker_strength <= 0.0:
		return

	_update_live_fire_state(Time.get_ticks_msec() * 0.001)


func _cache_nodes() -> void:
	_flames.clear()
	_flame_materials.clear()

	for flame_name in ["FlameOuterA", "FlameOuterB", "FlameCore"]:
		var flame := get_node_or_null(flame_name) as MeshInstance3D
		if flame == null:
			continue

		_flames.append(flame)
		_flame_materials.append(flame.material_override as ShaderMaterial)

	_embers = get_node_or_null("EmberParticles") as GPUParticles3D
	_ember_process_material = null
	_ember_quad_mesh = null
	if _embers != null:
		_ember_process_material = _embers.process_material as ParticleProcessMaterial
		_ember_quad_mesh = _embers.draw_pass_1 as QuadMesh

	_glow_light = get_node_or_null("GlowLight") as OmniLight3D
	_smoke_plume = get_node_or_null("BlackSmoke")
	_ground_glow = get_node_or_null("GroundGlow") as MeshInstance3D


func _capture_base_state() -> void:
	_base_flame_scales.clear()
	_base_flame_positions.clear()
	_base_flame_mesh_heights.clear()
	_base_intensities.clear()

	for index in range(_flames.size()):
		var flame := _flames[index]
		var material := _flame_materials[index]

		_base_flame_scales.append(flame.scale)
		_base_flame_positions.append(flame.position)
		_base_flame_mesh_heights.append(_get_flame_mesh_height(flame))
		_base_intensities.append(1.0 if material == null else material.get_shader_parameter("intensity"))

	if _embers != null:
		_base_ember_ratio = _embers.amount_ratio
	if _ember_process_material != null:
		_base_ember_scale_min = _ember_process_material.scale_min
		_base_ember_scale_max = _ember_process_material.scale_max
	if _ember_quad_mesh != null:
		_base_ember_quad_size = _ember_quad_mesh.size
	if _glow_light != null:
		_base_light_energy = _glow_light.light_energy
		_base_light_range = _glow_light.omni_range
		_base_light_color = _glow_light.light_color
	if _ground_glow != null:
		_base_ground_glow_scale = _ground_glow.scale

	_base_state_ready = true


func _apply_settings() -> void:
	if not is_inside_tree():
		return

	_cache_nodes()
	if not _base_state_ready or _base_flame_scales.size() != _flames.size():
		_capture_base_state()
	_apply_ember_settings()

	for flame in _flames:
		flame.visible = emitting

	if _ground_glow != null:
		_ground_glow.visible = emitting
	if _glow_light != null:
		_glow_light.visible = emitting
	if _embers != null:
		_embers.emitting = emitting
	if _smoke_plume != null:
		_smoke_plume.set("emitting", emitting)

	if not emitting:
		_restore_base_state()
		set_process(false)
		return

	if light_flicker and flicker_strength > 0.0:
		if Engine.is_editor_hint():
			_restore_base_state()
		else:
			_update_live_fire_state(Time.get_ticks_msec() * 0.001)
	else:
		_restore_base_state()

	set_process(light_flicker and flicker_strength > 0.0 and not Engine.is_editor_hint())


func _restore_base_state() -> void:
	for index in range(_flames.size()):
		_flames[index].scale = _base_flame_scales[index]
		if index < _base_flame_positions.size():
			_flames[index].position = _base_flame_positions[index]

		var material := _flame_materials[index]
		if material != null and index < _base_intensities.size():
			material.set_shader_parameter("intensity", _base_intensities[index])

	if _embers != null:
		_embers.amount_ratio = _base_ember_ratio
	if _glow_light != null:
		_glow_light.light_energy = _base_light_energy
		_glow_light.omni_range = _base_light_range
		_glow_light.light_color = _base_light_color
	if _ground_glow != null:
		_ground_glow.scale = _base_ground_glow_scale


func _apply_ember_settings() -> void:
	if not is_inside_tree():
		return

	if _embers == null:
		_cache_nodes()

	if _ember_process_material != null:
		_ember_process_material.scale_min = _base_ember_scale_min * ember_size
		_ember_process_material.scale_max = _base_ember_scale_max * ember_size

	if _ember_quad_mesh != null:
		_ember_quad_mesh.size = _base_ember_quad_size * ember_size


func _update_live_fire_state(time_sec: float) -> void:
	var strength := flicker_strength

	var wave: float = 0.92
	wave += sin(time_sec * 4.8) * 0.08 * strength
	wave += sin(time_sec * 9.1 + 0.7) * 0.04 * strength
	wave += sin(time_sec * 15.3 + 1.6) * 0.02 * strength

	var lick: float = pow(maxf(sin(time_sec * 2.05 + 0.35), 0.0), 4.0) * 0.22 * strength
	var dip: float = pow(maxf(sin(time_sec * 1.65 + 2.1), 0.0), 6.0) * 0.12 * strength
	var spark_flash := _spark_flash(time_sec) * strength

	var height_ratio := clampf(wave + lick - dip, 0.78, 1.22)
	var width_ratio := clampf(0.96 + (height_ratio - 0.92) * 0.24 - dip * 0.08, 0.84, 1.08)

	if _flames.size() > 0:
		_set_flame_anchored_scale(0, _base_flame_scales[0] * Vector3(width_ratio, height_ratio, width_ratio))
	if _flames.size() > 1:
		_set_flame_anchored_scale(1, _base_flame_scales[1] * Vector3(width_ratio * 0.96, height_ratio * 1.02, width_ratio * 0.96))
	if _flames.size() > 2:
		_set_flame_anchored_scale(2, _base_flame_scales[2] * Vector3(width_ratio * 0.92, height_ratio * 1.08 + lick * 0.08, width_ratio * 0.92))

	for index in range(_flame_materials.size()):
		var material := _flame_materials[index]
		if material == null:
			continue

		var intensity := _base_intensities[index] * (0.94 + (height_ratio - 0.92) * 0.9 + lick * 0.35)
		if index == 2:
			intensity *= 1.08
		material.set_shader_parameter("intensity", intensity)

	if _embers != null:
		_embers.amount_ratio = clampf(_base_ember_ratio * (0.76 + (height_ratio - 0.92) * 0.95 + lick * 0.5 + spark_flash * 0.16), 0.2, 1.0)

	if _glow_light != null:
		var body_light := clampf(0.5 + (height_ratio - 0.92) * 1.2 + lick * 0.34 - dip * 0.22, 0.0, 1.0)
		var flash_light := clampf(body_light + spark_flash, 0.0, 1.0)
		var peak_energy := maxf(light_peak_energy, _base_light_energy)
		var peak_range := maxf(light_peak_range, _base_light_range)
		var color_mix := clampf((height_ratio - 0.9) * 0.9 + lick * 0.3 + spark_flash * 0.58, 0.0, 1.0)

		_glow_light.light_energy = lerpf(_base_light_energy * 0.72, peak_energy, pow(flash_light, 0.72))
		_glow_light.omni_range = lerpf(_base_light_range * 0.9, peak_range, clampf(body_light + spark_flash * 0.42, 0.0, 1.0))
		_glow_light.light_color = _base_light_color.lerp(light_hot_color, color_mix)

	if _ground_glow != null:
		var ground_ratio := clampf(0.92 + (height_ratio - 0.92) * 0.28 + lick * 0.18 + spark_flash * 0.08, 0.82, 1.18)
		_ground_glow.scale = _base_ground_glow_scale * Vector3(ground_ratio, 1.0, ground_ratio)


func _spark_flash(time_sec: float) -> float:
	if spark_flash_strength <= 0.0 or spark_flash_rate <= 0.0 or spark_flash_chance <= 0.0:
		return 0.0

	var cycle_time := time_sec * spark_flash_rate
	var cycle := floorf(cycle_time)
	var phase := cycle_time - cycle
	var active := 1.0 if _hash11(cycle + 23.0) > 1.0 - spark_flash_chance else 0.0
	if active <= 0.0:
		return 0.0

	var width := maxf(spark_flash_width, 0.001)
	var main_flash := 1.0 - _smoothstep01(clampf(phase / width, 0.0, 1.0))
	var echo_flash := 0.0
	var echo_phase := phase - width * 2.1
	if echo_phase > 0.0:
		echo_flash = (1.0 - _smoothstep01(clampf(echo_phase / (width * 1.9), 0.0, 1.0))) * 0.35

	return maxf(main_flash, echo_flash) * spark_flash_strength


func _set_flame_anchored_scale(index: int, new_scale: Vector3) -> void:
	if index >= _flames.size() or index >= _base_flame_scales.size() or index >= _base_flame_positions.size():
		return

	var flame := _flames[index]
	var base_scale := _base_flame_scales[index]
	var base_position := _base_flame_positions[index]
	var mesh_height := _base_flame_mesh_heights[index] if index < _base_flame_mesh_heights.size() else 0.0

	flame.scale = new_scale
	if mesh_height <= 0.0:
		flame.position = base_position
		return

	var base_half_height := mesh_height * base_scale.y * 0.5
	var new_half_height := mesh_height * new_scale.y * 0.5
	flame.position = base_position + Vector3(0.0, new_half_height - base_half_height, 0.0)


func _get_flame_mesh_height(flame: MeshInstance3D) -> float:
	var quad := flame.mesh as QuadMesh
	if quad != null:
		return quad.size.y
	return 0.0


func _hash11(value: float) -> float:
	return fposmod(sin(value * 127.1) * 43758.5453123, 1.0)


func _smoothstep01(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)
