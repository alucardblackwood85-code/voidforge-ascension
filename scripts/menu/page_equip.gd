class_name PageEquip
extends VBoxContainer
## EQUIPAMIENTO: slots de la nave activa (láseres, generadores, módulos), pet y barra rápida.
## Arrastra objetos del inventario a los slots compatibles; arrastra de un slot al inventario
## (o clic derecho) para quitarlo; doble clic en el inventario equipa en el primer slot libre.

const SLOT_NAMES := {"lasers": "Láser", "gens": "Generador", "mods": "Módulo", "drone_lasers": "Láser de pet"}

var menu: StartMenu


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var tabs := W.hbox(6)
	for t in [["ship", "NAVE"], ["pet", "PET / DRON"], ["hotbar", "BARRA RÁPIDA 1-0"]]:
		var b := Button.new()
		b.text = "  %s  " % t[1]
		b.focus_mode = Control.FOCUS_NONE
		if menu.state["equip_tab"] == t[0]:
			b.add_theme_stylebox_override("normal", UiTheme.box(Color(0.1, 0.2, 0.3), UiTheme.ACCENT, 4, 2, 8))
		var id: String = t[0]
		b.pressed.connect(func():
			menu.state["equip_tab"] = id
			menu.refresh())
		tabs.add_child(b)
	tabs.add_child(W.spacer())
	tabs.add_child(UiTheme.label("Arrastra objetos a los slots · clic derecho en un slot para quitarlo · doble clic para equipar", 13, UiTheme.MUTED))
	add_child(tabs)
	match menu.state["equip_tab"]:
		"ship":
			_ship_view()
		"pet":
			_pet_view()
		"hotbar":
			_hotbar_view()


# --- Nave --------------------------------------------------------------------------------
func _ship_view() -> void:
	var ship_id: String = GameState.data["current_ship"]
	var s: Dictionary = GameData.SHIPS[ship_id]
	var lo := GameState.current_loadout()
	var row := W.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	# Columna izquierda: nave + slots
	var left := W.vbox(10)
	left.custom_minimum_size.x = 760
	var head := W.card()
	var hh := W.hbox(14)
	head.add_child(hh)
	hh.add_child(ShipPreview.make(W.icon("ship", ship_id), Vector2(200, 150)))
	var st := GameState.ship_stats(ship_id)
	var info := W.vbox(4)
	info.add_child(UiTheme.label(s["name"], 24, UiTheme.ACCENT))
	var stats_txt := UiTheme.rich("", 15)
	stats_txt.custom_minimum_size.x = 500
	stats_txt.text = "Casco [b]%s[/b]  ·  Escudo [b]%s[/b]  ·  Velocidad [b]%d[/b]\nDaño [b]x%.2f[/b]  ·  DPS (x1) [b]%s[/b]  ·  Crítico [b]%d%%[/b]" % [
		GameData.format_num(st["hull"]), GameData.format_num(st["shield"]), int(st["speed"]), st["dmg"],
		GameData.format_num(GameState.theoretical_dps(ship_id)), int(st["crit"] * 100)]
	info.add_child(stats_txt)
	info.add_child(W.button("Cambiar de nave (Hangar)", func(): menu.show_page("hangar")))
	hh.add_child(info)
	left.add_child(head)
	for key in ["lasers", "gens", "mods"]:
		var sec := W.card(Color(0.04, 0.06, 0.1, 0.9))
		var sv := W.vbox(6)
		sec.add_child(sv)
		var arr: Array = lo[key]
		sv.add_child(UiTheme.label("%s  (%d slots)" % [{"lasers": "LÁSERES", "gens": "GENERADORES", "mods": "MÓDULOS"}[key], arr.size()], 16, UiTheme.ACCENT))
		var slots := HFlowContainer.new()
		slots.add_theme_constant_override("h_separation", 8)
		for i in arr.size():
			var uid := int(arr[i])
			var it := GameState.find_item("modules" if key == "mods" else key, uid) if uid >= 0 else {}
			var slot := DropSlot.make(key, i, uid, W.item_info(key, it) if not it.is_empty() else {}, "%s %d" % [SLOT_NAMES[key], i + 1])
			slot.dropped.connect(_on_drop)
			slot.cleared.connect(func(sl): _equip(key, sl.index, -1))
			slots.add_child(slot)
		if arr.is_empty():
			slots.add_child(UiTheme.label("Esta nave no tiene slots de este tipo.", 13, UiTheme.MUTED))
		sv.add_child(slots)
		left.add_child(sec)
	row.add_child(W.scroll(left))
	row.add_child(_inventory(menu.state["equip_filter"], ship_id))


