extends CanvasLayer

const THEME := preload("res://themes/main_theme.tres")
const GAMEPLAY_SCENES := ["village", "open_world", "house_interior", "shop_interior"]
const MAP_SIZE := 132.0
const WORLD_SCALE := 0.22
const MARGIN := 12.0
# Hard offset shadow (no blur), matching the rest of the shell's
# neo-brutalist drop-shadow convention instead of a soft blurred one.
const SHADOW_OFFSET := 4.0
const SHADOW_COLOR := Color(0, 0, 0, 0.4)
const COLOR_SELF := Color(1, 0.819608, 0.4)
const COLOR_OTHER := Color(0.290196, 0.870588, 0.501961)
const COLOR_NPC := Color(0.62, 0.58, 0.5)
const COLOR_BG := Color(0.039216, 0.031373, 0.019608, 1.0)

# Ornate gold frame drawn around the map instead of the old 1px hairline.
# The art is 64x64 with 4px of transparent padding, corner ornaments running
# ~17px in, and plain rails between them, so it's a nine-patch: the corners
# stay at native pixel size and only the rails stretch. Patch margins have to
# sit inside the uniform rail region (rows 16-46) or the ornaments smear.
const FRAME_TEX := preload("res://assets/ui/minimap_frame.png")
const FRAME_PATCH := 17
# Distance from the texture's outer edge to the inner opening (4px padding +
# ~7px of rail). The frame is grown by this much on every side so the map
# stays fully visible inside the opening rather than being cropped by it.
const FRAME_INSET := 11.0
# Transparent padding baked into each edge of the source art.
const FRAME_PAD := 4.0

var _root: Control
var _map: Control

func _ready() -> void:
	layer = 95
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = THEME
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)

	# Top-right, sized to fit the map plus the frame around it plus the
	# shadow's offset, so none of the three gets clipped by the display
	# container's own bounds. The map sits FRAME_INSET in from the top-left
	# so the frame can hang outside it on every side.
	var widget := MAP_SIZE + FRAME_INSET * 2.0
	var display := Control.new()
	display.custom_minimum_size = Vector2(widget + SHADOW_OFFSET, widget + SHADOW_OFFSET)
	display.anchor_left = 1.0
	display.anchor_right = 1.0
	display.offset_left = -(MARGIN + widget + SHADOW_OFFSET)
	display.offset_right = -MARGIN
	display.offset_top = MARGIN
	display.offset_bottom = MARGIN + widget + SHADOW_OFFSET
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(display)

	# Shadow tracks the frame's visible edge, not the texture's bounds, or it
	# would stick out by the 4px of transparent padding on each side.
	var shadow_size := widget - FRAME_PAD * 2.0
	var shadow := Control.new()
	shadow.position = Vector2(FRAME_PAD + SHADOW_OFFSET, FRAME_PAD + SHADOW_OFFSET)
	shadow.custom_minimum_size = Vector2(shadow_size, shadow_size)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.draw.connect(func(): shadow.draw_rect(Rect2(Vector2.ZERO, Vector2(shadow_size, shadow_size)), SHADOW_COLOR))
	display.add_child(shadow)

	# The map content is drawn into a SubViewport and displayed through a
	# TextureRect. The viewport is square and unmasked, so the terrain fills
	# the whole widget out to the corners.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(MAP_SIZE), int(MAP_SIZE))
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	display.add_child(viewport)

	_map = Control.new()
	_map.custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.draw.connect(_draw_map)
	viewport.add_child(_map)

	var tex_rect := TextureRect.new()
	tex_rect.position = Vector2(FRAME_INSET, FRAME_INSET)
	tex_rect.custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)
	tex_rect.texture = viewport.get_texture()
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.add_child(tex_rect)

	# Added last so it sits over the map's outer edge and hides the seam.
	var frame := NinePatchRect.new()
	frame.texture = FRAME_TEX
	frame.position = Vector2.ZERO
	frame.size = Vector2(widget, widget)
	frame.custom_minimum_size = Vector2(widget, widget)
	frame.patch_margin_left = FRAME_PATCH
	frame.patch_margin_top = FRAME_PATCH
	frame.patch_margin_right = FRAME_PATCH
	frame.patch_margin_bottom = FRAME_PATCH
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.add_child(frame)

func _process(_delta: float) -> void:
	var show := _in_gameplay() and not global.ui_blocked()
	_root.visible = show
	if show:
		_map.queue_redraw()

func _draw_map() -> void:
	var full := Rect2(Vector2.ZERO, Vector2(MAP_SIZE, MAP_SIZE))
	var center := Vector2(MAP_SIZE, MAP_SIZE) / 2.0
	_map.draw_rect(full, COLOR_BG)
	var world := get_tree().current_scene
	if world == null or not "remote_players" in world:
		return
	var me = world.get("_local_player")
	if me == null or not is_instance_valid(me):
		return
	var origin: Vector2 = me.global_position
	_draw_terrain(MapData.scene_key(world), origin, full)
	for child in world.get_children():
		if child is CharacterBody2D and child.has_method("npc_id"):
			_draw_dot(center + (child.global_position - origin) * WORLD_SCALE, COLOR_NPC, 2.0)
	var remotes: Dictionary = world.get("remote_players")
	for uid in remotes:
		var rp = remotes[uid]
		if is_instance_valid(rp):
			_draw_dot(center + (rp.global_position - origin) * WORLD_SCALE, COLOR_OTHER, 3.0)
	_draw_dot(center, COLOR_SELF, 3.0)

# Terrain under the dots, cut out of the PNG that scripts/tools/bake_world_map.gd
# renders. No-op until that has been run, which leaves the old flat-rect minimap.
func _draw_terrain(key: String, origin: Vector2, dest: Rect2) -> void:
	if key == "":
		return
	var tex := MapData.texture(key)
	if tex == null:
		return
	var img_scale := MapData.image_scale(key)
	if img_scale == Vector2.ZERO:
		return
	# The minimap shows MAP_SIZE screen px at WORLD_SCALE, so it covers this many
	# world px in each direction from the player.
	var half_world := (MAP_SIZE * 0.5) / WORLD_SCALE
	var top_left := MapData.world_to_image(key, origin - Vector2(half_world, half_world))
	_map.draw_texture_rect_region(tex, dest, Rect2(top_left, Vector2(half_world, half_world) * 2.0 * img_scale))

func _draw_dot(pos: Vector2, color: Color, half: float) -> void:
	# Pin off-screen players to the edge. Square widget, so each axis clamps on
	# its own rather than against a radius.
	var edge := 5.0
	pos.x = clampf(pos.x, edge, MAP_SIZE - edge)
	pos.y = clampf(pos.y, edge, MAP_SIZE - edge)
	_map.draw_rect(Rect2(pos - Vector2(half, half), Vector2(half, half) * 2.0), color)

func _in_gameplay() -> bool:
	var cur := get_tree().current_scene
	return cur != null and GAMEPLAY_SCENES.has(cur.scene_file_path.get_file().get_basename())
