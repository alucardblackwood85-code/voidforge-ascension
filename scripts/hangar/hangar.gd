class_name Hangar
extends Control
## Hangar (17.1): nave, armamento, generadores, fabricación, mejoras, barra rápida, dron y mapa estelar.

signal launch_requested(params: Dictionary)

var tabs: TabContainer
var header: HBoxContainer
var selected_ship := ""
var selected_level := 1
var selected_biome := "ferron"


func _ready() -> void:
	# El padre es un Node (no Control): ajustamos el tamaño al viewport manualmente.
	_fit_viewport()
	get_viewport().size_changed.connect(_fit_viewport)
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)
	header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	vb.add_child(header)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(tabs)
	selected_ship = GameState.data["current_ship"]
	selected_level = int(GameState.data["sector_max"])
	GameState.changed.connect(_rebuild)
	_rebuild()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tab="):
			tabs.current_tab = int(arg.substr(6))
	if not GameState.last_result.is_empty():
		_show_last_result()


func _fit_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _rebuild() -> void:
	var current := tabs.current_tab
	for c in header.get_children():
		c.queue_free()
	for c in tabs.get_children():
		tabs.remove_child(c)
		c.queue_free()
	_build_header()
	_add_tab("Mapa estelar", _tab_starmap())
	_add_tab("Nave", _tab_ships())
	_add_tab("Armamento", _tab_lasers())
	_add_tab("Generadores", _tab_generators())
	_add_tab("Fabricación", _tab_crafting())
	_add_tab("Mejoras", _tab_upgrades())
	_add_tab("Barra rápida", _tab_hotbar())
	_add_tab("Dron", _tab_drone())
	_add_tab("Códex", _tab_codex())
	_add_tab("Inventario", _tab_inventory())
	if current >= 0 and current < tabs.get_tab_count():
		tabs.current_tab = current


func _add_tab(title: String, content: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	tabs.add_child(scroll)


func _build_header() -> void:
	var title := UiTheme.label("VOIDFORGE: ASCENSION", 26, UiTheme.ACCENT)
	header.add_child(title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)
	for k in ["credits", "nexo", "seals"]:
		header.add_child(UiTheme.label("%s  %s" % [GameData.mat_name(k), GameData.format_num(GameState.get_amount(k))], 17, GameData.mat_color(k) if k != "seals" else UiTheme.WARN))


func _section(parent: Control, text: String) -> void:
	var l := UiTheme.label(text, 20, UiTheme.ACCENT)
	parent.add_child(l)


func _vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func _row(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func _card() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_LIGHT, UiTheme.BORDER, 6, 1, 10))
	return p


# --- Mapa estelar -----------------------------------------------------------------------
func _biome_unlocked(id: String) -> bool:
	var b: Dictionary = GameData.BIOMES[id]
	return not b.get("locked", false) and int(GameState.data["sector_max"]) >= int(b["min_level"])


