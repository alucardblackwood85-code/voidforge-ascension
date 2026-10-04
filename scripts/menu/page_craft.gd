class_name PageCraft
extends HBoxContainer
## CRAFTEO: fabricación con los materiales recolectados en los sectores. Categorías: munición,
## consumibles, cajas de módulos (gacha con probabilidades visibles y pity), naves, láseres,
## generadores, pet y mejoras de nivel 1-16. El panel derecho muestra el inventario de materiales.

const CATS := [["ammo", "Munición"], ["item", "Consumibles"], ["box", "Cajas de módulos"], ["ship", "Naves"],
	["laser", "Láseres"], ["gen", "Generadores"], ["drone_laser", "Pet"], ["upgrade", "Mejoras 1-16"]]

var menu: StartMenu
var reveal: Control


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	# Categorías
	var cats := W.card(Color(0.04, 0.06, 0.1, 0.92))
	cats.custom_minimum_size.x = 210
	var cv := W.vbox(6)
	cats.add_child(cv)
	cv.add_child(UiTheme.label("CATEGORÍAS", 15, UiTheme.ACCENT))
	for c in CATS:
		var b := Button.new()
		b.text = c[1]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size.y = 38
		if menu.state["craft_tab"] == c[0]:
			b.add_theme_stylebox_override("normal", UiTheme.box(Color(0.1, 0.2, 0.3), UiTheme.ACCENT, 4, 2, 8))
		var id: String = c[0]
		b.pressed.connect(func():
			menu.state["craft_tab"] = id
			menu.refresh())
		cv.add_child(b)
	add_child(cats)
	# Recetas
	var mid := W.vbox(8)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tab: String = menu.state["craft_tab"]
	var list := W.vbox(8)
	match tab:
		"upgrade":
			_upgrades(list)
		"box":
			_boxes(list)
		_:
			for id in _ids(tab):
				if tab == "ship" and id == "kestrel_a1":
					continue
				list.add_child(_recipe(tab, id))
	mid.add_child(W.scroll(list))
	add_child(mid)
	add_child(_materials_panel())


func _ids(kind: String) -> Array:
	match kind:
		"ammo":
			return GameData.AMMO.keys()
		"item":
			return GameData.ITEMS.keys()
		"ship":
			return GameData.SHIPS.keys()
		"laser":
			return GameData.LASERS.keys()
		"gen":
			return GameData.GENERATORS.keys()
		"drone_laser":
			return GameData.DRONE_LASERS.keys()
	return []


func _recipe(kind: String, id: String) -> Control:
	var name := ""
	var sub := ""
	var tex: Texture2D
	var col := UiTheme.BORDER
	match kind:
		"ammo":
			var a: Dictionary = GameData.AMMO[id]
			name = "%s (%s) — lote de 100" % [a["name"], a["short"]]
			sub = "En almacén: %s" % GameData.format_num(GameState.data["ammo"].get(id, 0))
			tex = W.icon("ammo", id)
			col = a["color"]
		"item":
			var it: Dictionary = GameData.ITEMS[id]
			name = it["name"]
			sub = "%s · Tienes %d" % [it["desc"], int(GameState.data["items"].get(id, 0))]
			tex = W.icon("item", id)
			col = it["color"]
		"ship":
			var s: Dictionary = GameData.SHIPS[id]
			name = ("★ " if s.get("special", false) else "") + s["name"]
			sub = "%s · %s" % [GameData.SHIP_CLASSES[s["class"]]["name"], "✔ En propiedad" if GameState.data["ships"].has(id) else s["note"]]
			tex = W.icon("ship", id)
			col = UiTheme.WARN if s.get("special", false) else UiTheme.BORDER
		"laser":
			var d: Dictionary = GameData.LASERS[id]
			name = d["name"]
			sub = "%s · %s" % [GameData.ITEM_RARITY_NAMES[d["rarity"]], d["adv"]]
			tex = W.icon("laser", id)
			col = GameData.ITEM_RARITY_COLORS[d["rarity"]]
		"gen":
			var g: Dictionary = GameData.GENERATORS[id]
			name = g["name"]
			sub = W.gen_stats(g["stats"])
			tex = W.icon("gen", id)
			col = Color("4aa3ff") if g["type"] == "shield" else Color("ffd84a")
		"drone_laser":
			var dl: Dictionary = GameData.DRONE_LASERS[id]
			name = dl["name"]
			sub = dl["desc"]
			tex = W.icon("drone_laser", id)
			col = dl["color"]
	var recipe := GameState.recipe_of(kind, id)
	var c := W.card(Color(0.05, 0.08, 0.13, 0.94), col.darkened(0.2), 8)
	var h := W.hbox(12)
	c.add_child(h)
	h.add_child(W.pic(tex, Vector2(72, 72)))
	var v := W.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UiTheme.label(name, 16, col.lightened(0.3)))
	var sl := UiTheme.label(sub, 12, UiTheme.MUTED)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sl)
	v.add_child(W.cost_row(recipe))
	h.add_child(v)
	var bv := W.vbox(4)
	if kind == "ship" and GameState.data["ships"].has(id):
		bv.add_child(UiTheme.label("✔", 22, UiTheme.GOOD))
	else:
		var qtys := [1]
		if kind == "ammo":
			qtys = [1, 10]
		elif kind == "item":
			qtys = [1, 5]
		for q in qtys:
			var label := "Fabricar" if q == 1 else "x%d" % q
			if kind == "ammo":
				label = "+%d" % (100 * q)
			var b := W.button(label, func(): _craft(kind, id, q), q == 1, 110)
			b.disabled = not GameState.can_afford(recipe, q)
			bv.add_child(b)
	h.add_child(bv)
	return c


