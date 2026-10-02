class_name Hud
extends CanvasLayer
## HUD del sector. Casi todo se dibuja en `canvas` para mantenerlo ligero; la barra rápida usa controles.

signal result_closed

var sector: Sector
var root: Control
var canvas: Control
var hotbar: HBoxContainer
var slots: Array[HotbarSlot] = []
var toasts: Array = []        # {text, t, color}
var pickups: Array = []       # {text, t, color}
var damage_flash := 0.0
var gate_near := false
var map_open := false
var pause_panel: Control
var result_panel: Control
var touch_fire: Button


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_canvas)
	root.add_child(canvas)

	hotbar = HBoxContainer.new()
	hotbar.add_theme_constant_override("separation", 4)
	hotbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hotbar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hotbar.position.y -= 14
	root.add_child(hotbar)
	for i in GameState.HOTBAR_SIZE:
		var s := HotbarSlot.new()
		s.index = i
		s.sector = sector
		s.activated.connect(sector.use_hotbar)
		hotbar.add_child(s)
		slots.append(s)
	hotbar.offset_top = -72
	hotbar.offset_bottom = -14

	if Controls.is_touch:
		_build_touch()


func _build_touch() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_left = -150
	box.offset_top = -330
	box.offset_right = -16
	box.offset_bottom = -90
	box.add_theme_constant_override("separation", 8)
	root.add_child(box)
	touch_fire = _tbtn(box, "FUEGO: ON" if sector.auto_fire else "FUEGO: OFF", func():
		sector.auto_fire = not sector.auto_fire
		touch_fire.text = "FUEGO: ON" if sector.auto_fire else "FUEGO: OFF")
	_tbtn(box, "IMPULSO", func(): sector.player.try_boost())
	_tbtn(box, "HABILIDAD", func(): sector.player.try_ability())
	_tbtn(box, "DRON", func(): sector.drone.use_ability())
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top.position = Vector2(16, 130)
	root.add_child(top)
	_tbtn(top, "MAPA", toggle_map)
	_tbtn(top, "PAUSA", toggle_pause)


func _tbtn(parent: Control, text: String, cb: Callable) -> Button:
	var b := UiTheme.button(text, cb, 120)
	b.custom_minimum_size.y = 52
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	return b


func toast(text: String, t: float = 2.0, color: Color = UiTheme.TEXT) -> void:
	toasts.append({"text": text, "t": t, "color": color})
	if toasts.size() > 4:
		toasts.pop_front()


func pickup(item: String, amount: int) -> void:
	for p in pickups:
		if p["item"] == item:
			p["amount"] += amount
			p["t"] = 2.0
			return
	pickups.append({"item": item, "amount": amount, "t": 2.0})
	if pickups.size() > 6:
		pickups.pop_front()


func flash_damage() -> void:
	damage_flash = 1.0


func slot_feedback(i: int, ok: bool) -> void:
	slots[i].flash(ok)


