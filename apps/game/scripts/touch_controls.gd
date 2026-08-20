extends CanvasLayer
# switch-style touch controls: dpad + A/B + start(+)/select(-). touch only,
# gated by DisplayServer.is_touchscreen_available(). Button/dpad art is
# sliced from the gdb-gamepad-2 Switch prompt sheet (assets/ui/switch_buttons);
# start/select keep a drawn pill backing since the source +/- glyphs have none.

const GAMEPLAY_SCENES := ["village", "open_world", "house_interior", "shop_interior"]
const MOVE_ACTIONS := {
	"right": "move_right", "left": "move_left",
	"down": "move_bottom", "up": "move_top",
}

const DPAD_TEX := preload("res://assets/ui/switch_buttons/dpad.png")
const A_TEX := preload("res://assets/ui/switch_buttons/button_a.png")
const B_TEX := preload("res://assets/ui/switch_buttons/button_b.png")
const PLUS_TEX := preload("res://assets/ui/switch_buttons/plus.png")
const MINUS_TEX := preload("res://assets/ui/switch_buttons/minus.png")

var _root: Control
var _dpad: Control
var _dpad_glow: Control
var _a_btn: Control
var _b_btn: Control
var _start_btn: Control
var _select_btn: Control

var _dpad_center: Vector2 = Vector2.ZERO
var _dpad_radius: float = 55.0
var _dpad_strength := {"right": 0.0, "left": 0.0, "up": 0.0, "down": 0.0}
var _dpad_touch_index: int = -1
var _a_touch_index: int = -1
var _b_touch_index: int = -1
var _start_touch_index: int = -1
var _select_touch_index: int = -1

var _a_pressed := false
var _b_pressed := false
var _start_pressed := false
var _select_pressed := false

func _ready() -> void:
	layer = 96
	if not DisplayServer.is_touchscreen_available():
		set_process(false)
		return
	_build_ui()

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# scales with the HUD text-size setting, same as everything else
	var s: float = Settings.font_scale
	var dpad_size := 176.0 * s
	var a_size := 118.0 * s
	var b_size := 86.0 * s
	var margin := 30.0 * s
	var action_gap := 120.0 # clears the emote quick-bar in the corner
	var pill_w := 104.0 * s
	var pill_h := 36.0 * s

	var gold := PixlTheme.color("gold")
	var panel := PixlTheme.color("panel")

	_dpad = _icon_button(DPAD_TEX, dpad_size)
	_dpad.anchor_left = 0; _dpad.anchor_right = 0
	_dpad.anchor_top = 1; _dpad.anchor_bottom = 1
	_dpad.offset_left = margin; _dpad.offset_right = margin + dpad_size
	_dpad.offset_top = -(margin + dpad_size); _dpad.offset_bottom = -margin
	_root.add_child(_dpad)
	_dpad_radius = dpad_size / 2.0

	_dpad_glow = Control.new()
	_dpad_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dpad_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dpad_glow.draw.connect(func(): _draw_dpad_glow(_dpad_glow, dpad_size))
	_dpad.add_child(_dpad_glow)

	# A: primary action (interact)
	_a_btn = _icon_button(A_TEX, a_size)
	_a_btn.anchor_left = 1; _a_btn.anchor_right = 1
	_a_btn.anchor_top = 1; _a_btn.anchor_bottom = 1
	_a_btn.offset_right = -margin; _a_btn.offset_left = -margin - a_size
	_a_btn.offset_bottom = -(margin + action_gap); _a_btn.offset_top = _a_btn.offset_bottom - a_size
	_root.add_child(_a_btn)

	# B: hold to run, offset lower-left of A like a real pad
	_b_btn = _icon_button(B_TEX, b_size)
	_b_btn.anchor_left = 1; _b_btn.anchor_right = 1
	_b_btn.anchor_top = 1; _b_btn.anchor_bottom = 1
	_b_btn.offset_right = _a_btn.offset_left + b_size * 0.55
	_b_btn.offset_left = _b_btn.offset_right - b_size
	_b_btn.offset_bottom = _a_btn.offset_bottom + b_size * 0.3
	_b_btn.offset_top = _b_btn.offset_bottom - b_size
	_root.add_child(_b_btn)

	# select: chat (Switch "-")
	_select_btn = _bevel_pill(pill_w, pill_h, panel, gold, "_select_pressed")
	_select_btn.anchor_left = 0.5; _select_btn.anchor_right = 0.5
	_select_btn.anchor_top = 1; _select_btn.anchor_bottom = 1
	_select_btn.offset_left = -pill_w - 8.0; _select_btn.offset_right = -8.0
	_select_btn.offset_bottom = -margin; _select_btn.offset_top = -(margin + pill_h)
	_pill_icon(_select_btn, MINUS_TEX, pill_h * 0.4)
	_root.add_child(_select_btn)

	# start: pause menu (Switch "+")
	_start_btn = _bevel_pill(pill_w, pill_h, panel, gold, "_start_pressed")
	_start_btn.anchor_left = 0.5; _start_btn.anchor_right = 0.5
	_start_btn.anchor_top = 1; _start_btn.anchor_bottom = 1
	_start_btn.offset_left = 8.0; _start_btn.offset_right = pill_w + 8.0
	_start_btn.offset_bottom = -margin; _start_btn.offset_top = -(margin + pill_h)
	_pill_icon(_start_btn, PLUS_TEX, pill_h * 0.4)
	_root.add_child(_start_btn)

