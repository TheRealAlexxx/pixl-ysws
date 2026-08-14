class_name PixlcraftRegionBuilder
extends RefCounted

## Paints a new Pixlcraft-style region into open_world.tscn, in the empty plot
## left behind after the old one was removed (cell footprint below).
##
## Two entry points, same split as world_map_baker.gd:
##   build_pixlcraft_region.gd      EditorScript - open it and hit File > Run
##   build_pixlcraft_region_cli.gd  godot --script scripts/tools/build_pixlcraft_region_cli.gd
##
## Safe to re-run: _remove_existing() clears out this builder's own nodes by
## name first, so iterating on layout is just "edit constants below, re-run".
##
## Layout is no longer procedurally generated - it's a literal hand-authored
## grid (STONE_PATH_LOCAL / DIRT_PATH_LOCAL / WATER_LOCAL / WOOD_BRIDGE_LOCAL
## below), given as (row, col) coordinates on a 24-col x 20-row grid with
## row 0 = north/top and col 0 = west/left. Godot's TileMapLayer.set_cell()
## takes Vector2i(x, y) i.e. (col, row) - the OPPOSITE axis order - so every
## constant below is pre-transposed to Vector2i(col, row) at definition time,
## then shifted into world space by GRID_ORIGIN at runtime (see
## _grid_to_world). Tile size is 16x16px (TILE below) throughout this file
## and the wider project.

const SCENE_PATH := "res://scenes/open_world.tscn"

const TILE := 16

# The grid's own local space is 26 cols (0-25) x 20 rows (0-19). GRID_ORIGIN
# is where local (0,0) - the grid's top-left corner - lands in the shared
# open_world map's cell space.
#
# Relocated south per the user's reference screenshot (a world-map screenshot
# with a hand-drawn "PC" + arrow marking open water south of the existing
# Farwest/hub/village cluster). The arrow tip was calibrated against real
# scene landmarks (Farwest and the starter-village cluster, both precisely
# located via color-thresholded centroids in a wide debug bake) rather than
# eyeballed off the ruler, landing at ~world (600, 700) - straight south of
# the old site, same X. GRID_ORIGIN.x is left untouched (still 24) so the
# island keeps the same west-edge X alignment (world x=25) that the old
# Bridge2 landing used; only .y moves, from 10 to 34 (+24 rows / +384px
# south). See EXTERNAL_CONNECTOR_WORLD below for how Bridge2 now reaches the
# new site across the water gap this move opens up.
const GRID_ORIGIN := Vector2i(24, 34)
const GRID_COLS := 26
const GRID_ROWS := 20
const X_MIN := GRID_ORIGIN.x
const X_MAX := GRID_ORIGIN.x + GRID_COLS - 1
const Y_MIN := GRID_ORIGIN.y
const Y_MAX := GRID_ORIGIN.y + GRID_ROWS - 1

# No Pixlcraft plank connector: the existing non-Pixlcraft bridge remains
# independent, while the region's ocean edge is blocked below.
const EXTERNAL_CONNECTOR_WORLD := []

# The reference island is a plain rectangle - straight edges, sharp corners,
# no rounding - so the corner chamfer is disabled (radius 0 = never
# chamfered). Kept as a knob rather than deleted in case a rounded look is
# wanted again later; see _is_chamfered.
const CORNER_CHAMFER_NW := 0
const CORNER_CHAMFER_NE := 0
const CORNER_CHAMFER_SW := 0
const CORNER_CHAMFER_SE := 0

const OWNED_NODE_NAMES := [
	"Pixlcraft ground", "Pixlcraft dual-grid", "Pixlcraft pond water", "Pixlcraft houses", "Pixlcraft props", "Pixlcraft Prop Collision",
	"Pixlcraft Pond Collision", "Pixlcraft Ocean Collision", "Bridge3", "Pixlcraft Boat", "Pixlcraft Boat Trigger",
]

# --- literal feature grid (local col,row - see header) ---------------------
# Source: user hand-marked exact coordinates directly on a numbered grid
# overlay of the reference image (26 cols x 20 rows, same convention as this
# file's own local grid) - not eyeballed/derived by us. Reference composition:
# two cottages on the west side (top house north, bottom house south), a wide
# horizontal path band running from the west dock through a well to a rounded
# clearing under the dark-oak tree, a short top-house branch, a central branch
# down to the lower cottage, and an organic pond in the south-east quadrant.
# Path is uniformly dirt, so
# STONE_PATH_LOCAL is unused here.
const STONE_PATH_LOCAL := []

# --- path: rectangular bands + rounded clearing blobs ----------------------
# The reference has three clear path runs: a west-dock-to-tree road, a short
# branch from the top cottage door into that road, and a central branch down
# to the lower cottage. The road is deliberately built from offset segments
# and rounded joins so it feels worn-in rather than like a perfect rectangle.
const PATH_RECTS := [
	{"cols": [0, 4], "rows": [8, 10]},    # dock landing.
	{"cols": [4, 8], "rows": [8, 9]},     # first road turn.
	{"cols": [7, 12], "rows": [7, 9]},    # shallow northward drift.
	{"cols": [11, 16], "rows": [8, 10]},  # middle road.
	{"cols": [15, 19], "rows": [9, 11]},  # shallow southward drift.
	{"cols": [18, 22], "rows": [8, 10]},  # tree-side approach.
	{"cols": [4, 6], "rows": [4, 7]},     # top-cottage doorstep branch.
	{"cols": [5, 7], "rows": [6, 8]},     # curved branch join.
	{"cols": [10, 11], "rows": [10, 13]}, # central branch north section.
	{"cols": [9, 10], "rows": [13, 16]},  # lower branch drifts west.
	{"cols": [4, 9], "rows": [16, 18]},   # lower-cottage doorstep bend.
]
# Rounded dirt clearings/pads, all still shape masks rather than hand-typed
# tile lists. These soften the hard rectangle joins where the screenshot has
# bulbous path edges.
const PATH_BLOBS := [
	{"center": Vector2(5.0, 8.8), "radius": Vector2(1.8, 1.5)},   # dock turn.
	{"center": Vector2(9.1, 8.2), "radius": Vector2(2.1, 1.6)},   # first road join.
	{"center": Vector2(15.3, 9.7), "radius": Vector2(2.2, 1.7)},  # middle road join.
	{"center": Vector2(19.4, 9.1), "radius": Vector2(2.0, 1.6)},  # tree-side turn.
	{"center": Vector2(7.0, 17.3), "radius": Vector2(2.7, 1.7)},  # lower bend.
	{"center": Vector2(22.4, 8.5), "radius": Vector2(2.6, 2.1)},  # tree clearing.
]

