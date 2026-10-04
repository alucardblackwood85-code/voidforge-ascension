class_name PageHangar
extends HBoxContainer
## HANGAR, al estilo de los MMO de naves: a la izquierda las naves (✓ adquirida, anillo = no adquirida,
## ★ activa); en el centro la seleccionada gira en el hangar en vista semifrontal; a la derecha su ficha
## de estadísticas (pestañas Nave / Pet) con el estado y las acciones.

var menu: StartMenu


## Distintivo de la tarjeta: círculo verde con ✓ (adquirida), anillo azul (no adquirida) y estrella (activa).
class Badge extends Control:
	var owned := false
	var active := false

	func _draw() -> void:
		var c := Vector2(size.x - 14, size.y - 14)
		if owned:
			draw_circle(c, 10, Color("1f6b3a"))
			draw_arc(c, 10, 0, TAU, 24, Color("6fd17a"), 2.0, true)
			draw_polyline(PackedVector2Array([c + Vector2(-5, 0), c + Vector2(-1, 4), c + Vector2(5, -4)]), Color.WHITE, 2.5, true)
		else:
			draw_arc(c, 9, 0, TAU, 24, Color("3aa0ff"), 3.0, true)
		if active:
			var s := Vector2(size.x - 14, 14)
			var pts := PackedVector2Array()
			for k in 10:
				var r := 9.0 if k % 2 == 0 else 4.0
				pts.append(s + Vector2.from_angle(-PI / 2 + k * TAU / 10) * r)
			draw_colored_polygon(pts, UiTheme.GOLD)


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var sel: String = menu.state["ship"]
	if sel == "" or not GameData.SHIPS.has(sel):
		sel = GameState.data["current_ship"]
		menu.state["ship"] = sel
	# Izquierda: naves
	var left := W.vbox(8)
	left.custom_minimum_size.x = 610
	if Prog.training_index() < Prog.TRAINING.size():
		left.add_child(_training_card())
	var fr: Array = W.frame("Naves  ·  %d / %d" % [GameState.data["ships"].size(), GameData.SHIPS.size()])
	fr[0].size_flags_vertical = Control.SIZE_EXPAND_FILL
	var g := W.grid(4, 8)
	for id in GameData.SHIPS.keys():
		g.add_child(_ship_card(id, id == sel))
	fr[1].add_child(W.scroll(g))
	left.add_child(fr[0])
	add_child(left)
	add_child(_view(sel))
	add_child(_sheet(sel))


## Entrenamiento: paso actual, su recompensa y el progreso de los siete pasos.
func _training_card() -> Control:
	var i := Prog.training_index()
	var step: Dictionary = Prog.TRAINING[i]
	var done := Prog.training_done(step["id"])
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", UiTheme.bevel(Color(0.04, 0.14, 0.16, 0.95), Color(0.02, 0.07, 0.09, 0.95), UiTheme.GOOD if done else UiTheme.ACCENT, 8, 8))
	var h := W.hbox(12)
	c.add_child(h)
	var v := W.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UiTheme.heading("Entrenamiento %d/%d — %s" % [i + 1, Prog.TRAINING.size(), step["name"]], 15))
	var d := UiTheme.label(step["desc"], 13, UiTheme.TEXT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	v.add_child(UiTheme.label("Recompensa: " + Prog.training_reward_text(step["reward"]), 12, UiTheme.WARN))
	h.add_child(v)
	var b := W.btn("Reclamar" if done else "En curso", func():
		if Prog.claim_training():
			Sfx.play("ui_select")
			menu.refresh(), "gold" if done else "normal", 130)
	b.disabled = not done
	h.add_child(b)
	return c


func _ship_card(id: String, selected: bool) -> Control:
	var s: Dictionary = GameData.SHIPS[id]
	var owned: bool = GameState.data["ships"].has(id)
	var active: bool = id == GameState.data["current_ship"]
	var c := PanelContainer.new()
	var border := UiTheme.GOLD if selected else (Color("2f5f80") if owned else UiTheme.BORDER)
	c.add_theme_stylebox_override("panel", UiTheme.bevel(Color(0.08, 0.12, 0.2) if owned else Color(0.05, 0.07, 0.11), Color(0.03, 0.05, 0.09), border, 4, 7))
	c.custom_minimum_size = Vector2(138, 128)
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var v := W.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(v)
	var nm := UiTheme.label(("★ " if s.get("special", false) else "") + s["name"], 13, Color.WHITE if owned else UiTheme.MUTED)
	nm.add_theme_font_override("font", UiTheme.display_font())
	nm.uppercase = true
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 92)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := W.pic(ShipSpin.frame_tex(id, 21), Vector2(0, 92))
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.custom_minimum_size = Vector2.ZERO
	if not owned:
		p.modulate = Color(0.55, 0.58, 0.65)
	holder.add_child(p)
	var badge := Badge.new()
	badge.owned = owned
	badge.active = active
	badge.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(badge)
	v.add_child(holder)
	c.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			menu.state["ship"] = id
			Sfx.play("ui_click")
			menu.refresh())
	return c