func set_gate_hint(near: bool, _done: bool) -> void:
	gate_near = near


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused and event.is_action_pressed("cancel"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_map() -> void:
	map_open = not map_open


func _process(delta: float) -> void:
	damage_flash = maxf(0.0, damage_flash - delta * 2.5)
	for t in toasts.duplicate():
		t["t"] -= delta
		if t["t"] <= 0.0:
			toasts.erase(t)
	for p in pickups.duplicate():
		p["t"] -= delta
		if p["t"] <= 0.0:
			pickups.erase(p)
	canvas.queue_redraw()


# --- Dibujo -------------------------------------------------------------------------
func _text(pos: Vector2, s: String, size: int = 16, color: Color = UiTheme.TEXT, align := HORIZONTAL_ALIGNMENT_LEFT, width: float = -1) -> void:
	var f := ThemeDB.fallback_font
	canvas.draw_string_outline(f, pos, s, align, width, size, 4, Color(0, 0, 0, 0.75))
	canvas.draw_string(f, pos, s, align, width, size, color)


func _bar(pos: Vector2, w: float, h: float, frac: float, color: Color, label: String) -> void:
	canvas.draw_rect(Rect2(pos, Vector2(w, h)), Color(0, 0, 0, 0.6))
	canvas.draw_rect(Rect2(pos, Vector2(w * clampf(frac, 0, 1), h)), color)
	canvas.draw_rect(Rect2(pos, Vector2(w, h)), UiTheme.BORDER, false, 1.0)
	_text(pos + Vector2(6, h - 4), label, 13)


func _draw_canvas() -> void:
	var vs := canvas.size
	var p := sector.player
	# Vida / escudo / energía
	var x := 16.0
	# Paneles de fondo para que el texto se lea sobre cualquier objeto del mapa.
	var panel_bg := Color(0.02, 0.03, 0.06, 0.6)
	canvas.draw_rect(Rect2(8, 4, 480, 130), panel_bg)
	canvas.draw_rect(Rect2(vs.x * 0.5 - 320, 4, 640, 132 if p.target_valid() else 72), panel_bg)
	_text(Vector2(x, 26), p.stats.get("name", ""), 18, UiTheme.ACCENT)
	_bar(Vector2(x, 36), 300, 18, p.shield / maxf(1.0, p.shield_max), Color("3aa0ff"), "Escudo %s / %s" % [GameData.format_num(p.shield), GameData.format_num(p.shield_max)])
	_bar(Vector2(x, 58), 300, 18, p.hull / p.hull_max, Color("5ad16a") if p.hull / p.hull_max > 0.3 else UiTheme.BAD, "Casco %s / %s" % [GameData.format_num(p.hull), GameData.format_num(p.hull_max)])
	_bar(Vector2(x, 80), 300, 10, p.energy / 100.0, Color("ffe04a"), "")
	# Habilidades
	_ability(Vector2(x, 100), Controls.key_label("ability"), GameData.ABILITIES[p.ability_id]["name"], p.ability_cd, GameData.ABILITIES[p.ability_id]["cd"])
	_ability(Vector2(x + 156, 100), Controls.key_label("boost"), "Impulso", p.boost_cd, 2.5)
	_ability(Vector2(x + 312, 100), Controls.key_label("drone"), "Dron", sector.drone.ability_cd, Drone.ROLES[sector.drone.role]["cd"])

	# Objetivo y alerta
	var cx := vs.x * 0.5
	_text(Vector2(cx - 300, 28), sector.objective_text(), 20, UiTheme.GOOD if sector.objective_done else UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 600)
	var al := sector.alert
	var aw := 240.0
	canvas.draw_rect(Rect2(cx - aw * 0.5, 38, aw, 8), Color(0, 0, 0, 0.6))
	canvas.draw_rect(Rect2(cx - aw * 0.5, 38, aw * al / 5.0, 8), UiTheme.WARN.lerp(UiTheme.BAD, al / 5.0))
	for i in 5:
		canvas.draw_line(Vector2(cx - aw * 0.5 + aw * i / 5.0, 38), Vector2(cx - aw * 0.5 + aw * i / 5.0, 46), Color.BLACK, 1.0)
	_text(Vector2(cx - 150, 64), "Alerta %d   %s" % [int(floorf(al)), _time(sector.elapsed)], 14, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 300)

	# Objetivo seleccionado
	if p.target_valid():
		var t := p.target
		var nm := ""
		var frac := 1.0
		if t is Enemy:
			nm = t.display_name() + "  Nv %d" % t.level
			frac = t.hp / t.hp_max
		elif t is Asteroid:
			nm = "Depósito de " + GameData.mat_name(t.ore)
			frac = t.hp / t.hp_max
		var dist := p.plane_pos.distance_to(t.plane_pos)
		var in_range := dist <= GameData.LASER_RANGE
		_text(Vector2(cx - 200, 92), nm, 16, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 400)
		canvas.draw_rect(Rect2(cx - 140, 98, 280, 10), Color(0, 0, 0, 0.6))
		canvas.draw_rect(Rect2(cx - 140, 98, 280 * frac, 10), Color("ff4a4a"))
		if not in_range:
			_text(Vector2(cx - 200, 126), "Fuera de alcance", 14, UiTheme.WARN, HORIZONTAL_ALIGNMENT_CENTER, 400)
		elif not p.firing:
			_text(Vector2(cx - 200, 126), "Mantén clic derecho para disparar" if not Controls.is_touch else "Activa FUEGO", 14, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 400)

	# Botín y bodega
	var rx := vs.x - 236.0
	_minimap(Rect2(rx, 16, 220, 220))
	_text(Vector2(rx, 258), "Créditos  " + GameData.format_num(sector.loot.get("credits", 0)), 15, GameData.mat_color("credits"))
	_text(Vector2(rx, 278), "Bodega  %d / %d" % [sector.cargo_used, sector.cargo_capacity()], 15, UiTheme.WARN if sector.cargo_used >= sector.cargo_capacity() else UiTheme.TEXT)
	if sector.loot.get("nexo", 0) > 0:
		_text(Vector2(rx, 298), "Cristales Nexo  %d" % sector.loot["nexo"], 15, GameData.mat_color("nexo"))
	var py := 330.0
	for pk in pickups:
		var a := clampf(pk["t"], 0.0, 1.0)
		_text(Vector2(rx, py), "+%s %s" % [GameData.format_num(pk["amount"]), GameData.mat_name(pk["item"])], 14, Color(GameData.mat_color(pk["item"]), a))
		py += 20

	# Munición activa
	var am: Dictionary = GameData.AMMO[sector.active_ammo]
	_text(Vector2(cx - 200, vs.y - 84), "Munición: %s (%s)  %s" % [am["name"], am["short"], GameData.format_num(sector.run_ammo.get(sector.active_ammo, 0))], 14, am["color"], HORIZONTAL_ALIGNMENT_CENTER, 400)

	# Avisos
	var ty := vs.y * 0.3
	for t in toasts:
		var a := clampf(t["t"] * 2.0, 0.0, 1.0)
		_text(Vector2(cx - 400, ty), t["text"], 24, Color(t["color"], a), HORIZONTAL_ALIGNMENT_CENTER, 800)
		ty += 34
	if gate_near:
		var msg := "Portal: pulsa %s o haz clic en el portal para extraer" % Controls.key_label("interact")
		if not sector.objective_done:
			msg += " (objetivo incompleto)"
		_text(Vector2(cx - 400, vs.y - 110), msg, 16, UiTheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER, 800)

	if damage_flash > 0.0:
		var c := Color(1, 0, 0, 0.25 * damage_flash)
		canvas.draw_rect(Rect2(0, 0, vs.x, 30), c)
		canvas.draw_rect(Rect2(0, vs.y - 30, vs.x, 30), c)
		canvas.draw_rect(Rect2(0, 0, 30, vs.y), c)
		canvas.draw_rect(Rect2(vs.x - 30, 0, 30, vs.y), c)

	if map_open:
		var m := minf(vs.x, vs.y) * 0.8
		canvas.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.6))
		_minimap(Rect2((vs.x - m) * 0.5, (vs.y - m) * 0.5, m, m), true)
		_text(Vector2(cx - 300, (vs.y - m) * 0.5 - 12), "MAPA TÁCTICO — %s" % sector.objective_text(), 20, UiTheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER, 600)