func _tab_starmap() -> Control:
	var v := _vbox(12)
	_section(v, "Seleccionar sector")
	var row := _row(20)
	v.add_child(row)
	var biomes := _vbox(6)
	biomes.custom_minimum_size.x = 360
	row.add_child(biomes)
	if not _biome_unlocked(selected_biome):
		selected_biome = "ferron"
	for id in GameData.BIOMES.keys():
		var b: Dictionary = GameData.BIOMES[id]
		var btn := Button.new()
		var tag := ""
		if b.get("locked", false):
			tag = "(expansión)"
		elif not _biome_unlocked(id):
			tag = "(requiere nivel %d)" % b["min_level"]
		else:
			tag = "Nivel %d+" % b["min_level"]
		btn.text = "%s   %s" % [b["name"], tag]
		btn.disabled = not _biome_unlocked(id)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if id == selected_biome:
			btn.add_theme_stylebox_override("normal", UiTheme.box(Color(0.12, 0.18, 0.28), UiTheme.ACCENT, 5, 1, 8))
			btn.add_theme_color_override("font_color", UiTheme.ACCENT)
		btn.pressed.connect(func():
			Sfx.play("ui_click")
			selected_biome = id
			selected_level = clampi(selected_level, int(b["min_level"]), int(GameState.data["sector_max"]))
			_rebuild())
		biomes.add_child(btn)
	var info := _vbox(10)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var bg_path := "res://assets/backgrounds/%s.png" % selected_biome
	if ResourceLoader.exists(bg_path):
		var preview := TextureRect.new()
		preview.texture = load(bg_path)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		preview.custom_minimum_size = Vector2(0, 150)
		preview.clip_contents = true
		info.add_child(preview)
	var b_sel: Dictionary = GameData.BIOMES[selected_biome]
	var lv_row := _row()
	lv_row.add_child(UiTheme.label("Nivel de amenaza:", 18))
	var spin := SpinBox.new()
	spin.min_value = b_sel["min_level"]
	spin.max_value = maxi(int(b_sel["min_level"]), int(GameState.data["sector_max"]))
	spin.value = clampi(selected_level, int(spin.min_value), int(spin.max_value))
	lv_row.add_child(spin)
	lv_row.add_child(UiTheme.label("(máximo desbloqueado: %d)" % GameState.data["sector_max"], 14, UiTheme.MUTED))
	info.add_child(lv_row)
	var details := UiTheme.rich("")
	info.add_child(details)
	var update := func():
		selected_level = int(spin.value)
		details.text = _sector_details(selected_level)
	spin.value_changed.connect(func(_v): update.call())
	update.call()
	var launch := UiTheme.button("  LANZAR INCURSIÓN  ", func():
		GameState.save_game()
		Sfx.play("warp")
		launch_requested.emit({"level": selected_level, "seed": randi(), "biome": selected_biome}))
	launch.add_theme_font_size_override("font_size", 22)
	launch.custom_minimum_size = Vector2(320, 56)
	launch.add_theme_stylebox_override("normal", UiTheme.box(Color(0.05, 0.25, 0.3), UiTheme.ACCENT, 6, 2, 10))
	var warn := ""
	if GameState.equipped_lasers().is_empty():
		launch.disabled = true
		warn = "Equipa al menos un láser en Armamento."
	info.add_child(launch)
	if warn != "":
		info.add_child(UiTheme.label(warn, 15, UiTheme.BAD))
	return v


func power_index(ship_id: String = "") -> float:
	# 23.1: Poder = Casco^0.45 x Velocidad^0.20 x DañoEfectivo^0.70 x Escudo^0.35
	var st := GameState.ship_stats(ship_id)
	var dps := maxf(1.0, GameState.theoretical_dps(ship_id))
	return pow(st["hull"], 0.45) * pow(st["speed"], 0.2) * pow(dps, 0.7) * pow(st["shield"], 0.35) / 100.0


func recommended_power(level: int) -> float:
	var base := 1000.0 # poder aproximado del Kestrel inicial
	return base * pow(GameData.level_hp(1.0, level) / GameData.level_hp(1.0, 1), 0.9) * pow(GameData.level_dmg(1.0, level) / GameData.level_dmg(1.0, 1), 0.5)


func _sector_details(level: int) -> String:
	var b: Dictionary = GameData.BIOMES[selected_biome]
	var mine := power_index()
	var rec := recommended_power(level)
	var col := "6fd17a" if mine >= rec else ("ffb84a" if mine >= rec * 0.8 else "ff5a5a")
	var res: PackedStringArray = []
	for k in b["resources"].keys():
		res.append(GameData.mat_name(k))
	var s := "[b]%s[/b] — %s  Facción: [b]%s[/b]\n" % [b["name"], b["desc"], b["faction"]]
	s += "Peligros: %s  Recursos: %s.\n\n" % [b["hazards"], ", ".join(res)]
	s += "Poder recomendado: [b]%s[/b]   ·   Tu poder: [color=#%s][b]%s[/b][/color]\n" % [GameData.format_num(rec), col, GameData.format_num(mine)]
	s += "Vida enemiga x%.2f   ·   Daño enemigo x%.2f   ·   Recompensas x%.2f\n" % [GameData.level_hp(1.0, level), GameData.level_dmg(1.0, level), GameData.level_reward(1.0, level)]
	s += "Objetivo procedural: Limpieza o Destruir nidos. Jefe: %s. Variantes élite: Boss%s.\n" % [GameData.ENEMIES[b["elites"][0]]["name"], ", Mega" if level >= 3 else ""]
	if GameState.data["sector_cleared"].has(level):
		s += "[color=#7d8aa3]Primera limpieza ya obtenida.[/color]"
	else:
		s += "[color=#ff4fd8]Primera limpieza: +%d Cristales Nexo[/color]" % (5 + level / 2)
	return s