func _inventory(filter: String, ship_id: String) -> Control:
	var zone := DropZone.new()
	zone.kind = filter
	zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zone.add_theme_stylebox_override("panel", UiTheme.box(Color(0.04, 0.06, 0.1, 0.92), UiTheme.BORDER, 8, 1, 10))
	zone.received.connect(func(d): _equip(d["kind"], int(d["from_slot"]), -1))
	var v := W.vbox(8)
	zone.add_child(v)
	var fb := W.hbox(6)
	fb.add_child(UiTheme.label("INVENTARIO", 16, UiTheme.ACCENT))
	fb.add_child(W.spacer())
	for f in [["lasers", "Láseres"], ["gens", "Generadores"], ["mods", "Módulos"]]:
		var b := Button.new()
		b.text = f[1]
		b.focus_mode = Control.FOCUS_NONE
		if f[0] == filter:
			b.add_theme_stylebox_override("normal", UiTheme.box(Color(0.1, 0.2, 0.3), UiTheme.ACCENT, 4, 1, 6))
		var id: String = f[0]
		b.pressed.connect(func():
			menu.state["equip_filter"] = id
			menu.refresh())
		fb.add_child(b)
	v.add_child(fb)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	var list_key := "modules" if filter == "mods" else filter
	var count := 0
	var items: Array = GameState.data[list_key].duplicate()
	if filter == "mods":
		items.sort_custom(func(a, b): return int(a["rarity"]) > int(b["rarity"]))
	for it in items:
		var where := GameState.equipped_on(filter, int(it["uid"]))
		if where == ship_id:
			continue
		var note := ""
		if where != "":
			note = "En %s" % GameData.SHIPS[where]["name"]
		var d := DragItem.make(filter, int(it["uid"]), W.item_info(filter, it), note)
		d.activated.connect(func(item): _quick_equip(item.kind, item.uid))
		flow.add_child(d)
		count += 1
	if count == 0:
		var msg := "No tienes objetos libres de este tipo. Consíguelos en la Tienda o en Crafteo."
		if filter == "mods":
			msg = "Aún no tienes módulos. Fabrica cajas de módulos en Crafteo → Cajas."
		var l := UiTheme.label(msg, 14, UiTheme.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 560
		flow.add_child(l)
	v.add_child(W.scroll(flow))
	v.add_child(UiTheme.label("Suelta aquí un objeto de un slot para desequiparlo.", 12, UiTheme.MUTED))
	return zone


# --- Pet / dron ----------------------------------------------------------------------------
func _pet_view() -> void:
	var row := W.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	var left := W.vbox(10)
	left.custom_minimum_size.x = 760
	var head := W.card()
	var hh := W.hbox(14)
	head.add_child(hh)
	hh.add_child(ShipPreview.make(SpriteLib.get_tex("drone", "drone"), Vector2(200, 150)))
	var iv := W.vbox(6)
	iv.add_child(UiTheme.label("Dron acompañante", 24, UiTheme.ACCENT))
	iv.add_child(UiTheme.label("Sigue a tu nave y ataca automáticamente a tu objetivo. Habilidad: [%s]" % Controls.key_label("drone"), 14, UiTheme.MUTED))
	var roles := W.hbox(8)
	var cur: String = GameState.data["drone"]["role"]
	for r in Drone.ROLES.keys():
		var rd: Dictionary = Drone.ROLES[r]
		var b := W.button("%s %s" % ["●" if r == cur else "○", rd["name"]], func(): GameState.set_drone_role(r), r == cur, 150)
		b.tooltip_text = rd["ability"]
		roles.add_child(b)
	iv.add_child(roles)
	iv.add_child(UiTheme.label(Drone.ROLES[cur]["ability"], 13, UiTheme.TEXT))
	hh.add_child(iv)
	left.add_child(head)
	var sec := W.card(Color(0.04, 0.06, 0.1, 0.9))
	var sv := W.vbox(6)
	sec.add_child(sv)
	sv.add_child(UiTheme.label("LÁSERES DEL PET  (%d slots)" % GameData.DRONE_SLOTS, 16, UiTheme.ACCENT))
	var slots := W.hbox(8)
	var dl: Array = GameState.data["drone"]["lasers"]
	for i in dl.size():
		var uid := int(dl[i])
		var it := GameState.find_item("drone_lasers", uid) if uid >= 0 else {}
		var slot := DropSlot.make("drone_lasers", i, uid, W.item_info("drone_lasers", it) if not it.is_empty() else {}, "Láser %d" % (i + 1))
		slot.dropped.connect(_on_drop)
		slot.cleared.connect(func(sl): _equip("drone_lasers", sl.index, -1))
		slots.add_child(slot)
	sv.add_child(slots)
	left.add_child(sec)
	row.add_child(left)
	# Inventario de láseres de pet
	var zone := DropZone.new()
	zone.kind = "drone_lasers"
	zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zone.add_theme_stylebox_override("panel", UiTheme.box(Color(0.04, 0.06, 0.1, 0.92), UiTheme.BORDER, 8, 1, 10))
	zone.received.connect(func(d): _equip("drone_lasers", int(d["from_slot"]), -1))
	var v := W.vbox(8)
	zone.add_child(v)
	v.add_child(UiTheme.label("INVENTARIO DE PET", 16, UiTheme.ACCENT))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	for it in GameState.data["drone_lasers"]:
		if dl.has(int(it["uid"])):
			continue
		var d := DragItem.make("drone_lasers", int(it["uid"]), W.item_info("drone_lasers", it))
		d.activated.connect(func(item): _quick_equip(item.kind, item.uid))
		flow.add_child(d)
	v.add_child(W.scroll(flow))
	v.add_child(W.button("Comprar láseres de pet en la Tienda", func():
		menu.state["shop_tab"] = "pet"
		menu.show_page("shop")))
	row.add_child(zone)


# --- Barra rápida ---------------------------------------------------------------------------
func _hotbar_view() -> void:
	var sec := W.card(Color(0.04, 0.06, 0.1, 0.9))
	var sv := W.vbox(8)
	sec.add_child(sv)
	sv.add_child(UiTheme.label("BARRA RÁPIDA de %s (se guarda por nave)" % GameData.SHIPS[GameState.data["current_ship"]]["name"], 16, UiTheme.ACCENT))
	var slots := W.hbox(6)
	var hb: Array = GameState.current_loadout()["hotbar"]
	for i in GameState.HOTBAR_SIZE:
		var e = hb[i]
		var info := _entry_info(e) if e is Dictionary else {}
		var slot := DropSlot.make("hotbar", i, -1, info, "[%s]" % Controls.key_label("hotbar_%d" % i))
		slot.entry = e if e is Dictionary else null
		slot.dropped.connect(_on_hotbar_drop)
		slot.cleared.connect(func(sl): GameState.set_hotbar(sl.index, null))
		slots.add_child(slot)
	sv.add_child(slots)
	add_child(sec)
	var zone := DropZone.new()
	zone.kind = "hotbar"
	zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	zone.add_theme_stylebox_override("panel", UiTheme.box(Color(0.04, 0.06, 0.1, 0.92), UiTheme.BORDER, 8, 1, 10))
	zone.received.connect(func(d): GameState.set_hotbar(int(d["from_slot"]), null))
	var v := W.vbox(8)
	zone.add_child(v)
	v.add_child(UiTheme.label("MUNICIÓN Y OBJETOS — arrastra a un número de la barra", 16, UiTheme.ACCENT))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	for id in GameData.AMMO.keys():
		flow.add_child(_entry_item({"type": "ammo", "id": id}))
	for id in GameData.ITEMS.keys():
		flow.add_child(_entry_item({"type": "item", "id": id}))
	v.add_child(flow)
	add_child(zone)


func _entry_info(e: Dictionary) -> Dictionary:
	if e["type"] == "ammo":
		var a: Dictionary = GameData.AMMO[e["id"]]
		return {"name": "%s (%s)" % [a["name"], a["short"]], "color": a["color"], "icon": W.icon("ammo", e["id"]), "level": -1,
			"tip": "%s — multiplicador %s\nEn almacén: %s" % [a["name"], a["short"], GameData.format_num(GameState.data["ammo"].get(e["id"], 0))]}
	var it: Dictionary = GameData.ITEMS[e["id"]]
	return {"name": it["name"], "color": it["color"], "icon": W.icon("item", e["id"]), "level": -1,
		"tip": "%s\n%s\nTienes: %d" % [it["name"], it["desc"], int(GameState.data["items"].get(e["id"], 0))]}


func _entry_item(e: Dictionary) -> DragItem:
	var qty := int(GameState.data["ammo"].get(e["id"], 0)) if e["type"] == "ammo" else int(GameState.data["items"].get(e["id"], 0))
	var d := DragItem.make("hotbar", -1, _entry_info(e), "x%s" % GameData.format_num(qty))
	d.entry = e
	d.activated.connect(func(item):
		var free: int = GameState.current_loadout()["hotbar"].find(null)
		if free >= 0:
			GameState.set_hotbar(free, item.entry))
	return d


func _on_hotbar_drop(slot: DropSlot, data: Dictionary) -> void:
	var from := int(data.get("from_slot", -1))
	if from >= 0:
		# Intercambio entre dos números de la barra.
		var hb: Array = GameState.current_loadout()["hotbar"]
		var tmp = hb[slot.index]
		hb[slot.index] = hb[from]
		hb[from] = tmp
		GameState.set_hotbar(slot.index, hb[slot.index])
	else:
		GameState.set_hotbar(slot.index, data["entry"])
	Sfx.play("ui_select")


# --- Acciones comunes -----------------------------------------------------------------------
func _on_drop(slot: DropSlot, data: Dictionary) -> void:
	var from := int(data.get("from_slot", -1))
	var uid := int(data["uid"])
	if from >= 0 and from != slot.index and slot.uid >= 0:
		# Mover entre slots: intercambia los objetos.
		var other := slot.uid
		_equip(slot.kind, slot.index, uid, false)
		_equip(slot.kind, from, other)
		return
	_equip(slot.kind, slot.index, uid)


func _equip(kind: String, index: int, uid: int, sound: bool = true) -> void:
	GameState.equip(kind, index, uid)
	if sound:
		Sfx.play("ui_select" if uid >= 0 else "ui_click")


func _quick_equip(kind: String, uid: int) -> void:
	var slot := GameState.first_free_slot(kind)
	if slot < 0:
		Sfx.play("ui_error")
		return
	_equip(kind, slot, uid)
