extends Node
## Raíz del juego: alterna entre la pantalla de INICIO (StartMenu) y el Sector.
## Argumentos de depuración (tras "--"): --sector  entra directo a un sector con autopiloto de demo.

var current: Node = null
var autotest := false


func _ready() -> void:
	UiTheme.apply_root(get_tree().root)
	var demo_biome := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sector"):
			demo_biome = arg.get_slice("=", 1) if "=" in arg else "ferron"
	autotest = demo_biome != ""
	var showcase_biome := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--showcase"):
			showcase_biome = arg.get_slice("=", 1) if "=" in arg else "ferron"
	if OS.get_cmdline_user_args().has("--aimtest"):
		goto_sector({"level": 1, "seed": 7, "aimtest": true, "biome": "ferron"})
		return
	if showcase_biome != "":
		goto_sector({"level": 1, "seed": 7, "showcase": true, "biome": showcase_biome})
	elif autotest:
		goto_sector({"level": 1, "seed": 12345, "demo": true, "biome": demo_biome})
	else:
		goto_menu()


func _swap(node: Node) -> void:
	if current:
		current.queue_free()
	current = node
	add_child(node)


func goto_menu() -> void:
	var h := StartMenu.new()
	h.launch_requested.connect(goto_sector)
	_swap(h)


func goto_sector(params: Dictionary) -> void:
	var s := Sector.new()
	s.params = params
	s.finished.connect(_on_sector_finished)
	_swap(s)


func _on_sector_finished(result: Dictionary) -> void:
	GameState.apply_run_result(result)
	goto_menu()