# --- Naves ------------------------------------------------------------------------
func _tab_ships() -> Control:
	var row := _row(16)
	var list := GridContainer.new()
	list.columns = 2
	list.add_theme_constant_override("h_separation", 6)
	list.add_theme_constant_override("v_separation", 6)
	list.custom_minimum_size.x = 520
	row.add_child(list)
	for id in GameData.SHIPS.keys():
		var s: Dictionary = GameData.SHIPS[id]
		var owned: bool = GameState.data["ships"].has(id)
		var b := Button.new()
		b.text = "%s%s%s" % ["★ " if s.get("special", false) else "", s["name"], "  ✔" if owned else ""]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.x = 250
		b.icon = _ship_tex(id)
		b.add_theme_constant_override("icon_max_width", 44)
		if id == GameState.data["current_ship"]:
			b.add_theme_color_override("font_color", UiTheme.ACCENT)
		if id == selected_ship:
			b.add_theme_stylebox_override("normal", UiTheme.box(Color(0.12, 0.18, 0.28), UiTheme.ACCENT, 5, 1, 8))
		b.pressed.connect(func():
			selected_ship = id
			_rebuild())
		list.add_child(b)
	row.add_child(_ship_detail(selected_ship))
	return row


func _ship_detail(id: String) -> Control:
	var s: Dictionary = GameData.SHIPS[id]
	var owned: bool = GameState.data["ships"].has(id)
	var card := _card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := _vbox()
	card.add_child(v)
	var tex := _ship_tex(id)
	if tex:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(0, 220)
		v.add_child(pic)
	v.add_child(UiTheme.label(s["name"], 24, UiTheme.ACCENT))
	v.add_child(UiTheme.label("%s%s — %s" % [GameData.SHIP_CLASSES[s["class"]]["name"], " especial" if s.get("special", false) else "", s["note"]], 15, UiTheme.MUTED))
	var st := GameState.ship_stats(id)
	var txt := "[table=4][cell][b]Atributo  [/b][/cell][cell][b]Base  [/b][/cell][cell][b]Bonos  [/b][/cell][cell][b]Total[/b][/cell]"
	txt += _stat_row("Casco", st["hull_base"], st["hull"])
	txt += _stat_row("Escudo", st["shield_base"], st["shield"])
	txt += _stat_row("Velocidad", st["speed_base"], st["speed"])
	txt += "[/table]\n"
	txt += "Daño: x%.2f   ·   Carga: %d u   ·   Slots: %d láseres, %d generadores, %d módulos\n" % [s["dmg"], st["cargo"], s["lasers"], s["gens"], s["mods"]]
	var ab_id: String = s.get("ability", GameData.SHIP_CLASSES[s["class"]]["ability"])
	var ab: Dictionary = GameData.ABILITIES[ab_id]
	txt += "Habilidad [%s]: [b]%s[/b] — %s (CD %ds)\n" % [Controls.key_label("ability"), ab["name"], ab["desc"], int(ab["cd"])]
	if owned:
		txt += "DPS teórico (x1): [b]%s[/b]   ·   Poder: [b]%s[/b]" % [GameData.format_num(GameState.theoretical_dps(id)), GameData.format_num(power_index(id))]
	else:
		txt += "Coste: " + UiTheme.cost_text(s["cost"])
	v.add_child(UiTheme.rich(txt))
	if owned:
		var b := UiTheme.button("Nave activa" if id == GameState.data["current_ship"] else "Seleccionar como nave activa", func(): GameState.select_ship(id))
		b.disabled = id == GameState.data["current_ship"]
		v.add_child(b)
	else:
		var b := UiTheme.button("Fabricar", func(): GameState.buy_ship(id))
		b.disabled = not GameState.can_afford(s["cost"])
		v.add_child(b)
	return card


