class_name PageShop
extends HBoxContainer
## TIENDA al estilo de los MMO de naves: categorías a la izquierda y, a la derecha, tarjetas con el objeto
## sobre un brillo de su color, una descripción breve, sus datos y el precio en créditos O Cristales Nexo.
## Todo lo que se compra aquí también puede fabricarse con materiales en Fabricación.

const TABS := [["ship", "Naves"], ["laser", "Láseres"], ["gen", "Generadores"], ["ammo", "Munición"], ["missile", "Misiles"], ["item", "Consumibles"], ["drone_laser", "Pet"]]

var menu: StartMenu


## Brillo radial detrás del icono del objeto.
class Glow extends Control:
	var color := UiTheme.ACCENT
	var tex: Texture2D

	func _draw() -> void:
		var c := size * 0.5
		for k in 6:
			draw_circle(c, minf(size.x, size.y) * (0.5 - k * 0.07), Color(color, 0.05 + k * 0.025))
		if tex:
			var s := minf(size.x, size.y) * 0.92
			draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var kind: String = menu.state["shop_tab"]
	if not TABS.any(func(t): return t[0] == kind):
		kind = "ship"
	# Categorías
	var cat: Array = W.frame("Tienda")
	cat[0].custom_minimum_size.x = 230
	for t in TABS:
		var id: String = t[0]
		var b := W.btn(t[1], func():
			menu.state["shop_tab"] = id
			menu.refresh(), "primary" if id == kind else "normal", 0, 17)
		b.custom_minimum_size.y = 44
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		cat[1].add_child(b)
	var note := UiTheme.label("Paga con créditos o con Cristales Nexo. Todo se puede fabricar también en Fabricación.", 12, UiTheme.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cat[1].add_child(note)
	add_child(cat[0])
	# Artículos
	var title: String = TABS.filter(func(t): return t[0] == kind)[0][1]
	var fr: Array = W.frame(title)
	fr[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var g := W.grid(4, 10)
	if kind == "drone_laser":
		g.add_child(_product("pet", "pet"))
	for id in _ids(kind):
		if GameState.in_shop(kind, id):
			g.add_child(_product(kind, id))
	fr[1].add_child(W.scroll(g))
	add_child(fr[0])


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
		"missile":
			return GameData.MISSILES.keys()
		"item":
			return GameData.ITEMS.keys()
		"drone_laser":
			return GameData.DRONE_LASERS.keys()
	return []


func _product(kind: String, id: String) -> Control:
	var name := ""
	var sub := ""
	var stats := ""
	var col := UiTheme.ACCENT
	var tex: Texture2D = null
	var owned_txt := ""
	var owned := false
	match kind:
		"ship":
			var s: Dictionary = GameData.SHIPS[id]
			name = ("★ " if s.get("special", false) else "") + s["name"]
			sub = GameData.SHIP_CLASSES[s["class"]]["name"]
			var gtxt := ("%d+%d" % [s["gens"], GameData.shield_slots(id)]) if GameData.shield_slots(id) > 0 else str(s["gens"])
			stats = "Casco %s · Vel %d · Daño x%.2f\n%d láseres · %s gen. · %d mód." % [GameData.format_num(s["hull"]), s["speed"], s["dmg"], s["lasers"], gtxt, s["mods"]]
			col = UiTheme.GOLD if s.get("special", false) else Color("4aa3ff")
			tex = ShipSpin.frame_tex(id, 21)
			owned = GameState.data["ships"].has(id)
		"laser":
			var d: Dictionary = GameData.LASERS[id]
			name = d["name"]
			sub = GameData.ITEM_RARITY_NAMES[d["rarity"]]
			stats = "Daño/andanada %d%s\n+ %s  ·  − %s" % [int(GameState.laser_volley_damage(d, 0) * int(d["shots"])), " (%d rayos)" % d["shots"] if int(d["shots"]) > 1 else "", d["adv"], d["dis"]]
			col = GameData.ITEM_RARITY_COLORS[d["rarity"]]
			tex = W.icon("laser", id)
			owned_txt = _count_owned("lasers", id)
		"gen":
			var g: Dictionary = GameData.GENERATORS[id]
			name = g["name"]
			sub = "Escudo" if g["type"] == "shield" else "Velocidad"
			stats = "%s\n%s" % [W.gen_desc(g), g["trait"]]
			col = Color("4aa3ff") if g["type"] == "shield" else Color("ffd84a")
			tex = W.icon("gen", id)
			owned_txt = _count_owned("gens", id)
		"ammo":
			var a: Dictionary = GameData.AMMO[id]
			name = "%s (%s)" % [a["name"], a["short"]]
			sub = "Lote de 100"
			stats = "Multiplicador de daño %s · en almacén %s" % [a["short"], GameData.format_num(GameState.data["ammo"].get(id, 0))]
			col = a["color"]
			tex = W.icon("ammo", id)
		"missile":
			var md: Dictionary = GameData.MISSILES[id]
			name = md["name"]
			sub = "Lote de %d" % GameData.MISSILE_LOT
			stats = "Daño %s · precisión %d%%%s\nEn almacén %s" % [GameData.format_num(md["dmg"]), int(md["acc"] * 100), (" · área %d u" % int(md["splash"])) if float(md["splash"]) > 0.0 else "", GameData.format_num(GameState.data["missiles"].get(id, 0))]
			col = md["color"]
			tex = W.icon("missile", id)
		"item":
			var it: Dictionary = GameData.ITEMS[id]
			name = it["name"]
			sub = "Consumible" if it["kind"] == "instant" else "Desplegable"
			stats = "%s · tienes %d" % [it["desc"], int(GameState.data["items"].get(id, 0))]
			col = it["color"]
			tex = W.icon("item", id)
		"drone_laser":
			var dl: Dictionary = GameData.DRONE_LASERS[id]
			name = dl["name"]
			sub = "Láser de pet"
			stats = dl["desc"]
			col = dl["color"]
			tex = W.icon("drone_laser", id)
			owned_txt = _count_owned("drone_lasers", id)
		"pet":
			name = "Pet acompañante"
			sub = "Compañero"
			stats = "5 formas al subir de nivel: +1 láser por forma y generadores de escudo desde la 3.ª"
			col = Color("5affc8")
			tex = SpriteLib.get_tex("drone", "pet_s1")
			if tex == null:
				tex = SpriteLib.get_tex("drone", "drone")
			owned = GameState.data["unlocks"].get("pet", false)
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", UiTheme.bevel(Color(0.07, 0.1, 0.17, 0.96), Color(0.03, 0.05, 0.09, 0.96), col.darkened(0.35), 8, 8))
	c.custom_minimum_size = Vector2(300, 0)
	var v := W.vbox(5)
	c.add_child(v)
	# Cabecera: nombre y tipo.
	var head := W.hbox(6)
	var nl := UiTheme.label(name, 16, col.lightened(0.35))
	nl.clip_text = true
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nl)
	head.add_child(UiTheme.label(sub, 12, UiTheme.MUTED))
	v.add_child(head)
	var glow := Glow.new()
	glow.color = col
	glow.tex = tex
	glow.custom_minimum_size = Vector2(0, 112)
	v.add_child(glow)
	var desc := UiTheme.label(ItemDesc.of(kind, id), 13, UiTheme.TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(270, 36)
	v.add_child(desc)
	var st := UiTheme.label(stats, 12, UiTheme.MUTED)
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	st.custom_minimum_size = Vector2(270, 0)
	v.add_child(st)
	if owned:
		var ok := UiTheme.heading("✔ En propiedad", 16, UiTheme.GOOD)
		ok.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(ok)
		return c
	# Precio: créditos O Cristales Nexo (nunca ambos), con lotes para los consumibles.
	var qtys := [1]
	if kind in ["ammo", "missile"]:
		qtys = [1, 10]
	elif kind == "item":
		qtys = [1, 5]
	if GameState.nexo_only(kind, id):
		v.add_child(UiTheme.label("Se fabrica con materiales (Fabricación) o se compra con Nexo.", 12, UiTheme.WARN))
	for cur in ["credits", "nexo"]:
		if cur == "credits" and GameState.nexo_only(kind, id):
			continue
		var price := GameState.price_of(kind, id, cur)
		var row := W.hbox(6)
		row.add_child(W.cost_row(price))
		row.add_child(W.spacer())
		for q in qtys:
			var label := "Comprar" if q == 1 else "x%d" % q
			if kind == "ammo":
				label = "+%d" % (100 * q)
			elif kind == "missile":
				label = "+%d" % (GameData.MISSILE_LOT * q)
			var b := W.btn(label, func(): _buy(kind, id, q, cur), "gold" if cur == "credits" else "normal", 0, 14)
			b.disabled = not GameState.can_afford(price, q)
			row.add_child(b)
		v.add_child(row)
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