static func _build_path_cells() -> Array:
	var cells := {}
	for r in PATH_RECTS:
		for x in range(r["cols"][0], r["cols"][1] + 1):
			for y in range(r["rows"][0], r["rows"][1] + 1):
				cells[Vector2i(x, y)] = true
	for blob in PATH_BLOBS:
		for x in range(GRID_COLS):
			for y in range(GRID_ROWS):
				if _in_ellipse(Vector2(x + 0.5, y + 0.5), blob["center"], blob["radius"]):
					cells[Vector2i(x, y)] = true
	return cells.keys()
# --- pond shape mask --------------------------------------------------------
# The pond is a shape mask built from overlapping ellipses (union of two
# lobes, minus a smaller "bite" ellipse carved out of where they meet) - not
# a fixed circle radius, and not a hand-typed cell list. This produces a
# genuinely organic kidney/river outline that mixes concave and convex
# curves, so the dual-grid boundary hits many different mask values
# (straight edges, outer corners, inner corners) as it winds around, instead
# of the same 2-3 tile variants repeating on a blocky hand-drawn shape.
# Target shape from the numbered reference: a shallow north-west lobe joined
# to a deeper south-east lobe, visually occupying cols13-23 and rows11-18.
const POND_LOBES := [
	{"center": Vector2(15.8, 12.6), "radius": Vector2(3.4, 1.9)},   # north-west lobe
	{"center": Vector2(20.2, 15.8), "radius": Vector2(3.6, 2.8)},   # south-east lobe
]
const POND_BITE := {"center": Vector2(18.0, 12.5), "radius": Vector2(0.9, 0.8)}

static func _in_ellipse(p: Vector2, center: Vector2, radius: Vector2) -> bool:
	var dx := (p.x - center.x) / radius.x
	var dy := (p.y - center.y) / radius.y
	return dx * dx + dy * dy <= 1.0

static func _build_pond_cells() -> Array:
	var cells := []
	for x in range(GRID_COLS):
		for y in range(GRID_ROWS):
			var p := Vector2(x + 0.5, y + 0.5)
			var inside := false
			for lobe in POND_LOBES:
				if _in_ellipse(p, lobe["center"], lobe["radius"]):
					inside = true
					break
			if inside and _in_ellipse(p, POND_BITE["center"], POND_BITE["radius"]):
				inside = false
			if inside:
				cells.append(Vector2i(x, y))
	return cells
# No interior bridge in this composition - the reference's only bridge is the
# exterior one leading onto the plot (Bridge2, already in the scene); the
# interior pond isn't crossed by anything.
const WOOD_BRIDGE_LOCAL := []
# Anchor = top-left corner of the building's fixed 6x6 (96px) footprint.
# User's spec gave each house as "footprint" (the grounded wall rows) plus
# "roof overhang" (the full sprite bounds, since the roof is taller/wider
# than the walls) - the overhang range IS the 6x6 anchor box (footprint is a
# subset of it), so anchor_local is read straight off the overhang's
# top-left corner. House1's overhang reaches row-2 (roof peak pokes above
# the island's north edge into open water) - intentional per spec, see
# BUILDING_EDGE_MARGIN note below. House2's two given ranges summed to 7
# rows (one more than the fixed 6-tall sprite can cover); resolved by
# bottom-aligning to the footprint (the functionally-relevant, door-bearing
# part) rather than the purely-decorative roof overhang, costing 1 row of
# overhang at the very top - flagged, not silently dropped.
const BUILDINGS := [
	# Shifted one tile east from the previous handoff layout.
	{"texture": "res://assets/pixlcraft/buildings/stone-cottage.png", "anchor_local": Vector2i(5, 1)},
	{"texture": "res://assets/pixlcraft/buildings/oak-cabin.png", "anchor_local": Vector2i(4, 14)},
]
const BUILDING_SIZE := Vector2i(6, 6)
# Minimum tiles kept clear between any building's footprint and the local
# grid's SOUTH/EAST/WEST edges - a building flush against those renders
# against open ocean backdrop. The NORTH edge is deliberately exempted (see
# _clamp_to_margin): the reference composition wants roof peaks overhanging
# past row0 into open water/sky, same as the dark-oak tree's canopy already
# does, so only the lower bound on x and the upper bounds on x/y are clamped.
const BUILDING_EDGE_MARGIN := 0
# Matches the real building tiles already in this scene (Houses layer) - same
# 96x96 cell anchor convention, not art-specific.
const BUILDING_Y_SORT_ORIGIN := 23
const BUILDING_COLLISION_POLYGON: PackedVector2Array = [
	Vector2(-40, -10), Vector2(40, -10), Vector2(40, 45), Vector2(-40, 45),
]

const PROP_TEXTURES := {
	"flower": "res://assets/pixlcraft/props/flower-16.png",
	"mushroom": "res://assets/pixlcraft/props/mushroom-16.png",
	"boulder": "res://assets/pixlcraft/props/boulder-16.png",
	"hay_bale": "res://assets/pixlcraft/props/hay_bale.png",
	"dirt_speckle_a": "res://assets/pixlcraft/tiles/dirt_speckle_a-16.png",
	"dirt_speckle_b": "res://assets/pixlcraft/tiles/dirt_speckle_b-16.png",
	# anvil/furnace/chest/well/relic_stand replaced with a matching hand-drawn
	# set (sliced from a single reference sheet, background removed, each
	# resized to 32x32) - the old ones were a mismatched grab-bag from
	# different sources ("those ass looking props").
	"anvil": "res://assets/pixlcraft/props/anvil.png",
	"furnace": "res://assets/pixlcraft/props/furnace.png",
	"chest": "res://assets/pixlcraft/props/chest.png",
	"relic_stand": "res://assets/pixlcraft/props/relic_stand.png",
	"tree_dark_oak": "res://assets/pixlcraft/props/tree_dark_oak.png",
	"well": "res://assets/pixlcraft/props/well.png",
	"lily_pad": "res://assets/pixlcraft/props/lily_pad.png",
}

