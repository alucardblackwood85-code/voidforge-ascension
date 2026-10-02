extends Node
## Perfil persistente del jugador: monedas, inventario, loadouts, experiencia y progreso.
## Prototipo: guardado local en user://. El GDD exige servidor autoritativo en producción (20.2).

signal changed
signal leveled_up(level: int)

const SAVE_PATH := "user://voidforge_save.json"
const SAVE_VERSION := 2
const HOTBAR_SIZE := 10

var data: Dictionary = {}
## Parámetros de la siguiente incursión elegidos en el mapa estelar.
var pending_sector: Dictionary = {}
## Resultado de la última incursión, para mostrarlo en el inicio.
var last_result: Dictionary = {}


func _ready() -> void:
	load_game()


func new_profile() -> Dictionary:
	data = {
		"version": SAVE_VERSION,
		"next_uid": 1,
		"credits": 5000,
		"nexo": 0,
		"seals": 0,
		"xp": 0,
		"materials": {"ferrita": 40, "plata": 30, "nanoespuma": 12, "resina_plasma": 8},
		"ammo": {"mk1": 2500, "mk2": 300},
		"items": {"repair": 3, "boost": 2, "mine": 0, "shield_cell": 0},
		"ships": ["kestrel_a1"],
		"current_ship": "kestrel_a1",
		"lasers": [],
		"gens": [],
		"modules": [],
		"drone_lasers": [],
		"drone": {"role": "asalto", "lasers": [-1, -1]},
		"loadouts": {},
		"sector_max": 1,
		"sector_cleared": [],
		"kills_by": {},
		"pity": {"since_relic": 0, "since_exotic": 0, "opened": 0},
		"stats": {"kills": 0, "runs": 0, "deaths": 0, "extractions": 0, "time": 0, "credits_earned": 0, "boxes": 0},
		"settings": {"auto_fire_touch": true, "audio": default_audio()},
	}
	for i in 3:
		add_laser("l01")
	add_generator("sg_aegis1")
	add_generator("vg_thrust1")
	var dl := add_drone_laser("pet_pulse")
	data["drone"]["lasers"][0] = dl["uid"]
	var lo := ensure_loadout("kestrel_a1")
	for i in 3:
		lo["lasers"][i] = data["lasers"][i]["uid"]
	lo["gens"][0] = data["gens"][0]["uid"]
	lo["gens"][1] = data["gens"][1]["uid"]
	lo["hotbar"] = default_hotbar()
	return data


func default_audio() -> Dictionary:
	return {"master": 0.8, "music": 0.55, "sfx": 0.8, "lasers": 0.6, "voice": 0.9}


func default_hotbar() -> Array:
	var hb: Array = []
	hb.resize(HOTBAR_SIZE)
	hb[0] = {"type": "ammo", "id": "mk1"}
	hb[1] = {"type": "ammo", "id": "mk2"}
	hb[2] = {"type": "item", "id": "repair"}
	hb[3] = {"type": "item", "id": "boost"}
	return hb


