extends Node3D
## Marks this scene as an assassination target for the bomb's blast check,
## and pops a billboarded speech bubble above his head so he tells jokes
## while a goblin with a lit bomb sneaks up on him.

@export_multiline var jokes: PackedStringArray = [
	"I've been sitting so long I've grown roots.",
	"I am Count Dracula Bla bla blaa!",
	"I You can COUNT on me!",
	"Well...This is a bit awkward...",
	"What an interesting...sparkling red cape?",
]
## Local height above the target's origin. Scales with the node.
@export var bubble_height := 1.4
@export var bubble_size := 0.0026
@export var show_time := 4.5
@export var gap_time := 2.0

const BUBBLE_BG := Color(0.97, 0.96, 0.92)
const BUBBLE_INK := Color(0.11, 0.09, 0.13)
const VIEW_SIZE := Vector2i(560, 260)
const TAIL_W := 26.0
const TAIL_H := 34.0

var _sprite: Sprite3D
var _label: Label
var _panel: PanelContainer
var _tail_dark: Polygon2D
var _tail_fill: Polygon2D
var _timer: Timer
var _queue: Array[String] = []
var _next := 0
var _showing := false


func _ready() -> void:
	add_to_group("target")
	_build_bubble()
	_start_jokes()


func _build_bubble() -> void:
	var vp := SubViewport.new()
	vp.size = VIEW_SIZE
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	# Tails first so the panel paints over their flat top edge.
	_tail_dark = Polygon2D.new()
	_tail_dark.color = BUBBLE_INK
	vp.add_child(_tail_dark)
	_tail_fill = Polygon2D.new()
	_tail_fill.color = BUBBLE_BG
	vp.add_child(_tail_fill)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp.add_child(center)

	var sb := StyleBoxFlat.new()
	sb.bg_color = BUBBLE_BG
	sb.set_corner_radius_all(30)
	sb.set_content_margin_all(24)
	sb.set_border_width_all(6)
	sb.border_color = BUBBLE_INK

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(_panel)

	_label = Label.new()
	_label.custom_minimum_size.x = 430.0
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 40)
	_label.add_theme_color_override("font_color", BUBBLE_INK)
	_panel.add_child(_label)
	_panel.resized.connect(_place_tail)

	_sprite = Sprite3D.new()
	_sprite.texture = vp.get_texture()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	_sprite.double_sided = true
	_sprite.pixel_size = bubble_size
	_sprite.position.y = bubble_height
	_sprite.render_priority = 2
	_sprite.visible = false
	add_child(_sprite)


func _place_tail() -> void:
	# Panel is centred in the viewport; hang the tail off its bottom edge.
	var bottom := _panel.position.y + _panel.size.y
	var cx := _panel.position.x + _panel.size.x * 0.5
	_tail_dark.polygon = PackedVector2Array([
		Vector2(cx - TAIL_W, bottom - 12.0),
		Vector2(cx + TAIL_W, bottom - 12.0),
		Vector2(cx - TAIL_W * 0.35, bottom + TAIL_H),
	])
	_tail_fill.polygon = PackedVector2Array([
		Vector2(cx - TAIL_W + 8.0, bottom - 16.0),
		Vector2(cx + TAIL_W - 8.0, bottom - 16.0),
		Vector2(cx - TAIL_W * 0.35 + 3.0, bottom + TAIL_H - 12.0),
	])


func _start_jokes() -> void:
	if jokes.is_empty():
		return
	# First line always leads; the rest cycle in a shuffled order.
	_queue = [jokes[0]]
	var rest: Array[String] = []
	for i in range(1, jokes.size()):
		rest.append(jokes[i])
	rest.shuffle()
	_queue.append_array(rest)

	# A Timer rather than an await chain: it dies with the node, so getting
	# blown up mid-joke can't resume a coroutine on a freed instance.
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_advance)
	add_child(_timer)
	_advance()


func _advance() -> void:
	if _showing:
		_showing = false
		var fade := create_tween()
		fade.set_parallel(true)
		fade.tween_property(_sprite, "scale", Vector3.ONE * 0.4, 0.22)
		fade.tween_property(_sprite, "modulate:a", 0.0, 0.22)
		fade.chain().tween_callback(func() -> void: _sprite.visible = false)
		_timer.start(0.25 + gap_time)
		return

	_showing = true
	_label.text = _queue[_next]
	_next += 1
	if _next >= _queue.size():
		_next = 0
		_queue.shuffle()

	_sprite.visible = true
	_sprite.scale = Vector3.ONE * 0.3
	_sprite.modulate.a = 0.0
	var pop := create_tween()
	pop.set_parallel(true)
	pop.tween_property(_sprite, "scale", Vector3.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_sprite, "modulate:a", 1.0, 0.2)
	_timer.start(show_time)