# Minimum Chebyshev distance kept between ANY two placed props (across all
# types together), enforced in _paint_props. Hand-picked positions below
# were validated against every STONE/DIRT/WATER/BRIDGE/BUILDING(+1 margin)
# cell and against each other at this spacing before being written down
# (see the prop-candidate validation pass) - _spacing_ok is still run at
# paint time too, as a second line of defense.
const PROP_MIN_SPACING := 3

# The screenshot's visible flowers are already baked into the cottage sprites'
# window boxes. Keep standalone flower candidates empty so the candidate-list
# placer does not add extra red flowers that are not in the reference.
const FLOWERS_LOCAL := []
# Three generated boulders sit on open grass, clear of the route and pond.
const FIXED_BOULDERS_LOCAL := [Vector2i(8, 5), Vector2i(12, 4), Vector2i(24, 13)]
const BOULDERS_LOCAL := []
const BOULDER_SIZE := Vector2i(2, 2)
const BOULDER_COLLISION_POLYGON: PackedVector2Array = [
	Vector2(3, 3), Vector2(29, 3), Vector2(29, 29), Vector2(3, 29),
]
const HAY_BALE_SIZE := Vector2i(2, 2)
const HAY_BALE_COLLISION_POLYGON: PackedVector2Array = [
	Vector2(2, 2), Vector2(30, 2), Vector2(30, 30), Vector2(2, 30),
]
# Separate hay bales distributed around the region.
const HAY_BALES_LOCAL := [Vector2i(1, 12), Vector2i(14, 4), Vector2i(23, 12)]

# Mushrooms are user-specified as CLUSTERS (multiple sprites close together,
# down to 1 tile apart) rather than single scattered sprites, so they go
# through the same unconditional fixed-placement path as the blacksmith
# cluster/lily pads below instead of the PROP_MIN_SPACING-gated candidate
# list - that spacing rule exists to keep scattered decor from overlapping,
# which is the opposite of what a tight cluster wants. Each sub-array is one
# cluster. Two entries were nudged off a real conflict found in
# layout_sim2.py: the well/tree pair's 2nd tile (17,5) sat on both the
# dark-oak canopy footprint and the tree-clearing path blob, moved to
# (16,4); the lone "by pond" mushroom at (21,13) landed inside the actual
# water shape, moved to (21,12) - still shore-adjacent, just on grass.
const MUSHROOM_CLUSTERS_LOCAL := [
	[Vector2i(2, 3), Vector2i(2, 4)],                                          # by house1
	[Vector2i(16, 5), Vector2i(16, 4)],                                        # pair near well/tree - nudged
	[Vector2i(13, 17), Vector2i(14, 17), Vector2i(13, 18), Vector2i(14, 18)],  # large cluster, pond's SW corner
	[Vector2i(23, 17), Vector2i(24, 17), Vector2i(23, 18), Vector2i(24, 18)],  # cluster, pond's SE shore
	[Vector2i(21, 12)],                                                        # single, by pond - nudged off water
]

# 4 lily pads resting directly on pond water cells (see POND_LOBES) - placed
# through the fixed set-piece loop in _paint_props (not the spacing-gated
# candidate list) since a water cell is deliberately marked `occupied` to
# keep flowers/mushrooms/boulders off it, which would also block a lily pad
# if it went through that same check. All 4 verified against the final
# retuned pond shape in layout_sim2.py.
const LILY_PADS_LOCAL := [Vector2i(15, 13), Vector2i(18, 13), Vector2i(19, 16), Vector2i(21, 17)]

# Small surface marks add variation inside the dirt without changing the
# route's dual-grid silhouette. These are intentionally fixed on path cells,
# unlike flowers/boulders which must stay on grass.
const DIRT_SPECKLES_A_LOCAL := [
	Vector2i(2, 9), Vector2i(8, 8), Vector2i(13, 9), Vector2i(16, 10),
	Vector2i(21, 9), Vector2i(5, 7), Vector2i(10, 12), Vector2i(6, 17),
]
const DIRT_SPECKLES_B_LOCAL := [
	Vector2i(4, 9), Vector2i(10, 8), Vector2i(15, 9), Vector2i(19, 10),
	Vector2i(6, 8), Vector2i(11, 13), Vector2i(8, 17), Vector2i(4, 17),
]

# Forge/anvil/chest along the north edge, in a row (matches the reference's
# "house1 yard to forge/anvil/chest" branch). All 3 are the same fixed 2x2
# (32x32) art; the user's forge box (cols10-12, 3 wide) doesn't fit the
# fixed 2-wide asset exactly - anchored to its given left edge (col10),
# read the extra column as the chimney-flame VFX bleeding wider than the
# sprite (same treatment as the tree canopy's soft alpha edge elsewhere).
const FURNACE_LOCAL := Vector2i(10, 0)
const ANVIL_LOCAL := Vector2i(13, 0)
const CHEST_LOCAL := Vector2i(15, 0)
const RELIC_STAND_LOCAL := Vector2i(18, 4)   # NPC by the tree - exact 2x2 match to spec.
const BLACKSMITH_PROP_SIZE := Vector2i(2, 2)
const BLACKSMITH_Y_SORT_ORIGIN := 8

# Source PNG is a 128x128 transparent-background tree, so it sits on clean
# 16px tile boundaries like every other atlas source here. y_sort_origin keeps
# the same ~24% of image-height ratio already used by
# BUILDING_Y_SORT_ORIGIN/the old TREE_Y_SORT_ORIGIN.
const DARK_OAK_SIZE := Vector2i(8, 8)
const DARK_OAK_Y_SORT_ORIGIN := 31
const DARK_OAK_COLLISION_POLYGON: PackedVector2Array = [
	Vector2(17, 64), Vector2(47, 64), Vector2(47, 94), Vector2(17, 94),
]
# User gave trunk (cols19-21, rows3-5) and canopy overhang (cols17-24,
# rows-2 to 3) separately; their union is exactly 8x8 (canopy's col range is
# already 8 wide; rows -2..3 union trunk's rows..5 = -2..5, 8 tall) -
# matches the fixed 8x8 asset exactly, same overhang-defines-anchor logic as
# the houses above. Canopy legitimately overhangs past row0, same as before.
const DARK_OAK_LOCAL := Vector2i(18, -2)

