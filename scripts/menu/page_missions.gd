class_name PageMissions
extends VBoxContainer
## MISIONES: diarias y semanales con racha (M4), temporada de 8 semanas con 40 niveles y
## modificador semanal (M18), y logros con la maestría del códex (M13).

var menu: StartMenu


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	Prog.ensure()
	var tab: String = menu.state.get("missions_tab", "missions")
	var tabs := W.hbox(6)
	for t in [["missions", "MISIONES"], ["season", "TEMPORADA"], ["achievements", "LOGROS"]]:
		var id: String = t[0]
		var go := func():
			menu.state["missions_tab"] = id
			menu.refresh()
		var b := W.button("  %s  " % t[1], go, id == tab)
		tabs.add_child(b)
	tabs.add_child(W.spacer())
	var wm := Prog.weekly_mod()
	tabs.add_child(UiTheme.label("Modificador semanal: %s — %s" % [wm["name"], wm["desc"]], 14, UiTheme.WARN))
	add_child(tabs)
	match tab:
		"missions":
			_missions()
		"season":
			_season()
		"achievements":
			_achievements()


func _missions() -> void:
	var m: Dictionary = GameState.data["missions"]
	var head := W.hbox(20)
	head.add_child(UiTheme.label("Racha: %d días" % int(m["streak"]), 18, UiTheme.GOOD if int(m["streak"]) > 0 else UiTheme.MUTED))
	head.add_child(UiTheme.label("Bonificación de racha: +%d%% a las recompensas" % int(100.0 * minf(0.5, Prog.STREAK_BONUS * int(m["streak"]))), 14, UiTheme.MUTED))
	head.add_child(W.spacer())
	var left := Prog.time_to_next_day()
	head.add_child(UiTheme.label("Nuevas diarias en %dh %02dm" % [left / 3600, (left / 60) % 60], 14, UiTheme.MUTED))
	add_child(head)
	add_child(UiTheme.label("Completa las tres diarias cada día para mantener la racha.", 13, UiTheme.MUTED))
	var body := W.vbox(10)
	body.add_child(W.title("Diarias", 18))
	for i in m["daily"].size():
		body.add_child(_mission_row(m["daily"][i], false, i))
	body.add_child(W.title("Semanales", 18))
	for i in m["weekly"].size():
		body.add_child(_mission_row(m["weekly"][i], true, i))
	var sc := W.scroll(body)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(sc)


func _mission_row(mi: Dictionary, weekly: bool, i: int) -> Control:
	var done := int(mi["progress"]) >= int(mi["target"])
	var c := W.card(Color(0.05, 0.08, 0.13, 0.92), UiTheme.GOOD if done and not mi["claimed"] else UiTheme.BORDER, 10)
	var h := W.hbox(14)
	c.add_child(h)
	var v := W.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UiTheme.label(Prog.mission_text(mi), 16, Color.WHITE if not mi["claimed"] else UiTheme.MUTED))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(320, 10)
	bar.show_percentage = false
	bar.max_value = int(mi["target"])
	bar.value = int(mi["progress"])
	bar.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.GOOD, UiTheme.GOOD, 3, 0, 0))
	v.add_child(bar)
	v.add_child(UiTheme.label("%s / %s  ·  Recompensa: %s" % [GameData.format_num(mi["progress"]), GameData.format_num(mi["target"]), Prog.reward_line(Prog.mission_reward(weekly))], 12, UiTheme.MUTED))
	h.add_child(v)
	if mi["claimed"]:
		h.add_child(UiTheme.label("✔ Reclamada", 14, UiTheme.GOOD))
	else:
		var claim := func():
			if Prog.claim_mission(weekly, i):
				Sfx.play("objective")
		var b := W.button("Reclamar", claim, true, 130)
		b.disabled = not done
		h.add_child(b)
	return c


