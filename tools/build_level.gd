extends SceneTree
## Headless generator: builds a MeshLibrary from Mini Dungeon tiles and paints
## the test arena into scenes/level_test.tscn. Run with:
##   godot --headless --script res://tools/build_level.gd
## Safe to re-run; overwrites both outputs.
##
## Tiles are scaled by SCALE to fit the 2x-scaled goblin. Kenney floor tiles
## pivot at their WALK SURFACE (slab hangs below), props/walls pivot at their
## base, so floors and objects paint at the same cell level with no lift.
## Pits are one meter deep (PIT_GM sits +SCALE/2 up from cell y=-1): shallow
## enough to dash out of anywhere, no stairs needed.

const SCALE := 2.0
const KIT := "res://Dungeon models/GLB format/"
const SOLID := ["floor", "floor-detail", "wall", "wall-half", "wall-opening", "stairs", "column", "barrel"]
const DECOR := ["rocks", "stones", "dirt", "banner"]

# 19 wide (x), 30 deep (z), one char per 2m cell. W wall x2 high, O doorway,
# h half-wall cover, P column, B barrel, '.' floor, '_' shallow pit.
const MAP := [
	"WWWWWWWWWOWWWWWWWWW",
	"W.................W",
	"W....h....B..P....W",
	"W..B...........h..W",
	"W......P..hh......W",
	"W..P......B....B..W",
	"W....hh.......P...W",
	"W.B........h......W",
	"W.................W",
	"W_________________W",
	"W.................W",
	"W...B..P....hh....W",
	"W.h.........B.....W",
	"W....B..P.....h...W",
	"W.................W",
	"W_________________W",
	"W_________________W",
	"W.................W",
	"W..P...hh.....B...W",
	"W.....B.......P...W",
	"W.hh.......B......W",
	"W.................W",
	"W_________________W",
	"W.................W",
	"W...B.........P...W",
	"W......hh.........W",
	"W.................W",
	"W.................W",
	"W.................W",
	"WWWWWWWWWWWWWWWWWWW",
]


func _init() -> void:
	_run()
	quit()


func _run() -> void:
	var lib := MeshLibrary.new()
	var scale_xf := Transform3D(Basis.from_scale(Vector3.ONE * SCALE), Vector3.ZERO)
	var names := SOLID + DECOR
	for i in names.size():
		var item_name: String = names[i]
		var ps: PackedScene = load(KIT + item_name + ".glb")
		var inst: Node = ps.instantiate()
		var meshes: Array = []
		_collect_meshes(inst, Transform3D(), meshes)
		if meshes.is_empty():
			push_error("no mesh in " + item_name)
			continue
		lib.create_item(i)
		lib.set_item_name(i, item_name)
		lib.set_item_mesh(i, meshes[0][0])
		lib.set_item_mesh_transform(i, scale_xf * meshes[0][1])
		if item_name in SOLID:
			var shapes := []
			for m in meshes:
				shapes.append(m[0].create_trimesh_shape())
				shapes.append(scale_xf * m[1])
			lib.set_item_shapes(i, shapes)
		inst.free()

	var lib_path := "res://scenes/dungeon_tiles.meshlib"
	var err := ResourceSaver.save(lib, lib_path)
	print("meshlib saved to ", lib_path, " err=", err)
	lib.take_over_path(lib_path)

	var root := Node3D.new()
	root.name = "TestArena"
	var floor_gm := _make_gridmap("Floor", lib, root)
	var obj_gm := _make_gridmap("Objects", lib, root)
	var pit_gm := _make_gridmap("PitFloor", lib, root)
	pit_gm.position.y = SCALE / 2.0  # cells at y=-1 -> floor one METER down

	var yaw90 := obj_gm.get_orthogonal_index_from_basis(Basis(Vector3.UP, PI / 2.0))
	var item := {}
	for i in names.size():
		item[names[i]] = i

	for z in MAP.size():
		var row: String = MAP[z]
		for x in row.length():
			var c := row[x]
			if c == "_":
				pit_gm.set_cell_item(Vector3i(x, -1, z), _floor_item(item, x, z), 0)
				continue
			floor_gm.set_cell_item(Vector3i(x, 0, z), _floor_item(item, x, z), 0)
			var side := 0 if (z == 0 or z == MAP.size() - 1) else yaw90
			match c:
				"W":
					obj_gm.set_cell_item(Vector3i(x, 0, z), item["wall"], side)
					obj_gm.set_cell_item(Vector3i(x, 1, z), item["wall"], side)
				"O":
					obj_gm.set_cell_item(Vector3i(x, 0, z), item["wall-opening"], side)
					obj_gm.set_cell_item(Vector3i(x, 1, z), item["wall"], side)
				"h":
					obj_gm.set_cell_item(Vector3i(x, 0, z), item["wall-half"], 0)
				"P":
					obj_gm.set_cell_item(Vector3i(x, 0, z), item["column"], 0)
				"B":
					obj_gm.set_cell_item(Vector3i(x, 0, z), item["barrel"], 0)

	# Chest as the placeholder objective on the far platform.
	var chest: Node3D = (load(KIT + "chest.glb") as PackedScene).instantiate()
	chest.name = "Chest"
	root.add_child(chest)
	chest.owner = root
	chest.transform = Transform3D(
		Basis(Vector3.UP, PI).scaled(Vector3.ONE * SCALE), Vector3(19, 0, 55)
	)

	var packed := PackedScene.new()
	err = packed.pack(root)
	err = ResourceSaver.save(packed, "res://scenes/level_test.tscn")
	print("level_test.tscn err=", err)


func _make_gridmap(gm_name: String, lib: MeshLibrary, root: Node3D) -> GridMap:
	var gm := GridMap.new()
	gm.name = gm_name
	gm.mesh_library = lib
	gm.cell_size = Vector3.ONE * SCALE
	gm.cell_center_y = false
	root.add_child(gm)
	gm.owner = root
	return gm


func _floor_item(item: Dictionary, x: int, z: int) -> int:
	return item["floor-detail"] if (x * 7 + z * 13) % 9 == 0 else item["floor"]


func _collect_meshes(node: Node, xf: Transform3D, out: Array) -> void:
	if node is Node3D:
		xf = xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		out.append([(node as MeshInstance3D).mesh, xf])
	for child in node.get_children():
		_collect_meshes(child, xf, out)
