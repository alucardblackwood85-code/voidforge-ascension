class_name W
## Utilidades de interfaz del menú de inicio: iconos, descripciones de objetos, tarjetas y textos.

static func icon(kind: String, id: String) -> Texture2D:
	match kind:
		"lasers", "laser":
			return SpriteLib.get_icon("lasers", id)
		"gens", "gen":
			return SpriteLib.get_icon("gens", id)
		"mods", "module":
			return SpriteLib.get_icon("mods", id)
		"drone_lasers", "drone_laser":
			return SpriteLib.get_icon("drone_lasers", id)
		"ammo":
			return SpriteLib.get_icon("ammo", id)
		"item":
			return SpriteLib.get_icon("items", id)
		"box":
			return SpriteLib.get_icon("boxes", id)
		"mat":
			return SpriteLib.get_icon("mats", id)
		"ship":
			var t := SpriteLib.get_tex("ships", id)
			return t if t else SpriteLib.get_tex("ships", GameData.SHIPS[id]["class"])
	return null


## Nombre, color de rareza y tooltip de una instancia de inventario.
static func item_info(list_key: String, it: Dictionary) -> Dictionary:
	match list_key:
		"lasers":
			var d: Dictionary = GameData.LASERS[it["id"]]
			var per := GameState.laser_volley_damage(d, int(it["level"])) * int(d["shots"])
			return {"name": d["name"], "level": int(it["level"]), "color": GameData.ITEM_RARITY_COLORS[d["rarity"]], "icon": icon("lasers", it["id"]),
				"tip": "%s  (Nv %d/16)\n%s\nDaño por andanada: %d%s\n+ %s\n- %s" % [d["name"], int(it["level"]), GameData.ITEM_RARITY_NAMES[d["rarity"]], int(per), " (%d rayos)" % d["shots"] if int(d["shots"]) > 1 else "", d["adv"], d["dis"]]}
		"gens":
			var g: Dictionary = GameData.GENERATORS[it["id"]]
			return {"name": g["name"], "level": int(it["level"]), "color": Color("4aa3ff") if g["type"] == "shield" else Color("ffd84a"), "icon": icon("gens", it["id"]),
				"tip": "%s  (Nv %d/16)\nGenerador de %s\n%s\n%s" % [g["name"], int(it["level"]), "escudo" if g["type"] == "shield" else "velocidad", gen_stats(g["stats"]), g["trait"]]}
		"mods":
			var fam: Dictionary = GameData.MODULE_FAMILIES[it["family"]]
			var rar: String = GameData.MODULE_RARITIES[int(it["rarity"])]
			var tip := "Módulo %s — %s\n+%d%% %s" % [fam["name"], GameData.ITEM_RARITY_NAMES[rar], int(it["main"]), fam["name"].to_lower()]
			for line in it["lines"]:
				tip += "\n+%.1f%% %s" % [float(line["value"]), GameData.MODULE_SUB_NAMES.get(line["stat"], line["stat"])]
			tip += "\n(Una nave no puede equipar dos módulos del mismo color)"
			return {"name": "%s +%d%%" % [fam["name"], int(it["main"])], "level": -1, "color": GameData.ITEM_RARITY_COLORS[rar], "icon": icon("mods", it["family"]), "tint": fam["color"], "tip": tip}
		"drone_lasers":
			var dl: Dictionary = GameData.DRONE_LASERS[it["id"]]
			return {"name": dl["name"], "level": -1, "color": dl["color"], "icon": icon("drone_lasers", it["id"]), "tip": "%s\n%s" % [dl["name"], dl["desc"]]}
	return {"name": "?", "level": -1, "color": Color.WHITE, "icon": null, "tip": ""}


static func gen_stats(stats: Dictionary) -> String:
	var names := {"shield": "escudo", "speed": "velocidad", "hull": "casco", "recharge": "recarga", "accel": "aceleración", "turn": "giro", "boost_cd": "CD impulso", "shield_regen": "regen. escudo/s"}
	var parts: PackedStringArray = []
	for k in stats.keys():
		parts.append("%+.1f%% %s" % [float(stats[k]) * 100.0, names.get(k, k)])
	return ", ".join(parts)


static func card(bg: Color = Color(0.07, 0.10, 0.16, 0.92), border: Color = UiTheme.BORDER, pad: int = 10) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.box(bg, border, 8, 1, pad))
	return p


static func pic(tex: Texture2D, size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func title(text: String, size: int = 22) -> Label:
	return UiTheme.label(text, size, UiTheme.ACCENT)


static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func grid(cols: int, sep: int = 10) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", sep)
	g.add_theme_constant_override("v_separation", sep)
	return g


static func scroll(content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	return s


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


## Fila de coste con iconos de material y colores tengo/necesito.
static func cost_row(cost: Dictionary, times: int = 1) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 10)
	f.add_theme_constant_override("v_separation", 2)
	for k in cost.keys():
		var need := int(cost[k]) * times
		var ok := GameState.get_amount(k) >= need
		var h := hbox(3)
		var ic := icon("mat", k)
		if ic:
			h.add_child(pic(ic, Vector2(22, 22)))
		h.add_child(UiTheme.label("%s%s" % [GameData.format_num(need), "" if ic else " " + GameData.mat_name(k)], 14, UiTheme.GOOD if ok else UiTheme.BAD))
		h.tooltip_text = "%s: tienes %s" % [GameData.mat_name(k), GameData.format_num(GameState.get_amount(k))]
		h.mouse_filter = Control.MOUSE_FILTER_PASS
		f.add_child(h)
	return f


static func button(text: String, cb: Callable, primary: bool = false, min_w: int = 0) -> Button:
	var b := UiTheme.button(text, cb, min_w)
	if primary:
		b.add_theme_stylebox_override("normal", UiTheme.box(Color(0.04, 0.28, 0.32), UiTheme.ACCENT, 6, 2, 10))
		b.add_theme_stylebox_override("hover", UiTheme.box(Color(0.06, 0.38, 0.42), Color.WHITE, 6, 2, 10))
		b.add_theme_font_size_override("font_size", 18)
	return b
