extends CharacterBody3D

@export var move_speed := 4.5
@export var accel := 18.0
@export var dash_speed := 10.0
@export var dash_time := 0.25
@export var dash_up_speed := 5.0
@export var dash_cooldown := 0.7
@export var mouse_sensitivity := 0.0028
@export var turn_speed := 12.0

@onready var model: Node3D = $Model
@onready var anim: AnimationPlayer = $Model/AnimationPlayer
@onready var cam_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _dash_timer := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector3(0, 0, 1)
var _last_dir := Vector3(0, 0, 1)
var _air_time := 0.0
var _current_anim := ""
var _capture_ms := 0
var _dead := false
var _caught := false
var _tnt: Node3D


func _ready() -> void:
	add_to_group("player")
	_capture_mouse()
	spring_arm.add_excluded_object(get_rid())
	cam_pivot.rotation.x = -0.18
	# GLB animations import as non-looping; fix the ones we cycle.
	for anim_name in ["idle", "walk", "sprint", "fall", "crouch"]:
		var a := anim.get_animation(anim_name)
		if a:
			a.loop_mode = Animation.LOOP_LINEAR
	_flatten_bounce("sprint", 0.5)
	_play("idle")
	_tnt = model.find_child("TNT", true, false)
	if _tnt:
		_tnt.exploded.connect(_on_exploded)


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_capture_ms = Time.get_ticks_msec()


## Drop the goblin on a level's PlayerSpawn marker, facing the way it points.
func spawn_at(t: Transform3D) -> void:
	global_position = t.origin
	rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	# Models face +Z here, and the camera hangs off the pivot's +Z, so the rig
	# has to be spun round to end up behind him looking the way he faces.
	var yaw := t.basis.get_euler().y
	cam_pivot.global_rotation.y = yaw + PI
	model.global_rotation.y = yaw
	_last_dir = Vector3(sin(yaw), 0.0, cos(yaw))


func set_fuse(seconds: float) -> void:
	if _tnt:
		_tnt.fuse_time = seconds


func get_tnt() -> Node3D:
	return _tnt


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Capturing the mouse warps the cursor, firing one bogus motion event.
		if Time.get_ticks_msec() - _capture_ms < 250:
			return
		cam_pivot.rotation.y -= event.relative.x * mouse_sensitivity
		cam_pivot.rotation.x = clampf(
			cam_pivot.rotation.x - event.relative.y * mouse_sensitivity, -0.95, 0.45
		)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_capture_mouse()


func _physics_process(delta: float) -> void:
	if _dead:
		velocity.x = move_toward(velocity.x, 0.0, accel * delta)
		velocity.z = move_toward(velocity.z, 0.0, accel * delta)
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return

	_dash_cd = maxf(_dash_cd - delta, 0.0)

	var input_2d := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3(input_2d.x, 0.0, input_2d.y).rotated(Vector3.UP, cam_pivot.global_rotation.y)
	if dir.length_squared() > 0.01:
		_last_dir = dir.normalized()

	if is_on_floor():
		_air_time = 0.0
	else:
		velocity.y -= gravity * delta
		_air_time += delta

	if Input.is_action_just_pressed("dash") and _dash_cd == 0.0:
		_dash_timer = dash_time
		_dash_cd = dash_cooldown
		_dash_dir = _last_dir
		if is_on_floor():
			velocity.y = dash_up_speed
		anim.speed_scale = 1.4
		_play("jump", 0.05)

	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity.x = _dash_dir.x * dash_speed
		velocity.z = _dash_dir.z * dash_speed
		if _dash_timer <= 0.0:
			anim.speed_scale = 1.0
	else:
		var target := dir * move_speed
		velocity.x = move_toward(velocity.x, target.x, accel * delta)
		velocity.z = move_toward(velocity.z, target.z, accel * delta)

	var flat_vel := Vector3(velocity.x, 0.0, velocity.z)
	if flat_vel.length() > 0.5:
		model.global_rotation.y = lerp_angle(
			model.global_rotation.y, atan2(flat_vel.x, flat_vel.z), minf(turn_speed * delta, 1.0)
		)

	move_and_slide()
	_update_anim(flat_vel.length())


func _update_anim(speed: float) -> void:
	if _dash_timer > 0.0:
		return
	if _air_time > 0.2:
		_play("fall")
	elif speed > 0.8:
		_play("sprint")
	else:
		_play("idle", 0.3)


func _play(anim_name: String, blend := 0.2) -> void:
	if _current_anim == anim_name:
		return
	_current_anim = anim_name
	anim.play(anim_name, blend)


func caught_by(_enemy: Node) -> void:
	if _dead or _caught:
		return
	_caught = true
	_dead = true
	if _tnt:
		_tnt.defuse()
	anim.speed_scale = 1.0
	_play("die", 0.15)
	_show_result(false)


func _on_exploded() -> void:
	_dead = true
	anim.speed_scale = 1.0
	_play("die", 0.15)
	var radius: float = _tnt.blast_radius
	var win := false
	for t in get_tree().get_nodes_in_group("target"):
		if t is Node3D and t.global_position.distance_to(global_position) <= radius:
			win = true
			_blast_target(t)
	_show_result(win)


func _blast_target(t: Node3D) -> void:
	var dir := (t.global_position - global_position).normalized() + Vector3.UP * 1.2
	var tw := t.create_tween()
	tw.set_parallel(true)
	tw.tween_property(t, "global_position", t.global_position + dir * 6.0, 0.9) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(t, "rotation", t.rotation + Vector3(TAU * 1.5, 0.0, TAU), 0.9)
	tw.chain().tween_callback(t.queue_free)


func _result_text(win: bool) -> String:
	if not win:
		var why := "GRABBED!" if _caught else "THE TARGET SURVIVED..."
		return why + "\nSAME LEVEL AGAIN"
	if Game.is_final_level():
		return "TARGET ELIMINATED!\nEVERY COUNT IS DOWN"
	return "TARGET ELIMINATED!\nON TO LEVEL %d" % (Game.level_number() + 1)


func _show_result(win: bool) -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = _result_text(win)
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override(
		"font_color", Color(1.0, 0.85, 0.3) if win else Color(0.95, 0.3, 0.2)
	)
	label.add_theme_constant_override("outline_size", 14)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(label)
	add_child(layer)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	await get_tree().create_timer(3.0).timeout
	# Winning advances the run; losing rebuilds the same level.
	Game.finish_round(win)


func _flatten_bounce(anim_name: String, factor: float) -> void:
	# Kenney run cycles bob the whole rig up and down; at 2x model scale
	# that reads too high, so compress the root Y keys around their average.
	var a := anim.get_animation(anim_name)
	if a == null or a.has_meta("bounce_flattened"):
		return
	a.set_meta("bounce_flattened", true)
	for ti in a.get_track_count():
		if a.track_get_type(ti) != Animation.TYPE_POSITION_3D:
			continue
		if a.track_is_compressed(ti):
			continue
		if not String(a.track_get_path(ti)).ends_with("root"):
			continue
		var count := a.track_get_key_count(ti)
		if count == 0:
			continue
		var avg := 0.0
		for k in count:
			avg += (a.track_get_key_value(ti, k) as Vector3).y
		avg /= count
		for k in count:
			var v := a.track_get_key_value(ti, k) as Vector3
			v.y = avg + (v.y - avg) * factor
			a.track_set_key_value(ti, k, v)