# well.png is the 32x32 (2x2-tile) art. User's well box (cols10-12,
# rows6-8) is 3x3, doesn't fit the fixed 2x2 asset - anchored to the box's
# top-left (10,6) rather than centering, so it stays flush with the forge
# row above and the horizontal path spine it sits on.
const WELL_SIZE := Vector2i(2, 2)
const WELL_Y_SORT_ORIGIN := 8
const WELL_LOCAL := Vector2i(10, 6)

static func build(host: Node) -> void:
	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		push_error("[PixlcraftRegionBuilder] cannot load %s" % SCENE_PATH)
		return
	var root: Node = packed.instantiate()

	_remove_existing(root)

	var island_cells := _build_island_cells()
	var stone_cells := _convert_set(STONE_PATH_LOCAL)
	var dirt_cells := _convert_set(_build_path_cells())
	var water_cells := _convert_set(_build_pond_cells())
	var bridge_cells := _convert_set(WOOD_BRIDGE_LOCAL)
	var bridge3_cells := _build_bridge3_cells()
	var bridge_mask := bridge_cells.duplicate()
	for c in bridge3_cells:
		bridge_mask[c] = true
	var connector_cells := {}  # world-space already, not grid-local
	for c in EXTERNAL_CONNECTOR_WORLD:
		connector_cells[c] = true
	var occupied := {}  # cell -> true, for buildings + features, used to keep props off them

	var ground_tileset := _build_ground_tileset()
	var ground := _make_layer("Pixlcraft ground", 2, false)
	ground.tile_set = ground_tileset
	var dual_grid := _make_layer("Pixlcraft dual-grid", 3, false)
	dual_grid.tile_set = ground_tileset
	# Dual-grid rendering: rendered tiles sit on the corners between logical
	# cells, so the layer itself is offset by half a tile.
	dual_grid.position = Vector2(-HALF, -HALF)

	_paint_ground(ground, island_cells, water_cells, bridge_cells)
	_add_bridge3(root, ground_tileset, bridge3_cells)
	for c in connector_cells:
		ground.set_cell(c, _src(ground_tileset, "wood_planks"), Vector2i.ZERO)
	_paint_features(dual_grid, stone_cells, dirt_cells, water_cells, bridge_mask)
	_paint_island_edge(dual_grid, island_cells)
	for c in stone_cells:
		occupied[c] = true
	for c in dirt_cells:
		occupied[c] = true
	for c in water_cells:
		occupied[c] = true
	for c in bridge_cells:
		occupied[c] = true

	var houses_tileset := TileSet.new()
	houses_tileset.tile_size = Vector2i(TILE, TILE)
	houses_tileset.add_physics_layer()
	houses_tileset.set_physics_layer_collision_layer(0, 1)
	var houses := _make_layer("Pixlcraft houses", 10, true)
	houses.tile_set = houses_tileset
	_paint_houses(houses, houses_tileset, occupied)

	var props_tileset := TileSet.new()
	props_tileset.tile_size = Vector2i(TILE, TILE)
	props_tileset.add_physics_layer()
	props_tileset.set_physics_layer_collision_layer(0, 1)
	var props := _make_layer("Pixlcraft props", 10, true)
	props.tile_set = props_tileset
	_paint_props(props, props_tileset, occupied)

	for layer in [ground, dual_grid, houses, props]:
		root.add_child(layer)
		layer.owner = root

	_add_water_collision(root, water_cells)
	_add_ocean_collision(root)
	_add_pixlcraft_boat(root)
	_add_prop_collision(root)

	var new_packed := PackedScene.new()
	var err := new_packed.pack(root)
	if err != OK:
		push_error("[PixlcraftRegionBuilder] pack() failed (%d)" % err)
		root.free()
		return
	err = ResourceSaver.save(new_packed, SCENE_PATH)
	if err != OK:
		push_error("[PixlcraftRegionBuilder] save failed (%d)" % err)
	else:
		print("[PixlcraftRegionBuilder] saved %s" % SCENE_PATH)
	root.free()

static func _remove_existing(root: Node) -> void:
	for name in OWNED_NODE_NAMES:
		var n := root.get_node_or_null(NodePath(name))
		if n != null:
			root.remove_child(n)
			n.free()

static func _make_layer(name: String, z: int, y_sort: bool) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = name
	layer.z_index = z
	layer.y_sort_enabled = y_sort
	return layer

static func _in_footprint(c: Vector2i) -> bool:
	return c.x >= X_MIN and c.x <= X_MAX and c.y >= Y_MIN and c.y <= Y_MAX

static func _grid_to_world(local: Vector2i) -> Vector2i:
	return GRID_ORIGIN + local

static func _convert_set(local_list: Array) -> Dictionary:
	var out := {}
	for c in local_list:
		out[_grid_to_world(c)] = true
	return out

# --- ground -----------------------------------------------------------------