# --- Guardado ----------------------------------------------------------------
func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("No se pudo guardar: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		new_profile()
		save_game()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f else null
	if typeof(parsed) != TYPE_DICTIONARY:
		new_profile()
		save_game()
		return
	data = parsed
	_migrate()
	_fix_json_types()
	save_game()


## Actualiza perfiles antiguos añadiendo los campos nuevos sin perder el progreso.
func _migrate() -> void:
	var defaults := {
		"xp": 0, "modules": [], "drone_lasers": [], "kills_by": {},
		"pity": {"since_relic": 0, "since_exotic": 0, "opened": 0},
		"drone": {"role": data.get("drone_role", "asalto"), "lasers": [-1, -1]},
	}
	for k in defaults.keys():
		if not data.has(k):
			data[k] = defaults[k]
	for k in ["time", "credits_earned", "boxes"]:
		if not data["stats"].has(k):
			data["stats"][k] = 0
	if not data["settings"].has("audio"):
		data["settings"]["audio"] = default_audio()
	data["settings"].erase("wasd")
	if data["drone_lasers"].is_empty():
		var dl := add_drone_laser("pet_pulse")
		data["drone"]["lasers"][0] = dl["uid"]
	for ship_id in data["loadouts"].keys():
		var lo: Dictionary = data["loadouts"][ship_id]
		if not lo.has("mods"):
			var mods: Array = []
			mods.resize(int(GameData.SHIPS[ship_id]["mods"]))
			mods.fill(-1)
			lo["mods"] = mods
	data["version"] = SAVE_VERSION


## JSON convierte enteros en float; los normalizamos.
func _fix_json_types() -> void:
	for k in ["next_uid", "credits", "nexo", "seals", "sector_max", "xp"]:
		data[k] = int(data[k])
	for dict_key in ["materials", "ammo", "items", "stats", "kills_by", "pity"]:
		var d: Dictionary = data[dict_key]
		for k in d.keys():
			d[k] = int(d[k])
	for list_key in ["lasers", "gens", "drone_lasers"]:
		for it in data[list_key]:
			it["uid"] = int(it["uid"])
			it["level"] = int(it.get("level", 0))
	for m in data["modules"]:
		m["uid"] = int(m["uid"])
		m["rarity"] = int(m["rarity"])
	for lo in data["loadouts"].values():
		for list_key in ["lasers", "gens", "mods"]:
			var arr: Array = lo[list_key]
			for i in arr.size():
				arr[i] = int(arr[i])
	var dls: Array = data["drone"]["lasers"]
	for i in dls.size():
		dls[i] = int(dls[i])
	var cleared: Array = data["sector_cleared"]
	for i in cleared.size():
		cleared[i] = int(cleared[i])


func reset_profile() -> void:
	var audio: Dictionary = data["settings"]["audio"]
	new_profile()
	data["settings"]["audio"] = audio
	save_game()
	changed.emit()


# --- Recursos ------------------------------------------------------------------
func get_amount(id: String) -> int:
	match id:
		"credits", "nexo", "seals":
			return int(data[id])
	return int(data["materials"].get(id, 0))


func add_amount(id: String, qty: int) -> void:
	match id:
		"credits", "nexo", "seals":
			data[id] = int(data[id]) + qty
		_:
			data["materials"][id] = int(data["materials"].get(id, 0)) + qty


func can_afford(cost: Dictionary, times: int = 1) -> bool:
	for k in cost.keys():
		if get_amount(k) < int(cost[k]) * times:
			return false
	return true


func pay(cost: Dictionary, times: int = 1) -> bool:
	if not can_afford(cost, times):
		return false
	for k in cost.keys():
		add_amount(k, -int(cost[k]) * times)
	return true


func add_loot(loot: Dictionary) -> void:
	for k in loot.keys():
		add_amount(k, int(loot[k]))


# --- Experiencia y rango ----------------------------------------------------------
func level() -> int:
	return GameData.level_from_xp(int(data["xp"]))


func rank_name(lvl: int = -1) -> String:
	if lvl < 0:
		lvl = level()
	return GameData.RANKS[clampi(lvl, 1, GameData.MAX_LEVEL) - 1]


## Suma experiencia y devuelve cuántos niveles se ganaron.
func add_xp(amount: int) -> int:
	var before := level()
	data["xp"] = int(data["xp"]) + amount
	var after := level()
	if after > before:
		leveled_up.emit(after)
	return after - before


# --- Inventario de componentes ---------------------------------------------------
func _uid() -> int:
	var u: int = data["next_uid"]
	data["next_uid"] = u + 1
	return u


func add_laser(id: String) -> Dictionary:
	var it := {"uid": _uid(), "id": id, "level": 0}
	data["lasers"].append(it)
	return it


func add_generator(id: String) -> Dictionary:
	var it := {"uid": _uid(), "id": id, "level": 0}
	data["gens"].append(it)
	return it


func add_drone_laser(id: String) -> Dictionary:
	var it := {"uid": _uid(), "id": id, "level": 0}
	data["drone_lasers"].append(it)
	return it


func find_item(list_key: String, uid: int) -> Dictionary:
	for it in data[list_key]:
		if int(it["uid"]) == uid:
			return it
	return {}


## Devuelve el id de nave donde está equipado el objeto, o "".
func equipped_on(list_key: String, uid: int) -> String:
	if list_key == "drone_lasers":
		return "drone" if data["drone"]["lasers"].has(uid) else ""
	for ship_id in data["loadouts"].keys():
		if data["loadouts"][ship_id][list_key].has(uid):
			return ship_id
	return ""


func ensure_loadout(ship_id: String) -> Dictionary:
	var ship: Dictionary = GameData.SHIPS[ship_id]
	if not data["loadouts"].has(ship_id):
		var mk := func(n: int) -> Array:
			var a: Array = []
			a.resize(n)
			a.fill(-1)
			return a
		data["loadouts"][ship_id] = {"lasers": mk.call(int(ship["lasers"])), "gens": mk.call(int(ship["gens"])), "mods": mk.call(int(ship["mods"])), "hotbar": default_hotbar()}
	var lo: Dictionary = data["loadouts"][ship_id]
	var hb: Array = lo["hotbar"]
	if hb.size() != HOTBAR_SIZE:
		hb.resize(HOTBAR_SIZE)
	return lo


func current_loadout() -> Dictionary:
	return ensure_loadout(data["current_ship"])


## Equipa (o desequipa con uid = -1) en un slot; si el objeto estaba en otra nave/slot lo libera.
## Módulos: una nave nunca puede llevar dos del mismo color (9) — el anterior se desequipa.
func equip(list_key: String, slot: int, uid: int, ship_id: String = "") -> void:
	if ship_id == "":
		ship_id = data["current_ship"]
	if list_key == "drone_lasers":
		var dl: Array = data["drone"]["lasers"]
		if uid >= 0:
			var idx := dl.find(uid)
			if idx >= 0:
				dl[idx] = -1
		dl[slot] = uid
		save_game()
		changed.emit()
		return
	var lo := ensure_loadout(ship_id)
	if uid >= 0:
		for other in data["loadouts"].values():
			var arr: Array = other[list_key]
			var idx := arr.find(uid)
			if idx >= 0:
				arr[idx] = -1
		if list_key == "mods":
			var fam: String = find_item("modules", uid).get("family", "")
			var mods: Array = lo["mods"]
			for i in mods.size():
				if i != slot and int(mods[i]) >= 0 and find_item("modules", int(mods[i])).get("family", "") == fam:
					mods[i] = -1
	lo[list_key][slot] = uid
	save_game()
	changed.emit()


## Primer slot libre compatible (para equipar con doble clic).
func first_free_slot(list_key: String, ship_id: String = "") -> int:
	if list_key == "drone_lasers":
		return data["drone"]["lasers"].find(-1)
	if ship_id == "":
		ship_id = data["current_ship"]
	return ensure_loadout(ship_id)[list_key].find(-1)


func set_hotbar(slot: int, entry) -> void:
	current_loadout()["hotbar"][slot] = entry
	save_game()
	changed.emit()


func select_ship(ship_id: String) -> void:
	if data["ships"].has(ship_id):
		data["current_ship"] = ship_id
		ensure_loadout(ship_id)
		save_game()
		changed.emit()


func set_drone_role(role: String) -> void:
	data["drone"]["role"] = role
	save_game()
	changed.emit()


# --- Tienda (créditos/Nexo) y fabricación (materiales) ------------------------------------
## kind: ship | laser | gen | drone_laser | ammo (lote de 100) | item
## Receta de crafteo (créditos + materiales). Naves y armas no piden Nexo al fabricarse; sólo las
## cajas Anómalas y las mejoras 13-16 lo usan (GDD 14).
func recipe_of(kind: String, id: String) -> Dictionary:
	var r := _raw_recipe(kind, id)
	if kind in ["ship", "laser", "gen", "drone_laser"] and r.has("nexo"):
		r = r.duplicate()
		r.erase("nexo")
	return r


func _raw_recipe(kind: String, id: String) -> Dictionary:
	match kind:
		"ship":
			return GameData.SHIPS[id]["cost"]
		"laser":
			return GameData.LASERS[id]["cost"]
		"gen":
			return GameData.GENERATORS[id]["cost"]
		"drone_laser":
			return GameData.DRONE_LASERS[id]["cost"]
		"ammo":
			return GameData.AMMO[id]["recipe"]
		"item":
			return GameData.ITEMS[id]["recipe"]
		"box":
			return GameData.MODULE_BOXES[id]["recipe"]
	return {}


func price_of(kind: String, id: String, currency: String = "credits") -> Dictionary:
	var raw := _raw_recipe(kind, id)
	return GameData.nexo_price(raw) if currency == "nexo" else GameData.shop_price(raw)


## La munición Mk-V/VI y las cajas de módulos sólo se fabrican (GDD 18.1 y 14.2).
func in_shop(kind: String, id: String) -> bool:
	if kind == "ammo":
		return id in ["mk1", "mk2", "mk3", "mk4"]
	if kind == "box":
		return false
	if kind == "ship":
		return id != "kestrel_a1"
	return true


func buy(kind: String, id: String, qty: int = 1, currency: String = "credits") -> bool:
	return _acquire(kind, id, qty, price_of(kind, id, currency))


func craft(kind: String, id: String, qty: int = 1) -> bool:
	return _acquire(kind, id, qty, recipe_of(kind, id))


func _acquire(kind: String, id: String, qty: int, cost: Dictionary) -> bool:
	if kind == "ship" and data["ships"].has(id):
		return false
	if not pay(cost, qty):
		return false
	for i in qty:
		match kind:
			"ship":
				data["ships"].append(id)
				ensure_loadout(id)
			"laser":
				add_laser(id)
			"gen":
				add_generator(id)
			"drone_laser":
				add_drone_laser(id)
			"ammo":
				data["ammo"][id] = int(data["ammo"].get(id, 0)) + 100
			"item":
				data["items"][id] = int(data["items"].get(id, 0)) + 1
	save_game()
	changed.emit()
	return true


func item_base_credits(list_key: String, id: String) -> int:
	var table: Dictionary = GameData.LASERS if list_key == "lasers" else GameData.GENERATORS
	return maxi(800, int(table[id]["cost"].get("credits", 2000)) / 4)


func upgrade_item(list_key: String, uid: int) -> bool:
	var it := find_item(list_key, uid)
	if it.is_empty() or int(it["level"]) >= 16:
		return false
	var cost := GameData.upgrade_cost(int(it["level"]), item_base_credits(list_key, it["id"]))
	if not pay(cost):
		return false
	it["level"] = int(it["level"]) + 1
	save_game()
	changed.emit()
	return true


# --- Módulos y cajas con protección de mala suerte (9.2) -------------------------------------
func open_box(box_id: String) -> Dictionary:
	var box: Dictionary = GameData.MODULE_BOXES[box_id]
	if not pay(box["recipe"]):
		return {}
	var w: Array = box["weights"].duplicate()
	var pity: Dictionary = data["pity"]
	if int(pity["since_exotic"]) >= GameData.PITY_EXOTIC:
		w[4] += 0.05 * (int(pity["since_exotic"]) - GameData.PITY_EXOTIC + 1)
	var rarity := 0
	if int(pity["since_relic"]) + 1 >= GameData.PITY_RELIC:
		rarity = 4 if randf() * (w[3] + w[4]) < w[4] else 3
	else:
		var total := 0.0
		for x in w:
			total += x
		var roll := randf() * total
		for i in w.size():
			roll -= w[i]
			if roll <= 0.0:
				rarity = i
				break
	pity["since_relic"] = 0 if rarity >= 3 else int(pity["since_relic"]) + 1
	pity["since_exotic"] = 0 if rarity == 4 else int(pity["since_exotic"]) + 1
	pity["opened"] = int(pity["opened"]) + 1
	data["stats"]["boxes"] = int(data["stats"]["boxes"]) + 1
	var m := roll_module(rarity)
	data["modules"].append(m)
	save_game()
	changed.emit()
	return m


func roll_module(rarity: int, family: String = "") -> Dictionary:
	if family == "":
		family = GameData.MODULE_FAMILIES.keys()[randi() % 4]
	var fam: Dictionary = GameData.MODULE_FAMILIES[family]
	var band: Array = GameData.MODULE_BANDS[fam["stat"]][rarity]
	var main := randi_range(int(band[0]), int(band[1]))
	var lines_range: Array = GameData.MODULE_LINES[rarity]
	var n_subs := randi_range(int(lines_range[0]), int(lines_range[1])) - 1
	var subs: Array = fam["subs"].duplicate()
	subs.shuffle()
	var lines: Array = []
	for i in n_subs:
		lines.append({"stat": subs[i], "value": snappedf(randf_range(1.0, 3.0) * (rarity + 1), 0.1)})
	return {"uid": _uid(), "family": family, "rarity": rarity, "main": main, "lines": lines}


func module_label(m: Dictionary) -> String:
	var fam: Dictionary = GameData.MODULE_FAMILIES[m["family"]]
	return "%s +%d%% %s" % [GameData.ITEM_RARITY_NAMES[GameData.MODULE_RARITIES[int(m["rarity"])]], int(m["main"]), fam["name"]]


# --- Estadísticas calculadas -----------------------------------------------------------
## Estadísticas finales de una nave con su loadout (base, bonos y total por separado: 17.2).
func ship_stats(ship_id: String = "") -> Dictionary:
	if ship_id == "":
		ship_id = data["current_ship"]
	var ship: Dictionary = GameData.SHIPS[ship_id]
	var lo := ensure_loadout(ship_id)
	var bonus := {"hull": 0.0, "shield": 0.0, "speed": 0.0, "dmg": 0.0, "recharge": 0.0, "shield_regen": 0.0, "boost_cd": 0.0,
		"accel": 0.0, "turn": 0.0, "crit": 0.0, "elite_dmg": 0.0, "hull_regen": 0.0, "recharge_delay": 0.0}
	for uid in lo["gens"]:
		if int(uid) < 0:
			continue
		var it := find_item("gens", int(uid))
		if it.is_empty():
			continue
		var g: Dictionary = GameData.GENERATORS[it["id"]]
		var mult := GameData.component_mult(int(it["level"]))
		for k in g["stats"].keys():
			var v: float = g["stats"][k]
			# Las penalizaciones no escalan con el nivel; sólo los beneficios.
			bonus[k] = float(bonus.get(k, 0.0)) + (v * mult if v > 0.0 else v)
	for uid in lo["mods"]:
		if int(uid) < 0:
			continue
		var m := find_item("modules", int(uid))
		if m.is_empty():
			continue
		var stat: String = GameData.MODULE_FAMILIES[m["family"]]["stat"]
		bonus[stat] += float(m["main"]) / 100.0
		for line in m["lines"]:
			var key: String = line["stat"]
			var v: float = float(line["value"]) / 100.0
			match key:
				"boost_cd":
					bonus["boost_cd"] -= v
				"hull_regen":
					bonus["hull_regen"] += v * 0.1
				_:
					if bonus.has(key):
						bonus[key] += v
	var hull_base := float(ship["hull"])
	var shield_base := hull_base * GameData.SHIELD_FROM_HULL
	var speed_base := float(ship["speed"])
	return {
		"name": ship["name"],
		"hull_base": hull_base, "hull": hull_base * (1.0 + bonus["hull"]),
		"shield_base": shield_base, "shield": shield_base * (1.0 + bonus["shield"]),
		"speed_base": speed_base, "speed": speed_base * (1.0 + bonus["speed"]),
		"dmg_base": float(ship["dmg"]), "dmg": float(ship["dmg"]) * (1.0 + bonus["dmg"]),
		"cargo": int(ship["cargo"]) * GameData.CARGO_UNIT,
		"recharge": 1.0 + bonus["recharge"],
		"recharge_delay": maxf(1.0, GameData.SHIELD_RECHARGE_DELAY * (1.0 - bonus["recharge_delay"])),
		"shield_regen": bonus["shield_regen"],
		"hull_regen": bonus["hull_regen"],
		"boost_cd": maxf(0.3, 1.0 + bonus["boost_cd"]),
		"accel": 1.0 + bonus["accel"],
		"turn": 1.0 + bonus["turn"],
		"crit": bonus["crit"],
		"elite_dmg": bonus["elite_dmg"],
		"bonus": bonus,
	}


## Lista de láseres equipados como diccionarios {id, level, def}.
func equipped_lasers(ship_id: String = "") -> Array:
	if ship_id == "":
		ship_id = data["current_ship"]
	var out: Array = []
	for uid in ensure_loadout(ship_id)["lasers"]:
		if int(uid) < 0:
			continue
		var it := find_item("lasers", int(uid))
		if not it.is_empty():
			out.append({"id": it["id"], "level": int(it["level"]), "def": GameData.LASERS[it["id"]]})
	return out


func equipped_drone_lasers() -> Array:
	var out: Array = []
	for uid in data["drone"]["lasers"]:
		if int(uid) < 0:
			continue
		var it := find_item("drone_lasers", int(uid))
		if not it.is_empty():
			out.append({"id": it["id"], "def": GameData.DRONE_LASERS[it["id"]]})
	return out


## Daño por andanada de un láser: la cadencia del GDD se convierte en daño por andanada (VOLLEY_INTERVAL).
static func laser_volley_damage(def: Dictionary, level: int) -> float:
	return GameData.LASER_BASE_DAMAGE * float(def["dmg"]) * float(def["rate"]) * GameData.component_mult(level) * GameData.VOLLEY_INTERVAL


## DPS teórico con munición x1 contra objetivo sin resistencias (para comparar builds).
func theoretical_dps(ship_id: String = "") -> float:
	var st := ship_stats(ship_id)
	var per_volley := 0.0
	for l in equipped_lasers(ship_id):
		per_volley += laser_volley_damage(l["def"], l["level"]) * int(l["def"]["shots"])
	return per_volley / GameData.VOLLEY_INTERVAL * float(st["dmg"])


# --- Resultado de incursión ---------------------------------------------------------
func apply_run_result(result: Dictionary) -> void:
	var loot: Dictionary = result.get("loot", {})
	add_loot(loot)
	for k in ["ammo", "items"]:
		var used: Dictionary = result.get(k + "_used", {})
		for id in used.keys():
			data[k][id] = maxi(0, int(data[k].get(id, 0)) - int(used[id]))
	var stats: Dictionary = data["stats"]
	stats["runs"] = int(stats["runs"]) + 1
	stats["kills"] = int(stats["kills"]) + int(result.get("kills", 0))
	stats["time"] = int(stats["time"]) + int(result.get("time", 0))
	stats["credits_earned"] = int(stats["credits_earned"]) + int(loot.get("credits", 0))
	var kb: Dictionary = result.get("kills_by", {})
	for id in kb.keys():
		data["kills_by"][id] = int(data["kills_by"].get(id, 0)) + int(kb[id])
	if result.get("outcome", "") == "death":
		stats["deaths"] = int(stats["deaths"]) + 1
	else:
		stats["extractions"] = int(stats["extractions"]) + 1
	var lvl := int(result.get("level", 1))
	if result.get("objective_done", false):
		if not data["sector_cleared"].has(lvl):
			data["sector_cleared"].append(lvl)
			var first_nexo := 5 + lvl / 2
			add_amount("nexo", first_nexo)
			result["first_clear_nexo"] = first_nexo
		data["sector_max"] = maxi(int(data["sector_max"]), lvl + 1)
	# La experiencia ya se fue sumando durante la incursión (ascensos en tiempo real).
	last_result = result
	save_game()
	changed.emit()
