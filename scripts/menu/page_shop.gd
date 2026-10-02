class_name PageShop
extends VBoxContainer
## TIENDA: compra con créditos (y Cristales Nexo en objetos especiales). Subventanas por categoría.
## Todo lo que se compra aquí también puede fabricarse con materiales en Crafteo.

const TABS := [["ship", "NAVES"], ["laser", "LÁSERES"], ["gen", "GENERADORES"], ["ammo", "MUNICIÓN"], ["item", "CONSUMIBLES"], ["drone_laser", "PET"]]

var menu: StartMenu


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var tabs := W.hbox(6)
	for t in TABS:
		var b := Button.new()
		b.text = "  %s  " % t[1]
		b.focus_mode = Control.FOCUS_NONE
		if menu.state["shop_tab"] == t[0]:
			b.add_theme_stylebox_override("normal", UiTheme.box(Color(0.1, 0.2, 0.3), UiTheme.ACCENT, 4, 2, 8))
		var id: String = t[0]
		b.pressed.connect(func():
			menu.state["shop_tab"] = id
			menu.refresh())
		tabs.add_child(b)
	add_child(tabs)
	var g := W.grid(5, 10)
	var kind: String = menu.state["shop_tab"]
	for id in _ids(kind):
		if GameState.in_shop(kind, id):
			g.add_child(_product(kind, id))
	add_child(W.scroll(g))


func _ids(kind: String) -> Array:
	match kind:
		"ship":
			return GameData.SHIPS.keys()
		"laser":
			return GameData.LASERS.keys()
		"gen":
			return GameData.GENERATORS.keys()
		"ammo":
			return GameData.AMMO.keys()
		"item":
			return GameData.ITEMS.keys()
		"drone_laser":
			return GameData.DRONE_LASERS.keys()
	return []


