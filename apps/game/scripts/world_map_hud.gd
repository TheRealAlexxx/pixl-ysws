extends CanvasLayer

const GAMEPLAY_SCENES := ["village", "open_world", "house_interior", "shop_interior"]
const COLOR_ACCENT := Color(1, 0.819608, 0.4)
const COLOR_DIM := Color(0.788235, 0.694118, 0.54902)
const COLOR_MARKER := Color(1, 0.85, 0.1)

# Hand-authored hotspots: region name (must match sidequests.region in the
# dashboard) -> fractional position on the map panel. These were placed against
# the old flat placeholder, so they need re-tuning once the terrain bake exists -
# the regions are real places on the image now, not evenly spaced guesses.
const REGIONS := {
	"The Hub": Vector2(0.28, 0.62),
	"Dustline": Vector2(0.68, 0.32),
}

# Interiors (house/shop) are rooms inside the overworld and have no bake of
# their own, so they fall back to it. The village does have its own bake, so
# standing in it shows the village rather than the overworld it sits in.
const FALLBACK_MAP_KEY := "open_world"

func _map_key() -> String:
	var cur := get_tree().current_scene
	if cur == null:
		return FALLBACK_MAP_KEY
	var key := MapData.scene_key(cur)
	return key if MapData.has(key) else FALLBACK_MAP_KEY
const COLOR_SELF := Color(1, 0.819608, 0.4)

var _root: Control
var _map_panel: Control
var _map_art: Control
var _detail_panel: PanelContainer
var _detail_title: Label
var _detail_body: RichTextLabel
var _markers: Dictionary = {}
var _open := false
var _quests_by_region: Dictionary = {}

func _ready() -> void:
	layer = 105
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_root.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_M:
		if ChatHud.is_typing() or Dialogue.is_open or (not _open and global.ui_blocked()):
			return
		_toggle()
		get_viewport().set_input_as_handled()
	elif _open and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	if _open:
		close()
		return
	var current := get_tree().current_scene
	if current and GAMEPLAY_SCENES.has(current.scene_file_path.get_file().get_basename()):
		open()

func is_open() -> bool:
	return _open

func open() -> void:
	if _open:
		return
	_open = true
	global.push_ui_blocker()
	_root.visible = true
	_detail_panel.visible = false
	# The map is modal and blocks movement, so one redraw on open is enough to
	# keep the "you are here" dot honest.
	_map_art.queue_redraw()
	_refresh_markers()

