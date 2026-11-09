extends Node2D
## DeskBuddy mascot: the critter (vector art in critter_art.gd) walking along
## the bottom of the overlay. The node origin is at its feet.
##
## Behaviours:
##  IDLE   stands, breathes, blinks; dozes ("z z Z") while the computer is idle
##  WALK   hops toward a random spot with squash & stretch
##  REMIND stops, faces the user, waves and talks; speech bubble (reminders)
## On top of these, say() shows a short chat bubble (e.g. a comment about the
## app the user just opened) with a little hop, without interrupting reminders.

const CritterArt := preload("res://scripts/overlay/critter_art.gd")
const CartoonTheme := preload("res://scripts/ui/cartoon_theme.gd")

## Drawing scale per "Ukuran maskot" level: kecil / sedang / besar.
const SIZE_SCALES := [0.95, 1.25, 1.6]
const BUBBLE_WIDTH := 240.0
const BUBBLE_GAP := 26.0
const HOP_HEIGHT := 18.0

## Per intensity level: walk speed (units/s), idle pause range (s), hop height.
var INTENSITY := [
	{"speed": 38.0, "idle_min": 6.0, "idle_max": 12.0, "bounce": 4.0},
	{"speed": 60.0, "idle_min": 2.5, "idle_max": 6.0, "bounce": 7.0},
	{"speed": 90.0, "idle_min": 1.0, "idle_max": 3.0, "bounce": 10.0},
]

enum Behavior { IDLE, WALK, REMIND }

var body_color: Color = CritterArt.color_for("pink")
var intensity := 1
## True while the computer is idle: the critter naps instead of walking.
var sleepy := false
var behavior: int = Behavior.IDLE
var facing := 1.0
var min_x := 40.0
var max_x := 400.0
var ground_y := 200.0

var _scale := 1.25
var _target_x := 0.0
var _state_time := 0.0
var _t := 0.0
var _walk_phase := 0.0
var _look := 0.0
var _blink_left := 3.0
var _hop := 0.0
var _chat_left := 0.0
var _rng := RandomNumberGenerator.new()

var _bubble: PanelContainer
var _bubble_label: Label
var _remind_style: StyleBoxFlat
var _chat_style: StyleBoxFlat
var _tail: Node2D
var _bubble_tween: Tween


func _ready() -> void:
	_rng.randomize()
	_blink_left = _rng.randf_range(2.0, 5.0)
	_build_bubble()
	_enter_idle()


# ------------------------------------------------------------- public API

func set_color_name(color_name: String) -> void:
	body_color = CritterArt.color_for(color_name)
	queue_redraw()


func set_intensity(level: int) -> void:
	intensity = clampi(level, 0, INTENSITY.size() - 1)


func set_size_level(level: int) -> void:
	_scale = SIZE_SCALES[clampi(level, 0, SIZE_SCALES.size() - 1)]
	queue_redraw()


func get_height() -> float:
	return CritterArt.TOP * _scale


func set_walk_area(p_min_x: float, p_max_x: float, p_ground_y: float) -> void:
	min_x = p_min_x
	max_x = maxf(p_min_x, p_max_x)
	ground_y = p_ground_y
	position = Vector2(clampf(position.x if position.x > 0.0 else (min_x + max_x) * 0.5, min_x, max_x), ground_y)
	_target_x = clampf(_target_x, min_x, max_x)


## Reminder bubble (stays until hide_message()). Has priority over chat.
func show_message(text: String) -> void:
	behavior = Behavior.REMIND
	_chat_left = 0.0
	_open_bubble(text, _remind_style)


func hide_message() -> void:
	if behavior == Behavior.REMIND:
		_close_bubble()
		_enter_idle()


## Short chat bubble above the head. Returns false (and shows nothing) while a
## reminder is on screen.
func say(text: String, duration := 4.5) -> bool:
	if behavior == Behavior.REMIND:
		return false
	_chat_left = duration
	_hop = 1.0
	_open_bubble(text, _chat_style)
	return true


func is_chatting() -> bool:
	return _chat_left > 0.0


## Small reaction when the user clicks the critter.
func poke() -> void:
	_hop = 1.0


## Bounds (parent coordinates) covering body + bubble. Used for the overlay's
## click-through region and for click detection.
func get_bounds() -> Rect2:
	var w := CritterArt.HALF_WIDTH * _scale
	var h := get_height() + HOP_HEIGHT * _scale + 8.0
	var r := Rect2(position + Vector2(-w, -h), Vector2(w * 2.0, h + 6.0))
	if _bubble != null and _bubble.visible:
		r = r.merge(Rect2(position + _bubble.position, _bubble.size))
	return r


