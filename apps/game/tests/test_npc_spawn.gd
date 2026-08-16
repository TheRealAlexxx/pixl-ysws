extends SceneTree
# Headless unit test for the NPC data contract. Run:
#   godot --headless --path . --script res://tests/test_npc_spawn.gd
#
# multiplayer_world.gd's _add_npc() reads a fixed set of keys off each row,
# whether the row came from /api/npcs or the res://npcs.json bake. If the bake
# drifts from that set (a column renamed, `bun run npcs:bake` not re-run after a
# schema change) an offline player silently gets NPCs with default names, no
# skin, and no dialogue. This asserts the two stay in step.

const FALLBACK := "res://npcs.json"

# Every key _add_npc() reads. Keep in sync with multiplayer_world.gd.
const REQUIRED := [
	"npc_name", "pos_x", "pos_y", "skin", "custom_hair", "custom_sheet", "dialogue",
	"opens_projects", "opens_explore", "quest_project", "faq", "quest_trial",
	"trial_checkin", "trial_name", "quest_offer", "quest_done", "trial_reminder",
	"wanders", "speed", "wander_radius", "min_wait", "max_wait",
]

var _fail := 0

func _initialize() -> void:
	_run()

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok  ", msg)
	else:
		_fail += 1
		printerr("  FAIL ", msg)

func _run() -> void:
	print("npc spawn data contract")

	check(FileAccess.file_exists(FALLBACK), "%s exists" % FALLBACK)
	if not FileAccess.file_exists(FALLBACK):
		return _finish()

	var json = JSON.parse_string(FileAccess.get_file_as_string(FALLBACK))
	check(typeof(json) == TYPE_DICTIONARY, "bake parses as a dictionary")
	if typeof(json) != TYPE_DICTIONARY:
		return _finish()

	# The two worlds that call spawn_world_npcs().
	for world in ["village", "open_world"]:
		var rows = json.get(world, null)
		check(typeof(rows) == TYPE_ARRAY, "%s is an array" % world)
		if typeof(rows) != TYPE_ARRAY:
			continue
		check(rows.size() > 0, "%s has at least one NPC" % world)

		var names := {}
		for row in rows:
			if typeof(row) != TYPE_DICTIONARY:
				check(false, "%s row is a dictionary" % world)
				continue
			var who := String(row.get("npc_name", "?"))

			var missing: Array = []
			for key in REQUIRED:
				if not row.has(key):
					missing.append(key)
			check(missing.is_empty(), "%s/%s has every key _add_npc reads%s" % [
				world, who, "" if missing.is_empty() else " (missing: %s)" % ", ".join(missing),
			])

			# npc_id() returns npc_name, and the server's saved-position sync keys
			# off it, so a duplicate within one world means two NPCs fighting over
			# the same stored position.
			check(not names.has(who), "%s/%s name is unique in its world" % [world, who])
			names[who] = true

			check(SkinUtil.is_valid(String(row.get("skin", ""))),
				"%s/%s skin %s is a skin SkinUtil can resolve" % [world, who, row.get("skin", "")])

			# A check-in copy is spawned hidden and revealed once its Trial is
			# active; without a Trial to match it can never appear at all.
			if bool(row.get("trial_checkin", false)):
				check(bool(row.get("quest_trial", false)),
					"%s/%s is a check-in copy and so must also be quest_trial" % [world, who])

	_finish()

func _finish() -> void:
	if _fail == 0:
		print("all npc spawn checks passed")
	else:
		printerr("%d check(s) failed" % _fail)
	quit(1 if _fail > 0 else 0)
