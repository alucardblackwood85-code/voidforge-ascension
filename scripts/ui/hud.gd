class_name Hud
extends CanvasLayer
## HUD del sector. Casi todo se dibuja en `canvas` para mantenerlo ligero; la barra rápida usa controles.

signal result_closed

var sector: Sector
var hint := ""                 # M11: consejo del tutorial
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
var inventory: InventoryPanel


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
	# Ventana de inventario/refinado (tecla I) y su botón bajo el minimapa.
	inventory = InventoryPanel.new()
	inventory.sector = sector
	inventory.visible = false
	# A la izquierda, bajo los indicadores: nunca tapa la nave (centro de pantalla).
	inventory.set_anchors_preset(Control.PRESET_TOP_LEFT)
	inventory.offset_left = 8
	inventory.offset_top = 150
	root.add_child(inventory)
	var inv_btn := UiTheme.button("INVENTARIO / REFINADO (%s)" % Controls.key_label("inventory"), toggle_inventory)
	inv_btn.focus_mode = Control.FOCUS_NONE
	inv_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	inv_btn.offset_left = -236
	inv_btn.offset_right = -16
	inv_btn.offset_top = 262
	inv_btn.offset_bottom = 294
	root.add_child(inv_btn)

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
	_tbtn(box, "IMPULSO", func(): sector.player.try_boost())
	_tbtn(box, "HABILIDAD", func(): sector.player.try_ability())
	_tbtn(box, "PET", func(): sector.drone.use_ability())
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