# Single-cell flat sources. grass is a tile lifted straight out of
# grass_dirt_wang.png's own "all-grass" cell (see extract_grass.py) instead
# of an independently-sourced texture - guarantees byte-identical grass
# between the flat fill and the wang sheets' own grass halves, and it's
# already confirmed seamless (grass_plain.png, what we used before, was not -
# it tiled with a visible grid/checkerboard seam).
const FLAT_SOURCES := {
	"grass": "res://assets/pixlcraft/tiles/grass_pure.png",
	"wood_planks": "res://assets/pixlcraft/tiles/wood_planks.png",
}
# 4x4 real dual-grid wang tilesets (recolored from the broader asset library,
# see recolor_wang.py / recolor_water.py), rendered via _paint_dual_grid.
const WANG_SOURCES := {
	"grass_dirt_wang": "res://assets/pixlcraft/tiles/grass_dirt_wang.png",
	"grass_stone_wang": "res://assets/pixlcraft/tiles/grass_stone_wang.png",
	"grass_water_wang": "res://assets/pixlcraft/tiles/grass_water_wang.png",
	"island_edge_wang": "res://assets/pixlcraft/tiles/island_edge_wang.png",
}
# These sheets are assembled directly from PixelLab's per-mask tile output:
# each returned tile's NW/NE/SW/SE corner metadata is turned into a 4-bit mask
# (1=TL,2=TR,4=BL,8=BR, bit set when that corner is the "upper"/overlay
# material) and pasted into the sheet at grid cell (mask%4, mask/4), so frame
# index == mask directly. -1 = nothing to draw (base grass layer shows through).
const DIRT_STONE_FRAME_BY_MASK := [-1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
const WATER_FRAME_BY_MASK := [-1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
# Same identity mapping, but mask==15 (fully-interior, no ocean in any
# corner) is also skipped - the flat grass fill already covers those cells,
# so only the boundary ring where island meets ocean needs a real tile.
const EDGE_FRAME_BY_MASK := [-1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, -1]
const HALF := TILE / 2.0

static func _add_atlas(ts: TileSet, path: String, id: int) -> void:
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load(path)
	atlas.texture_region_size = Vector2i(TILE, TILE)
	for mask in range(16):
		atlas.create_tile(Vector2i(mask % 4, mask / 4))
	ts.add_source(atlas, id)

static func _build_ground_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var id := 0
	for key in FLAT_SOURCES:
		var atlas := TileSetAtlasSource.new()
		atlas.texture = load(FLAT_SOURCES[key])
		atlas.texture_region_size = Vector2i(TILE, TILE)
		atlas.create_tile(Vector2i.ZERO)
		ts.add_source(atlas, id)
		ts.set_meta(key, id)  # stash id->name lookup for painting code below
		id += 1
	for key in WANG_SOURCES:
		_add_atlas(ts, WANG_SOURCES[key], id)
		ts.set_meta(key, id)
		id += 1
	return ts

static func _src(ts: TileSet, key: String) -> int:
	return ts.get_meta(key)

# Dual-grid mask: which of the 4 logical cells diagonally around visual
# position (x,y) are filled. TL=(x-1,y-1) TR=(x,y-1) BL=(x-1,y) BR=(x,y).
static func _dual_grid_mask(cell_set: Dictionary, x: int, y: int) -> int:
	var mask := 0
	if cell_set.has(Vector2i(x - 1, y - 1)):
		mask |= 1
	if cell_set.has(Vector2i(x, y - 1)):
		mask |= 2
	if cell_set.has(Vector2i(x - 1, y)):
		mask |= 4
	if cell_set.has(Vector2i(x, y)):
		mask |= 8
	return mask

static func _dual_grid_frame_coords(cell_set: Dictionary, frame_table: Array, x: int, y: int, skip_full: bool = false) -> Vector2i:
	var mask := _dual_grid_mask(cell_set, x, y)
	if skip_full and mask == 15:
		return Vector2i(-1, -1)
	var frame: int = frame_table[mask]
	if frame < 0:
		return Vector2i(-1, -1)
	return Vector2i(frame % 4, frame / 4)

# Paints any number of dual-grid materials onto one half-tile-offset layer
# (the offset is what makes rendered tiles sit on the corners between
# logical cells, per SpriteCook's dual-grid convention). `entries` is
# ordered by priority: an entry only "claims" a corner position if at least
# one of its OWN 4 diagonal cells is present there, but the tile SHAPE it
# renders is picked using the mask against the union of every entry's cells
# PLUS `extra_compatible` (e.g. a wood bridge that isn't itself dual-grid
# rendered, but should still count as "not grass" so the stone bordering it
# renders as fully-interior instead of fading out). That distinction matters
# anywhere two different materials meet - without it, each one only sees its
# own cells as "filled" and renders as if fading out to grass against the
# other, leaving a pale seam between two materials that are actually
# directly touching. Each entry is {cells, src, frames, skip_full}.
# skip_full=true additionally skips mask==15 (fully-surrounded) so a
# shader-animated layer underneath (water) can show through instead of a
# static "fully water" tile.
static func _paint_dual_grid(layer: TileMapLayer, entries: Array, region: Rect2i, extra_compatible: Dictionary = {}, exclude: Dictionary = {}) -> void:
	var union_cells := {}
	for entry in entries:
		for c in entry["cells"]:
			union_cells[c] = true
	for c in extra_compatible:
		union_cells[c] = true
	for x in range(region.position.x, region.position.x + region.size.x):
		for y in range(region.position.y, region.position.y + region.size.y):
			if exclude.has(Vector2i(x, y)):
				continue
			for entry in entries:
				if _dual_grid_mask(entry["cells"], x, y) == 0:
					continue
				var coords := _dual_grid_frame_coords(union_cells, entry["frames"], x, y, entry.get("skip_full", false))
				if coords.x >= 0:
					layer.set_cell(Vector2i(x, y), entry["src"], coords)
				break

static func _bounds_of(cell_sets: Array, pad: int = 1) -> Rect2i:
	var seeded := false
	var min_c := Vector2i.ZERO
	var max_c := Vector2i.ZERO
	for cell_set in cell_sets:
		for c in cell_set:
			if not seeded:
				min_c = c
				max_c = c
				seeded = true
			else:
				min_c.x = mini(min_c.x, c.x)
				min_c.y = mini(min_c.y, c.y)
				max_c.x = maxi(max_c.x, c.x)
				max_c.y = maxi(max_c.y, c.y)
	if not seeded:
		return Rect2i()
	min_c -= Vector2i(pad, pad)
	max_c += Vector2i(pad, pad)
	return Rect2i(min_c, max_c - min_c + Vector2i(2, 2))

# True for a LOCAL (0-based) cell within its corner's diagonal chamfer cut -
# used to carve a rounded, asymmetric platform silhouette out of what would
# otherwise be a flat rectangle. Each corner has its own radius (see the
# CORNER_CHAMFER_* constants above) instead of one shared value.
static func _is_chamfered(local: Vector2i) -> bool:
	var corners := [
		[Vector2i(0, 0), CORNER_CHAMFER_NW],
		[Vector2i(GRID_COLS - 1, 0), CORNER_CHAMFER_NE],
		[Vector2i(0, GRID_ROWS - 1), CORNER_CHAMFER_SW],
		[Vector2i(GRID_COLS - 1, GRID_ROWS - 1), CORNER_CHAMFER_SE],
	]
	for entry in corners:
		var corner: Vector2i = entry[0]
		var radius: int = entry[1]
		if absi(local.x - corner.x) + absi(local.y - corner.y) < radius:
			return true
	return false

# The full footprint minus its 4 chamfered corners - this is "the island":
# every cell that should get a grass fill and count as land for the
# island-edge dual-grid pass. Independent of the pond (WATER_LOCAL) - the
# pond is an interior hole in the island, not part of its outer boundary.
static func _build_island_cells() -> Dictionary:
	var cells := {}
	for x in range(X_MIN, X_MAX + 1):
		for y in range(Y_MIN, Y_MAX + 1):
			if not _is_chamfered(Vector2i(x - X_MIN, y - Y_MIN)):
				cells[Vector2i(x, y)] = true
	return cells

static func _paint_ground(layer: TileMapLayer, island_cells: Dictionary, water_cells: Dictionary, bridge_cells: Dictionary) -> void:
	var grass := _src(layer.tile_set, "grass")
	for c in island_cells:
		if water_cells.has(c):
			continue
		layer.set_cell(c, grass, Vector2i.ZERO)
	var planks := _src(layer.tile_set, "wood_planks")
	for c in bridge_cells:
		layer.set_cell(c, planks, Vector2i.ZERO)

static func _build_bridge3_cells() -> Dictionary:
	var cells := {}
	for x in range(GRID_ORIGIN.x - 4, GRID_ORIGIN.x):
		for y in range(GRID_ORIGIN.y + 8, GRID_ORIGIN.y + 11):
			cells[Vector2i(x, y)] = true
	return cells

static func _add_bridge3(root: Node, tileset: TileSet, cells: Dictionary) -> void:
	var layer := _make_layer("Bridge3", 4, false)
	layer.tile_set = tileset
	var planks := _src(tileset, "wood_planks")
	for c in cells:
		layer.set_cell(c, planks, Vector2i.ZERO)
	root.add_child(layer)
	layer.owner = root

# `layer` must already be positioned at the half-tile dual-grid offset (see
# build()). Stone and dirt share one dual-grid pass so their shared boundary
# cuts cleanly (via _paint_dual_grid's union-mask handling) instead of both
# fading to grass against each other; the wood bridge cells are passed in as
# extra_compatible so the stone tiles bordering the bridge render as
# fully-interior too, rather than fading out against what would otherwise
# look like open grass. Water is its own dual-grid pass since it doesn't
# spatially overlap the path network.
static func _paint_features(layer: TileMapLayer, stone_cells: Dictionary, dirt_cells: Dictionary, water_cells: Dictionary, bridge_cells: Dictionary) -> void:
	var dirt_wang := _src(layer.tile_set, "grass_dirt_wang")
	var stone_wang := _src(layer.tile_set, "grass_stone_wang")
	var water_wang := _src(layer.tile_set, "grass_water_wang")

	_paint_dual_grid(layer, [
		{"cells": stone_cells, "src": stone_wang, "frames": DIRT_STONE_FRAME_BY_MASK},
		{"cells": dirt_cells, "src": dirt_wang, "frames": DIRT_STONE_FRAME_BY_MASK},
	], _bounds_of([stone_cells, dirt_cells, bridge_cells]), bridge_cells)

	# The two ponds' local grid put row15 (the bridge) only 1 row from
	# either bank, so water's own bounding box reaches the bridge cells and
	# would otherwise paint a fading water tile straight over the crossing
	# (its mask only checks water_cells, blind to what stone/dirt already
	# drew there). Excluding bridge_cells here is what keeps the crossing
	# clear for the wood-plank ground tile underneath. No skip_full here -
	# the pond's deep interior gets the real water tile (frame 15) instead of
	# leaving it transparent to the shader-animated ocean layer underneath,
	# since that shader water doesn't visually match this blocky tileset.
	_paint_dual_grid(layer, [
		{"cells": water_cells, "src": water_wang, "frames": WATER_FRAME_BY_MASK},
	], _bounds_of([water_cells]), {}, bridge_cells)

# Cliff-edge ring around the whole island footprint, where grass drops to the
# surrounding ocean. island_cells fills the entire chamfered footprint
# uniformly, so every interior cell masks to 15 (skipped by
# EDGE_FRAME_BY_MASK - the flat grass fill already covers it) and only the
# outer ring - including the chamfered corners, now genuinely partial masks -
# gets a real tile. Region is padded a tile beyond the footprint so the
# overhanging "lip" half of the dual-grid boundary also gets painted.
static func _paint_island_edge(layer: TileMapLayer, island_cells: Dictionary) -> void:
	var edge_wang := _src(layer.tile_set, "island_edge_wang")
	_paint_dual_grid(layer, [
		{"cells": island_cells, "src": edge_wang, "frames": EDGE_FRAME_BY_MASK},
	], _bounds_of([island_cells]))

# --- houses -------------------------------------------------------------

# Keeps a building's footprint at least BUILDING_EDGE_MARGIN tiles clear of
# every local-grid edge, regardless of what anchor_local was hand-picked to.
static func _clamp_to_margin(anchor_local: Vector2i) -> Vector2i:
	var max_x := GRID_COLS - BUILDING_SIZE.x - BUILDING_EDGE_MARGIN
	var max_y := GRID_ROWS - BUILDING_SIZE.y - BUILDING_EDGE_MARGIN
	# y's lower bound is intentionally unclamped (-BUILDING_SIZE.y, i.e. the
	# whole sprite could poke above row0) - roof peaks overhanging the
	# island's north edge are wanted here, see BUILDINGS note above.
	var clamped := Vector2i(
		clampi(anchor_local.x, BUILDING_EDGE_MARGIN, max_x),
		clampi(anchor_local.y, -BUILDING_SIZE.y, max_y)
	)
	if clamped != anchor_local:
		push_warning("[PixlcraftRegionBuilder] anchor_local %s clamped to %s" % [anchor_local, clamped])
	return clamped

static func _paint_houses(layer: TileMapLayer, ts: TileSet, occupied: Dictionary) -> void:
	var id := 0
	for b in BUILDINGS:
		var atlas := TileSetAtlasSource.new()
		atlas.texture = load(b["texture"])
		atlas.texture_region_size = Vector2i(TILE, TILE)
		atlas.create_tile(Vector2i.ZERO, BUILDING_SIZE)
		ts.add_source(atlas, id)
		var tile_data := atlas.get_tile_data(Vector2i.ZERO, 0)
		tile_data.y_sort_origin = BUILDING_Y_SORT_ORIGIN
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(0, 0, BUILDING_COLLISION_POLYGON)
		var anchor := _grid_to_world(_clamp_to_margin(b["anchor_local"]))
		layer.set_cell(anchor, id, Vector2i.ZERO)
		for x in range(anchor.x, anchor.x + BUILDING_SIZE.x):
			for y in range(anchor.y, anchor.y + BUILDING_SIZE.y):
				occupied[Vector2i(x, y)] = true
		id += 1

# --- props ----------------------------------------------------------------

static func _add_single_cell_prop(ts: TileSet, key: String, id: int) -> void:
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load(PROP_TEXTURES[key])
	atlas.texture_region_size = Vector2i(TILE, TILE)
	atlas.create_tile(Vector2i.ZERO)
	ts.add_source(atlas, id)

static func _add_multi_cell_prop(ts: TileSet, key: String, id: int, size: Vector2i, y_sort_origin: int, collision_polygon: PackedVector2Array = PackedVector2Array()) -> void:
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load(PROP_TEXTURES[key])
	atlas.texture_region_size = Vector2i(TILE, TILE)
	atlas.create_tile(Vector2i.ZERO, size)
	ts.add_source(atlas, id)
	var data := atlas.get_tile_data(Vector2i.ZERO, 0)
	data.y_sort_origin = y_sort_origin
	if not collision_polygon.is_empty():
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, collision_polygon)

static func _paint_props(layer: TileMapLayer, ts: TileSet, occupied: Dictionary) -> void:
	# Single-cell sources, ids 0-2.
	var SRC_FLOWER := 0
	var SRC_MUSHROOM := 1
	var SRC_BOULDER := 2
	_add_single_cell_prop(ts, "flower", SRC_FLOWER)
	_add_single_cell_prop(ts, "mushroom", SRC_MUSHROOM)
	_add_multi_cell_prop(ts, "boulder", SRC_BOULDER, BOULDER_SIZE, 8, BOULDER_COLLISION_POLYGON)
	var SRC_HAY_BALE := 12
	_add_multi_cell_prop(ts, "hay_bale", SRC_HAY_BALE, HAY_BALE_SIZE, 8, HAY_BALE_COLLISION_POLYGON)
	var SRC_DIRT_SPECKLE_A := 10
	var SRC_DIRT_SPECKLE_B := 11
	_add_single_cell_prop(ts, "dirt_speckle_a", SRC_DIRT_SPECKLE_A)
	_add_single_cell_prop(ts, "dirt_speckle_b", SRC_DIRT_SPECKLE_B)
	var SRC_LILY_PAD := 9
	_add_single_cell_prop(ts, "lily_pad", SRC_LILY_PAD)

	# Multi-cell sources, ids 3-8. Blacksmith-cluster props (anvil/furnace/
	# chest/relic_stand/well) are all 2x2 now, matching their new art.
	var SRC_ANVIL := 3
	var SRC_FURNACE := 4
	var SRC_CHEST := 5
	var SRC_RELIC_STAND := 6
	var SRC_DARK_OAK := 7
	var SRC_WELL := 8
	_add_multi_cell_prop(ts, "anvil", SRC_ANVIL, BLACKSMITH_PROP_SIZE, BLACKSMITH_Y_SORT_ORIGIN)
	_add_multi_cell_prop(ts, "furnace", SRC_FURNACE, BLACKSMITH_PROP_SIZE, BLACKSMITH_Y_SORT_ORIGIN)
	_add_multi_cell_prop(ts, "chest", SRC_CHEST, BLACKSMITH_PROP_SIZE, BLACKSMITH_Y_SORT_ORIGIN)
	_add_multi_cell_prop(ts, "relic_stand", SRC_RELIC_STAND, BLACKSMITH_PROP_SIZE, BLACKSMITH_Y_SORT_ORIGIN)
	_add_multi_cell_prop(ts, "tree_dark_oak", SRC_DARK_OAK, DARK_OAK_SIZE, DARK_OAK_Y_SORT_ORIGIN, DARK_OAK_COLLISION_POLYGON)
	_add_multi_cell_prop(ts, "well", SRC_WELL, WELL_SIZE, WELL_Y_SORT_ORIGIN)

	# Fixed set-piece placements (dark oak, book/NPC stand, lily pads,
	# mushroom clusters) go straight onto the layer rather than through
	# the spacing-gated candidate list below - PROP_MIN_SPACING is meant to
	# keep scattered decoration from overlapping, but the mushroom clusters
	# are deliberately grouped tight, and lily pads deliberately sit on water
	# cells, all of which the candidate list's checks would reject.
	var fixed_entries := [
		{"local": DARK_OAK_LOCAL, "src": SRC_DARK_OAK, "size": DARK_OAK_SIZE},
		{"local": RELIC_STAND_LOCAL, "src": SRC_RELIC_STAND, "size": BLACKSMITH_PROP_SIZE},
	]
	for pad_local in LILY_PADS_LOCAL:
		fixed_entries.append({"local": pad_local, "src": SRC_LILY_PAD, "size": Vector2i.ONE})
	for cluster in MUSHROOM_CLUSTERS_LOCAL:
		for mush_local in cluster:
			fixed_entries.append({"local": mush_local, "src": SRC_MUSHROOM, "size": Vector2i.ONE})
	for speckle_local in DIRT_SPECKLES_A_LOCAL:
		fixed_entries.append({"local": speckle_local, "src": SRC_DIRT_SPECKLE_A, "size": Vector2i.ONE})
	for speckle_local in DIRT_SPECKLES_B_LOCAL:
		fixed_entries.append({"local": speckle_local, "src": SRC_DIRT_SPECKLE_B, "size": Vector2i.ONE})
	for boulder_local in FIXED_BOULDERS_LOCAL:
		fixed_entries.append({"local": boulder_local, "src": SRC_BOULDER, "size": BOULDER_SIZE})
	for hay_local in HAY_BALES_LOCAL:
		fixed_entries.append({"local": hay_local, "src": SRC_HAY_BALE, "size": HAY_BALE_SIZE})
	for entry in fixed_entries:
		var anchor: Vector2i = _grid_to_world(entry["local"])
		var size: Vector2i = entry["size"]
		layer.set_cell(anchor, entry["src"], Vector2i.ZERO)
		for x in range(anchor.x, anchor.x + size.x):
			for y in range(anchor.y, anchor.y + size.y):
				occupied[Vector2i(x, y)] = true

	# One combined candidate list (rather than placing per-type independently)
	# so PROP_MIN_SPACING is enforced across every prop together, not just
	# within a type - otherwise two props could still land right on top of
	# each other.
	var candidates := []
	for c in FLOWERS_LOCAL:
		candidates.append({"cell": _grid_to_world(c), "src": SRC_FLOWER})
	for c in BOULDERS_LOCAL:
		candidates.append({"cell": _grid_to_world(c), "src": SRC_BOULDER})

	var placed := []
	for cand in candidates:
		var cell: Vector2i = cand["cell"]
		if not _in_footprint(cell) or occupied.has(cell):
			continue
		if not _spacing_ok(cell, placed):
			continue
		layer.set_cell(cell, cand["src"], Vector2i.ZERO)
		placed.append(cell)

static func _spacing_ok(cell: Vector2i, placed: Array) -> bool:
	for p in placed:
		if maxi(absi(cell.x - p.x), absi(cell.y - p.y)) < PROP_MIN_SPACING:
			return false
	return true

static func _add_prop_collision_box(body: StaticBody2D, local_anchor: Vector2i, size: Vector2, center_offset: Vector2) -> void:
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	shape.position = Vector2((GRID_ORIGIN.x + local_anchor.x) * TILE, (GRID_ORIGIN.y + local_anchor.y) * TILE) + center_offset
	body.add_child(shape)
	shape.owner = body.owner

static func _add_prop_collision(root: Node) -> void:
	var body := StaticBody2D.new()
	body.name = "Pixlcraft Prop Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	body.owner = root
	# Only the trunk/base blocks movement; the canopy remains walk-under-able.
	_add_prop_collision_box(body, DARK_OAK_LOCAL, Vector2(32, 32), Vector2(48, 104))
	_add_prop_collision_box(body, RELIC_STAND_LOCAL, Vector2(28, 28), Vector2(16, 16))
	for boulder_local in FIXED_BOULDERS_LOCAL:
		_add_prop_collision_box(body, boulder_local, Vector2(28, 28), Vector2(16, 16))
	for hay_local in HAY_BALES_LOCAL:
		_add_prop_collision_box(body, hay_local, Vector2(28, 28), Vector2(16, 16))

# --- water collision -----------------------------------------------------

# The water area is an irregular hand-authored shape. Use one rectangle per
# logical water cell so the player is blocked by the actual pond footprint,
# without over-blocking the grass around its curved corners.
static func _add_water_collision(root: Node, water_cells: Dictionary) -> void:
	if water_cells.is_empty():
		return

	var body := StaticBody2D.new()
	body.name = "Pixlcraft Pond Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	body.owner = root
	for cell in water_cells:
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(TILE, TILE)
		shape.shape = rectangle
		shape.position = Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE + TILE / 2.0)
		body.add_child(shape)
		shape.owner = root

