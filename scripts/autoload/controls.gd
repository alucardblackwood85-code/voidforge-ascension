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
