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
## There is one set, "paper": the landing site's cream-and-black look, the same
## one the web shell and docs run. It replaced the old LEDGER gold-on-charcoal
## on 2026-08-17. Theme switching is kept wired up but has nothing to switch
## between right now, so every lookup resolves against SET.

const PATH := "res://theme.json"
## The one value set in theme.json. Adding a second means keying this off
## Settings.theme_name instead of a constant.
const SET := "paper"
const MAIN_THEME := preload("res://themes/main_theme.tres")

## Loud and impossible to miss in-game, unlike silently returning black.
const UNKNOWN_TOKEN_COLOR := Color(1, 0, 1)

static var _data: Dictionary = {}
static var _loaded := false

static func color(token: String) -> Color:
	_load()
	var themed: Dictionary = _data.get(SET, {})
	if not themed.has(token):
		push_warning("[PixlTheme] unknown token '%s'" % token)
		return UNKNOWN_TOKEN_COLOR
	return Color(String(themed[token]))

static func current() -> String:
	return Settings.theme_name

## Boot-time entry point: picks up a theme choice already made on the web
## shell (same localStorage key, read once at startup like pixl.js does),
## falling back to whatever was last saved locally. The key is versioned and
## must match the one in apps/game/web/pixl.js - bumping it there is how a
## look is forced onto people who already picked something.
const STORAGE_KEY := "pixl_theme_v2"

static func boot() -> void:
	if OS.has_feature("web"):
		var stored = JavaScriptBridge.eval("localStorage.getItem('%s')" % STORAGE_KEY, true)
		if typeof(stored) == TYPE_STRING and stored != "":
			Settings.theme_name = stored
	apply()

static func set_theme(name: String) -> void:
	Settings.set_theme_name(name)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("localStorage.setItem('%s', '%s')" % [STORAGE_KEY, name], true)
	apply()

## Every label color the theme defines, so a repaint can't leave one behind.
const _BUTTON_FONT_COLORS := [
	"font_color", "font_disabled_color", "font_focus_color",
	"font_hover_color", "font_hover_pressed_color", "font_pressed_color",
]

## Repaints the one shared main_theme.tres resource in place - every scene
## that preloads it (there are about fifteen) picks up the change immediately,
## no reassignment needed.
##
## This has to cover the WHOLE resource, not just the base controls. The .tres
## still holds the old gold-on-brown values, and most of its type variations
## (GreyButton, StepButton, SubText, TextEdit, ...) bake a pale cream label
## meant to sit on a dark panel. Repainting only the base types would leave
## that pale text on the new cream surfaces, i.e. invisible. Anything with a
## baked color is therefore re-derived from a token here.
static func apply() -> void:
	_load()
	var gold := color("gold")
	var gold_soft := color("gold-soft")
	var accent := color("accent")
	var ink := color("ink")
	var dim := color("dim")
	var panel := color("panel")
	var panel_2 := color("panel-2")
	var panel_deep := color("panel-deep")
	var btn_ink := color("btn-ink")
	var good := color("good")

	# Filled action buttons: orange face, cream label. Both variations share the
	# recipe and differ only in size.
	for variation in ["Button", "SmallButton"]:
		_paint(variation, "normal", gold, ink)
		_paint(variation, "hover", gold_soft, ink)
		_paint(variation, "pressed", gold_soft, ink)
		_paint(variation, "disabled", gold, ink)
		_set_colors(variation, _BUTTON_FONT_COLORS, btn_ink)
	# focus is an outline over the face, so it only gets a rule
	_paint_border("Button", "focus", accent)

	# Secondary buttons: the deeper cream, dark label. These were mid-brown with
	# pale text, which is the pairing that breaks hardest on paper.
	for variation in ["GreyButton", "StepButton"]:
		_paint(variation, "normal", panel_2, ink)
		_paint(variation, "hover", panel_2, ink)
		_paint(variation, "pressed", panel_2, ink)
		_set_colors(variation, _BUTTON_FONT_COLORS, ink)

	_paint("Panel", "panel", panel, ink)
	_paint("PanelContainer", "panel", panel, ink)
	# The title plate is a filled block like a button, so it takes button ink.
	_paint("TitlePlate", "panel", gold, ink)
	MAIN_THEME.set_color("font_color", "TitlePlateText", btn_ink)

	# Text entry sits on the page tone so it reads as a well, with the rule
	# doing the work and the accent marking focus.
	for variation in ["LineEdit", "TextEdit"]:
		_paint(variation, "normal", panel_deep, ink)
		_paint(variation, "focus", panel_deep, accent)
		_set_colors(variation, ["font_color", "font_selected_color"], ink)
		_set_colors(variation, ["font_placeholder_color"], dim)
		_set_colors(variation, ["caret_color"], accent)
		_set_colors(variation, ["selection_color"], gold)

	_set_colors("CheckButton", ["font_color", "font_hover_color", "font_pressed_color"], ink)
	_paint("CheckButton", "hover", panel_2, ink)

	MAIN_THEME.set_color("font_color", "Label", ink)
	# Headings are ink now rather than gold: orange type on cream is the one
	# combination in this palette that genuinely can't be read.
	MAIN_THEME.set_color("font_color", "TitleText", ink)
	MAIN_THEME.set_color("font_color", "SubText", dim)
	MAIN_THEME.set_color("font_color", "InfoText", dim)
	MAIN_THEME.set_color("font_color", "FooterText", dim)
	MAIN_THEME.set_color("font_color", "StatusText", good)

	# Sliders, scrollbars and list rows. The grabber states all point at ONE
	# shared sub-resource in the .tres, so they're painted once: giving them a
	# state-by-state treatment here would just be last-write-wins on the same
	# object. Same story for the slider fill.
	_paint("HSlider", "grabber_area", gold, ink)
	_paint("HSlider", "slider", panel_2, ink)
	_paint("VScrollBar", "grabber", gold, ink)
	_paint("VScrollBar", "scroll", panel_2, ink)
	_paint("RowPanel", "panel", panel_2, ink)

## Repaints one stylebox: face, rule and the hard shadow behind it. Alpha is
## always preserved, several boxes are deliberately translucent. Missing
## entries are skipped rather than pushing an error, the theme doesn't define
## every state for every variation.
static func _paint(variation: String, state: String, bg: Color, border: Color) -> void:
	if not MAIN_THEME.has_stylebox(state, variation):
		return
	var box := MAIN_THEME.get_stylebox(state, variation) as StyleBoxFlat
	if box == null:
		return
	box.bg_color = Color(bg, box.bg_color.a)
	box.border_color = Color(border, box.border_color.a)
	box.shadow_color = Color(border, box.shadow_color.a)

static func _paint_border(variation: String, state: String, border: Color) -> void:
	if not MAIN_THEME.has_stylebox(state, variation):
		return
	var box := MAIN_THEME.get_stylebox(state, variation) as StyleBoxFlat
	if box == null:
		return
	box.border_color = Color(border, box.border_color.a)

static func _set_colors(variation: String, names: Array, c: Color) -> void:
	for name in names:
		if not MAIN_THEME.has_color(name, variation):
			continue
		var existing: Color = MAIN_THEME.get_color(name, variation)
		MAIN_THEME.set_color(name, variation, Color(c, existing.a))

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