func toggle_inventory() -> void:
	inventory.visible = not inventory.visible
	Sfx.play("ui_click")


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
	# Títulos y cifras grandes con la tipografía propia (en mayúsculas); el texto pequeño, legible.
	var f: Font = ThemeDB.fallback_font
	if size >= 15:
		f = UiTheme.display_font()
		s = s.to_upper()
		size += 2
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
	_text(Vector2(x, 26), "%s · Nv %d" % [GameState.rank_name(), GameState.level()], 13, UiTheme.WARN, HORIZONTAL_ALIGNMENT_RIGHT, 300)
	_bar(Vector2(x, 36), 300, 18, p.shield / maxf(1.0, p.shield_max), Color("3aa0ff"), "Escudo %s / %s" % [GameData.format_num(p.shield), GameData.format_num(p.shield_max)])
	_bar(Vector2(x, 58), 300, 18, p.hull / p.hull_max, Color("5ad16a") if p.hull / p.hull_max > 0.3 else UiTheme.BAD, "Casco %s / %s" % [GameData.format_num(p.hull), GameData.format_num(p.hull_max)])
	_bar(Vector2(x, 80), 300, 10, p.energy / 100.0, Color("ffe04a"), "")
	# Habilidades
	_ability(Vector2(x, 100), Controls.key_label("ability"), GameData.ABILITIES[p.ability_id]["name"], p.ability_cd, GameData.ABILITIES[p.ability_id]["cd"])
	_ability(Vector2(x + 156, 100), Controls.key_label("boost"), "Impulso", p.boost_cd, 2.5)
	if not sector.drone.locked:
		_ability(Vector2(x + 312, 100), Controls.key_label("drone"), "Pet", sector.drone.ability_cd, Drone.ROLES[sector.drone.role]["cd"])

	# Objetivo y alerta
	var cx := vs.x * 0.5
	_text(Vector2(cx - 300, 28), sector.objective_text(), 20, UiTheme.GOOD if sector.objective_done else UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 600)
	var al := sector.alert
	var aw := 240.0
	canvas.draw_rect(Rect2(cx - aw * 0.5, 38, aw, 8), Color(0, 0, 0, 0.6))
	canvas.draw_rect(Rect2(cx - aw * 0.5, 38, aw * al / 5.0, 8), UiTheme.WARN.lerp(UiTheme.BAD, al / 5.0))
	for i in 5:
		canvas.draw_line(Vector2(cx - aw * 0.5 + aw * i / 5.0, 38), Vector2(cx - aw * 0.5 + aw * i / 5.0, 46), Color.BLACK, 1.0)
	_text(Vector2(cx - 150, 64), _time(sector.elapsed), 14, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 300)

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
		if t is Enemy and t.shield_max > 0.0:
			canvas.draw_rect(Rect2(cx - 140, 110, 280 * t.shield / t.shield_max, 5), Color("4ab8ff"))
		if t is Enemy and not t.affixes.is_empty():
			_text(Vector2(cx - 300, 130), t.affix_text(), 13, UiTheme.WARN, HORIZONTAL_ALIGNMENT_CENTER, 600)
		if not in_range:
			_text(Vector2(cx - 200, 148 if (t is Enemy and not t.affixes.is_empty()) else 130), "Fuera de alcance", 14, UiTheme.WARN, HORIZONTAL_ALIGNMENT_CENTER, 400)

	# M6: barra del jefe (cuando está cerca o en combate)
	var boss: Enemy = sector.boss
	if is_instance_valid(boss) and boss.alive and boss.aggro and boss.plane_pos.distance_to(p.plane_pos) < 1600.0:
		var bw := minf(720.0, vs.x - 560.0)
		var by := vs.y - 150.0
		canvas.draw_rect(Rect2(cx - bw * 0.5 - 6, by - 26, bw + 12, 50), panel_bg)
		_text(Vector2(cx - bw * 0.5, by - 8), "%s · FASE %d" % [boss.boss_name(), boss.boss_phase], 16, UiTheme.BAD, HORIZONTAL_ALIGNMENT_CENTER, bw)
		canvas.draw_rect(Rect2(cx - bw * 0.5, by, bw, 14), Color(0, 0, 0, 0.7))
		canvas.draw_rect(Rect2(cx - bw * 0.5, by, bw * boss.hp / boss.hp_max, 14), Color("d02a3a"))
		for k in [0.33, 0.66]:
			canvas.draw_line(Vector2(cx - bw * 0.5 + bw * k, by), Vector2(cx - bw * 0.5 + bw * k, by + 14), Color.BLACK, 2.0)
		if boss.shield_max > 0.0:
			canvas.draw_rect(Rect2(cx - bw * 0.5, by + 16, bw * boss.shield / boss.shield_max, 4), Color("4ab8ff"))

	# Botín y bodega
	# Minimapa 2:1 (el mapa en proyección iso siempre tiene esa proporción).
	var rx := vs.x - 336.0
	_minimap(Rect2(rx, 16, 320, 170))
	rx = vs.x - 236.0
	_text(Vector2(rx, 208), "Créditos  " + GameData.format_num(sector.loot.get("credits", 0)), 15, GameData.mat_color("credits"))
	_text(Vector2(rx, 228), "Bodega  %d / %d" % [sector.cargo_used, sector.cargo_capacity()], 15, UiTheme.WARN if sector.cargo_used >= sector.cargo_capacity() else UiTheme.TEXT)
	if sector.loot.get("nexo", 0) > 0:
		_text(Vector2(rx, 248), "Cristales Nexo  %d" % sector.loot["nexo"], 15, GameData.mat_color("nexo"))
	var py := 320.0
	for pk in pickups:
		var a := clampf(pk["t"], 0.0, 1.0)
		_text(Vector2(rx, py), "+%s %s" % [GameData.format_num(pk["amount"]), GameData.mat_name(pk["item"])], 14, Color(GameData.mat_color(pk["item"]), a))
		py += 20

	# Munición activa
	var am: Dictionary = GameData.AMMO[sector.active_ammo]
	_text(Vector2(cx - 200, vs.y - 84), "Munición: %s (%s)  %s  ·  %d por andanada" % [am["name"], am["short"], GameData.format_num(sector.run_ammo.get(sector.active_ammo, 0)), p.lasers.size()], 14, am["color"], HORIZONTAL_ALIGNMENT_CENTER, 400)
	var md: Dictionary = GameData.MISSILES[sector.active_missile]
	var mleft := int(sector.run_missiles.get(sector.active_missile, 0))
	_text(Vector2(cx - 200, vs.y - 102), "Misil: %s  %s  ·  %s" % [md["name"], GameData.format_num(mleft), ("listo" if sector.missile_cd <= 0.05 else "%.1f s" % sector.missile_cd) if mleft > 0 else "sin misiles"], 13, md["color"] if mleft > 0 else UiTheme.BAD, HORIZONTAL_ALIGNMENT_CENTER, 400)

	# M11: tutorial
	if hint != "":
		var hw := 760.0
		var hy := vs.y - 190.0
		canvas.draw_rect(Rect2(cx - hw * 0.5, hy - 26, hw, 40), Color(0.02, 0.08, 0.12, 0.85))
		canvas.draw_rect(Rect2(cx - hw * 0.5, hy - 26, hw, 40), UiTheme.ACCENT, false, 2.0)
		_text(Vector2(cx - hw * 0.5, hy), "TUTORIAL · " + hint, 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, hw)

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
		var mw := minf(vs.x * 0.88, vs.y * 0.8 * 2.0)
		var mh := mw * 0.5
		canvas.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.6))
		_minimap(Rect2((vs.x - mw) * 0.5, (vs.y - mh) * 0.5, mw, mh), true)
		_text(Vector2(cx - 300, (vs.y - mh) * 0.5 - 12), "MAPA TÁCTICO — %s" % sector.objective_text(), 20, UiTheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER, 600)