func _product(kind: String, id: String) -> Control:
	var name := ""
	var sub := ""
	var desc := ""
	var col := UiTheme.BORDER
	var tex: Texture2D = null
	var owned_txt := ""
	match kind:
		"ship":
			var s: Dictionary = GameData.SHIPS[id]
			name = ("★ " if s.get("special", false) else "") + s["name"]
			sub = GameData.SHIP_CLASSES[s["class"]]["name"]
			desc = "Casco %s · Vel %d · Daño x%.2f\n%d láseres · %d gen. · %d mód." % [GameData.format_num(s["hull"]), s["speed"], s["dmg"], s["lasers"], s["gens"], s["mods"]]
			col = UiTheme.WARN if s.get("special", false) else UiTheme.BORDER
			tex = W.icon("ship", id)
			if GameState.data["ships"].has(id):
				owned_txt = "En propiedad"
		"laser":
			var d: Dictionary = GameData.LASERS[id]
			name = d["name"]
			sub = GameData.ITEM_RARITY_NAMES[d["rarity"]]
			desc = "Daño/andanada %d%s\n+ %s\n- %s" % [int(GameState.laser_volley_damage(d, 0) * int(d["shots"])), " (%d rayos)" % d["shots"] if int(d["shots"]) > 1 else "", d["adv"], d["dis"]]
			col = GameData.ITEM_RARITY_COLORS[d["rarity"]]
			tex = W.icon("laser", id)
			owned_txt = _count_owned("lasers", id)
		"gen":
			var g: Dictionary = GameData.GENERATORS[id]
			name = g["name"]
			sub = "Escudo" if g["type"] == "shield" else "Velocidad"
			desc = "%s\n%s" % [W.gen_stats(g["stats"]), g["trait"]]
			col = Color("4aa3ff") if g["type"] == "shield" else Color("ffd84a")
			tex = W.icon("gen", id)
			owned_txt = _count_owned("gens", id)
		"ammo":
			var a: Dictionary = GameData.AMMO[id]
			name = "%s (%s)" % [a["name"], a["short"]]
			sub = "Lote de 100"
			desc = "Multiplicador de daño %s.\nEn almacén: %s" % [a["short"], GameData.format_num(GameState.data["ammo"].get(id, 0))]
			col = a["color"]
			tex = W.icon("ammo", id)
		"item":
			var it: Dictionary = GameData.ITEMS[id]
			name = it["name"]
			sub = "Consumible" if it["kind"] == "instant" else "Desplegable"
			desc = "%s\nTienes: %d" % [it["desc"], int(GameState.data["items"].get(id, 0))]
			col = it["color"]
			tex = W.icon("item", id)
		"drone_laser":
			var dl: Dictionary = GameData.DRONE_LASERS[id]
			name = dl["name"]
			sub = "Láser de pet"
			desc = dl["desc"]
			col = dl["color"]
			tex = W.icon("drone_laser", id)
			owned_txt = _count_owned("drone_lasers", id)
	var c := W.card(Color(0.05, 0.08, 0.13, 0.94), col.darkened(0.15), 10)
	c.custom_minimum_size = Vector2(296, 0)
	var v := W.vbox(4)
	c.add_child(v)
	v.add_child(W.pic(tex, Vector2(0, 110)))
	var h := W.hbox(6)
	h.add_child(UiTheme.label(name, 16, col.lightened(0.3)))
	h.add_child(W.spacer())
	h.add_child(UiTheme.label(sub, 12, UiTheme.MUTED))
	v.add_child(h)
	var dl_label := UiTheme.label(desc, 12, UiTheme.TEXT)
	dl_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl_label.custom_minimum_size = Vector2(270, 54)
	v.add_child(dl_label)
	if kind == "ship" and GameState.data["ships"].has(id):
		v.add_child(UiTheme.label("✔ En propiedad", 14, UiTheme.GOOD))
		return c
	# Dos formas de pago excluyentes: créditos O Cristales Nexo (nunca ambos).
	var qtys := [1]
	if kind == "ammo":
		qtys = [1, 10]
	elif kind == "item":
		qtys = [1, 5]
	for cur in ["credits", "nexo"]:
		var price := GameState.price_of(kind, id, cur)
		var row := W.hbox(6)
		row.add_child(W.cost_row(price))
		row.add_child(W.spacer())
		for q in qtys:
			var label := "Comprar" if q == 1 else "x%d" % q
			if kind == "ammo":
				label = "+%d" % (100 * q)
			var b := W.button(label, func(): _buy(kind, id, q, cur), q == 1 and cur == "credits")
			b.disabled = not GameState.can_afford(price, q)
			row.add_child(b)
		v.add_child(row)
		if cur == "credits":
			var o := UiTheme.label("— o —", 11, UiTheme.MUTED)
			o.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(o)
	if owned_txt != "":
		v.add_child(UiTheme.label(owned_txt, 12, UiTheme.MUTED))
	return c


func _count_owned(list_key: String, id: String) -> String:
	var n := 0
	for it in GameState.data[list_key]:
		if it["id"] == id:
			n += 1
	return "Tienes %d" % n if n > 0 else ""


func _buy(kind: String, id: String, qty: int, currency: String) -> void:
	# M14 / GDD 17.2: confirmar gastos de Cristales Nexo por encima de 50.
	var cost := int(GameState.price_of(kind, id, "nexo")["nexo"]) * qty
	if currency == "nexo" and cost > 50:
		var dlg := ConfirmationDialog.new()
		dlg.title = "Confirmar compra"
		dlg.dialog_text = "¿Gastar %d Cristales Nexo?" % cost
		dlg.ok_button_text = "Comprar"
		dlg.confirmed.connect(func(): _do_buy(kind, id, qty, currency))
		menu.add_child(dlg)
		dlg.popup_centered()
		return
	_do_buy(kind, id, qty, currency)


func _do_buy(kind: String, id: String, qty: int, currency: String) -> void:
	if GameState.buy(kind, id, qty, currency):
		Sfx.play("craft")
	else:
		Sfx.play("ui_error")
