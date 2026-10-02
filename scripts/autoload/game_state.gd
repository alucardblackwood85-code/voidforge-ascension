extends Node
## Perfil persistente del jugador: monedas, inventario, loadouts y progreso.
## Prototipo: guardado local en user://. El GDD exige servidor autoritativo en producción (20.2).

signal changed

const SAVE_PATH := "user://voidforge_save.json"
const SAVE_VERSION := 1
const HOTBAR_SIZE := 10

var data: Dictionary = {}
## Parámetros de la siguiente incursión elegidos en el mapa estelar.
var pending_sector: Dictionary = {}
## Resultado de la última incursión, para mostrarlo en el hangar.
var last_result: Dictionary = {}


func _ready() -> void:
	load_game()


func new_profile() -> Dictionary:
	var p := {
		"version": SAVE_VERSION,
		"next_uid": 1,
		"credits": 5000,
		"nexo": 0,
		"seals": 0,
		"materials": {"ferrita": 40, "plata": 30, "nanoespuma": 12, "resina_plasma": 8},
		"ammo": {"mk1": 2500, "mk2": 300},
		"items": {"repair": 3, "boost": 2, "mine": 0, "shield_cell": 0},
		"ships": ["kestrel_a1"],
		"current_ship": "kestrel_a1",
		"lasers": [],
		"gens": [],
		"loadouts": {},
		"sector_max": 1,
		"sector_cleared": [],
		"stats": {"kills": 0, "runs": 0, "deaths": 0, "extractions": 0},
		"settings": {"auto_fire_touch": true, "wasd": true},
	}
	data = p
	for i in 3:
		add_laser("l01")
	add_generator("sg_aegis1")
	add_generator("vg_thrust1")
	var lo := ensure_loadout("kestrel_a1")
	for i in 3:
		lo["lasers"][i] = data["lasers"][i]["uid"]
	lo["gens"][0] = data["gens"][0]["uid"]
	lo["gens"][1] = data["gens"][1]["uid"]
	lo["hotbar"] = default_hotbar()
	return p


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
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", 0)) != SAVE_VERSION:
		new_profile()
		save_game()
		return
	data = parsed
	_fix_json_types()


## JSON convierte enteros en float; los normalizamos.
func _fix_json_types() -> void:
	data["next_uid"] = int(data["next_uid"])
	for k in ["credits", "nexo", "seals", "sector_max"]:
		data[k] = int(data[k])
	for dict_key in ["materials", "ammo", "items", "stats"]:
		var d: Dictionary = data[dict_key]
		for k in d.keys():
			d[k] = int(d[k])
	for list_key in ["lasers", "gens"]:
		for it in data[list_key]:
			it["uid"] = int(it["uid"])
			it["level"] = int(it["level"])
	for lo in data["loadouts"].values():
		for list_key in ["lasers", "gens"]:
			var arr: Array = lo[list_key]
			for i in arr.size():
				arr[i] = int(arr[i])
	var cleared: Array = data["sector_cleared"]
	for i in cleared.size():
		cleared[i] = int(cleared[i])


func reset_profile() -> void:
	new_profile()
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


func find_item(list_key: String, uid: int) -> Dictionary:
	for it in data[list_key]:
		if int(it["uid"]) == uid:
			return it
	return {}


## Devuelve el id de nave donde está equipado el objeto, o "".
func equipped_on(list_key: String, uid: int) -> String:
	for ship_id in data["loadouts"].keys():
		if data["loadouts"][ship_id][list_key].has(uid):
			return ship_id
	return ""


func ensure_loadout(ship_id: String) -> Dictionary:
	var ship: Dictionary = GameData.SHIPS[ship_id]
	if not data["loadouts"].has(ship_id):
		var lasers: Array = []
		lasers.resize(int(ship["lasers"]))
		lasers.fill(-1)
		var gens: Array = []
		gens.resize(int(ship["gens"]))
		gens.fill(-1)
		data["loadouts"][ship_id] = {"lasers": lasers, "gens": gens, "hotbar": default_hotbar()}
	var lo: Dictionary = data["loadouts"][ship_id]
	var hb: Array = lo["hotbar"]
	if hb.size() != HOTBAR_SIZE:
		hb.resize(HOTBAR_SIZE)
	return lo


