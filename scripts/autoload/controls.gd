extends Node
## Registro de acciones de entrada. Esquema mouse-first: clic izquierdo selecciona objetivo, clic derecho
## mueve la nave y el ataque es automático. Teclado: barra rápida 1-0, Q, Espacio, E, Tab, F y Esc.

const HOTBAR_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]

var is_touch := false


func _ready() -> void:
	is_touch = DisplayServer.is_touchscreen_available() and (OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile"))
	_key("ability", KEY_Q)
	_key("boost", KEY_SPACE)
	_key("drone", KEY_E)
	_key("interact", KEY_F)
	_key("tactical_map", KEY_TAB)
	_key("inventory", KEY_I)
	_key("cancel", KEY_ESCAPE)
	for i in HOTBAR_KEYS.size():
		_key("hotbar_%d" % i, HOTBAR_KEYS[i])
	apply_saved_keys()
	apply_ui_scale()


func _key(action: String, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


func _mouse(action: String, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


## Texto de la tecla asignada actualmente (la UI nunca asume el número por defecto: 4.3).
func key_label(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var code: Key = ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
			return OS.get_keycode_string(code)
		if ev is InputEventMouseButton:
			return "RMB" if ev.button_index == MOUSE_BUTTON_RIGHT else "Mouse"
	return "?"


# --- M16: reasignación de teclas y escala de interfaz ------------------------------------------
const REBINDABLE := [
	["ability", "Habilidad de nave"], ["boost", "Impulso"], ["drone", "Habilidad del pet"],
	["interact", "Interactuar / extraer"], ["tactical_map", "Mapa táctico"], ["inventory", "Inventario / refinado"],
	["hotbar_0", "Barra rápida 1"], ["hotbar_1", "Barra rápida 2"], ["hotbar_2", "Barra rápida 3"], ["hotbar_3", "Barra rápida 4"],
	["hotbar_4", "Barra rápida 5"], ["hotbar_5", "Barra rápida 6"], ["hotbar_6", "Barra rápida 7"], ["hotbar_7", "Barra rápida 8"],
	["hotbar_8", "Barra rápida 9"], ["hotbar_9", "Barra rápida 10"],
]


func _set_key(action: String, keycode: int) -> void:
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode as Key
	InputMap.action_add_event(action, ev)


func key_code(action: String) -> int:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
	return KEY_NONE


## Asigna una tecla; si otra acción la usaba, intercambia las teclas.
func rebind(action: String, keycode: int) -> void:
	var old := key_code(action)
	for pair in REBINDABLE:
		var other: String = pair[0]
		if other != action and key_code(other) == keycode:
			_set_key(other, old)
			_store(other, old)
	_set_key(action, keycode)
	_store(action, keycode)
	GameState.save_game()


func _store(action: String, keycode: int) -> void:
	var s: Dictionary = GameState.data["settings"]
	if not s.has("keys"):
		s["keys"] = {}
	s["keys"][action] = keycode


func apply_saved_keys() -> void:
	var keys: Dictionary = GameState.data["settings"].get("keys", {})
	for action in keys.keys():
		if InputMap.has_action(action):
			_set_key(action, int(keys[action]))


func reset_keys() -> void:
	GameState.data["settings"].erase("keys")
	var defaults := {"ability": KEY_Q, "boost": KEY_SPACE, "drone": KEY_E, "interact": KEY_F, "tactical_map": KEY_TAB, "inventory": KEY_I}
	for i in HOTBAR_KEYS.size():
		defaults["hotbar_%d" % i] = HOTBAR_KEYS[i]
	for a in defaults.keys():
		_set_key(a, defaults[a])
	GameState.save_game()


## Escala de la interfaz (en móvil por defecto 1,3 para que los botones sean pulsables).
func ui_scale() -> float:
	return float(GameState.data["settings"].get("ui_scale", 1.3 if is_touch else 1.0))


func apply_ui_scale() -> void:
	get_tree().root.content_scale_factor = ui_scale()


func set_ui_scale(v: float) -> void:
	GameState.data["settings"]["ui_scale"] = clampf(v, 0.75, 1.6)
	apply_ui_scale()
	GameState.save_game()
