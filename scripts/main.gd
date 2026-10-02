extends Node
## Raíz del juego: alterna entre Hangar y Sector.
## Argumentos de depuración (tras "--"): --sector  entra directo a un sector con autopiloto de demo.

var current: Node = null
var autotest := false


func _ready() -> void:
	UiTheme.apply_root(get_tree().root)
	autotest = OS.get_cmdline_user_args().has("--sector")
	if autotest:
		goto_sector({"level": 1, "seed": 12345, "demo": true})
	else:
		goto_hangar()


func _swap(node: Node) -> void:
	if current:
		current.queue_free()
	current = node
	add_child(node)


func goto_hangar() -> void:
	var h := Hangar.new()
	h.launch_requested.connect(goto_sector)
	_swap(h)


func goto_sector(params: Dictionary) -> void:
	var s := Sector.new()
	s.params = params
	s.finished.connect(_on_sector_finished)
	_swap(s)


func _on_sector_finished(result: Dictionary) -> void:
	GameState.apply_run_result(result)
	goto_hangar()