func current_loadout() -> Dictionary:
	return ensure_loadout(data["current_ship"])


## Equipa (o desequipa con uid = -1) en un slot; si el objeto estaba en otra nave/slot lo libera.
func equip(list_key: String, slot: int, uid: int) -> void:
	if uid >= 0:
		for lo in data["loadouts"].values():
			var arr: Array = lo[list_key]
			var idx := arr.find(uid)
			if idx >= 0:
				arr[idx] = -1
	current_loadout()[list_key][slot] = uid
	changed.emit()


func set_hotbar(slot: int, entry) -> void:
	current_loadout()["hotbar"][slot] = entry
	changed.emit()


func buy_ship(ship_id: String) -> bool:
	if data["ships"].has(ship_id):
		return false
	if not pay(GameData.SHIPS[ship_id]["cost"]):
		return false
	data["ships"].append(ship_id)
	ensure_loadout(ship_id)
	save_game()
	changed.emit()
	return true


func select_ship(ship_id: String) -> void:
	if data["ships"].has(ship_id):
		data["current_ship"] = ship_id
		ensure_loadout(ship_id)
		save_game()
		changed.emit()


func buy_laser(id: String) -> bool:
	if not pay(GameData.LASERS[id]["cost"]):
		return false
	add_laser(id)
	save_game()
	changed.emit()
	return true


func buy_generator(id: String) -> bool:
	if not pay(GameData.GENERATORS[id]["cost"]):
		return false
	add_generator(id)
	save_game()
	changed.emit()
	return true


func craft_ammo(id: String, batches: int) -> bool:
	if not pay(GameData.AMMO[id]["recipe"], batches):
		return false
	data["ammo"][id] = int(data["ammo"].get(id, 0)) + 100 * batches
	save_game()
	changed.emit()
	return true


func craft_item(id: String, qty: int) -> bool:
	if not pay(GameData.ITEMS[id]["recipe"], qty):
		return false
	data["items"][id] = int(data["items"].get(id, 0)) + qty
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


# --- Estadísticas calculadas -----------------------------------------------------------
## Estadísticas finales de una nave con su loadout (base, bonos y total por separado: 17.2).
func ship_stats(ship_id: String = "") -> Dictionary:
	if ship_id == "":
		ship_id = data["current_ship"]
	var ship: Dictionary = GameData.SHIPS[ship_id]
	var lo := ensure_loadout(ship_id)
	var bonus := {"hull": 0.0, "shield": 0.0, "speed": 0.0, "recharge": 0.0, "shield_regen": 0.0, "boost_cd": 0.0, "accel": 0.0, "turn": 0.0}
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
	var hull_base := float(ship["hull"])
	var shield_base := hull_base * GameData.SHIELD_FROM_HULL
	var speed_base := float(ship["speed"])
	return {
		"name": ship["name"],
		"hull_base": hull_base, "hull": hull_base * (1.0 + bonus["hull"]),
		"shield_base": shield_base, "shield": shield_base * (1.0 + bonus["shield"]),
		"speed_base": speed_base, "speed": speed_base * (1.0 + bonus["speed"]),
		"dmg": float(ship["dmg"]),
		"cargo": int(ship["cargo"]) * GameData.CARGO_UNIT,
		"recharge": 1.0 + bonus["recharge"],
		"shield_regen": bonus["shield_regen"],
		"boost_cd": 1.0 + bonus["boost_cd"],
		"accel": 1.0 + bonus["accel"],
		"turn": 1.0 + bonus["turn"],
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


## DPS teórico con munición x1 contra objetivo sin resistencias (para comparar builds).
func theoretical_dps(ship_id: String = "") -> float:
	var st := ship_stats(ship_id)
	var dps := 0.0
	for l in equipped_lasers(ship_id):
		var d: Dictionary = l["def"]
		dps += GameData.LASER_BASE_DAMAGE * float(d["dmg"]) * int(d["shots"]) * float(d["rate"]) * GameData.component_mult(l["level"])
	return dps * float(st["dmg"])


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
	last_result = result
	save_game()
	changed.emit()
