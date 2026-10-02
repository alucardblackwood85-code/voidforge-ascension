class_name HotbarSlot
extends Control
## Un espacio de la barra rápida 1-0: icono, tecla, cantidad, cooldown y selección activa (4.3, 17.2).

signal activated(index: int)

var index := 0
var sector: Sector
var feedback := 0.0
var feedback_ok := true


func _ready() -> void:
	custom_minimum_size = Vector2(58, 58)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		activated.emit(index)
		accept_event()


func flash(ok: bool) -> void:
	feedback = 1.0
	feedback_ok = ok


func _process(delta: float) -> void:
	feedback = maxf(0.0, feedback - delta * 3.0)
	tooltip_text = _tooltip()
	queue_redraw()


func _entry():
	return sector.hotbar_entry(index)


func _tooltip() -> String:
	var e = _entry()
	if not (e is Dictionary):
		return "Vacío"
	if e["type"] == "ammo":
		var a: Dictionary = GameData.AMMO[e["id"]]
		return "%s (%s daño)\nRestante: %d" % [a["name"], a["short"], int(sector.run_ammo.get(e["id"], 0))]
	var it: Dictionary = GameData.ITEMS[e["id"]]
	return "%s\n%s\nRestante: %d" % [it["name"], it["desc"], int(sector.run_items.get(e["id"], 0))]


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var e = _entry()
	var active := false
	var color := Color(0.3, 0.35, 0.45)
	var label := ""
	var count := -1
	var cd_frac := 0.0
	if e is Dictionary:
		if e["type"] == "ammo":
			var a: Dictionary = GameData.AMMO[e["id"]]
			color = a["color"]
			label = a["short"]
			count = int(sector.run_ammo.get(e["id"], 0))
			active = sector.active_ammo == e["id"]
		else:
			var it: Dictionary = GameData.ITEMS[e["id"]]
			color = it["color"]
			label = it["short"]
			count = int(sector.run_items.get(e["id"], 0))
			cd_frac = sector.item_cd.get(e["id"], 0.0) / float(it["cd"])
			active = sector.placing == e["id"]
	draw_rect(r, Color(0.04, 0.05, 0.09, 0.85))
	if e is Dictionary:
		var inner := r.grow(-8)
		draw_rect(inner, Color(color, 0.18))
		draw_rect(inner, Color(color, 0.8), false, 1.5)
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(0, size.y * 0.58), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, color.lightened(0.3))
		if count >= 0:
			var ct := GameData.format_num(count)
			draw_string_outline(f, Vector2(0, size.y - 4), ct, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 4, 12, 3, Color.BLACK)
			draw_string(f, Vector2(0, size.y - 4), ct, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 4, 12, Color.WHITE if count > 0 else UiTheme.BAD)
		if count == 0:
			draw_rect(r, Color(0, 0, 0, 0.5))
		if cd_frac > 0.0:
			draw_rect(Rect2(0, size.y * (1.0 - cd_frac), size.x, size.y * cd_frac), Color(0, 0, 0, 0.6))
	var border := UiTheme.ACCENT if active else UiTheme.BORDER
	draw_rect(r, border, false, 3.0 if active else 1.0)
	if feedback > 0.0:
		draw_rect(r, Color(UiTheme.GOOD if feedback_ok else UiTheme.BAD, feedback * 0.4))
	var key := Controls.key_label("hotbar_%d" % index)
	draw_string(ThemeDB.fallback_font, Vector2(4, 13), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTheme.MUTED)