static func _add_ocean_collision(root: Node) -> void:
	var body := StaticBody2D.new()
	body.name = "Pixlcraft Ocean Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	body.owner = root
	# Four edge barriers stop the player leaving the island into the existing
	# ocean TileMapLayer, without filling the playable grass with collision.
	_add_ocean_collision_box(body, Vector2(X_MIN * TILE, (Y_MIN + 4.0) * TILE), Vector2(TILE, 8.0 * TILE))
	_add_ocean_collision_box(body, Vector2(X_MIN * TILE, (Y_MIN + 15.0) * TILE), Vector2(TILE, 9.0 * TILE))
	_add_ocean_collision_box(body, Vector2((X_MAX + 1) * TILE, (Y_MIN + GRID_ROWS / 2.0) * TILE), Vector2(TILE, GRID_ROWS * TILE))
	_add_ocean_collision_box(body, Vector2((X_MIN + GRID_COLS / 2.0) * TILE, Y_MIN * TILE), Vector2(GRID_COLS * TILE, TILE))
	_add_ocean_collision_box(body, Vector2((X_MIN + GRID_COLS / 2.0) * TILE, (Y_MAX + 1) * TILE), Vector2(GRID_COLS * TILE, TILE))

static func _add_ocean_collision_box(body: StaticBody2D, center: Vector2, size: Vector2) -> void:
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	shape.position = center
	body.add_child(shape)
	shape.owner = body.owner

