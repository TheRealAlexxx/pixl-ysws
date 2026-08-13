extends Area2D

const MONOCRAFT := preload("res://assets/fonts/Monocraft.ttf")

@export var speaker: String = "Boat"
@export_multiline var dialogue_text: String = "Oh it has a note! It says - other regions like cyberpunk coming soon! come here again in some time and check again!"
@export var prompt_y: float = -34.0
## Leave empty for the "coming soon" note. Set to a Marker2D in this scene
## (e.g. "../FarwestSpawn") to teleport the local player there on interact
## instead of opening the dialogue.
@export var target_marker: NodePath = NodePath("")

var _player_near := false
var _player_body: Node2D
var _prompt: Label

func _ready() -> void:
	_prompt = Label.new()
	_prompt.z_index = 30
	_prompt.text = "[%s]" % _interact_key_label()
	_prompt.add_theme_font_override("font", MONOCRAFT)
	_prompt.add_theme_font_size_override("font_size", 24)
	_prompt.add_theme_color_override("font_color", Color(1, 0.819608, 0.4))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.scale = Vector2.ONE / 3.5
	_prompt.visible = false
	add_child(_prompt)
	_prompt.reset_size()

func _interact_key_label() -> String:
	for e in InputMap.action_get_events("interact"):
		if e is InputEventKey:
			var kc: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
			return OS.get_keycode_string(kc)
	return "E"

func _process(_delta: float) -> void:
	var show := _player_near and not Dialogue.is_open and not ChatHud.is_typing()
	_prompt.visible = show
	if show:
		var bob := sin(Time.get_ticks_msec() / 150.0) * 2.0
		_prompt.position = Vector2(round(-_prompt.size.x * _prompt.scale.x / 2.0), round(prompt_y + bob))

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("player") and body.is_local:
		_player_near = true
		_player_body = body

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("player") and body.is_local:
		_player_near = false

func _unhandled_input(event: InputEvent) -> void:
	if not _player_near or Dialogue.is_open or ChatHud.is_typing():
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if target_marker != NodePath(""):
			_teleport()
		else:
			Dialogue.open(speaker, [dialogue_text])

func _teleport() -> void:
	var marker := get_node_or_null(target_marker)
	if marker == null or not is_instance_valid(_player_body):
		Dialogue.open(speaker, [dialogue_text])
		return
	_player_body.global_position = marker.global_position
