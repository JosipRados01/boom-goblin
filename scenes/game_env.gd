extends Node3D
## Builds whichever level the run is currently on and wires the player into it.
## The sky, the light and the goblin live here and never reload; only the level
## under them changes.

## Seconds left when the clock turns red and starts pulsing.
const PANIC_TIME := 10.0

@onready var player: CharacterBody3D = $Player

var level: Node3D  # root of the loaded level scene, running level.gd
var _time_label: Label
var _tnt: Node3D
var _panicking := false


func _ready() -> void:
	_build_level()
	_build_hud()
	_show_intro()


func _build_level() -> void:
	var packed: PackedScene = load(Game.level_path())
	if packed == null:
		push_error("Missing level scene: %s" % Game.level_path())
		return
	level = packed.instantiate()
	add_child(level)
	# Children are ready by now, so the spawn marker and the enemies exist.
	player.spawn_at(level.spawn_transform())
	player.set_fuse(level.fuse_time)
	_tnt = player.get_tnt()


func _process(_delta: float) -> void:
	if _tnt == null or not is_instance_valid(_tnt):
		return
	var left: float = _tnt.time_left()
	_time_label.text = "%0.1f" % left
	if left >= PANIC_TIME:
		return
	# Goes red and starts pulsing once there is no time left to be subtle.
	if not _panicking:
		_panicking = true
		_time_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25))
	_time_label.pivot_offset = _time_label.size * 0.5
	_time_label.scale = Vector2.ONE * (1.0 + 0.08 * absf(sin(left * PI)))


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", -6)
	layer.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.position.y = 18.0

	_time_label = _make_label("%0.1f" % level.fuse_time, 60, Color(1.0, 0.86, 0.4))
	box.add_child(_time_label)

	var lvl_label := _make_label(
		"LEVEL %d / %d" % [Game.level_number(), Game.level_count()],
		22,
		Color(0.85, 0.85, 0.9)
	)
	box.add_child(lvl_label)


func _show_intro() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var text := "LEVEL %d" % Game.level_number()
	if level.title != "":
		text += "\n" + level.title
	if Game.run_complete:
		text = "ALL TARGETS ELIMINATED\nRUN IT BACK"
	var label := _make_label(text, 52, Color(1.0, 0.92, 0.7))
	layer.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.pivot_offset = label.size * 0.5

	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(label, "modulate:a", 0.0, 0.7)
	tw.tween_callback(layer.queue_free)


func _make_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", maxi(size / 5, 6))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	return label


func _unhandled_key_input(event: InputEvent) -> void:
	# Jam shortcuts: R restarts the level, N skips to the next one.
	if not event.is_pressed() or event.is_echo():
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_R:
		Game.retry()
	elif key == KEY_N:
		Game.skip()