func _craft(kind: String, id: String, qty: int) -> void:
	if GameState.craft(kind, id, qty):
		Sfx.play("craft")
	else:
		Sfx.play("ui_error")


# --- Cajas de módulos --------------------------------------------------------------------------
func _boxes(list: VBoxContainer) -> void:
	var pity: Dictionary = GameState.data["pity"]
	var info := W.card(Color(0.06, 0.05, 0.12, 0.9), UiTheme.ACCENT2, 10)
	info.add_child(UiTheme.rich("[b]Protección de mala suerte:[/b] Reliquia garantizada tras %d cajas sin Reliquia/Exótico (llevas [b]%d[/b]). A partir de %d cajas sin Exótico su probabilidad aumenta (llevas [b]%d[/b]). Los módulos nunca tienen estadísticas elegidas." % [GameData.PITY_RELIC, int(pity["since_relic"]), GameData.PITY_EXOTIC, int(pity["since_exotic"])], 14))
	list.add_child(info)
	for id in GameData.MODULE_BOXES.keys():
		var bx: Dictionary = GameData.MODULE_BOXES[id]
		var c := W.card(Color(0.05, 0.08, 0.13, 0.94), UiTheme.BORDER, 8)
		var h := W.hbox(12)
		c.add_child(h)
		h.add_child(W.pic(W.icon("box", id), Vector2(84, 84)))
		var v := W.vbox(4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UiTheme.label(bx["name"], 17, UiTheme.TEXT))
		var odds: PackedStringArray = []
		var w: Array = bx["weights"]
		var total := 0.0
		for x in w:
			total += x
		for i in w.size():
			if w[i] > 0.0:
				var rar: String = GameData.MODULE_RARITIES[i]
				odds.append("[color=#%s]%s %.1f%%[/color]" % [GameData.ITEM_RARITY_COLORS[rar].to_html(false), GameData.ITEM_RARITY_NAMES[rar], w[i] / total * 100.0])
		v.add_child(UiTheme.rich("Probabilidades: " + "  ".join(odds), 13))
		v.add_child(W.cost_row(bx["recipe"]))
		h.add_child(v)
		var b := W.button("Abrir", func(): _open(id), true, 110)
		b.disabled = not GameState.can_afford(bx["recipe"])
		h.add_child(b)
		list.add_child(c)
	list.add_child(UiTheme.label("Los módulos obtenidos se equipan en Equipamiento → Módulos (uno por color y nave).", 13, UiTheme.MUTED))


func _open(box_id: String) -> void:
	var m := GameState.open_box(box_id)
	if m.is_empty():
		Sfx.play("ui_error")
		return
	Sfx.play("pickup_rare" if int(m["rarity"]) >= 2 else "craft")
	_show_reveal(m)