## Centro: hangar con la nave girando y su nombre.
func _view(id: String) -> Control:
	var s: Dictionary = GameData.SHIPS[id]
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", UiTheme.bevel(Color(0.04, 0.07, 0.12, 0.96), Color(0.02, 0.03, 0.06, 0.96), UiTheme.BORDER, 6, 10))
	var stack := Control.new()
	stack.clip_contents = true
	p.add_child(stack)
	if ResourceLoader.exists("res://assets/backgrounds/hangar.png"):
		var bg := TextureRect.new()
		bg.texture = load("res://assets/backgrounds/hangar.png")
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.modulate = Color(0.8, 0.85, 0.95)
		stack.add_child(bg)
	var spin := ShipSpin.make(id, Vector2(420, 360), 0.82)
	spin.set_anchors_preset(Control.PRESET_FULL_RECT)
	spin.tooltip_text = "Arrastra para girar la nave"
	stack.add_child(spin)
	var title := W.vbox(0)
	title.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	title.position = Vector2(-20, 14)
	title.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var n := UiTheme.heading(s["name"], 34, UiTheme.GOLD)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.add_child(n)
	var cl := UiTheme.heading(GameData.SHIP_CLASSES[s["class"]]["name"] + (" especial" if s.get("special", false) else ""), 18, UiTheme.TEXT)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.add_child(cl)
	stack.add_child(title)
	var note := UiTheme.label(s["note"], 13, UiTheme.MUTED)
	note.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	note.position = Vector2(16, -30)
	stack.add_child(note)
	return p


## Derecha: ficha de estadísticas con pestañas, estado y acciones.
func _sheet(id: String) -> Control:
	var s: Dictionary = GameData.SHIPS[id]
	var owned: bool = GameState.data["ships"].has(id)
	var active: bool = id == GameState.data["current_ship"]
	var col := W.vbox(10)
	col.custom_minimum_size.x = 380
	var tab: String = menu.state.get("hangar_tab", "ship")
	var tabs := W.hbox(4)
	for t in [["ship", "Nave"], ["pet", "Pet"]]:
		var key: String = t[0]
		var b := W.btn(t[1], func():
			menu.state["hangar_tab"] = key
			menu.refresh(), "primary" if key == tab else "normal", 0, 15)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
	col.add_child(tabs)
	var fr: Array = W.frame("")
	fr[0].size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rows := W.vbox(0)
	var data: Array = _ship_rows(id, owned) if tab == "ship" else _pet_rows()
	for i in data.size():
		var r: Array = data[i]
		if r.is_empty():
			var sep := ColorRect.new()
			sep.color = Color(UiTheme.BORDER, 0.6)
			sep.custom_minimum_size = Vector2(0, 1)
			rows.add_child(sep)
			continue
		rows.add_child(W.stat_row(r[0], r[1], i % 2 == 0, r[2] if r.size() > 2 else UiTheme.TEXT))
	fr[1].add_child(W.scroll(rows))
	col.add_child(fr[0])
	# Estado grande y acciones (como ACTIVE / MANAGE).
	var state := UiTheme.heading("Activa" if active else ("En propiedad" if owned else "No adquirida"), 30, UiTheme.GOOD if active else (UiTheme.ACCENT if owned else UiTheme.MUTED))
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(state)
	var acts := W.hbox(8)
	if owned:
		if not active:
			var ab := W.btn("Activar", func(): GameState.select_ship(id), "primary", 0, 18)
			ab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			acts.add_child(ab)
		var mb := W.btn("Gestionar", func():
			GameState.select_ship(id)
			menu.state["equip_tab"] = "ship"
			menu.show_page("equip"), "normal" if not active else "primary", 0, 18)
		mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		acts.add_child(mb)
	else:
		var pv := W.vbox(4)
		var pr := W.hbox(8)
		pr.add_child(W.cost_row(GameState.price_of("ship", id, "credits")))
		pr.add_child(UiTheme.label("o", 13, UiTheme.MUTED))
		pr.add_child(W.cost_row(GameState.price_of("ship", id, "nexo")))
		pv.add_child(pr)
		var bh := W.hbox(8)
		var buy := W.btn("Ir a comprar", func():
			menu.state["shop_tab"] = "ship"
			menu.show_page("shop"), "gold", 0, 17)
		buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bh.add_child(buy)
		var cr := W.btn("Fabricar", func():
			menu.state["craft_tab"] = "ship"
			menu.show_page("craft"), "normal", 0, 17)
		cr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bh.add_child(cr)
		pv.add_child(bh)
		acts.add_child(pv)
	col.add_child(acts)
	return col