func _stat_row(name: String, base: float, total: float) -> String:
	var diff := total - base
	var col := "6fd17a" if diff > 0.01 else ("ff5a5a" if diff < -0.01 else "7d8aa3")
	return "[cell]%s  [/cell][cell]%s  [/cell][cell][color=#%s]%+.0f[/color]  [/cell][cell][b]%s[/b][/cell]" % [name, GameData.format_num(base), col, diff, GameData.format_num(total)]


# --- Láseres y generadores --------------------------------------------------------------
func _tab_lasers() -> Control:
	return _equip_tab("lasers", GameData.LASERS, "Láseres equipados en %s" % GameData.SHIPS[GameState.data["current_ship"]]["name"])


func _tab_generators() -> Control:
	return _equip_tab("gens", GameData.GENERATORS, "Generadores en %s (escudo o velocidad en cualquier slot)" % GameData.SHIPS[GameState.data["current_ship"]]["name"])


func _item_label(list_key: String, it: Dictionary) -> String:
	var table: Dictionary = GameData.LASERS if list_key == "lasers" else GameData.GENERATORS
	return "%s  Nv %d" % [table[it["id"]]["name"], int(it["level"])]


func _equip_tab(list_key: String, table: Dictionary, title: String) -> Control:
	var v := _vbox(10)
	_section(v, title)
	var lo := GameState.current_loadout()
	var slots: Array = lo[list_key]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	v.add_child(grid)
	for i in slots.size():
		grid.add_child(UiTheme.label("Slot %d" % (i + 1), 16, UiTheme.MUTED))
		var opt := OptionButton.new()
		opt.custom_minimum_size.x = 420
		opt.add_item("— vacío —", -1)
		var sel := 0
		for it in GameState.data[list_key]:
			var where := GameState.equipped_on(list_key, int(it["uid"]))
			var tag := ""
			if where != "" and where != GameState.data["current_ship"]:
				tag = "  (en %s)" % GameData.SHIPS[where]["name"]
			elif where == GameState.data["current_ship"] and int(it["uid"]) != int(slots[i]):
				continue
			opt.add_item(_item_label(list_key, it) + tag, int(it["uid"]))
			if int(it["uid"]) == int(slots[i]):
				sel = opt.item_count - 1
		opt.select(sel)
		var slot_i := i
		opt.item_selected.connect(func(idx): GameState.equip(list_key, slot_i, opt.get_item_id(idx)))
		grid.add_child(opt)
	if list_key == "lasers":
		v.add_child(UiTheme.label("DPS teórico con munición x1: %s" % GameData.format_num(GameState.theoretical_dps()), 16, UiTheme.GOOD))
	_section(v, "Fabricar")
	var shop := GridContainer.new()
	shop.columns = 4
	shop.add_theme_constant_override("h_separation", 14)
	shop.add_theme_constant_override("v_separation", 6)
	v.add_child(shop)
	for id in table.keys():
		var d: Dictionary = table[id]
		var name_l := UiTheme.label(d["name"], 16, GameData.ITEM_RARITY_COLORS.get(d.get("rarity", "comun"), UiTheme.TEXT))
		name_l.custom_minimum_size.x = 200
		shop.add_child(name_l)
		var desc := ""
		if list_key == "lasers":
			desc = "%s%s · %.1f/s · %s / %s" % [("%.2fx" % d["dmg"]), (" x%d" % d["shots"] if int(d["shots"]) > 1 else ""), d["rate"], d["adv"], d["dis"]]
		else:
			desc = "%s · %s" % [_gen_stats(d["stats"]), d["trait"]]
		var dl := UiTheme.label(desc, 14, UiTheme.MUTED)
		dl.custom_minimum_size.x = 420
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		shop.add_child(dl)
		var cl := UiTheme.rich(UiTheme.cost_text(d["cost"]), 13)
		cl.custom_minimum_size.x = 300
		shop.add_child(cl)
		var b := UiTheme.button("Fabricar", func():
			if list_key == "lasers":
				GameState.buy_laser(id)
			else:
				GameState.buy_generator(id))
		b.disabled = not GameState.can_afford(d["cost"])
		shop.add_child(b)
	return v


