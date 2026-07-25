extends Node3D
## Hovers side to side along its local X axis — fast but predictable.
## Tiny sense radius; darts at the goblin only when he gets very close.
## No collision on purpose: it is a ghost.

## Which axis the lane runs along. Rotating the node aims it too, but the ghost
## turns to face where it is flying, so the rotation you set vanishes on frame
## one — pick the axis here instead.
@export_enum("X", "Z") var patrol_axis := 0
@export var patrol_span := 22.0
@export var patrol_speed := 4.5
@export var chase_speed := 4.2
@export var detect_range := 3.0
@export var catch_range := 0.9
@export var turn_speed := 10.0

@onready var model: Node3D = $Model
@onready var anim: AnimationPlayer = $Model/AnimationPlayer

var _origin: Vector3
var _axis: Vector3
var _t := 0.0
var _player: Node3D
var _chasing := false
var _grabbed := false
var _hover_base: float
var _current_anim := ""


func _ready() -> void:
	add_to_group("no_autocol")
	_origin = global_position
	_axis = (global_basis.z if patrol_axis == 1 else global_basis.x).normalized()
	_hover_base = model.position.y
	for anim_name in ["idle", "sprint"]:
		var a := anim.get_animation(anim_name)
		if a:
			a.loop_mode = Animation.LOOP_LINEAR
	_play("idle")
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).transparency = 0.35


func _physics_process(delta: float) -> void:
	_t += delta
	model.position.y = _hover_base + sin(_t * 3.0) * 0.15
	if _grabbed:
		return
	if not _player:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if not _player:
			return

	var to_player := _player.global_position + Vector3.UP * 0.8 - global_position
	var dist := to_player.length()
	_chasing = dist < detect_range or (_chasing and dist < detect_range * 1.7)

	var before := global_position
	if _chasing:
		var target := _player.global_position + Vector3.UP
		global_position = global_position.move_toward(target, chase_speed * delta)
	else:
		var k := pingpong(_t * patrol_speed, patrol_span) - patrol_span * 0.5
		global_position = global_position.move_toward(
			_origin + _axis * k, patrol_speed * 1.5 * delta
		)
	_play("sprint" if _chasing else "idle", 0.3)

	var vel := global_position - before
	var flat := Vector3(vel.x, 0.0, vel.z)
	if flat.length_squared() > 0.000001:
		rotation.y = lerp_angle(
			rotation.y, atan2(flat.x, flat.z), minf(turn_speed * delta, 1.0)
		)

	if dist < catch_range and _player.has_method("caught_by"):
		_grabbed = true
		anim.play("attack-melee-right", 0.1)
		_player.caught_by(self)


func _play(anim_name: String, blend := 0.2) -> void:
	if _current_anim == anim_name:
		return
	_current_anim = anim_name
	anim.play(anim_name, blend)