# ------------------------------------------------------------- behaviour

func _process(delta: float) -> void:
	_t += delta
	_state_time -= delta
	var p: Dictionary = INTENSITY[intensity]
	match behavior:
		Behavior.IDLE:
			if _state_time <= 0.0 and not sleepy and not is_chatting():
				_enter_walk()
		Behavior.WALK:
			if sleepy:
				_enter_idle()
			else:
				var dir := signf(_target_x - position.x)
				if dir != 0.0:
					facing = dir
				var speed := float(p["speed"]) * _scale
				position.x = move_toward(position.x, _target_x, speed * delta)
				_walk_phase += delta * speed / (14.0 * _scale)
				if is_equal_approx(position.x, _target_x):
					_enter_idle()
	position.y = ground_y

	if _chat_left > 0.0:
		_chat_left -= delta
		if _chat_left <= 0.0 and behavior != Behavior.REMIND:
			_close_bubble()
	_hop = maxf(0.0, _hop - delta * 2.2)
	_blink_left -= delta
	if _blink_left < -0.12:
		_blink_left = _rng.randf_range(2.0, 5.5)
	var look_target := facing if behavior == Behavior.WALK else 0.0
	_look = lerpf(_look, look_target, clampf(delta * 8.0, 0.0, 1.0))
	_place_bubble()
	queue_redraw()
	_tail.queue_redraw()


func _enter_idle() -> void:
	behavior = Behavior.IDLE
	var p: Dictionary = INTENSITY[intensity]
	_state_time = _rng.randf_range(float(p["idle_min"]), float(p["idle_max"]))


func _enter_walk() -> void:
	var span := max_x - min_x
	if span < 20.0:
		_enter_idle()
		return
	var target := _rng.randf_range(min_x, max_x)
	if absf(target - position.x) < minf(120.0, span * 0.3):
		target = min_x + fposmod(target - min_x + span * 0.5, span)
	_target_x = target
	behavior = Behavior.WALK


func _dozing() -> bool:
	return sleepy and behavior != Behavior.REMIND and not is_chatting()


## Vertical offset (up, units) and squash factor for the current frame.
func _pose() -> Vector2:
	var p: Dictionary = INTENSITY[intensity]
	var lift := 0.0
	var squash := 1.0
	match behavior:
		Behavior.WALK:
			var s := absf(sin(_walk_phase * PI))
			lift = s * float(p["bounce"])
			squash = 1.0 + (s - 0.5) * 0.12
		Behavior.REMIND:
			var s := absf(sin(_t * 5.0))
			lift = s * 5.0
			squash = 1.0 + (s - 0.5) * 0.08
		_:
			squash = 1.0 + sin(_t * (1.4 if _dozing() else 2.4)) * (0.035 if _dozing() else 0.022)
	if _hop > 0.0:
		var k := sin(_hop * PI)
		lift += k * HOP_HEIGHT
		squash += k * 0.12 - (0.1 if _hop > 0.9 else 0.0)
	return Vector2(lift, squash)


func _draw() -> void:
	var pose := _pose()
	var sy := pose.y
	var sx := 1.0 / sqrt(maxf(sy, 0.5))
	draw_set_transform(Vector2(0, -pose.x * _scale), 0.0, Vector2(sx, sy) * _scale)
	var eyes := "open"
	var mouth := "smile"
	var wave := 0.0
	if behavior == Behavior.REMIND:
		eyes = "wow"
		mouth = "talk"
		wave = 1.0
	elif is_chatting():
		eyes = "happy"
		mouth = "talk" if _chat_left > 2.0 else "smile"
		wave = clampf(_chat_left - 3.0, 0.0, 1.0)
	elif _dozing():
		eyes = "sleep"
		mouth = "o"
	elif _blink_left < 0.0:
		eyes = "blink"
	CritterArt.draw(self, {
		"color": body_color.lerp(Color("b8b0d8"), 0.25) if _dozing() else body_color,
		"look": _look,
		"t": _t,
		"step": sin(_walk_phase * PI) if behavior == Behavior.WALK else 0.0,
		"eyes": eyes,
		"mouth": mouth,
		"wave": wave,
	})
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _dozing():
		_draw_zzz()