func _ability(pos: Vector2, key: String, name: String, cd: float, max_cd: float) -> void:
	var r := Rect2(pos, Vector2(150, 26))
	canvas.draw_rect(r, Color(0.04, 0.05, 0.09, 0.85))
	if cd > 0.0:
		canvas.draw_rect(Rect2(pos, Vector2(150 * cd / max_cd, 26)), Color(0.3, 0.3, 0.4, 0.5))
	canvas.draw_rect(r, UiTheme.BORDER if cd > 0.0 else UiTheme.ACCENT, false, 1.0)
	_text(pos + Vector2(5, 18), "[%s] %s" % [key, name], 12, UiTheme.MUTED if cd > 0.0 else UiTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT, 144)


func _time(t: float) -> String:
	return "%02d:%02d" % [int(t) / 60, int(t) % 60]


## Minimapa / mapa táctico en proyección iso: la imagen del bioma en miniatura, obstáculos, zonas de aliens
## (roja la del jefe), portal, objetivos, enemigos cercanos y la nave. Clic en él = piloto automático.
var _mm_tex: Texture2D = null
var _mm_rect := Rect2()
var _mm_sc := 1.0
var _mm_off := Vector2.ZERO


func _mm_texture() -> Texture2D:
	if _mm_tex == null:
		var path := "res://assets/backgrounds/%s.png" % sector.biome_id
		if not ResourceLoader.exists(path):
			path = "res://assets/backgrounds/%s.png" % sector.theme_id
		if ResourceLoader.exists(path):
			_mm_tex = load(path)
	return _mm_tex


## Punto del plano bajo el ratón si está sobre el minimapa (o el mapa táctico abierto); si no, INF.
func minimap_plane_at_mouse() -> Vector2:
	var m := canvas.get_local_mouse_position()
	if _mm_rect.size == Vector2.ZERO or not _mm_rect.has_point(m):
		return Vector2.INF
	var p := Iso.to_plane((m - _mm_off) / _mm_sc)
	var b: Rect2 = sector.bounds
	if p.x < -200.0 or p.y < -200.0 or p.x > b.size.x + 200.0 or p.y > b.size.y + 200.0:
		return Vector2.INF
	return p


