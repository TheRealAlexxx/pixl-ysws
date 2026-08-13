extends Node

const PLAYER_SCENE = preload("res://scenes/player.tscn")

var current_scene: String = "village"
var transition_scene: bool = false
var spawn_point: String = "PlayerSpawn"
var player_in_range: bool = false
var active_door_pos: Vector2 = Vector2.ZERO
var active_door_target: String = "house"
var house_variant: int = 0

var editor_return_scene: String = "res://scenes/main_menu.tscn"

var ui_blockers: int = 0

# Minecraft-style hide-HUD toggle (F2, since F1 is already guide_hud's help
# panel): hides the always-on overlays (stats bar, minimap, chat, emotes) so
# screenshots aren't cluttered. Mac keyboards map bare F-keys to system
# functions (brightness etc.) by default, so F2 never reaches the app there;
# Cmd+H is the Mac-only alternate binding for the same toggle.
var hud_hidden: bool = false

func push_ui_blocker() -> void:
	ui_blockers += 1

func pop_ui_blocker() -> void:
	ui_blockers = maxi(0, ui_blockers - 1)

func ui_blocked() -> bool:
	return ui_blockers > 0

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var is_toggle_key := event.keycode == KEY_F2
	if OS.get_name() == "macOS":
		is_toggle_key = is_toggle_key or (event.keycode == KEY_H and event.meta_pressed)
	if not is_toggle_key:
		return
	if ChatHud.is_typing() or Dialogue.is_open or ui_blocked():
		return
	hud_hidden = not hud_hidden
	MinimapHud.visible = not hud_hidden
	EmoteHud.visible = not hud_hidden
	PlayerHud.visible = not hud_hidden
	get_viewport().set_input_as_handled()

func day_phase() -> Dictionary:
	var td := Time.get_time_dict_from_system()
	var h := float(td.hour) + float(td.minute) / 60.0
	if h < 5.0 or h >= 21.0:
		return {"name": "Night", "next": "dawn 05:00", "color": Color(0.55, 0.62, 0.95)}
	if h < 7.0:
		return {"name": "Dawn", "next": "day 07:00", "color": Color(1.0, 0.65, 0.35)}
	if h < 17.0:
		return {"name": "Day", "next": "dusk 17:00", "color": Color(1, 0.819608, 0.4)}
	return {"name": "Dusk", "next": "night 21:00", "color": Color(1.0, 0.65, 0.35)}

func request_transition(target_scene: String, spawn_name: String = "PlayerSpawn") -> void:
	transition_scene = true
	current_scene = target_scene
	spawn_point = spawn_name
