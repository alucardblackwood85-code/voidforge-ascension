class_name PageStats
extends HBoxContainer
## ESTADÍSTICAS: rango y experiencia (x2 por nivel desde 10 000, máximo 21), escalafón militar,
## totales de carrera y bajas por cada tipo de alienígena.

var menu: StartMenu


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	var xp := int(GameState.data["xp"])
	var lvl := GameState.level()
	# Columna izquierda: rango + totales + escalafón
	var left := W.vbox(10)
	left.custom_minimum_size.x = 520
	var head := W.card(Color(0.06, 0.06, 0.1, 0.94), UiTheme.WARN, 14)
	var hh := W.hbox(16)
	head.add_child(hh)
	hh.add_child(RankBadge.make(lvl, 120))
	var hv := W.vbox(4)
	hv.add_child(UiTheme.label(GameState.rank_name(), 28, UiTheme.WARN))
	hv.add_child(UiTheme.label("Nivel %d de %d" % [lvl, GameData.MAX_LEVEL], 16))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(300, 14)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.WARN, UiTheme.WARN, 3, 0, 0))
	if lvl < GameData.MAX_LEVEL:
		bar.min_value = GameData.xp_for_level(lvl)
		bar.max_value = GameData.xp_for_level(lvl + 1)
		bar.value = xp
		hv.add_child(bar)
		hv.add_child(UiTheme.label("%s / %s XP  ·  faltan %s para %s" % [GameData.format_num(xp), GameData.format_num(GameData.xp_for_level(lvl + 1)), GameData.format_num(GameData.xp_for_level(lvl + 1) - xp), GameState.rank_name(lvl + 1)], 13, UiTheme.MUTED))
	else:
		hv.add_child(UiTheme.label("Rango máximo alcanzado · %s XP" % GameData.format_num(xp), 14, UiTheme.GOOD))
	hh.add_child(hv)
	left.add_child(head)
	var st: Dictionary = GameState.data["stats"]
	var totals := W.card()
	var tg := W.grid(4, 12)
	totals.add_child(tg)
	var t_s := int(st.get("time", 0))
	for pair in [["Incursiones", st["runs"]], ["Extracciones", st["extractions"]], ["Derrotas", st["deaths"]], ["Bajas totales", st["kills"]],
			["Tiempo en sector", "%dh %02dm" % [t_s / 3600, (t_s / 60) % 60]], ["Créditos ganados", GameData.format_num(st.get("credits_earned", 0))],
			["Cajas abiertas", st.get("boxes", 0)], ["Sector máximo", GameState.data["sector_max"]]]:
		var v := W.vbox(0)
		v.add_child(UiTheme.label(str(pair[0]), 12, UiTheme.MUTED))
		v.add_child(UiTheme.label(str(pair[1]), 18, Color.WHITE))
		v.custom_minimum_size.x = 110
		tg.add_child(v)
	left.add_child(totals)
	# M17: récords locales
	var recs: Dictionary = GameState.data.get("records", {})
	if not recs.is_empty():
		var rc := W.card()
		var rg := W.grid(3, 12)
		rc.add_child(rg)
		for k in GameState.RECORD_NAMES.keys():
			if not recs.has(k):
				continue
			var v := W.vbox(0)
			v.add_child(UiTheme.label(GameState.RECORD_NAMES[k], 12, UiTheme.MUTED))
			v.add_child(UiTheme.label(GameData.format_num(int(recs[k])), 18, UiTheme.WARN))
			v.custom_minimum_size.x = 150
			rg.add_child(v)
		left.add_child(UiTheme.label("RÉCORDS", 15, UiTheme.ACCENT))
		left.add_child(rc)
	var ladder := W.vbox(2)
	for i in range(1, GameData.MAX_LEVEL + 1):
		var row := W.hbox(10)
		row.add_child(RankBadge.make(i, 30))
		var reached := lvl >= i
		var l := UiTheme.label("%d. %s" % [i, GameState.rank_name(i)], 14, UiTheme.WARN if i == lvl else (Color.WHITE if reached else UiTheme.MUTED))
		l.custom_minimum_size.x = 260
		row.add_child(l)
		row.add_child(UiTheme.label(GameData.format_num(GameData.xp_for_level(i)) + " XP", 13, UiTheme.GOOD if reached else UiTheme.MUTED))
		var rw: Array = []
		for r in GameData.RANK_REWARDS.get(i, []):
			rw.append(GameData.reward_text(r))
		if not rw.is_empty():
			var rl := UiTheme.label("  " + ", ".join(rw), 12, UiTheme.GOOD if reached else UiTheme.MUTED)
			row.add_child(rl)
		ladder.add_child(row)
	var lc := W.card(Color(0.04, 0.06, 0.1, 0.9))
	lc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lv := W.vbox(6)
	lc.add_child(lv)
	lv.add_child(UiTheme.label("ESCALAFÓN", 15, UiTheme.ACCENT))
	lv.add_child(W.scroll(ladder))
	left.add_child(lc)
	add_child(left)
	# Columna derecha: bajas por tipo
	var right := W.card(Color(0.04, 0.06, 0.1, 0.92))
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rv := W.vbox(8)
	right.add_child(rv)
	rv.add_child(UiTheme.label("ENEMIGOS DERROTADOS POR TIPO", 15, UiTheme.ACCENT))
	var list := W.vbox(10)
	var kb: Dictionary = GameState.data["kills_by"]
	for bid in GameData.BIOMES.keys():
		var b: Dictionary = GameData.BIOMES[bid]
		# Una entrada por facción con las especies de sus dos mapas, sin repetir.
		if not b.has("enemies") or GameData.theme_of(bid) != bid:
			continue
		var fac_total := 0
		var ids: Array = []
		for bid2 in GameData.BIOMES.keys():
			var b2: Dictionary = GameData.BIOMES[bid2]
			if b2.has("enemies") and GameData.theme_of(bid2) == bid:
				for eid in b2["enemies"].keys() + b2["elites"]:
					if not ids.has(eid):
						ids.append(eid)
		for eid in ids:
			fac_total += int(kb.get(eid, 0))
		list.add_child(UiTheme.label("%s — %d bajas" % [b["faction"], fac_total], 15, UiTheme.TEXT))
		var g := W.grid(5, 6)
		for eid in ids:
			var e: Dictionary = GameData.ENEMIES[eid]
			var n := int(kb.get(eid, 0))
			var c := W.card(Color(0.06, 0.08, 0.13, 0.9), UiTheme.BORDER if n == 0 else (e["accent"] as Color).darkened(0.3), 4)
			c.custom_minimum_size = Vector2(150, 0)
			var cv := W.vbox(0)
			c.add_child(cv)
			var p := W.pic(SpriteLib.get_tex("enemies", eid), Vector2(0, 54))
			if n == 0:
				p.modulate = Color(0.35, 0.35, 0.4)
			cv.add_child(p)
			var nl := UiTheme.label(e["name"], 12, Color.WHITE if n > 0 else UiTheme.MUTED)
			nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cv.add_child(nl)
			var ql := UiTheme.label("× %s" % GameData.format_num(n), 15, UiTheme.WARN if n > 0 else UiTheme.MUTED)
			ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cv.add_child(ql)
			g.add_child(c)
		list.add_child(g)
	rv.add_child(W.scroll(list))
	add_child(right)