func _ability(pos: Vector2, key: String, name: String, cd: float, max_cd: float) -> void:
	var r := Rect2(pos, Vector2(150, 26))
	canvas.draw_rect(r, Color(0.04, 0.05, 0.09, 0.85))
	if cd > 0.0:
		canvas.draw_rect(Rect2(pos, Vector2(150 * cd / max_cd, 26)), Color(0.3, 0.3, 0.4, 0.5))
	canvas.draw_rect(r, UiTheme.BORDER if cd > 0.0 else UiTheme.ACCENT, false, 1.0)
	_text(pos + Vector2(5, 18), "[%s] %s" % [key, name], 12, UiTheme.MUTED if cd > 0.0 else UiTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT, 144)


func _time(t: float) -> String:
	return "%02d:%02d" % [int(t) / 60, int(t) % 60]


## Minimapa / mapa táctico en proyección iso, con chunks descubiertos, portal, nidos y enemigos.
func _minimap(r: Rect2, full: bool = false) -> void:
	canvas.draw_rect(r, Color(0.02, 0.03, 0.06, 0.85))
	canvas.draw_rect(r, UiTheme.BORDER, false, 1.0)
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for c in sector.cells.keys():
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			var s := Iso.to_screen((Vector2(c) + corner) * Sector.CHUNK)
			mn = mn.min(s)
			mx = mx.max(s)
	var span := mx - mn
	var sc := minf((r.size.x - 16) / span.x, (r.size.y - 16) / span.y)
	var off := r.position + (r.size - span * sc) * 0.5 - mn * sc
	var tf := func(p: Vector2) -> Vector2: return Iso.to_screen(p) * sc + off
	for c in sector.cells.keys():
		var o := Vector2(c) * Sector.CHUNK
		var pts := PackedVector2Array([tf.call(o), tf.call(o + Vector2(Sector.CHUNK, 0)), tf.call(o + Vector2(Sector.CHUNK, Sector.CHUNK)), tf.call(o + Vector2(0, Sector.CHUNK))])
		var visited: bool = sector.cells[c]["visited"]
		canvas.draw_colored_polygon(pts, Color(0.2, 0.3, 0.45, 0.5) if visited else Color(0.12, 0.14, 0.2, 0.5))
		pts.append(pts[0])
		canvas.draw_polyline(pts, Color(0.3, 0.4, 0.6, 0.6), 1.0)
	canvas.draw_circle(tf.call(sector.gate_pos), 5.0 if not full else 9.0, UiTheme.GOOD if sector.objective_done else UiTheme.ACCENT)
	for e in sector.enemies:
		if not e.alive:
			continue
		var visible_e: bool = sector.cells.get(sector.cell_of(e.plane_pos), {}).get("visited", false) or e.plane_pos.distance_to(sector.player.plane_pos) < 900.0
		if e.is_nest and visible_e:
			canvas.draw_circle(tf.call(e.plane_pos), 4.0 if not full else 7.0, Color("ff7a2a"))
		elif e.is_elite and visible_e:
			canvas.draw_circle(tf.call(e.plane_pos), 3.5 if not full else 6.0, Color("ffb84a"))
		elif e.plane_pos.distance_to(sector.player.plane_pos) < 900.0:
			canvas.draw_circle(tf.call(e.plane_pos), 2.0 if not full else 3.0, Color("ff4a4a"))
	canvas.draw_circle(tf.call(sector.player.plane_pos), 4.0 if not full else 7.0, Color.WHITE)