## Filas [nombre, valor, color]; [] = separador. Con la nave en propiedad usa su equipo real.
func _ship_rows(id: String, owned: bool) -> Array:
	var s: Dictionary = GameData.SHIPS[id]
	var st := GameState.ship_stats(id)
	var lo := GameState.ensure_loadout(id) if owned else {}
	var count := func(key: String, total: int) -> String:
		if not owned:
			return str(total)
		return "%d / %d" % [(lo[key] as Array).filter(func(u): return int(u) >= 0).size(), total]
	var ammo := 0
	for k in GameState.data["ammo"].keys():
		ammo += int(GameState.data["ammo"][k])
	var missiles := 0
	for k in GameState.data.get("missiles", {}).keys():
		missiles += int(GameState.data["missiles"][k])
	var ab: Dictionary = GameData.ABILITIES[s.get("ability", GameData.SHIP_CLASSES[s["class"]]["ability"])]
	var rows := [
		["Puntos de casco", GameData.format_num(st["hull"])],
		["Escudo", GameData.format_num(st["shield"])],
		["Velocidad", str(int(st["speed"]))],
		["Multiplicador de daño", "x%.2f" % st["dmg"]],
		["Bodega", "%s u" % GameData.format_num(st["cargo"])],
		[],
		["Láseres", count.call("lasers", int(s["lasers"]))],
		["Generadores", count.call("gens", GameData.gen_slots_total(id))],
		["Módulos", count.call("mods", int(s["mods"]))],
		["Munición láser", GameData.format_num(ammo)],
		["Misiles", GameData.format_num(missiles)],
	]
	if owned:
		rows.append(["DPS teórico (x1)", GameData.format_num(GameState.theoretical_dps(id))])
	rows.append([])
	rows.append(["Clase", GameData.SHIP_CLASSES[s["class"]]["name"]])
	rows.append(["Habilidad [%s]" % Controls.key_label("ability"), ab["name"], UiTheme.WARN])
	if GameData.special_dr(id) > 0.0:
		rows.append(["Blindaje especial", "-%d%% daño" % int(round(GameData.special_dr(id) * 100.0)), UiTheme.WARN])
	return rows


func _pet_rows() -> Array:
	if not GameState.data["unlocks"].get("pet", false):
		return [["Pet", "No adquirido", UiTheme.MUTED], ["Precio", GameData.format_num(GameState.price_of("pet", "pet")["credits"]) + " créditos"], ["Dónde", "Tienda → Pet"]]
	var lvl := GameState.pet_level()
	var st := GameData.pet_stage(lvl)
	var lz: Array = GameState.data["drone"]["lasers"]
	var gz: Array = GameState.data["drone"]["gens"]
	return [
		["Forma", GameData.PET_STAGE_NAMES[st - 1], UiTheme.GOOD],
		["Nivel", "%d / %d" % [lvl, GameData.PET_MAX_LEVEL]],
		["Rol", Drone.ROLES[GameState.data["drone"]["role"]]["name"]],
		[],
		["Láseres", "%d / %d" % [lz.slice(0, GameData.pet_laser_slots(lvl)).filter(func(u): return int(u) >= 0).size(), GameData.pet_laser_slots(lvl)]],
		["Generadores de escudo", "%d / %d" % [gz.slice(0, GameData.pet_gen_slots(lvl)).filter(func(u): return int(u) >= 0).size(), GameData.pet_gen_slots(lvl)]],
		["Daño extra", "+%d%%" % int(GameData.PET_DMG_PER_LEVEL * (lvl - 1) * 100)],
		["Experiencia", GameData.format_num(GameState.data["pet"]["xp"])],
	]
