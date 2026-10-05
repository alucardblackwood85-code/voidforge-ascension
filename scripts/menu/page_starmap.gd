class_name PageStarmap
extends VBoxContainer
## JUGAR: mapa estelar. Elige bioma y nivel de amenaza y lanza la incursión.

var menu: StartMenu


func _biome_unlocked(id: String) -> bool:
	var b: Dictionary = GameData.BIOMES[id]
	return not b.get("locked", false) and int(GameState.data["sector_max"]) >= int(b["min_level"])


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	if not _biome_unlocked(menu.state["biome"]):
		menu.state["biome"] = "ferron"
	var sel: String = menu.state["biome"]
	add_child(W.title("Mapa estelar — elige tu destino"))
	# Una columna por facción: arriba su mapa de especies débiles, debajo el de las fuertes.
	var cards := W.grid(5, 10)
	var open_ids: Array = []
	for id in GameData.BIOMES.keys():
		if not GameData.BIOMES[id].get("locked", false):
			open_ids.append(id)
	var weak := open_ids.filter(func(i): return GameData.theme_of(i) == i)
	var strong := open_ids.filter(func(i): return GameData.theme_of(i) != i)
	for id in weak + strong:
		cards.add_child(_biome_card(id, id == sel))
	add_child(cards)
	var locked: PackedStringArray = []
	for id in GameData.BIOMES.keys():
		if GameData.BIOMES[id].get("locked", false):
			locked.append(GameData.BIOMES[id]["name"])
	add_child(UiTheme.label("Próximamente: " + ", ".join(locked), 13, UiTheme.MUTED))
	var wm := Prog.weekly_mod()
	add_child(UiTheme.label("Modificador semanal — %s: %s" % [wm["name"], wm["desc"]], 15, UiTheme.WARN))
	# Detalle y lanzamiento
	var b_sel: Dictionary = GameData.BIOMES[sel]
	var panel := W.card(Color(0.04, 0.06, 0.11, 0.94), Color(0.2, 0.35, 0.5), 14)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pv := W.vbox(10)
	panel.add_child(pv)
	var lv_row := W.hbox(10)
	lv_row.add_child(UiTheme.label("Nivel de amenaza:", 18))
	var spin := SpinBox.new()
	spin.min_value = b_sel["min_level"]
	spin.max_value = maxi(int(b_sel["min_level"]), int(GameState.data["sector_max"]))
	spin.value = clampi(int(menu.state["level"]), int(spin.min_value), int(spin.max_value))
	lv_row.add_child(spin)
	lv_row.add_child(UiTheme.label("(máximo desbloqueado: %d)" % GameState.data["sector_max"], 14, UiTheme.MUTED))
	lv_row.add_child(W.spacer())
	# M12: seguro de carga opcional (al morir conservas el 50% del botín en lugar del 10%).
	var insure := CheckBox.new()
	insure.focus_mode = Control.FOCUS_NONE
	var update_insure := func():
		insure.text = "Seguro de carga: %s créditos (al morir conservas el 50%%)" % GameData.format_num(GameData.insurance_cost(int(spin.value)))
	update_insure.call()
	spin.value_changed.connect(func(_v): update_insure.call())
	# M9: Ascensión (se desbloquea al limpiar el nivel 50): vida x2^A, daño x1,55^A, recompensas x1,75^A.
	var asc_spin := SpinBox.new()
	asc_spin.min_value = 0
	asc_spin.max_value = int(GameState.data.get("asc_max", 0))
	asc_spin.value = mini(int(menu.state.get("asc", 0)), int(asc_spin.max_value))
	asc_spin.prefix = "Ascensión"
	asc_spin.tooltip_text = "Vida enemiga x2, daño x1,55 y recompensas x1,75 por nivel de Ascensión."
	asc_spin.visible = asc_spin.max_value > 0
	lv_row.add_child(asc_spin)
	var do_launch := func():
		var lvl := int(spin.value)
		var insured := insure.button_pressed
		if insured and not GameState.pay({"credits": GameData.insurance_cost(lvl)}):
			Sfx.play("ui_error")
			return
		menu.launch({"level": lvl, "seed": randi(), "biome": sel, "insured": insured, "asc": int(asc_spin.value)})
	var on_launch := func():
		# M7: aviso fuerte si tu poder queda muy por debajo del recomendado.
		var ratio := power_index() / recommended_power(int(spin.value))
		if ratio < 0.7:
			var dlg := ConfirmationDialog.new()
			dlg.title = "Sector peligroso"
			dlg.dialog_text = "Tu poder es el %d%% del recomendado para el nivel %d.\nLos enemigos pueden destruirte en segundos. ¿Lanzar igualmente?" % [int(ratio * 100), int(spin.value)]
			dlg.ok_button_text = "Lanzar"
			dlg.confirmed.connect(do_launch)
			menu.add_child(dlg)
			dlg.popup_centered()
		else:
			do_launch.call()
	var launch := W.btn("Lanzar incursión  >", on_launch, "gold", 340, 24)
	lv_row.add_child(insure)
	launch.custom_minimum_size.y = 60
	launch.add_theme_font_size_override("font_size", 24)
	if GameState.equipped_lasers().is_empty():
		launch.disabled = true
		launch.tooltip_text = "Equipa al menos un láser en Equipamiento."
	lv_row.add_child(launch)
	pv.add_child(lv_row)
	var details := UiTheme.rich("", 16)
	pv.add_child(details)
	var update := func():
		menu.state["level"] = int(spin.value)
		menu.state["asc"] = int(asc_spin.value)
		details.text = _details(sel, int(spin.value), int(asc_spin.value))
	spin.value_changed.connect(func(_v): update.call())
	asc_spin.value_changed.connect(func(_v): update.call())
	update.call()
	add_child(panel)


