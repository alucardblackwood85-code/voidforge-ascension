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
	for t in [["ship", "NAVE"], ["pet", "PET"], ["hotbar", "BARRA RÁPIDA 1-0"]]:
		var b := Button.new()
		b.text = "  %s  " % t[1]
		b.focus_mode = Control.FOCUS_NONE
		UiTheme.style_button(b, "primary" if menu.state["equip_tab"] == t[0] else "normal")
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
	# Total en grande y, al lado, base y bonificación de equipo, módulos y rango (GDD 17.2).
	stats_txt.text = "%s  ·  %s\n%s  ·  %s\nDPS (x1) [b]%s[/b]  ·  Crítico [b]%d%%[/b]" % [
		_stat("Casco", st["hull"], st["hull_base"]), _stat("Escudo", st["shield"], st["shield_base"]),
		_stat("Velocidad", st["speed"], st["speed_base"]), _stat("Daño", st["dmg"], st["dmg_base"], true),
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
		if key == "mods" and not GameState.data["unlocks"].get("modules", false):
			sv.add_child(UiTheme.label("🔒 Los módulos se desbloquean al alcanzar el nivel 5 (%s)." % GameState.rank_name(5), 14, UiTheme.WARN))
			left.add_child(sec)
			continue
		var slots := HFlowContainer.new()
		slots.add_theme_constant_override("h_separation", 8)
		for i in arr.size():
			var uid := int(arr[i])
			var it := GameState.find_item("modules" if key == "mods" else key, uid) if uid >= 0 else {}
			var slot_name := "%s %d" % [SLOT_NAMES[key], i + 1]
			if key == "gens" and i >= int(s["gens"]):
				slot_name = "Escudo extra"
			var slot := DropSlot.make(key, i, uid, W.item_info(key, it) if not it.is_empty() else {}, slot_name)
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
		UiTheme.style_button(b, "primary" if f[0] == filter else "normal")
		var id: String = f[0]
		b.pressed.connect(func():
			menu.state["equip_filter"] = id
			menu.refresh())
		fb.add_child(b)
	v.add_child(fb)
	# Filtros (GDD 17.2): estado del objeto y, según el tipo, clase de generador o familia de módulo.
	var sub: String = menu.state.get("equip_sub", "all")
	var opts := [["all", "Todos"], ["free", "Libres"], ["other", "En otras naves"]]
	if filter != "mods":
		opts.append(["up", "Mejorables"])
	if filter == "gens":
		opts += [["shield", "Escudo"], ["speed", "Velocidad"]]
	elif filter == "mods":
		for fam in GameData.MODULE_FAMILIES.keys():
			opts.append([fam, GameData.MODULE_FAMILIES[fam]["name"]])
	if not opts.any(func(o): return o[0] == sub):
		sub = "all"
	var sb := HFlowContainer.new()
	sb.add_theme_constant_override("h_separation", 6)
	for o in opts:
		var key: String = o[0]
		var ob := Button.new()
		ob.text = o[1]
		ob.focus_mode = Control.FOCUS_NONE
		ob.add_theme_font_size_override("font_size", 13)
		UiTheme.style_button(ob, "primary" if key == sub else "normal")
		ob.pressed.connect(func():
			menu.state["equip_sub"] = key
			menu.refresh())
		sb.add_child(ob)
	v.add_child(sb)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	var list_key := "modules" if filter == "mods" else filter
	var count := 0
	var items: Array = GameState.data[list_key].duplicate()
	# Lo mejor primero: así lo útil queda arriba aunque el inventario crezca.
	items.sort_custom(func(a, b): return _item_value(filter, a) > _item_value(filter, b))
	for it in items:
		var where := GameState.equipped_on(filter, int(it["uid"]))
		if where == ship_id or not _passes(filter, sub, it, where):
			continue
		var note := ""
		if where != "":
			note = "En %s" % GameData.holder_name(where)
		var info := W.item_info(filter, it)
		var cmp := _compare(filter, it, ship_id)
		if cmp != "":
			info["tip"] += "

Comparado con lo equipado: " + cmp
			if note == "":
				note = cmp
		var d := DragItem.make(filter, int(it["uid"]), info, note)
		d.activated.connect(func(item): _quick_equip(item.kind, item.uid))
		flow.add_child(d)
		count += 1
	if count == 0:
		var msg := "No tienes objetos libres de este tipo. Consíguelos en la Tienda o en Fabricación."
		if filter == "mods":
			msg = "Aún no tienes módulos. Fabrica cajas de módulos en Fabricación → Cajas."
		var l := UiTheme.label(msg, 14, UiTheme.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 560
		flow.add_child(l)
	v.add_child(W.scroll(flow))
	v.add_child(UiTheme.label("Suelta aquí un objeto de un slot para desequiparlo.", 12, UiTheme.MUTED))
	return zone


## "Casco 4.6K (base 4.2K +10%)": total, base y bonificación en verde o rojo.
func _stat(name: String, total: float, base: float, mult: bool = false) -> String:
	var pct := (total / maxf(0.001, base) - 1.0) * 100.0
	var tot := ("x%.2f" % total) if mult else GameData.format_num(total)
	var bas := ("x%.2f" % base) if mult else GameData.format_num(base)
	if absf(pct) < 0.5:
		return "%s [b]%s[/b]" % [name, tot]
	return "%s [b]%s[/b] [color=#7d8aa3](base %s [/color][color=#%s]%+d%%[/color][color=#7d8aa3])[/color]" % [name, tot, bas, "6fd17a" if pct > 0 else "ff5a5a", int(round(pct))]


## ¿Pasa el objeto el filtro `sub` del inventario?
func _passes(filter: String, sub: String, it: Dictionary, where: String) -> bool:
	match sub:
		"free":
			return where == ""
		"other":
			return where != ""
		"up":
			if int(it.get("level", 16)) >= 16:
				return false
			var cost := GameData.upgrade_cost(int(it["level"]), GameState.item_base_credits(filter, it["id"]))
			return GameState.can_afford(cost)
		"shield", "speed":
			return GameData.GENERATORS[it["id"]]["type"] == sub
		"all":
			return true
	# Familia de módulo
	return filter == "mods" and it.get("family", "") == sub


# --- Pet ----------------------------------------------------------------------------
func _pet_view() -> void:
	if not GameState.data["unlocks"].get("pet", false):
		# Sin pet: se compra en la tienda (créditos o Cristales Nexo).
		var lc := W.card(Color(0.05, 0.08, 0.13, 0.92), UiTheme.WARN, 20)
		var lv := W.vbox(10)
		lc.add_child(lv)
		var lh := W.hbox(16)
		lh.add_child(ShipPreview.make(_pet_tex(1), Vector2(180, 130)))
		var lt := W.vbox(6)
		lt.add_child(UiTheme.label("Aún no tienes pet", 22, UiTheme.WARN))
		lt.add_child(UiTheme.label("Un pet acompaña a tu nave, dispara a tu objetivo o recoge botín, y evoluciona al subir de nivel:\ncada forma nueva abre un láser más y, desde la tercera, generadores de escudo.", 14, UiTheme.TEXT))
		lt.add_child(W.button("Comprar pet en la Tienda", func():
			menu.state["shop_tab"] = "drone_laser"
			menu.show_page("shop"), true, 260))
		lh.add_child(lt)
		lv.add_child(lh)
		lv.add_child(_stage_strip(0))
		add_child(lc)
		return
	var row := W.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	var left := W.vbox(10)
	left.custom_minimum_size.x = 760
	var head := W.card()
	var hh := W.hbox(14)
	head.add_child(hh)
	var plv := GameState.pet_level()
	var stage := GameData.pet_stage(plv)
	hh.add_child(ShipPreview.make(_pet_tex(stage), Vector2(200, 150)))
	var iv := W.vbox(6)
	iv.add_child(UiTheme.label("Pet — %s" % GameData.PET_STAGE_NAMES[stage - 1], 24, UiTheme.ACCENT))
	var pxp := int(GameState.data["pet"]["xp"])
	iv.add_child(UiTheme.label("Nivel %d / %d  ·  +%d%% daño  ·  +%d%% cadencia" % [plv, GameData.PET_MAX_LEVEL, int(GameData.PET_DMG_PER_LEVEL * (plv - 1) * 100), int(GameData.PET_RATE_PER_LEVEL * (plv - 1) * 100)], 15, Color("5affc8")))
	var pbar := ProgressBar.new()
	pbar.show_percentage = false
	pbar.custom_minimum_size = Vector2(320, 10)
	pbar.add_theme_stylebox_override("fill", UiTheme.box(Color("5affc8"), Color("5affc8"), 3, 0, 0))
	if plv < GameData.PET_MAX_LEVEL:
		pbar.min_value = GameData.pet_xp_for_level(plv)
		pbar.max_value = GameData.pet_xp_for_level(plv + 1)
		pbar.value = pxp
	else:
		pbar.value = pbar.max_value
	iv.add_child(pbar)
	iv.add_child(UiTheme.label("El pet recibe el 25%% de tu experiencia (%s / %s XP de pet)" % [GameData.format_num(pxp), GameData.format_num(GameData.pet_xp_for_level(mini(plv + 1, GameData.PET_MAX_LEVEL)))], 12, UiTheme.MUTED))
	if stage < GameData.PET_STAGE_LEVELS.size():
		iv.add_child(UiTheme.label("Siguiente forma: %s en el nivel %d (+1 láser%s)" % [GameData.PET_STAGE_NAMES[stage], GameData.PET_STAGE_LEVELS[stage], ", +1 generador de escudo" if stage + 1 >= 3 else ""], 13, UiTheme.WARN))
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
	left.add_child(_stage_strip(stage))
	left.add_child(_pet_slots("drone_lasers", "LÁSERES DEL PET", GameData.PET_MAX_LASERS, GameData.pet_laser_slots(plv)))
	left.add_child(_pet_slots("drone_gens", "GENERADORES DE ESCUDO DEL PET  (proyectan el %d%% de su escudo sobre tu nave)" % int(GameData.PET_GEN_SHARE * 100), GameData.PET_MAX_GENS, GameData.pet_gen_slots(plv)))
	row.add_child(left)
	# Inventario: láseres de pet y generadores de escudo
	var zone := DropZone.new()
	zone.kind = "drone_lasers"
	zone.kinds = ["drone_gens"]
	zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zone.add_theme_stylebox_override("panel", UiTheme.box(Color(0.04, 0.06, 0.1, 0.92), UiTheme.BORDER, 8, 1, 10))
	zone.received.connect(func(d): _equip(d["kind"], int(d["from_slot"]), -1))
	var v := W.vbox(8)
	zone.add_child(v)
	v.add_child(UiTheme.label("LÁSERES DE PET", 16, UiTheme.ACCENT))
	var dl: Array = GameState.data["drone"]["lasers"]
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	for it in GameState.data["drone_lasers"]:
		if dl.has(int(it["uid"])):
			continue
		var d := DragItem.make("drone_lasers", int(it["uid"]), W.item_info("drone_lasers", it))
		d.activated.connect(func(item): _quick_equip(item.kind, item.uid))
		flow.add_child(d)
	v.add_child(flow)
	v.add_child(UiTheme.label("GENERADORES DE ESCUDO", 16, UiTheme.ACCENT))
	var pg: Array = GameState.data["drone"]["gens"]
	var gflow := HFlowContainer.new()
	gflow.add_theme_constant_override("h_separation", 8)
	for it in GameState.data["gens"]:
		if pg.has(int(it["uid"])) or GameData.GENERATORS[it["id"]]["type"] != "shield":
			continue
		var info := W.item_info("gens", it)
		var where := GameState.equipped_on("gens", int(it["uid"]))
		if where != "":
			info["tip"] += "\n(Equipado en %s: se moverá al pet)" % GameData.holder_name(where)
		var d := DragItem.make("drone_gens", int(it["uid"]), info)
		d.activated.connect(func(item): _quick_equip(item.kind, item.uid))
		gflow.add_child(d)
	v.add_child(W.scroll(gflow))
	v.add_child(W.button("Comprar láseres de pet en la Tienda", func():
		menu.state["shop_tab"] = "drone_laser"
		menu.show_page("shop")))
	row.add_child(zone)


## Textura de la forma `stage` del pet (cae a la esfera si aún no existe).
func _pet_tex(stage: int) -> Texture2D:
	var t := SpriteLib.get_tex("drone", "pet_s%d" % stage)
	return t if t else SpriteLib.get_tex("drone", "drone")


## Tira con las 5 formas del pet y el nivel en que se alcanza cada una.
func _stage_strip(current: int) -> Control:
	var c := W.card(Color(0.04, 0.06, 0.1, 0.9))
	var h := W.hbox(10)
	c.add_child(h)
	for i in GameData.PET_STAGE_LEVELS.size():
		var st := i + 1
		var col := W.vbox(2)
		var pic := W.pic(_pet_tex(st), Vector2(110, 70))
		if st > current:
			pic.modulate = Color(0.4, 0.4, 0.45)
		col.add_child(pic)
		var reached := st <= current
		var lab := UiTheme.label("%s\nNv %d · %d láser%s%s" % [GameData.PET_STAGE_NAMES[i], GameData.PET_STAGE_LEVELS[i], st, "es" if st > 1 else "", (" · %d esc." % (st - 2)) if st >= 3 else ""], 12, Color("5affc8") if st == current else (UiTheme.TEXT if reached else UiTheme.MUTED))
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(lab)
		h.add_child(col)
		if st < GameData.PET_STAGE_LEVELS.size():
			h.add_child(UiTheme.label("›", 22, UiTheme.MUTED))
	return c


## Ranuras del pet (láseres o generadores): las cerradas indican la forma/nivel que las abre.
func _pet_slots(kind: String, title: String, total: int, open: int) -> Control:
	var sec := W.card(Color(0.04, 0.06, 0.1, 0.9))
	var sv := W.vbox(6)
	sec.add_child(sv)
	sv.add_child(UiTheme.label(title, 16, UiTheme.ACCENT))
	var slots := W.hbox(8)
	var arr: Array = GameState.data["drone"]["lasers" if kind == "drone_lasers" else "gens"]
	for i in total:
		if i >= open:
			# Láser i+1 llega con la forma i+1; generador i+1 con la forma i+3.
			var st := i + 1 if kind == "drone_lasers" else i + 3
			var lock := W.card(Color(0.03, 0.04, 0.07, 0.9), UiTheme.BORDER, 6)
			lock.custom_minimum_size = Vector2(96, 112)
			var ll := UiTheme.label("Bloqueado\n%s\nNv %d" % [GameData.PET_STAGE_NAMES[st - 1], GameData.PET_STAGE_LEVELS[st - 1]], 12, UiTheme.MUTED)
			ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock.add_child(ll)
			slots.add_child(lock)
			continue
		var uid := int(arr[i])
		var list_key := "drone_lasers" if kind == "drone_lasers" else "gens"
		var it := GameState.find_item(list_key, uid) if uid >= 0 else {}
		var slot := DropSlot.make(kind, i, uid, W.item_info(list_key, it) if not it.is_empty() else {}, ("Láser %d" if kind == "drone_lasers" else "Escudo %d") % (i + 1))
		slot.dropped.connect(_on_drop)
		slot.cleared.connect(func(sl): _equip(kind, sl.index, -1))
		slots.add_child(slot)
	sv.add_child(slots)
	return sec

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
	for id in GameData.MISSILES.keys():
		flow.add_child(_entry_item({"type": "missile", "id": id}))
	for id in GameData.ITEMS.keys():
		flow.add_child(_entry_item({"type": "item", "id": id}))
	v.add_child(flow)
	add_child(zone)


func _entry_info(e: Dictionary) -> Dictionary:
	if e["type"] == "missile":
		var md: Dictionary = GameData.MISSILES[e["id"]]
		return {"name": "Misil " + md["name"], "color": md["color"], "icon": W.icon("missile", e["id"]), "level": -1,
			"tip": "Misil %s — daño %d, precisión %d%%%s\nEl lanzamisiles dispara solo 1 cada %d s.\nEn almacén: %s" % [md["name"], int(md["dmg"]), int(md["acc"] * 100), (", área %d u" % int(md["splash"])) if float(md["splash"]) > 0.0 else "", int(GameData.MISSILE_INTERVAL), GameData.format_num(GameState.data["missiles"].get(e["id"], 0))]}
	if e["type"] == "ammo":
		var a: Dictionary = GameData.AMMO[e["id"]]
		return {"name": "%s (%s)" % [a["name"], a["short"]], "color": a["color"], "icon": W.icon("ammo", e["id"]), "level": -1,
			"tip": "%s — multiplicador %s\nEn almacén: %s" % [a["name"], a["short"], GameData.format_num(GameState.data["ammo"].get(e["id"], 0))]}
	var it: Dictionary = GameData.ITEMS[e["id"]]
	return {"name": it["name"], "color": it["color"], "icon": W.icon("item", e["id"]), "level": -1,
		"tip": "%s\n%s\nTienes: %d" % [it["name"], it["desc"], int(GameState.data["items"].get(e["id"], 0))]}


func _entry_item(e: Dictionary) -> DragItem:
	var qty := int(GameState.data[{"ammo": "ammo", "missile": "missiles"}.get(e["type"], "items")].get(e["id"], 0))
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
	if slot.kind == "gens" and (not _gen_fits(slot.index, uid) or (from >= 0 and slot.uid >= 0 and not _gen_fits(from, slot.uid))):
		Sfx.play("ui_error")
		return
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
	var slot := GameState.first_free_slot(kind, "", uid)
	if slot < 0:
		Sfx.play("ui_error")
		return
	_equip(kind, slot, uid)


# --- M14: comparador -------------------------------------------------------------------------
## Diferencia del objeto frente al peor equipado de su tipo (o "slot libre").
func _compare(filter: String, it: Dictionary, ship_id: String) -> String:
	var lo := GameState.ensure_loadout(ship_id)
	var mine := _item_value(filter, it)
	var worst := INF
	var free := false
	var key := "mods" if filter == "mods" else filter
	for uid in lo[key]:
		if int(uid) < 0:
			free = true
			continue
		var eq := GameState.find_item("modules" if filter == "mods" else filter, int(uid))
		if eq.is_empty():
			continue
		if filter == "gens" and GameData.GENERATORS[eq["id"]]["type"] != GameData.GENERATORS[it["id"]]["type"]:
			continue
		if filter == "mods":
			# Regla de color: sólo se compara con el módulo del mismo color si lo hay.
			if eq["family"] == it["family"]:
				worst = _item_value(filter, eq)
				free = false
				break
			continue
		worst = minf(worst, _item_value(filter, eq))
	if lo[key].is_empty():
		return ""
	if free and (filter != "mods" or worst == INF):
		return "▲ slot libre"
	if worst == INF or worst <= 0.0:
		return "▲ nuevo tipo"
	var pct := (mine - worst) / worst * 100.0
	if absf(pct) < 0.5:
		return "= igual"
	return ("▲ +%d%%" if pct > 0.0 else "▼ %d%%") % int(round(pct))


func _item_value(filter: String, it: Dictionary) -> float:
	match filter:
		"lasers":
			var d: Dictionary = GameData.LASERS[it["id"]]
			return GameState.laser_volley_damage(d, int(it["level"])) * int(d["shots"])
		"gens":
			var g: Dictionary = GameData.GENERATORS[it["id"]]
			return float(g["stats"].get(g["type"], 0.0)) * GameData.component_mult(int(it["level"]))
		"mods":
			var lines := 0.0
			for l in it["lines"]:
				lines += float(l["value"])
			return float(it["main"]) + lines * 0.5
	return 0.0


## Los espacios extra de las naves pesadas sólo admiten generadores de escudo.
func _gen_fits(index: int, uid: int) -> bool:
	if index < int(GameData.SHIPS[GameState.data["current_ship"]]["gens"]):
		return true
	var it := GameState.find_item("gens", uid)
	return not it.is_empty() and GameData.GENERATORS[it["id"]]["type"] == "shield"
