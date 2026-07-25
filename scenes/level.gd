extends Node3D
## Root of a level scene. Holds everything level-specific — the grid, where the
## goblin starts, Dracula, the enemies — so game_env can swap one for another.
##
## To add a level: duplicate one of these, drop in a different grid, drag the
## PlayerSpawn marker where the goblin should start, then add the scene's path
## to LEVELS in game.gd.

## Shown under "LEVEL n" on the intro banner.
@export var title := ""
## How long the fuse burns in this level. Long enough to sneak, short enough
## that the last stretch is a sprint.
@export var fuse_time := 45.0


func spawn_transform() -> Transform3D:
	var marker := get_node_or_null("PlayerSpawn") as Node3D
	if marker:
		return marker.global_transform
	push_warning("Level '%s' has no PlayerSpawn marker." % name)
	return global_transform