func _season() -> void:
	var s: Dictionary = GameState.data["season"]
	var tier := Prog.season_tier()
	var head := W.hbox(20)
	head.add_child(UiTheme.label("Temporada %d · semana %d de %d" % [Prog.season_index() % 100 + 1, Prog.season_week(), Prog.SEASON_WEEKS], 18, UiTheme.ACCENT))
	head.add_child(UiTheme.label("Nivel %d / %d" % [tier, Prog.SEASON_TIERS], 18, UiTheme.WARN))
	var pts := int(s["pts"])
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(260, 12)
	bar.show_percentage = false
	bar.max_value = Prog.SEASON_TIER_PTS
	bar.value = pts % Prog.SEASON_TIER_PTS if tier < Prog.SEASON_TIERS else Prog.SEASON_TIER_PTS
	bar.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.WARN, UiTheme.WARN, 3, 0, 0))
	head.add_child(bar)
	head.add_child(UiTheme.label("%d pts · quedan %d días" % [pts, Prog.season_days_left()], 14, UiTheme.MUTED))
	head.add_child(W.spacer())
	var pending := tier - int(s["claimed"])
	var do_claim := func():
		var got := Prog.claim_season()
		if not got.is_empty():
			Sfx.play("objective")
			var dlg := AcceptDialog.new()
			dlg.title = "Recompensas de temporada"
			dlg.dialog_text = "\n".join(got)
			menu.add_child(dlg)
			dlg.popup_centered()
	var cb := W.button("Reclamar %d niveles" % pending if pending > 0 else "Nada que reclamar", do_claim, true, 200)
	cb.disabled = pending <= 0
	head.add_child(cb)
	add_child(head)
	add_child(UiTheme.label("Puntos: 1 cada 5 bajas, 40 por objetivo, 60 por jefe, 100 por misión diaria y 400 por semanal.", 13, UiTheme.MUTED))
	var g := W.grid(8, 6)
	for t in range(1, Prog.SEASON_TIERS + 1):
		var reached := tier >= t
		var claimed := int(s["claimed"]) >= t
		var big := t % 10 == 0
		var c := W.card(Color(0.05, 0.08, 0.13, 0.92), UiTheme.WARN if big else (UiTheme.GOOD if reached else UiTheme.BORDER), 6)
		c.custom_minimum_size = Vector2(170, 74)
		var v := W.vbox(2)
		c.add_child(v)
		v.add_child(UiTheme.label("Nivel %d%s" % [t, " ✔" if claimed else ""], 13, UiTheme.WARN if big else (Color.WHITE if reached else UiTheme.MUTED)))
		var parts: PackedStringArray = []
		for r in Prog.tier_reward(t):
			parts.append(GameData.reward_text(r))
		var l := UiTheme.label(", ".join(parts), 11, UiTheme.TEXT if reached else UiTheme.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
		g.add_child(c)
	var sc := W.scroll(g)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(sc)


func _achievements() -> void:
	var a: Dictionary = GameState.data["achievements"]
	add_child(UiTheme.label("Logros: %d / %d  ·  Maestrías del códex: %d (cada especie con %d bajas da +%d%% de daño contra ella)" % [a.size(), Prog.ACHIEVEMENTS.size(), Prog.mastery_count(), Prog.MASTERY_KILLS, int(Prog.MASTERY_DMG * 100)], 15, UiTheme.ACCENT))
	var g := W.grid(3, 8)
	for ach in Prog.ACHIEVEMENTS:
		var got := a.has(ach["id"])
		var c := W.card(Color(0.05, 0.08, 0.13, 0.92), UiTheme.GOOD if got else UiTheme.BORDER, 8)
		c.custom_minimum_size = Vector2(420, 0)
		var v := W.vbox(2)
		c.add_child(v)
		v.add_child(UiTheme.label(("🏆 " if got else "") + ach["name"], 16, UiTheme.WARN if got else Color.WHITE))
		v.add_child(UiTheme.label(ach["desc"], 12, UiTheme.MUTED))
		var cur := mini(Prog.stat_value(ach["stat"]), int(ach["n"]))
		v.add_child(UiTheme.label("%s / %s  ·  +%d Cristales Nexo" % [GameData.format_num(cur), GameData.format_num(ach["n"]), ach["nexo"]], 12, UiTheme.GOOD if got else UiTheme.MUTED))
		g.add_child(c)
	var sc := W.scroll(g)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(sc)