# a crisp, nearest-filtered sprite button; scale/modulate double as the
# "pressed" feedback since the art itself is a flat icon, not a drawn bevel.
func _icon_button(tex: Texture2D, size: float) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(size, size)
	t.size = Vector2(size, size)
	t.texture = tex
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.pivot_offset = Vector2(size, size) / 2.0
	return t

func _set_icon_pressed(t: Control, pressed: bool) -> void:
	if t == null:
		return
	t.scale = Vector2.ONE * (0.9 if pressed else 1.0)
	t.modulate = Color(0.8, 0.8, 0.8) if pressed else Color.WHITE

# small glyph (the +/- sheet icons have no button backing of their own),
# centred on top of the drawn pill.
func _pill_icon(parent: Control, tex: Texture2D, target_h: float) -> void:
	var aspect: float = float(tex.get_width()) / float(tex.get_height())
	var h := target_h
	var w := h * aspect
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(w, h)
	t.size = Vector2(w, h)
	t.texture = tex
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.set_anchors_preset(Control.PRESET_CENTER)
	t.offset_left = -w / 2.0; t.offset_right = w / 2.0
	t.offset_top = -h / 2.0; t.offset_bottom = h / 2.0
	parent.add_child(t)

# stadium shape (rect + circle caps) with a shadow/bevel treatment - still
# used for start/select since their sheet glyphs are bare (no button face).
func _bevel_pill(w: float, h: float, face: Color, ring: Color, pressed_var: String) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func(): _draw_bevel_pill(c, w, h, face, ring, get(pressed_var)))
	return c

func _stadium(c: Control, w: float, h: float, ox: float, oy: float, col: Color) -> void:
	var r := h / 2.0
	c.draw_circle(Vector2(r + ox, r + oy), r, col, true, -1.0, false)
	c.draw_circle(Vector2(w - r + ox, r + oy), r, col, true, -1.0, false)
	c.draw_rect(Rect2(r + ox, oy, w - h, h), col)

func _draw_bevel_pill(c: Control, w: float, h: float, face: Color, ring: Color, pressed: bool) -> void:
	var shadow_c := PixlTheme.color("panel-deep")
	var drop := 1.5 if pressed else 4.0
	_stadium(c, w, h, drop, drop, shadow_c)
	_stadium(c, w, h, 0.0, 0.0, face.lightened(0.15) if pressed else face)
	var r := h / 2.0
	c.draw_arc(Vector2(r, r), r - 1.5, PI / 2.0, 3.0 * PI / 2.0, 20, ring, 2.5, false)
	c.draw_arc(Vector2(w - r, r), r - 1.5, -PI / 2.0, PI / 2.0, 20, ring, 2.5, false)
	c.draw_line(Vector2(r, 1.25), Vector2(w - r, 1.25), ring, 2.5)
	c.draw_line(Vector2(r, h - 1.25), Vector2(w - r, h - 1.25), ring, 2.5)

func _cross_rects(ox: float, oy: float, size: float) -> Dictionary:
	var arm := size / 3.0
	return {
		"h": Rect2(ox, oy + arm, size, arm),
		"v": Rect2(ox + arm, oy, arm, size),
		"up": Rect2(ox + arm, oy, arm, arm),
		"down": Rect2(ox + arm, oy + size - arm, arm, arm),
		"left": Rect2(ox, oy + arm, arm, arm),
		"right": Rect2(ox + size - arm, oy + arm, arm, arm),
	}

# per-direction gold glow over the dpad art, inset slightly from its drawn
# edges - the sheet has its own lit-direction variants but swapping textures
# per touch would fight the drag-based analog strength this dpad already uses.
func _draw_dpad_glow(c: Control, size: float) -> void:
	var gold := PixlTheme.color("gold")
	var rects := _cross_rects(size * 0.06, size * 0.06, size * 0.88)
	for key in ["up", "down", "left", "right"]:
		var t: float = _dpad_strength.get(key, 0.0)
		if t > 0.02:
			c.draw_rect(rects[key], Color(gold, t * 0.6))