static func _add_pixlcraft_boat(root: Node) -> void:
	var boat_position := Vector2((GRID_ORIGIN.x - 5) * TILE + 8, (GRID_ORIGIN.y + 9) * TILE + 8)
	var boat := Sprite2D.new()
	boat.name = "Pixlcraft Boat"
	boat.texture = load("res://assets/cozy-towns/CozyValley_Premium_1.3/Tilesets/Boats.png")
	boat.region_enabled = true
	boat.region_rect = Rect2(0, 0, 32, 16)
	boat.position = boat_position
	boat.z_index = 5
	root.add_child(boat)
	boat.owner = root

	var trigger := Area2D.new()
	trigger.name = "Pixlcraft Boat Trigger"
	trigger.position = boat_position
	trigger.collision_mask = 2
	trigger.set_script(load("res://scripts/boat_trigger.gd"))
	trigger.set("target_marker", NodePath("../PlayerSpawn"))
	trigger.set("destination_label", "Go to Main Island")
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(40, 28)
	shape.shape = rectangle
	root.add_child(trigger)
	trigger.owner = root
	trigger.add_child(shape)
	shape.owner = root
	trigger.body_entered.connect(Callable(trigger, "_on_body_entered"))
	trigger.body_exited.connect(Callable(trigger, "_on_body_exited"))
