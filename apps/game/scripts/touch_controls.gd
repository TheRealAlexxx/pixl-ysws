extends CanvasLayer
# On-screen movement joystick + interact/chat/menu buttons for touchscreens
# (mobile web). Never shown on a desktop/mouse browser —
# DisplayServer.is_touchscreen_available() gates the whole thing off at boot.
# Movement/interact feed the same actions keyboard input already produces;
# chat and menu call straight into ChatHud/PauseMenu since there's no keyboard
# shortcut to simulate for those (Enter to chat, Esc for the pause menu).

const GAMEPLAY_SCENES := ["village", "open_world", "house_interior", "shop_interior"]
const MOVE_ACTIONS := {
	"right": "move_right", "left": "move_left",
	"down": "move_bottom", "up": "move_top",
}

var _root: Control
var _joy_base: Control
var _joy_knob: Control
var _interact_btn: Control
var _chat_btn: Control
var _menu_btn: Control

var _joy_center: Vector2 = Vector2.ZERO
var _joy_radius: float = 55.0
var _joy_touch_index: int = -1
var _interact_touch_index: int = -1

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

	# Everything below scales with the same font_scale the HUD text uses
	# (bumped to 1.3 by default on touch devices), so bumping the "text size"
	# setting also grows the touch targets.
	var s: float = Settings.font_scale
	var joy_size := 170.0 * s
	_joy_radius = joy_size / 2.0
	var knob_size := 72.0 * s
	var interact_size := 120.0 * s
	var side_btn_size := 92.0 * s
	var margin := 34.0 * s

	_joy_base = _circle(joy_size, Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.4))
	_joy_base.anchor_left = 0; _joy_base.anchor_right = 0
	_joy_base.anchor_top = 1; _joy_base.anchor_bottom = 1
	_joy_base.offset_left = margin; _joy_base.offset_right = margin + joy_size
	_joy_base.offset_top = -(margin + joy_size + 20.0); _joy_base.offset_bottom = -(margin + 20.0)
	_root.add_child(_joy_base)

	_joy_knob = _circle(knob_size, Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.7))
	_joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_base.add_child(_joy_knob)
	_center_knob()

	_interact_btn = _circle(interact_size, Color(1, 0.819608, 0.4, 0.28), Color(1, 0.819608, 0.4, 0.75))
	_interact_btn.anchor_left = 1; _interact_btn.anchor_right = 1
	_interact_btn.anchor_top = 1; _interact_btn.anchor_bottom = 1
	_interact_btn.offset_left = -margin - interact_size; _interact_btn.offset_right = -margin
	_interact_btn.offset_top = -(margin + interact_size + 10.0); _interact_btn.offset_bottom = -(margin + 10.0)
	_label(_interact_btn, "E", 30.0 * s)
	_root.add_child(_interact_btn)

	# Chat + menu sit on the right edge, vertically centered, well clear of
	# both the top HUD row (wallet/chips/clock) and the interact button below.
	_chat_btn = _circle(side_btn_size, Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.4))
	_chat_btn.anchor_left = 1; _chat_btn.anchor_right = 1
	_chat_btn.anchor_top = 0.5; _chat_btn.anchor_bottom = 0.5
	_chat_btn.offset_left = -margin - side_btn_size; _chat_btn.offset_right = -margin
	_chat_btn.offset_top = -side_btn_size - 12.0; _chat_btn.offset_bottom = -12.0
	_label(_chat_btn, "CHAT", 13.0 * s)
	_root.add_child(_chat_btn)

	_menu_btn = _circle(side_btn_size, Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.4))
	_menu_btn.anchor_left = 1; _menu_btn.anchor_right = 1
	_menu_btn.anchor_top = 0.5; _menu_btn.anchor_bottom = 0.5
	_menu_btn.offset_left = -margin - side_btn_size; _menu_btn.offset_right = -margin
	_menu_btn.offset_top = 12.0; _menu_btn.offset_bottom = side_btn_size + 12.0
	_label(_menu_btn, "MENU", 13.0 * s)
	_root.add_child(_menu_btn)

func _label(parent: Control, text: String, font_size: float) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", int(round(font_size)))
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)

func _circle(size: float, fill: Color, ring: Color) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(size, size)
	c.size = Vector2(size, size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var r := size / 2.0
		c.draw_circle(Vector2(r, r), r, fill)
		c.draw_arc(Vector2(r, r), r - 1.5, 0, TAU, 48, ring, 3.0, true))
	return c

func _center_knob() -> void:
	_joy_knob.position = (_joy_base.size - _joy_knob.size) / 2.0

func _in_gameplay() -> bool:
	var cur := get_tree().current_scene
	return cur != null and GAMEPLAY_SCENES.has(cur.scene_file_path.get_file().get_basename())

func _process(_delta: float) -> void:
	if _root == null:
		return
	# Dialogue.is_open is checked alongside ui_blocked() everywhere else too:
	# the dialogue box doesn't take a ui_blockers slot, so without this the
	# joystick stays live and you can walk off mid-conversation.
	var in_game := _in_gameplay() and not Dialogue.is_open and not global.ui_blocked()
	_root.visible = in_game
	if not in_game:
		_release_joystick()
		_release_interact()

func _input(event: InputEvent) -> void:
	if _root == null or not _root.visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_touch_down(event.index, event.position)
		else:
			_on_touch_up(event.index)
	elif event is InputEventScreenDrag and event.index == _joy_touch_index:
		_update_joystick(event.position)
		get_viewport().set_input_as_handled()

func _hits(c: Control, pos: Vector2, slop: float = 1.0) -> bool:
	return pos.distance_to(c.global_position + c.size / 2.0) <= c.size.x / 2.0 * slop

func _on_touch_down(index: int, pos: Vector2) -> void:
	if _joy_touch_index == -1 and _hits(_joy_base, pos, 1.6):
		_joy_touch_index = index
		_joy_center = _joy_base.global_position + _joy_base.size / 2.0
		_update_joystick(pos)
		get_viewport().set_input_as_handled()
	elif _interact_touch_index == -1 and _hits(_interact_btn, pos, 1.2):
		_interact_touch_index = index
		_press_interact()
		get_viewport().set_input_as_handled()
	elif _hits(_chat_btn, pos, 1.2):
		ChatHud._open_input()
		get_viewport().set_input_as_handled()
	elif _hits(_menu_btn, pos, 1.2):
		PauseMenu.pause_game()
		get_viewport().set_input_as_handled()

func _on_touch_up(index: int) -> void:
	if index == _joy_touch_index:
		_release_joystick()
		get_viewport().set_input_as_handled()
	elif index == _interact_touch_index:
		_release_interact()
		get_viewport().set_input_as_handled()

func _update_joystick(pos: Vector2) -> void:
	var delta := pos - _joy_center
	var mag := minf(delta.length(), _joy_radius)
	var dir := delta.normalized() if delta.length() > 0.001 else Vector2.ZERO
	_joy_knob.position = (_joy_base.size - _joy_knob.size) / 2.0 + dir * mag
	var strength := dir * (mag / _joy_radius)
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

func _release_joystick() -> void:
	_joy_touch_index = -1
	_center_knob()
	for action in MOVE_ACTIONS.values():
		Input.action_release(action)

func _press_interact() -> void:
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)

func _release_interact() -> void:
	if _interact_touch_index == -1 and not Input.is_action_pressed("interact"):
		return
	_interact_touch_index = -1
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = false
	Input.parse_input_event(ev)