func _gen_stats(stats: Dictionary) -> String:
	var names := {"shield": "escudo", "speed": "velocidad", "hull": "casco", "recharge": "recarga", "accel": "aceleración", "turn": "giro", "boost_cd": "CD impulso", "shield_regen": "regen. escudo/s"}
	var parts: PackedStringArray = []
	for k in stats.keys():
		parts.append("%+.1f%% %s" % [float(stats[k]) * 100.0, names.get(k, k)])
	return ", ".join(parts)


# --- Fabricación -------------------------------------------------------------------------
func _tab_crafting() -> Control:
	var v := _vbox(10)
	_section(v, "Munición (lotes de 100)")
	var g := GridContainer.new()
	g.columns = 6
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 6)
	v.add_child(g)
	for id in GameData.AMMO.keys():
		var a: Dictionary = GameData.AMMO[id]
		var icon := TextureRect.new()
		icon.texture = SpriteLib.get_icon("ammo", id)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(56, 56)
		g.add_child(icon)
		g.add_child(UiTheme.label("%s (%s)" % [a["name"], a["short"]], 16, a["color"]))
		g.add_child(UiTheme.label("En almacén: %s" % GameData.format_num(GameState.data["ammo"].get(id, 0)), 15))
		var c := UiTheme.rich(UiTheme.cost_text(a["recipe"]), 13)
		c.custom_minimum_size.x = 380
		g.add_child(c)
		var b1 := UiTheme.button("+100", func(): GameState.craft_ammo(id, 1))
		b1.disabled = not GameState.can_afford(a["recipe"])
		g.add_child(b1)
		var b10 := UiTheme.button("+1000", func(): GameState.craft_ammo(id, 10))
		b10.disabled = not GameState.can_afford(a["recipe"], 10)
		g.add_child(b10)
	_section(v, "Consumibles y desplegables")
	var g2 := GridContainer.new()
	g2.columns = 5
	g2.add_theme_constant_override("h_separation", 14)
	g2.add_theme_constant_override("v_separation", 6)
	v.add_child(g2)
	for id in GameData.ITEMS.keys():
		var it: Dictionary = GameData.ITEMS[id]
		var l := UiTheme.label("%s — %s" % [it["name"], it["desc"]], 15, it["color"])
		l.custom_minimum_size.x = 380
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		g2.add_child(l)
		g2.add_child(UiTheme.label("Tienes: %d" % int(GameState.data["items"].get(id, 0)), 15))
		var c := UiTheme.rich(UiTheme.cost_text(it["recipe"]), 13)
		c.custom_minimum_size.x = 300
		g2.add_child(c)
		var b1 := UiTheme.button("+1", func(): GameState.craft_item(id, 1))
		b1.disabled = not GameState.can_afford(it["recipe"])
		g2.add_child(b1)
		var b5 := UiTheme.button("+5", func(): GameState.craft_item(id, 5))
		b5.disabled = not GameState.can_afford(it["recipe"], 5)
		g2.add_child(b5)
	return v


