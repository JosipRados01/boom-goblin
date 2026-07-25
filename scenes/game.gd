extends Node
## Run state for BOOM GOBLIN. Autoloaded, so it survives the scene reloads that
## restart a level: game_env asks it which level to build, and it decides where
## a finished round goes next. Losing repeats the level — the only way forward
## is to blow up Dracula.

const LEVELS: Array[String] = [
	"res://scenes/level_1.tscn",
	"res://scenes/level_2.tscn",
]

## True for the one round right after the last level was beaten, so game_env
## can show the run-complete banner before looping back to level 1.
var run_complete := false

var _current := 0


func level_path() -> String:
	return LEVELS[clampi(_current, 0, LEVELS.size() - 1)]


func level_number() -> int:
	return _current + 1


func level_count() -> int:
	return LEVELS.size()


func is_final_level() -> bool:
	return _current == LEVELS.size() - 1


## Called by the player once the win/lose banner has had its moment.
func finish_round(win: bool) -> void:
	run_complete = false
	if win:
		if is_final_level():
			run_complete = true
			_current = 0
		else:
			_current += 1
	_reload()


func retry() -> void:
	run_complete = false
	_reload()


## Jump straight to a level. Used by the debug keys and any future menu.
func goto(index: int) -> void:
	run_complete = false
	_current = posmod(index, LEVELS.size())
	_reload()


func skip() -> void:
	goto(_current + 1)


func _reload() -> void:
	# Deferred: finish_round can be called from a signal mid-frame.
	get_tree().reload_current_scene.call_deferred()
