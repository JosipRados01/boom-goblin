extends CharacterBody3D
## Patrols between its spawn point and spawn + patrol_offset. Sees the goblin
## in a cone (blocked by walls and cover via raycast) and chases on sight.
## Breaking that sight line with level geometry drops the chase almost at once;
## just leaving the cone lets him hunt the last known spot for a while longer.
## The Eye spotlight IS the vision cone: yellow on patrol, red when chasing.

@export var patrol_offset := Vector3(12, 0, 0)
@export var walk_speed := 2.2
@export var chase_speed := 5.0
@export var vision_range := 11.0
@export var vision_angle_deg := 38.0
@export var catch_range := 1.2
@export var give_up_time := 2.5
## Cover beats footwork: dropping behind a wall breaks a chase this fast, while
## merely slipping out of the cone still buys the full give_up_time of pursuit.
@export var blocked_give_up_time := 0.35
@export var turn_speed := 8.0

@onready var model: Node3D = $Model
@onready var anim: AnimationPlayer = $Model/AnimationPlayer
@onready var eye: SpotLight3D = $Eye

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _a: Vector3
var _b: Vector3
var _to_b := true
var _player: Node3D
var _chasing := false
var _lost_t := 0.0
var _last_seen: Vector3
var _grabbed := false
var _current_anim := ""

const EYE_PATROL := Color(1.0, 0.93, 0.6)
const EYE_CHASE := Color(1.0, 0.25, 0.15)

enum Sight {
	VISIBLE,
	BLOCKED,  ## In the cone and in range, but something solid is in the way.
	OUT_OF_VIEW,  ## Too far away, or off to the side.
}


func _ready() -> void:
	_a = global_position
	_b = _a + patrol_offset
	eye.spot_range = vision_range
	eye.spot_angle = vision_angle_deg
	eye.light_color = EYE_PATROL
	for anim_name in ["idle", "walk", "sprint"]:
		var a := anim.get_animation(anim_name)
		if a:
			a.loop_mode = Animation.LOOP_LINEAR
	_play("walk")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	if _grabbed:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if not _player:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if not _player:
			return

	var sight := _look_for_player()
	if sight == Sight.VISIBLE:
		if not _chasing:
			eye.light_color = EYE_CHASE
		_chasing = true
		_lost_t = 0.0
		_last_seen = _player.global_position
	elif _chasing:
		_lost_t += delta
		var patience := blocked_give_up_time if sight == Sight.BLOCKED else give_up_time
		if _lost_t > patience:
			_chasing = false
			eye.light_color = EYE_PATROL

	var target := _last_seen if _chasing else (_b if _to_b else _a)
	var to_target := target - global_position
	to_target.y = 0.0

	if not _chasing and to_target.length() < 0.4:
		_to_b = not _to_b
	if _chasing and to_target.length() < 0.5:
		# Reached last known position without re-spotting him: stand and look.
		velocity.x = 0.0
		velocity.z = 0.0
		_play("idle", 0.3)
	else:
		var speed := chase_speed if _chasing else walk_speed
		var dir := to_target.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		rotation.y = lerp_angle(
			rotation.y, atan2(dir.x, dir.z), minf(turn_speed * delta, 1.0)
		)
		_play("sprint" if _chasing else "walk", 0.25)

	move_and_slide()

	var dist := global_position.distance_to(_player.global_position)
	if dist < catch_range and _player.has_method("caught_by"):
		_grabbed = true
		anim.play("attack-melee-right", 0.1)
		eye.light_color = EYE_CHASE
		_player.caught_by(self)


## Splits "can't see him" into "he's hiding" and "he's not in front of me", so the
## chase can end the moment he puts the grid map's geometry between us.
func _look_for_player() -> Sight:
	var head := _player_head()
	var to := head - _eye_pos()
	if to.length() > vision_range:
		return Sight.OUT_OF_VIEW
	var flat := Vector3(to.x, 0.0, to.z)
	# Body faces +Z, same convention as the models.
	if flat.length() > 0.01 \
			and global_basis.z.angle_to(flat) > deg_to_rad(vision_angle_deg):
		return Sight.OUT_OF_VIEW
	return Sight.VISIBLE if _eye_line_clear(head) else Sight.BLOCKED


## True when nothing solid — GridMap walls included — sits between eye and point.
func _eye_line_clear(to_pos: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(_eye_pos(), to_pos)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == _player


func _eye_pos() -> Vector3:
	return global_position + Vector3.UP * 1.3


func _player_head() -> Vector3:
	return _player.global_position + Vector3.UP * 0.8


func _play(anim_name: String, blend := 0.2) -> void:
	if _current_anim == anim_name:
		return
	_current_anim = anim_name
	anim.play(anim_name, blend)