# --- Mejoras 1-16 ---------------------------------------------------------------------------
func _tab_upgrades() -> Control:
	var v := _vbox(8)
	_section(v, "Mejora de componentes (+1% por nivel sobre el valor base, máx. 16)")
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 6)
	v.add_child(g)
	for list_key in ["lasers", "gens"]:
		for it in GameState.data[list_key]:
			var lvl := int(it["level"])
			var where := GameState.equipped_on(list_key, int(it["uid"]))
			var l := UiTheme.label(_item_label(list_key, it) + ("  [%s]" % GameData.SHIPS[where]["name"] if where != "" else ""), 16)
			l.custom_minimum_size.x = 360
			g.add_child(l)
			g.add_child(UiTheme.label("+%d%% → +%d%%" % [lvl, mini(16, lvl + 1)], 15, UiTheme.GOOD))
			if lvl >= 16:
				g.add_child(UiTheme.label("Nivel máximo", 14, UiTheme.MUTED))
				g.add_child(Control.new())
				continue
			var cost := GameData.upgrade_cost(lvl, GameState.item_base_credits(list_key, it["id"]))
			var c := UiTheme.rich(UiTheme.cost_text(cost), 13)
			c.custom_minimum_size.x = 420
			g.add_child(c)
			var uid := int(it["uid"])
			var b := UiTheme.button("Mejorar", func(): GameState.upgrade_item(list_key, uid))
			b.disabled = not GameState.can_afford(cost)
			g.add_child(b)
	return v


# --- Barra rápida ---------------------------------------------------------------------------
func _tab_hotbar() -> Control:
	var v := _vbox(8)
	_section(v, "Barra rápida de %s (preset guardado por nave)" % GameData.SHIPS[GameState.data["current_ship"]]["name"])
	v.add_child(UiTheme.label("Asigna munición o consumibles a cada tecla. En misión: tecla = equipar munición / usar objeto.", 14, UiTheme.MUTED))
	var hb: Array = GameState.current_loadout()["hotbar"]
	var options: Array = [null]
	for id in GameData.AMMO.keys():
		options.append({"type": "ammo", "id": id})
	for id in GameData.ITEMS.keys():
		options.append({"type": "item", "id": id})
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	v.add_child(g)
	for i in GameState.HOTBAR_SIZE:
		g.add_child(UiTheme.label("[%s]" % Controls.key_label("hotbar_%d" % i), 18, UiTheme.ACCENT))
		var opt := OptionButton.new()
		opt.custom_minimum_size.x = 380
		var sel := 0
		for oi in options.size():
			var o = options[oi]
			if o == null:
				opt.add_item("— vacío —")
			elif o["type"] == "ammo":
				opt.add_item("%s (%s) — %s" % [GameData.AMMO[o["id"]]["name"], GameData.AMMO[o["id"]]["short"], GameData.format_num(GameState.data["ammo"].get(o["id"], 0))])
			else:
				opt.add_item("%s — %d" % [GameData.ITEMS[o["id"]]["name"], int(GameState.data["items"].get(o["id"], 0))])
			var cur = hb[i]
			if cur is Dictionary and o is Dictionary and cur["type"] == o["type"] and cur["id"] == o["id"]:
				sel = oi
		opt.select(sel)
		var slot_i := i
		opt.item_selected.connect(func(idx): GameState.set_hotbar(slot_i, options[idx]))
		g.add_child(opt)
	return v


# --- Dron ----------------------------------------------------------------------------
func _tab_drone() -> Control:
	var v := _vbox(10)
	_section(v, "Dron acompañante")
	v.add_child(UiTheme.label("El dron sigue a la nave. Su habilidad se activa con [%s]." % Controls.key_label("drone"), 15, UiTheme.MUTED))
	var cur: String = GameState.data.get("drone_role", "asalto")
	for role in Drone.ROLES.keys():
		var r: Dictionary = Drone.ROLES[role]
		var b := UiTheme.button("%s%s — %s" % ["● " if role == cur else "○ ", r["name"], r["ability"]], func():
			GameState.data["drone_role"] = role
			GameState.save_game()
			_rebuild())
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(b)
	v.add_child(UiTheme.label("Próximamente: roles Defensa, Reparador e Interdictor; láseres y módulos exclusivos del dron.", 14, UiTheme.MUTED))
	return v