func _draw_zzz() -> void:
	var f := CartoonTheme.font(900)
	var base := Vector2(CritterArt.HALF_WIDTH * 0.55, -CritterArt.TOP * 0.95) * _scale
	for i in 3:
		var k := fmod(_t * 0.6 + i / 3.0, 1.0)
		var pos := base + Vector2(k * 18.0 + sin(_t * 2.0 + i) * 3.0, -k * 34.0) * _scale
		var size := int((15 + i * 5) * _scale)
		var col := Color(1, 1, 1, 1.0 - k)
		draw_string_outline(f, pos, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(CartoonTheme.INK, 1.0 - k))
		draw_string(f, pos, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


# ------------------------------------------------------------------ bubble

func _build_bubble() -> void:
	_remind_style = CartoonTheme.box(Color("fff0b3"), 18, 4, 3, 12.0)
	_chat_style = CartoonTheme.box(Color.WHITE, 18, 4, 3, 10.0)
	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_theme_stylebox_override("panel", _chat_style)
	_bubble_label = Label.new()
	_bubble_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble_label.add_theme_font_override("font", CartoonTheme.font(800))
	_bubble_label.add_theme_font_size_override("font_size", 15)
	_bubble_label.add_theme_color_override("font_color", CartoonTheme.INK)
	_bubble.add_child(_bubble_label)
	_bubble.visible = false
	add_child(_bubble)
	# The tail is drawn after the bubble so it covers the bubble's bottom edge.
	_tail = Node2D.new()
	_tail.draw.connect(_draw_tail)
	add_child(_tail)


func _open_bubble(text: String, style: StyleBoxFlat) -> void:
	_bubble.add_theme_stylebox_override("panel", style)
	_bubble_label.text = text
	var font := CartoonTheme.font(800)
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 4.0
	var w := minf(text_w, BUBBLE_WIDTH)
	# Autowrapped labels size their height from their current width, so set it first.
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_OFF if text_w <= BUBBLE_WIDTH else TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.custom_minimum_size = Vector2(w, 0)
	_bubble_label.size = Vector2(w, 0)
	_bubble.visible = true
	_bubble.size = Vector2.ZERO
	_bubble.reset_size()
	_place_bubble()
	if _bubble_tween != null:
		_bubble_tween.kill()
	_bubble.scale = Vector2(0.4, 0.4)
	# Invisible for the first frames while the label settles its size.
	_bubble.modulate.a = 0.0
	_bubble_tween = create_tween()
	_bubble_tween.tween_interval(0.05)
	_bubble_tween.tween_property(_bubble, "modulate:a", 1.0, 0.06)
	_bubble_tween.parallel().tween_property(_bubble, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_bubble() -> void:
	_chat_left = 0.0
	_bubble.visible = false


func _bubble_style() -> StyleBoxFlat:
	return _bubble.get_theme_stylebox("panel") as StyleBoxFlat


func _place_bubble() -> void:
	if not _bubble.visible:
		return
	# Labels update their minimum size lazily after a text change, so shrink-wrap every frame.
	_bubble.reset_size()
	var s := _bubble.size
	_bubble.pivot_offset = Vector2(s.x * 0.5, s.y)
	var x := -s.x * 0.5
	var left := position.x + x
	if left < 4.0:
		x += 4.0 - left
	var right := position.x + x + s.x
	if right > max_x + 46.0:
		x -= right - (max_x + 46.0)
	_bubble.position = Vector2(x, -get_height() - HOP_HEIGHT * _scale * 0.6 - BUBBLE_GAP - s.y)


func _draw_tail() -> void:
	if not _bubble.visible or _bubble.scale.x < 0.95:
		return
	var sb := _bubble_style()
	var bottom := _bubble.position.y + _bubble.size.y - float(sb.border_width_bottom)
	var cx := clampf(0.0, _bubble.position.x + 26.0, _bubble.position.x + _bubble.size.x - 26.0)
	var tip := Vector2(_look * 6.0, -get_height() - 6.0)
	var a := Vector2(cx - 11.0, bottom - 1.0)
	var b := Vector2(cx + 11.0, bottom - 1.0)
	var ink := CartoonTheme.INK
	_tail.draw_colored_polygon(PackedVector2Array([a + Vector2(-3, 0), b + Vector2(3, 0), tip]), ink)
	_tail.draw_colored_polygon(PackedVector2Array([a + Vector2(2.5, -2), b + Vector2(-2.5, -2), tip + Vector2(0, -6)]), sb.bg_color)