func _in_gameplay() -> bool:
	var cur := get_tree().current_scene
	return cur != null and GAMEPLAY_SCENES.has(cur.scene_file_path.get_file().get_basename())

func _process(_delta: float) -> void:
	if _root == null:
		return
	var in_game := _in_gameplay() and not Dialogue.is_open and not global.ui_blocked() and not ChatHud.is_typing()
	_root.visible = in_game
	if not in_game:
		_release_dpad()
		_release_a()
		_release_b()
		_release_start()
		_release_select()

func _input(event: InputEvent) -> void:
	if _root == null or not _root.visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_touch_down(event.index, event.position)
		else:
			_on_touch_up(event.index)
	elif event is InputEventScreenDrag and event.index == _dpad_touch_index:
		_update_dpad(event.position)
		get_viewport().set_input_as_handled()

func _hits(c: Control, pos: Vector2, slop: float = 1.0) -> bool:
	return pos.distance_to(c.global_position + c.size / 2.0) <= c.size.x / 2.0 * slop

func _hits_rect(c: Control, pos: Vector2) -> bool:
	return Rect2(c.global_position, c.size).has_point(pos)

func _on_touch_down(index: int, pos: Vector2) -> void:
	if _dpad_touch_index == -1 and _hits(_dpad, pos, 1.6):
		_dpad_touch_index = index
		_dpad_center = _dpad.global_position + _dpad.size / 2.0
		_update_dpad(pos)
		get_viewport().set_input_as_handled()
	elif _a_touch_index == -1 and _hits(_a_btn, pos, 1.2):
		_a_touch_index = index
		_press_a()
		get_viewport().set_input_as_handled()
	elif _b_touch_index == -1 and _hits(_b_btn, pos, 1.2):
		_b_touch_index = index
		_press_b()
		get_viewport().set_input_as_handled()
	elif _select_touch_index == -1 and _hits_rect(_select_btn, pos):
		_select_touch_index = index
		_select_pressed = true
		_select_btn.queue_redraw()
		ChatHud._open_input()
		get_viewport().set_input_as_handled()
	elif _start_touch_index == -1 and _hits_rect(_start_btn, pos):
		_start_touch_index = index
		_start_pressed = true
		_start_btn.queue_redraw()
		PauseMenu.pause_game()
		get_viewport().set_input_as_handled()

func _on_touch_up(index: int) -> void:
	if index == _dpad_touch_index:
		_release_dpad()
		get_viewport().set_input_as_handled()
	elif index == _a_touch_index:
		_release_a()
		get_viewport().set_input_as_handled()
	elif index == _b_touch_index:
		_release_b()
		get_viewport().set_input_as_handled()
	elif index == _select_touch_index:
		_release_select()
		get_viewport().set_input_as_handled()
	elif index == _start_touch_index:
		_release_start()
		get_viewport().set_input_as_handled()

func _update_dpad(pos: Vector2) -> void:
	var delta := pos - _dpad_center
	var mag := minf(delta.length(), _dpad_radius)
	var dir := delta.normalized() if delta.length() > 0.001 else Vector2.ZERO
	var strength := dir * (mag / _dpad_radius)
	_set_axis("right", maxf(strength.x, 0.0))
	_set_axis("left", maxf(-strength.x, 0.0))
	_set_axis("down", maxf(strength.y, 0.0))
	_set_axis("up", maxf(-strength.y, 0.0))

func _set_axis(key: String, strength: float) -> void:
	var action: String = MOVE_ACTIONS[key]
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)
	_dpad_strength[key] = strength
	_dpad_glow.queue_redraw()

func _release_dpad() -> void:
	_dpad_touch_index = -1
	for key in MOVE_ACTIONS:
		Input.action_release(MOVE_ACTIONS[key])
		_dpad_strength[key] = 0.0
	if _dpad_glow != null:
		_dpad_glow.queue_redraw()

func _press_a() -> void:
	_a_pressed = true
	_set_icon_pressed(_a_btn, true)
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)

func _release_a() -> void:
	var was_down := _a_touch_index != -1
	_a_touch_index = -1
	_a_pressed = false
	_set_icon_pressed(_a_btn, false)
	if not was_down and not Input.is_action_pressed("interact"):
		return
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = false
	Input.parse_input_event(ev)

func _press_b() -> void:
	_b_pressed = true
	_set_icon_pressed(_b_btn, true)
	Input.action_press("run", 1.0)

func _release_b() -> void:
	_b_touch_index = -1
	_b_pressed = false
	_set_icon_pressed(_b_btn, false)
	Input.action_release("run")

func _release_start() -> void:
	_start_touch_index = -1
	_start_pressed = false
	if _start_btn != null:
		_start_btn.queue_redraw()

func _release_select() -> void:
	_select_touch_index = -1
	_select_pressed = false
	if _select_btn != null:
		_select_btn.queue_redraw()