# --- Inventario / ajustes ---------------------------------------------------------------------
func _tab_inventory() -> Control:
	var v := _vbox(8)
	_section(v, "Materiales")
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 30)
	v.add_child(g)
	for id in GameData.MATERIALS.keys():
		var q := GameState.get_amount(id)
		if q <= 0:
			continue
		g.add_child(UiTheme.label(GameData.mat_name(id), 15, GameData.mat_color(id)))
		g.add_child(UiTheme.label(GameData.format_num(q), 15))
	var st: Dictionary = GameState.data["stats"]
	_section(v, "Estadísticas")
	v.add_child(UiTheme.label("Incursiones %d · Extracciones %d · Derrotas %d · Bajas %d" % [st["runs"], st["extractions"], st["deaths"], st["kills"]], 15))
	_section(v, "Ajustes")
	var wasd := CheckBox.new()
	wasd.text = "Movimiento alternativo WASD"
	wasd.button_pressed = GameState.data["settings"].get("wasd", true)
	wasd.toggled.connect(func(on):
		GameState.data["settings"]["wasd"] = on
		GameState.save_game())
	v.add_child(wasd)
	var reset := UiTheme.button("Reiniciar progreso", func():
		var dlg := ConfirmationDialog.new()
		dlg.dialog_text = "¿Borrar todo el progreso guardado?"
		dlg.confirmed.connect(GameState.reset_profile)
		add_child(dlg)
		dlg.popup_centered())
	reset.add_theme_color_override("font_color", UiTheme.BAD)
	v.add_child(reset)
	v.add_child(UiTheme.label("Versión %s — prototipo. Guardado local (el GDD prevé servidor autoritativo)." % ProjectSettings.get_setting("application/config/version"), 13, UiTheme.MUTED))
	return v


func _show_last_result() -> void:
	var r := GameState.last_result
	GameState.last_result = {}
	if r.has("first_clear_nexo"):
		var dlg := AcceptDialog.new()
		dlg.title = "Primera limpieza"
		dlg.dialog_text = "¡Sector nivel %d limpiado por primera vez!\n+%d Cristales Nexo. Nivel %d desbloqueado." % [r["level"], r["first_clear_nexo"], r["level"] + 1]
		add_child(dlg)
		dlg.popup_centered.call_deferred()


func _ship_tex(id: String) -> Texture2D:
	var t := SpriteLib.get_tex("ships", id)
	return t if t else SpriteLib.get_tex("ships", GameData.SHIPS[id]["class"])


# --- Códex de alienígenas (21.2) -----------------------------------------------------------
const ARCH_NAMES := {
	"harasser": "Hostigador", "swarm": "Enjambre", "tank": "Tanque", "hunter": "Cazador", "charger": "Rompelíneas",
	"support": "Soporte", "miner": "Minador", "artillery": "Artillería", "mother": "Nodriza / Invocador",
	"drainer": "Drenador", "ambusher": "Emboscador", "defender": "Defensor", "sniper": "Francotirador",
	"elite": "Élite", "control": "Control", "trap": "Trampa",
}


func _tab_codex() -> Control:
	var v := _vbox(10)
	for bid in GameData.BIOMES.keys():
		var b: Dictionary = GameData.BIOMES[bid]
		if not b.has("enemies"):
			continue
		_section(v, "%s — %s" % [b["faction"], b["name"]])
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		v.add_child(grid)
		var ids: Array = b["enemies"].keys() + b["elites"]
		for eid in ids:
			var e: Dictionary = GameData.ENEMIES[eid]
			var card := _card()
			card.custom_minimum_size = Vector2(250, 0)
			var cv := _vbox(2)
			card.add_child(cv)
			var t := SpriteLib.get_tex("enemies", eid)
			if t:
				var pic := TextureRect.new()
				pic.texture = t
				pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				pic.custom_minimum_size = Vector2(0, 110)
				cv.add_child(pic)
			cv.add_child(UiTheme.label(e["name"], 16, e["accent"].lerp(Color.WHITE, 0.4)))
			cv.add_child(UiTheme.label("%s · HP %d · DMG %d · VEL %d" % [ARCH_NAMES.get(e["arch"], e["arch"]), e["hp"], e["dmg"], e["vel"]], 12, UiTheme.MUTED))
			grid.add_child(card)
	return v
