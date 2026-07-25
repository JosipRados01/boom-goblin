extends Node3D

signal exploded

@export var fuse_time := 30.0
@export var blast_radius := 4.0

@onready var _fuse: CSGCylinder3D = $CSGCylinder3D2

var _elapsed := 0.0
var _burning := true
var _fuse_top_y: float


func _ready() -> void:
	_fuse_top_y = _fuse.position.y


func _process(delta: float) -> void:
	if not _burning:
		return
	_elapsed += delta
	var burnt := clampf(_elapsed / fuse_time, 0.0, 9.0)
	# The sparks are a child of the fuse, so they ride down with it.
	_fuse.position.y = _fuse_top_y - _fuse.height * burnt
	if burnt >= 1.0:
		detonate()


func time_left() -> float:
	return maxf(fuse_time - _elapsed, 0.0)


func defuse() -> void:
	_burning = false
	$CSGCylinder3D2/GPUParticles3D.emitting = false


func detonate() -> void:
	if not _burning:
		return
	_burning = false
	_fuse.visible = false
	_spawn_fx()
	exploded.emit()


func _spawn_fx() -> void:
	var fx := Node3D.new()
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position

	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.6, 0.15, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = mat
	flash.mesh = sphere
	fx.add_child(flash)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.3)
	light.light_energy = 10.0
	light.omni_range = blast_radius * 3.0
	fx.add_child(light)

	var debris := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.spread = 180.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 9.0
	pm.gravity = Vector3(0, -9.0, 0)
	debris.process_material = pm
	var grain := SphereMesh.new()
	grain.radius = 0.05
	grain.height = 0.1
	var grain_mat := StandardMaterial3D.new()
	grain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grain_mat.albedo_color = Color(1.0, 0.55, 0.1)
	grain.material = grain_mat
	debris.draw_pass_1 = grain
	debris.one_shot = true
	debris.explosiveness = 1.0
	debris.amount = 80
	debris.lifetime = 0.9
	debris.emitting = true
	fx.add_child(debris)

	var tw := fx.create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "scale", Vector3.ONE * blast_radius * 2.0, 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tw.tween_property(light, "light_energy", 0.0, 0.55)
	get_tree().create_timer(1.5).timeout.connect(fx.queue_free)