# --- Pausa y resultados -----------------------------------------------------------------
func toggle_pause() -> void:
	if result_panel:
		return
	if pause_panel:
		pause_panel.queue_free()
		pause_panel = null
		get_tree().paused = false
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	pause_panel = _modal("PAUSA")
	var box: VBoxContainer = pause_panel.get_meta("box")
	box.add_child(UiTheme.label("Controles: clic izq. mover/seleccionar · clic der. disparar · %s habilidad · %s impulso · %s dron · 1-0 barra rápida · %s mapa · rueda zoom" % [Controls.key_label("ability"), Controls.key_label("boost"), Controls.key_label("drone"), Controls.key_label("tactical_map")], 14, UiTheme.MUTED))
	box.add_child(UiTheme.button("Continuar", toggle_pause))
	box.add_child(UiTheme.button("Abandonar sector (pierdes el 50% del botín)", func():
		toggle_pause()
		sector._finish("death")))


func _modal(title: String) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var l := UiTheme.label(title, 28, UiTheme.ACCENT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	dim.set_meta("box", box)
	return dim


func show_result(result: Dictionary) -> void:
	if pause_panel:
		toggle_pause()
	var death: bool = result["outcome"] == "death"
	result_panel = _modal("NAVE PERDIDA" if death else "EXTRACCIÓN COMPLETADA")
	var box: VBoxContainer = result_panel.get_meta("box")
	var lines := "[b]Sector[/b] %s — Nivel %d   ·   Tiempo %s   ·   Bajas %d\n" % [sector.biome["name"], result["level"], _time(result["time"]), result["kills"]]
	lines += "[b]Objetivo:[/b] %s\n" % ("[color=#6fd17a]completado[/color]" if result["objective_done"] else "[color=#ff5a5a]incompleto[/color]")
	if death:
		lines += "[color=#ffb84a]Se pierde el %d%% del botín recogido.[/color]\n" % int(GameData.DEATH_LOOT_LOSS * 100)
	lines += "\n[b]Botín asegurado[/b]\n"
	var loot: Dictionary = result["loot"]
	if loot.is_empty():
		lines += "—\n"
	for k in loot.keys():
		lines += "[color=#%s]%s[/color]  %s\n" % [GameData.mat_color(k).to_html(false), GameData.mat_name(k), GameData.format_num(loot[k])]
	var used: Dictionary = result["ammo_used"]
	if not used.is_empty():
		lines += "\n[b]Munición gastada[/b]  "
		var parts: PackedStringArray = []
		for k in used.keys():
			parts.append("%s %s" % [GameData.AMMO[k]["short"], GameData.format_num(used[k])])
		lines += ", ".join(parts)
	box.add_child(UiTheme.rich(lines, 16))
	box.add_child(UiTheme.button("Volver al hangar", func(): result_closed.emit()))
	if sector.demo:
		await get_tree().create_timer(2.0).timeout
		result_closed.emit()
