class_name PixlTheme
extends RefCounted

## Reads res://theme.json - the copy of packages/theme/palette.json's "godot"
## value set that `bun run theme:sync` writes into this project. Mirrors
## PixlConfig's shape (see pixl_config.gd) for the same reason: the game runs
## from an exported PCK and cannot import a workspace package at runtime.
##
## Edit packages/theme/palette.json and re-run the sync - never edit
## res://theme.json.
##
## Only "dark" exists here. The game has no light-mode design yet, so color()
## silently falls back to dark values whenever the synced theme is "light" -
## see packages/theme/README.md for why that's the right call for now.

const PATH := "res://theme.json"
const MAIN_THEME := preload("res://themes/main_theme.tres")

## Loud and impossible to miss in-game, unlike silently returning black.
const UNKNOWN_TOKEN_COLOR := Color(1, 0, 1)

static var _data: Dictionary = {}
static var _loaded := false

static func color(token: String) -> Color:
	_load()
	var themed: Dictionary = _data.get("dark", {})
	if not themed.has(token):
		push_warning("[PixlTheme] unknown token '%s'" % token)
		return UNKNOWN_TOKEN_COLOR
	return Color(String(themed[token]))

static func current() -> String:
	return Settings.theme_name

## Boot-time entry point: picks up a theme choice already made on the web
## shell (same localStorage key, read once at startup like pixl.js does),
## falling back to whatever was last saved locally.
static func boot() -> void:
	if OS.has_feature("web"):
		var stored = JavaScriptBridge.eval("localStorage.getItem('pixl_theme')", true)
		if typeof(stored) == TYPE_STRING and stored != "":
			Settings.theme_name = stored
	apply()

static func set_theme(name: String) -> void:
	Settings.set_theme_name(name)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("localStorage.setItem('pixl_theme', '%s')" % name, true)
	apply()

## Repaints the one shared main_theme.tres resource in place - every scene
## that preloads it (there are about fifteen) picks up the change immediately,
## no reassignment needed. Only the subset of styleboxes/colors that are
## exact matches to a token are touched; borders that don't correspond to any
## shared token (the near-black pixel-art outline used everywhere) are left
## alone deliberately, see the theme-system plan notes.
static func apply() -> void:
	_load()
	var gold := color("gold")
	var gold_soft := color("gold-soft")
	var ink := color("ink")
	var panel := color("panel")
	var panel_deep := color("panel-deep")
	var btn_ink := color("btn-ink")

	var btn_normal: StyleBoxFlat = MAIN_THEME.get_stylebox("normal", "Button")
	btn_normal.bg_color = gold
	_tint_shadow(btn_normal, ink)

	var btn_hover: StyleBoxFlat = MAIN_THEME.get_stylebox("hover", "Button")
	btn_hover.bg_color = gold_soft
	_tint_shadow(btn_hover, ink)

	var btn_pressed: StyleBoxFlat = MAIN_THEME.get_stylebox("pressed", "Button")
	btn_pressed.bg_color = gold_soft
	_tint_shadow(btn_pressed, ink)

	var btn_disabled: StyleBoxFlat = MAIN_THEME.get_stylebox("disabled", "Button")
	btn_disabled.bg_color = Color(gold, btn_disabled.bg_color.a)
	_tint_shadow(btn_disabled, ink)

	var btn_focus: StyleBoxFlat = MAIN_THEME.get_stylebox("focus", "Button")
	btn_focus.border_color = gold

	var panel_box: StyleBoxFlat = MAIN_THEME.get_stylebox("panel", "Panel")
	panel_box.bg_color = panel
	var panel_container_box: StyleBoxFlat = MAIN_THEME.get_stylebox("panel", "PanelContainer")
	panel_container_box.bg_color = panel

	var input_normal: StyleBoxFlat = MAIN_THEME.get_stylebox("normal", "LineEdit")
	input_normal.bg_color = panel_deep
	var input_focus: StyleBoxFlat = MAIN_THEME.get_stylebox("focus", "LineEdit")
	input_focus.bg_color = panel_deep
	input_focus.border_color = gold
	var text_normal: StyleBoxFlat = MAIN_THEME.get_stylebox("normal", "TextEdit")
	text_normal.bg_color = panel_deep
	var text_focus: StyleBoxFlat = MAIN_THEME.get_stylebox("focus", "TextEdit")
	text_focus.bg_color = panel_deep
	text_focus.border_color = gold

	for name in ["font_color", "font_disabled_color", "font_focus_color", "font_hover_color", "font_hover_pressed_color", "font_pressed_color"]:
		var c: Color = MAIN_THEME.get_color(name, "Button")
		MAIN_THEME.set_color(name, "Button", Color(btn_ink, c.a))

	MAIN_THEME.set_color("font_color", "Label", ink)

static func _tint_shadow(box: StyleBoxFlat, ink: Color) -> void:
	box.shadow_color = Color(ink, box.shadow_color.a)

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		push_warning("[PixlTheme] %s missing - run `bun run theme:sync`" % PATH)
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		_data = parsed
	else:
		push_warning("[PixlTheme] %s is malformed" % PATH)