func _show_reveal(m: Dictionary) -> void:
	# El menú se reconstruye tras el cambio; el aviso vive en el menú para sobrevivir.
	var info := W.item_info("mods", m)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var col: Color = info["color"]
	var c := W.card(Color(0.05, 0.07, 0.12, 0.98), col, 18)
	c.custom_minimum_size = Vector2(420, 0)
	center.add_child(c)
	var v := W.vbox(10)
	c.add_child(v)
	var rar: String = GameData.MODULE_RARITIES[int(m["rarity"])]
	var t := UiTheme.label("¡MÓDULO %s!" % GameData.ITEM_RARITY_NAMES[rar].to_upper(), 26, col)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var p := W.pic(info["icon"], Vector2(0, 150))
	v.add_child(p)
	var d := UiTheme.label(info["tip"], 15)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(d)
	v.add_child(W.button("Aceptar", func(): dim.queue_free(), true))
	# Pequeña animación de aparición.
	c.pivot_offset = c.custom_minimum_size * 0.5
	c.scale = Vector2(0.6, 0.6)
	c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Mejoras 1-16 ----------------------------------------------------------------------------
func _upgrades(list: VBoxContainer) -> void:
	list.add_child(UiTheme.label("Cada nivel añade +3% de daño a un láser o +1% al valor de un generador (máximo 16).", 14, UiTheme.MUTED))
	for list_key in ["lasers", "gens"]:
		for it in GameState.data[list_key]:
			var info := W.item_info(list_key, it)
			var lvl := int(it["level"])
			var c := W.card(Color(0.05, 0.08, 0.13, 0.94), (info["color"] as Color).darkened(0.2), 8)
			var h := W.hbox(12)
			c.add_child(h)
			h.add_child(W.pic(info["icon"], Vector2(64, 64)))
			var v := W.vbox(3)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var where := GameState.equipped_on(list_key, int(it["uid"]))
			v.add_child(UiTheme.label("%s  Nv %d/16%s" % [info["name"], lvl, "  [%s]" % GameData.holder_name(where) if where != "" else ""], 15))
			var bar := ProgressBar.new()
			bar.max_value = 16
			bar.value = lvl
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(300, 8)
			v.add_child(bar)
			if lvl < 16:
				var cost := GameData.upgrade_cost(lvl, GameState.item_base_credits(list_key, it["id"]))
				v.add_child(W.cost_row(cost))
				h.add_child(v)
				var uid := int(it["uid"])
				var do_upgrade := func():
					Sfx.play("craft" if GameState.upgrade_item(list_key, uid) else "ui_error")
				var b := W.button("%s  → Nv %d" % ["+3%" if list_key == "lasers" else "+1%", lvl + 1], do_upgrade, false, 130)
				b.disabled = not GameState.can_afford(cost)
				h.add_child(b)
			else:
				v.add_child(UiTheme.label("Nivel máximo", 13, UiTheme.GOOD))
				h.add_child(v)
			list.add_child(c)


# --- Inventario de materiales (sincronizado con lo recolectado) ---------------------------------
func _materials_panel() -> Control:
	var c := W.card(Color(0.04, 0.06, 0.1, 0.92))
	c.custom_minimum_size.x = 300
	var v := W.vbox(6)
	c.add_child(v)
	v.add_child(UiTheme.label("MATERIALES", 15, UiTheme.ACCENT))
	v.add_child(UiTheme.label("Se recolectan en los sectores", 12, UiTheme.MUTED))
	var g := W.grid(2, 6)
	for id in GameData.MATERIALS.keys():
		var q := GameState.get_amount(id)
		var h := W.hbox(4)
		var ic := W.icon("mat", id)
		if ic:
			h.add_child(W.pic(ic, Vector2(28, 28)))
		var vv := W.vbox(0)
		vv.add_child(UiTheme.label(GameData.mat_name(id), 11, GameData.mat_color(id) if q > 0 else UiTheme.MUTED))
		vv.add_child(UiTheme.label(GameData.format_num(q), 13, Color.WHITE if q > 0 else Color(0.4, 0.45, 0.5)))
		h.add_child(vv)
		h.custom_minimum_size.x = 136
		h.tooltip_text = "%s (%s)" % [GameData.mat_name(id), GameData.RARITY_NAMES[GameData.MATERIALS[id]["rarity"]]]
		if q <= 0:
			h.modulate = Color(1, 1, 1, 0.55)
		g.add_child(h)
	v.add_child(W.scroll(g))
	return c