func _biome_card(id: String, selected: bool) -> Control:
	var b: Dictionary = GameData.BIOMES[id]
	var open := _biome_unlocked(id)
	var c := W.card(Color(0.04, 0.05, 0.09, 0.9), UiTheme.ACCENT if selected else UiTheme.BORDER, 4)
	c.custom_minimum_size = Vector2(270, 150)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if open else Control.CURSOR_FORBIDDEN
	var v := W.vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(v)
	var path := "res://assets/backgrounds/%s.png" % id
	if not ResourceLoader.exists(path):
		path = "res://assets/backgrounds/%s.png" % GameData.theme_of(id)
	if ResourceLoader.exists(path):
		var t := TextureRect.new()
		t.texture = load(path)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.custom_minimum_size = Vector2(0, 64)
		t.clip_contents = true
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not open:
			t.modulate = Color(0.3, 0.3, 0.35)
		v.add_child(t)
	var boss: String = GameData.ENEMIES[b["elites"][0]]["name"]
	v.add_child(UiTheme.label(b["name"], 17, UiTheme.ACCENT if selected else Color.WHITE))
	v.add_child(UiTheme.label(b["faction"] + " · Jefe: " + boss, 12, UiTheme.MUTED))
	v.add_child(UiTheme.label("Nivel %d+" % b["min_level"] if open else "🔒 Requiere nivel de sector %d" % b["min_level"], 13, UiTheme.GOOD if open else UiTheme.BAD))
	c.gui_input.connect(func(e):
		if open and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			menu.state["biome"] = id
			menu.state["level"] = maxi(int(menu.state["level"]), int(b["min_level"]))
			Sfx.play("ui_click")
			menu.refresh())
	return c


func power_index() -> float:
	# v2: Poder = raíz(vida efectiva x DPS), en la misma escala que el poder recomendado del bioma.
	var st := GameState.ship_stats()
	return GameData.power_index(float(st["hull"]) + float(st["shield"]), maxf(1.0, GameState.theoretical_dps()))


func recommended_power(level: int) -> float:
	var asc := int(menu.state.get("asc", 0)) if menu else 0
	return GameData.recommended_power(level, menu.state.get("biome", "ferron") if menu else "ferron", asc)


func _details(id: String, level: int, asc: int = 0) -> String:
	var b: Dictionary = GameData.BIOMES[id]
	var mine := power_index()
	var rec := recommended_power(level)
	var col := "6fd17a" if mine >= rec else ("ffb84a" if mine >= rec * 0.8 else "ff5a5a")
	var res: PackedStringArray = []
	for k in b["resources"].keys():
		res.append(GameData.mat_name(k))
	var s := "[b]%s[/b] — %s  Peligros: %s\nRecursos frecuentes: %s.\n\n" % [b["name"], b["desc"], b["hazards"], ", ".join(res)]
	s += "Poder recomendado: [b]%s[/b]   ·   Tu poder: [color=#%s][b]%s[/b][/color]   ·   Nave: [b]%s[/b]\n" % [GameData.format_num(rec), col, GameData.format_num(mine), GameData.SHIPS[GameState.data["current_ship"]]["name"]]
	var bf := GameData.biome_factor(id)
	var el := GameData.eff_level(level, id)
	s += "Vida enemiga x%.2f · Daño enemigo x%.2f · Recompensas x%.2f\n" % [bf["hp"] * GameData.level_hp(1.0, el), bf["dmg"] * GameData.level_dmg(1.0, el), GameData.level_reward(1.0, level)]
	if asc > 0:
		s += "[color=#ff4fd8]Ascensión %d: vida x%.0f · daño x%.2f · recompensas x%.2f[/color]\n" % [asc, pow(2.0, asc), pow(1.55, asc), pow(1.75, asc)]
	# Las especies de un mapa no cambian con el nivel: subirlo trae más variantes (con su aura de color).
	var d := level - int(b["min_level"])
	var vs := "[color=#ffb84a]Boss[/color]" + (", [color=#ff5a5a]Mega[/color]" if d >= 3 else "") + (", [color=#d05aff]Ultra[/color]" if d >= 8 else "") + (", [color=#4affff]Uber[/color]" if d >= 15 else "")
	var nxt := "" if d >= 15 else "  (siguiente: %s en el nivel %d)" % [["Mega", "Ultra", "Uber"][0 if d < 3 else (1 if d < 8 else 2)], int(b["min_level"]) + (3 if d < 3 else (8 if d < 8 else 15))]
	var sp: PackedStringArray = []
	for eid in b["enemies"].keys():
		sp.append(GameData.ENEMIES[eid]["name"])
	s += "Especies: %s.\n" % ", ".join(sp)
	s += "Objetivo aleatorio: limpieza, socorro%s%s. Variantes: %s%s.%s\n" % [", balizas, escolta y comandante" if level >= 3 else "", ", nidos" if level >= 4 else "", vs, nxt, " Jefe con 3 fases." if level >= 4 else ""]
	if level >= 20 or GameData.theme_of(id) in ["prismaticos", "vacio"]:
		s += "[color=#4ab8ff]Enemigos con escudo blindado: usa munición alta o láseres Ion.[/color]\n"
	if GameState.data["sector_cleared"].has(level):
		s += "[color=#7d8aa3]Primera limpieza de este nivel ya obtenida.[/color]"
	else:
		s += "[color=#ff4fd8]Primera limpieza: +%d Cristales Nexo[/color]" % (5 + level / 2)
	return s