func close() -> void:
	if not _open:
		return
	_open = false
	global.pop_ui_blocker()
	_root.visible = false

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.039216, 0.023529, 0.007843, 0.78)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 10)
	center.add_child(wrap)

	var title := Label.new()
	title.text = "MAP"
	title.add_theme_color_override("font_color", COLOR_ACCENT)
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(title)

	var map_frame := PanelContainer.new()
	map_frame.custom_minimum_size = Vector2(720, 480)
	wrap.add_child(map_frame)

	_map_panel = Control.new()
	_map_panel.custom_minimum_size = Vector2(720, 480)
	map_frame.add_child(_map_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.13, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_panel.add_child(bg)

	# Terrain + "you are here", under the hotspot buttons added below.
	_map_art = Control.new()
	_map_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_art.draw.connect(_draw_art)
	_map_panel.add_child(_map_art)

	var hint := Label.new()
	hint.text = "Press M to close"
	hint.theme_type_variation = &"InfoText"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(hint)

	for region_name in REGIONS.keys():
		_add_hotspot(region_name, REGIONS[region_name])

	_build_detail_panel()

# Draws the terrain baked by scripts/tools/bake_world_map.gd, letterboxed to keep
# the world's aspect ratio, plus the player's position on it. Silently draws
# nothing until that bake has been run, leaving the plain dark panel behind it.
func _draw_art() -> void:
	var key := _map_key()
	var tex := MapData.texture(key)
	if tex == null:
		return
	var art := _fit(Vector2(tex.get_size()), _map_art.size)
	_map_art.draw_texture_rect(tex, art, false)

	var world := get_tree().current_scene
	if world == null or MapData.scene_key(world) != key:
		return
	var me = world.get("_local_player")
	if me == null or not is_instance_valid(me):
		return
	var frac := MapData.world_to_image(key, me.global_position) / Vector2(tex.get_size())
	var at := art.position + frac * art.size
	_map_art.draw_rect(Rect2(at - Vector2(4, 4), Vector2(8, 8)), COLOR_SELF)
	_map_art.draw_rect(Rect2(at - Vector2(4, 4), Vector2(8, 8)), Color.BLACK, false, 1.0)

# Largest centred rect of the given aspect that fits inside the panel.
func _fit(tex_size: Vector2, panel: Vector2) -> Rect2:
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return Rect2(Vector2.ZERO, panel)
	var scale := minf(panel.x / tex_size.x, panel.y / tex_size.y)
	var size := tex_size * scale
	return Rect2((panel - size) * 0.5, size)

func _add_hotspot(region_name: String, frac: Vector2) -> void:
	var hotspot := Button.new()
	hotspot.text = region_name
	hotspot.flat = true
	hotspot.custom_minimum_size = Vector2(140, 40)
	hotspot.anchor_left = frac.x
	hotspot.anchor_right = frac.x
	hotspot.anchor_top = frac.y
	hotspot.anchor_bottom = frac.y
	hotspot.offset_left = -70.0
	hotspot.offset_right = 70.0
	hotspot.offset_top = -20.0
	hotspot.offset_bottom = 20.0
	hotspot.add_theme_color_override("font_color", Color.WHITE)
	hotspot.pressed.connect(_show_detail.bind(region_name))
	_map_panel.add_child(hotspot)

	var marker := ColorRect.new()
	marker.color = COLOR_MARKER
	marker.custom_minimum_size = Vector2(10, 10)
	marker.size = Vector2(10, 10)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.anchor_left = frac.x
	marker.anchor_right = frac.x
	marker.anchor_top = frac.y
	marker.anchor_bottom = frac.y
	marker.offset_left = 68.0
	marker.offset_right = 78.0
	marker.offset_top = -26.0
	marker.offset_bottom = -16.0
	marker.visible = false
	_map_panel.add_child(marker)
	_markers[region_name] = marker

func _build_detail_panel() -> void:
	_detail_panel = PanelContainer.new()
	_detail_panel.custom_minimum_size = Vector2(360, 200)
	_detail_panel.set_anchors_preset(Control.PRESET_CENTER)
	_detail_panel.anchor_left = 0.5
	_detail_panel.anchor_right = 0.5
	_detail_panel.anchor_top = 0.5
	_detail_panel.anchor_bottom = 0.5
	_detail_panel.offset_left = -180.0
	_detail_panel.offset_right = 180.0
	_detail_panel.offset_top = -100.0
	_detail_panel.offset_bottom = 100.0
	_detail_panel.visible = false
	_root.add_child(_detail_panel)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	_detail_panel.add_child(body)

	_detail_title = Label.new()
	_detail_title.add_theme_color_override("font_color", COLOR_ACCENT)
	_detail_title.add_theme_font_size_override("font_size", 18)
	body.add_child(_detail_title)

	_detail_body = RichTextLabel.new()
	_detail_body.bbcode_enabled = true
	_detail_body.fit_content = true
	_detail_body.custom_minimum_size = Vector2(340, 130)
	body.add_child(_detail_body)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): _detail_panel.visible = false)
	body.add_child(close_btn)

func _show_detail(region_name: String) -> void:
	_detail_title.text = region_name
	var quests: Array = _quests_by_region.get(region_name, [])
	if quests.is_empty():
		_detail_body.text = "No available Trials here right now."
	else:
		var lines := []
		for q in quests:
			lines.append("[b]%s[/b] (%s)\n%s" % [q.get("name", ""), q.get("npc", ""), q.get("description", "")])
		_detail_body.text = "\n\n".join(lines)
	_detail_panel.visible = true

# Pull /api/sidequests and mark any region with an unlocked-but-incomplete
# Trial with a yellow dot. Same fetch/response shape as npc.gd's
# _fetch_sidequests - kept local since HUD autoloads don't share NPC state.
func _refresh_markers() -> void:
	_quests_by_region.clear()
	for m in _markers.values():
		m.visible = false
	if NetworkManager.session_token == "":
		return
	var req := HTTPRequest.new()
	add_child(req)
	var url := NetworkManager.SERVER_HTTP_URL + "/api/sidequests?token=" + NetworkManager.session_token.uri_encode()
	if req.request(url) != OK:
		req.queue_free()
		return
	var r: Array = await req.request_completed
	req.queue_free()
	if int(r[1]) != 200 or (r[3] as PackedByteArray).size() == 0:
		return
	var json = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())
	if typeof(json) != TYPE_DICTIONARY or not json.get("ok", false):
		return
	var quests = json.get("quests", [])
	if typeof(quests) != TYPE_ARRAY:
		return
	for q in quests:
		var available := bool(q.get("unlocked", false)) and not bool(q.get("completed", false))
		if not available:
			continue
		var region := String(q.get("region", ""))
		if not _quests_by_region.has(region):
			_quests_by_region[region] = []
		_quests_by_region[region].append(q)
		if _markers.has(region):
			_markers[region].visible = true
