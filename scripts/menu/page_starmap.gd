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
	var cards := W.hbox(10)
	for id in GameData.BIOMES.keys():
		var b: Dictionary = GameData.BIOMES[id]
		if b.get("locked", false):
			continue
		cards.add_child(_biome_card(id, id == sel))
	add_child(cards)
	var locked: PackedStringArray = []
	for id in GameData.BIOMES.keys():
		if GameData.BIOMES[id].get("locked", false):
			locked.append(GameData.BIOMES[id]["name"])
	add_child(UiTheme.label("Próximamente: " + ", ".join(locked), 13, UiTheme.MUTED))
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
	var do_launch := func():
		var lvl := int(spin.value)
		var insured := insure.button_pressed
		if insured and not GameState.pay({"credits": GameData.insurance_cost(lvl)}):
			Sfx.play("ui_error")
			return
		menu.launch({"level": lvl, "seed": randi(), "biome": sel, "insured": insured})
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
	var launch := W.button("   LANZAR INCURSIÓN   ", on_launch, true, 320)
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
		details.text = _details(sel, int(spin.value))
	spin.value_changed.connect(func(_v): update.call())
	update.call()
	add_child(panel)


func _biome_card(id: String, selected: bool) -> Control:
	var b: Dictionary = GameData.BIOMES[id]
	var open := _biome_unlocked(id)
	var c := W.card(Color(0.04, 0.05, 0.09, 0.9), UiTheme.ACCENT if selected else UiTheme.BORDER, 4)
	c.custom_minimum_size = Vector2(290, 210)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if open else Control.CURSOR_FORBIDDEN
	var v := W.vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(v)
	var path := "res://assets/backgrounds/%s.png" % id
	if ResourceLoader.exists(path):
		var t := TextureRect.new()
		t.texture = load(path)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.custom_minimum_size = Vector2(0, 120)
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
	# 23.1: Poder = Casco^0.45 x Velocidad^0.20 x DañoEfectivo^0.70 x Escudo^0.35
	var st := GameState.ship_stats()
	var dps := maxf(1.0, GameState.theoretical_dps())
	return pow(st["hull"], 0.45) * pow(st["speed"], 0.2) * pow(dps, 0.7) * pow(st["shield"], 0.35) / 100.0


func recommended_power(level: int) -> float:
	return 1000.0 * pow(GameData.level_hp(1.0, level) / GameData.level_hp(1.0, 1), 0.9) * pow(GameData.level_dmg(1.0, level) / GameData.level_dmg(1.0, 1), 0.5)


func _details(id: String, level: int) -> String:
	var b: Dictionary = GameData.BIOMES[id]
	var mine := power_index()
	var rec := recommended_power(level)
	var col := "6fd17a" if mine >= rec else ("ffb84a" if mine >= rec * 0.8 else "ff5a5a")
	var res: PackedStringArray = []
	for k in b["resources"].keys():
		res.append(GameData.mat_name(k))
	var s := "[b]%s[/b] — %s  Peligros: %s\nRecursos frecuentes: %s.\n\n" % [b["name"], b["desc"], b["hazards"], ", ".join(res)]
	s += "Poder recomendado: [b]%s[/b]   ·   Tu poder: [color=#%s][b]%s[/b][/color]   ·   Nave: [b]%s[/b]\n" % [GameData.format_num(rec), col, GameData.format_num(mine), GameData.SHIPS[GameState.data["current_ship"]]["name"]]
	s += "Vida enemiga x%.2f · Daño enemigo x%.2f · Recompensas x%.2f\n" % [GameData.level_hp(1.0, level), GameData.level_dmg(1.0, level), GameData.level_reward(1.0, level)]
	s += "Objetivo procedural: Limpieza o Destruir nidos. Variantes élite: Boss%s.\n" % (", Mega" if level >= 3 else "")
	if GameState.data["sector_cleared"].has(level):
		s += "[color=#7d8aa3]Primera limpieza de este nivel ya obtenida.[/color]"
	else:
		s += "[color=#ff4fd8]Primera limpieza: +%d Cristales Nexo[/color]" % (5 + level / 2)
	return s
