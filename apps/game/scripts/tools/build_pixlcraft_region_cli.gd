extends SceneTree

const PixlcraftRegionBuilder = preload("res://scripts/tools/pixlcraft_region_builder.gd")

## Terminal entry point for PixlcraftRegionBuilder, for rebuilding the region
## without opening the editor:
##
##   cd apps/game && godot --script scripts/tools/build_pixlcraft_region_cli.gd
##
## Safe to re-run - the builder clears out its own nodes by name first.

var _started := false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		PixlcraftRegionBuilder.build(root)
		print("[build_pixlcraft_region_cli] done")
		quit(0)
	return false
