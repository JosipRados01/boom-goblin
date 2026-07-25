extends Node
## Generates static trimesh collision for every mesh in the parent scene at
## startup, so imported GLB tiles are solid without per-file import settings.
## Skips anything under a CharacterBody3D (player, enemies).


func _ready() -> void:
	_add_collision(get_parent())


func _add_collision(node: Node) -> void:
	if node is CharacterBody3D or node.is_in_group("no_autocol"):
		return
	if node is MeshInstance3D and node.mesh:
		node.create_trimesh_collision()
	for child in node.get_children():
		_add_collision(child)
