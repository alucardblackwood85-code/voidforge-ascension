class_name PageHangar
extends HBoxContainer
## HANGAR: naves disponibles, vista previa de la seleccionada con sus estadísticas y botón para
## confirmarla y pasar a Equipamiento.

var menu: StartMenu


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	var sel: String = menu.state["ship"]
	if sel == "" or not GameData.SHIPS.has(sel):
		sel = GameState.data["current_ship"]
		menu.state["ship"] = sel
	# Lista de naves
	var left := W.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(W.title("Naves"))
	left.add_child(UiTheme.label("En propiedad: %d / %d" % [GameState.data["ships"].size(), GameData.SHIPS.size()], 14, UiTheme.MUTED))
	var g := W.grid(5, 8)
	for id in GameData.SHIPS.keys():
		g.add_child(_ship_card(id, id == sel))
	left.add_child(W.scroll(g))
	add_child(left)
	add_child(_detail(sel))


func _ship_card(id: String, selected: bool) -> Control:
	var s: Dictionary = GameData.SHIPS[id]
	var owned: bool = GameState.data["ships"].has(id)
	var active: bool = id == GameState.data["current_ship"]
	var border := UiTheme.ACCENT if selected else (UiTheme.GOOD if active else UiTheme.BORDER)
	var c := W.card(Color(0.06, 0.09, 0.15, 0.92) if owned else Color(0.04, 0.05, 0.08, 0.85), border, 6)
	c.custom_minimum_size = Vector2(160, 150)
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var v := W.vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(v)
	var p := W.pic(W.icon("ship", id), Vector2(140, 92))
	if not owned:
		p.modulate = Color(0.45, 0.45, 0.5)
	v.add_child(p)
	var name_l := UiTheme.label(("★ " if s.get("special", false) else "") + s["name"], 14, Color.WHITE if owned else UiTheme.MUTED)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	var tag: String = "ACTIVA" if active else ("En propiedad" if owned else GameData.SHIP_CLASSES[s["class"]]["name"])
	var tl := UiTheme.label(tag, 11, UiTheme.GOOD if active else UiTheme.MUTED)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tl)
	c.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			menu.state["ship"] = id
			Sfx.play("ui_click")
			menu.refresh())
	return c


func _detail(id: String) -> Control:
	var s: Dictionary = GameData.SHIPS[id]
	var owned: bool = GameState.data["ships"].has(id)
	var panel := W.card(Color(0.04, 0.06, 0.11, 0.94), Color(0.2, 0.35, 0.5), 14)
	panel.custom_minimum_size.x = 620
	var v := W.vbox(8)
	panel.add_child(v)
	v.add_child(ShipPreview.make(W.icon("ship", id), Vector2(580, 280)))
	var head := W.hbox(10)
	head.add_child(UiTheme.label(("★ " if s.get("special", false) else "") + s["name"], 28, UiTheme.ACCENT))
	head.add_child(W.spacer())
	head.add_child(UiTheme.label(GameData.SHIP_CLASSES[s["class"]]["name"] + (" especial" if s.get("special", false) else ""), 16, UiTheme.WARN))
	v.add_child(head)
	v.add_child(UiTheme.label(s["note"], 14, UiTheme.MUTED))
	# Barras comparativas contra la nave activa.
	var cur: Dictionary = GameData.SHIPS[GameState.data["current_ship"]]
	var maxes := {"hull": 0.0, "speed": 0.0, "dmg": 0.0, "cargo": 0.0}
	for sid in GameData.SHIPS.keys():
		for k in maxes.keys():
			maxes[k] = maxf(maxes[k], float(GameData.SHIPS[sid][k]))
	var stats := W.grid(3, 8)
	_bar(stats, "Casco", float(s["hull"]), float(cur["hull"]), maxes["hull"], Color("5ad16a"), GameData.format_num(s["hull"]))
	_bar(stats, "Escudo", float(s["hull"]) * GameData.SHIELD_FROM_HULL, float(cur["hull"]) * GameData.SHIELD_FROM_HULL, maxes["hull"] * GameData.SHIELD_FROM_HULL, Color("3aa0ff"), GameData.format_num(float(s["hull"]) * GameData.SHIELD_FROM_HULL))
	_bar(stats, "Velocidad", float(s["speed"]), float(cur["speed"]), maxes["speed"], Color("ffd84a"), str(s["speed"]))
	_bar(stats, "Daño", float(s["dmg"]), float(cur["dmg"]), maxes["dmg"], Color("ff5a5a"), "x%.2f" % s["dmg"])
	_bar(stats, "Carga", float(s["cargo"]), float(cur["cargo"]), maxes["cargo"], Color("c8a0ff"), "%d u" % (int(s["cargo"]) * GameData.CARGO_UNIT))
	v.add_child(stats)
	var ab: Dictionary = GameData.ABILITIES[s.get("ability", GameData.SHIP_CLASSES[s["class"]]["ability"])]
	v.add_child(UiTheme.rich("Slots: [b]%d[/b] láseres · [b]%d[/b] generadores · [b]%d[/b] módulos\nHabilidad [%s]: [b]%s[/b] — %s (CD %ds)" % [s["lasers"], s["gens"], s["mods"], Controls.key_label("ability"), ab["name"], ab["desc"], int(ab["cd"])], 15))
	var buttons := W.hbox(10)
	if owned:
		var b := W.button("CONFIRMAR Y EQUIPAR  ›", func():
			GameState.select_ship(id)
			menu.state["equip_tab"] = "ship"
			menu.show_page("equip"), true)
		b.custom_minimum_size = Vector2(320, 52)
		buttons.add_child(b)
	else:
		buttons.add_child(UiTheme.label("Precio:", 15, UiTheme.MUTED))
		buttons.add_child(W.cost_row(GameState.price_of("ship", id)))
		buttons.add_child(W.spacer())
		buttons.add_child(W.button("Ir a la tienda", func():
			menu.state["shop_tab"] = "ship"
			menu.show_page("shop")))
		buttons.add_child(W.button("Fabricar", func():
			menu.state["craft_tab"] = "ship"
			menu.show_page("craft")))
	v.add_child(buttons)
	return panel


func _bar(g: GridContainer, name: String, val: float, cur: float, mx: float, col: Color, text: String) -> void:
	var l := UiTheme.label(name, 14)
	l.custom_minimum_size.x = 90
	g.add_child(l)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(360, 14)
	bar.max_value = mx
	bar.value = val
	bar.add_theme_stylebox_override("fill", UiTheme.box(col, col, 3, 0, 0))
	g.add_child(bar)
	var diff := val - cur
	var dtxt := ""
	if absf(diff) > 0.001:
		dtxt = " (%s)" % ("+" if diff > 0 else "−")
	g.add_child(UiTheme.label(text + dtxt, 14, UiTheme.GOOD if diff > 0.001 else (UiTheme.BAD if diff < -0.001 else UiTheme.TEXT)))