func _minimap(r: Rect2, full: bool = false) -> void:
	# Con el mapa táctico abierto, los clics van a él (el minimapa pequeño queda tapado).
	if full or not map_open:
		_mm_rect = r
	var b: Rect2 = sector.bounds
	var corners := [Vector2.ZERO, Vector2(b.size.x, 0), b.size, Vector2(0, b.size.y)]
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for c in corners:
		var s := Iso.to_screen(c)
		mn = mn.min(s)
		mx = mx.max(s)
	var span := mx - mn
	var sc := minf((r.size.x - 12) / span.x, (r.size.y - 12) / span.y)
	var off := r.position + (r.size - span * sc) * 0.5 - mn * sc
	if full or not map_open:
		_mm_sc = sc
		_mm_off = off
	var tf := func(p: Vector2) -> Vector2: return Iso.to_screen(p) * sc + off
	canvas.draw_rect(r, Color(0.01, 0.02, 0.04, 0.88))
	# Fondo: la imagen del bioma en miniatura, recortada al rombo del mapa.
	var pts := PackedVector2Array()
	for c in corners:
		pts.append(tf.call(c))
	var tex := _mm_texture()
	if tex:
		canvas.draw_polygon(pts, PackedColorArray([Color(1.6, 1.6, 1.7, 1.0)]), PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), tex)
	else:
		canvas.draw_colored_polygon(pts, Color(0.1, 0.13, 0.2, 0.8))
	var outline := pts.duplicate()
	outline.append(pts[0])
	canvas.draw_polyline(outline, Color(sector.biome.get("border", UiTheme.ACCENT), 0.8), 1.5, true)
	# Obstáculos (rocas y depósitos) a escala: la ruta automática los esquiva.
	for list in sector.asteroids_by_cell.values():
		for a in list:
			if is_instance_valid(a) and a.alive:
				canvas.draw_circle(tf.call(a.plane_pos), maxf(1.2, a.radius * sc * 1.3), Color(0.62, 0.6, 0.58, 0.85) if a.ore == "" else Color(0.95, 0.75, 0.35, 0.9))
	# Zonas: naranja las de aliens (con los que quedan), roja y latiendo la del jefe.
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005)
	for z in sector.zones:
		var left := 0
		for e in z["members"]:
			if is_instance_valid(e) and e.alive:
				left += 1
		var zc: Vector2 = tf.call(z["pos"])
		var zr: float = z["r"] * sc * 1.15
		if z["kind"] == "boss":
			if left == 0:
				continue
			canvas.draw_circle(zc, zr, Color(1.0, 0.15, 0.15, 0.16 + 0.12 * pulse))
			canvas.draw_arc(zc, zr, 0, TAU, 40, Color(1.0, 0.3, 0.3, 0.9), 2.0, true)
			_text(zc + Vector2(-30, 4), "JEFE", 11 if not full else 15, Color(1, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 60)
		elif left > 0:
			canvas.draw_circle(zc, zr, Color(1.0, 0.55, 0.15, 0.12))
			canvas.draw_arc(zc, zr, 0, TAU, 32, Color(1.0, 0.6, 0.2, 0.75), 1.4, true)
			if full:
				_text(zc + Vector2(-30, 5), str(left), 14, Color(1, 0.9, 0.75), HORIZONTAL_ALIGNMENT_CENTER, 60)
		else:
			canvas.draw_arc(zc, zr, 0, TAU, 32, Color(0.4, 1.0, 0.5, 0.35), 1.0, true)
	# Portal de extracción.
	var gc: Vector2 = tf.call(sector.gate_pos)
	var gr := 5.0 if not full else 9.0
	canvas.draw_arc(gc, gr, 0, TAU, 24, UiTheme.GOOD if sector.objective_done else UiTheme.ACCENT, 2.0, true)
	canvas.draw_circle(gc, gr * 0.4, UiTheme.GOOD if sector.objective_done else UiTheme.ACCENT)
	# Objetivos y puntos de interés (rombos).
	for pt in sector.points:
		if not is_instance_valid(pt) or (pt.done and pt.kind != "convoy"):
			continue
		var pc: Vector2 = tf.call(pt.plane_pos)
		var ps := 4.0 if not full else 7.0
		var dia := PackedVector2Array([pc + Vector2(0, -ps), pc + Vector2(ps, 0), pc + Vector2(0, ps), pc + Vector2(-ps, 0)])
		var col: Color = ObjPoint.COLORS[pt.kind]
		if pt.is_objective():
			canvas.draw_colored_polygon(dia, col)
		dia.append(dia[0])
		canvas.draw_polyline(dia, col, 1.5, true)
	# Enemigos cercanos: puntos con borde oscuro (dorado los élite, naranja los nidos).
	for e in sector.enemies:
		if not e.alive or e.plane_pos.distance_to(sector.player.plane_pos) > 2200.0:
			continue
		var ec: Vector2 = tf.call(e.plane_pos)
		var er := 2.2 if not full else 3.5
		var col := Color("ff4a4a")
		if e.is_nest:
			col = Color("ff7a2a")
			er *= 1.6
		elif e.is_elite or e.is_boss:
			col = Color("ffc24a")
			er *= 1.4
		canvas.draw_circle(ec, er + 1.0, Color(0, 0, 0, 0.8))
		canvas.draw_circle(ec, er, col)
	# Ruta del piloto automático.
	var path: PackedVector2Array = sector.nav_path
	if not path.is_empty():
		var line := PackedVector2Array([tf.call(sector.player.plane_pos)])
		for q in path:
			line.append(tf.call(q))
		canvas.draw_polyline(line, Color(0.4, 1.0, 0.85, 0.85), 1.5, true)
		canvas.draw_circle(line[line.size() - 1], 3.0 if not full else 5.0, Color(0.4, 1.0, 0.85))
	# Nave: flecha blanca orientada según su rumbo.
	var pp: Vector2 = tf.call(sector.player.plane_pos)
	var dir := Iso.to_screen(Vector2.from_angle(sector.player.heading)).normalized()
	var side := dir.orthogonal()
	var L := 7.0 if not full else 11.0
	var tri := PackedVector2Array([pp + dir * L, pp - dir * L * 0.6 + side * L * 0.6, pp - dir * L * 0.3, pp - dir * L * 0.6 - side * L * 0.6])
	canvas.draw_colored_polygon(tri, Color.WHITE)
	tri.append(tri[0])
	canvas.draw_polyline(tri, Color(0, 0, 0, 0.9), 1.2, true)
	canvas.draw_rect(r, UiTheme.BORDER, false, 1.0)


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
	pause_panel = _modal("Pausa")
	var box: VBoxContainer = pause_panel.get_meta("box")
	# Resumen de la incursión en curso.
	var sumr := W.vbox(0)
	sumr.add_child(W.stat_row("Sector", "%s · nivel %d" % [sector.biome["name"], sector.level], true))
	sumr.add_child(W.stat_row("Tiempo", _time(int(sector.elapsed)), false))
	sumr.add_child(W.stat_row("Bajas", str(sector.kills), true))
	sumr.add_child(W.stat_row("Objetivo", sector.objective_text(), false, UiTheme.GOOD if sector.objective_done else UiTheme.TEXT))
	sumr.add_child(W.stat_row("Créditos recogidos", GameData.format_num(int(sector.loot.get("credits", 0))), true, UiTheme.GOLD))
	box.add_child(sumr)
	var ctl := UiTheme.label("Clic izquierdo: fijar objetivo  ·  Clic derecho: mover (mantener para guiar)  ·  Ataque automático
1-0: munición y objetos  ·  %s habilidad  ·  %s impulso  ·  %s pet  ·  %s mapa  ·  rueda: zoom" % [Controls.key_label("ability"), Controls.key_label("boost"), Controls.key_label("drone"), Controls.key_label("tactical_map")], 14, UiTheme.MUTED)
	ctl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(ctl)
	box.add_child(UiTheme.heading("Sonido", 18))
	box.add_child(AudioPanel.new())
	var cont := W.btn("Continuar", toggle_pause, "primary", 0, 22)
	cont.custom_minimum_size.y = 50
	box.add_child(cont)
	# Abandonar pide una segunda pulsación (se pierde el 90% del botín).
	var quit := W.btn("Abandonar sector", func(): pass, "danger", 0, 16)
	quit.pressed.connect(func():
		if quit.has_meta("armed"):
			toggle_pause()
			sector._finish("death")
		else:
			quit.set_meta("armed", true)
			quit.text = "¿SEGURO? PIERDES EL %d%% DEL BOTÍN · PULSA OTRA VEZ" % int(GameData.DEATH_LOOT_LOSS * 100))
	box.add_child(quit)


func _modal(title: String) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.add_theme_stylebox_override("panel", UiTheme.bevel(Color(0.06, 0.09, 0.16, 0.97), Color(0.02, 0.04, 0.08, 0.97), UiTheme.ACCENT.darkened(0.3), 16, 12))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var l := UiTheme.heading(title, 32, UiTheme.ACCENT)
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
