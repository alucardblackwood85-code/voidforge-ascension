class_name PlaytestRunner
extends Node
## Playtest automático completo (godot -- --playtest). Usa una partida aparte (GameState.PLAYTEST_SAVE_PATH).
## Fase 1: economía y desbloqueos (compra/fabrica todo, cajas, módulos, mejoras, guardado).
## Fase 2: incursiones con bot en todos los biomas y niveles de equipo, con métricas.
## Fase 3: ritmo de progresión (horas por rango, por nave) calculado de las métricas.
## Escribe build/playtest_report.json y lo imprime entre PLAYTEST_JSON_BEGIN / PLAYTEST_JSON_END.

const SIM_LIMIT := 420.0   # segundos simulados máximos por incursión

var report := {"errors": [], "warnings": [], "economy": {}, "ships": [], "runs": [], "pacing": {}}
var _sector: Sector = null
var _done := false
var _frame_us: Array = []
var _last_us := 0
var _only := -1


func _ready() -> void:
	await get_tree().process_frame
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pt-only="):
			_only = int(a.get_slice("=", 1))
	_phase_economy()
	await _phase_combat()
	_phase_pacing()
	_write()
	get_tree().quit()


func err(msg: String) -> void:
	report["errors"].append(msg)
	print("PT|ERROR|", msg)


func warn(msg: String) -> void:
	report["warnings"].append(msg)
	print("PT|WARN|", msg)


# --- Fase 1: economía ------------------------------------------------------------------------
func _amounts() -> Dictionary:
	var d := {"credits": GameState.get_amount("credits"), "nexo": GameState.get_amount("nexo")}
	for m in GameData.MATERIALS.keys():
		d[m] = GameState.get_amount(m)
	return d


func _spent(before: Dictionary, after: Dictionary) -> Dictionary:
	var s := {}
	for k in before.keys():
		var dlt := int(before[k]) - int(after[k])
		if dlt != 0:
			s[k] = dlt
	return s


func _phase_economy() -> void:
	var eco: Dictionary = report["economy"]
	GameState.new_profile()
	var d: Dictionary = GameState.data
	eco["start"] = {"credits": d["credits"], "ammo": d["ammo"].duplicate(), "items": d["items"].duplicate(),
		"dps": GameState.theoretical_dps(), "ship": d["current_ship"]}
	# Precios de referencia (antes de conceder recursos).
	var prices := []
	for id in GameData.SHIPS.keys():
		prices.append({"ship": id, "credits": GameState.price_of("ship", id)["credits"], "nexo": GameState.price_of("ship", id, "nexo")["nexo"]})
	eco["ship_prices"] = prices
	# Recursos ilimitados para desbloquearlo todo.
	d["credits"] = 4000000000
	d["nexo"] = 20000000
	d["seals"] = 1000000
	for m in GameData.MATERIALS.keys():
		d["materials"][m] = 5000000
	# Naves: alternando créditos / Nexo / fabricación, comprobando que se cobra exactamente el precio.
	var i := 0
	for id in GameData.SHIPS.keys():
		if id == "kestrel_a1":
			continue
		var mode: String = ["credits", "nexo", "craft"][i % 3]
		var before := _amounts()
		var expected: Dictionary = GameState.recipe_of("ship", id) if mode == "craft" else GameState.price_of("ship", id, mode)
		var ok := GameState.craft("ship", id) if mode == "craft" else GameState.buy("ship", id, 1, mode)
		if not ok:
			err("No se pudo adquirir la nave %s (%s)" % [id, mode])
		elif _spent(before, _amounts()) != _int_dict(expected):
			err("Cobro incorrecto en nave %s (%s): esperado %s, cobrado %s" % [id, mode, expected, _spent(before, _amounts())])
		i += 1
	if GameState.buy("ship", "raptor_v2"):
		err("Se pudo comprar dos veces la misma nave")
	if GameState.data["ships"].size() != GameData.SHIPS.size():
		err("Naves en propiedad: %d de %d" % [GameState.data["ships"].size(), GameData.SHIPS.size()])
	# Láseres, generadores y láseres de pet: uno comprado y uno fabricado de cada.
	for pair in [["laser", GameData.LASERS], ["gen", GameData.GENERATORS], ["drone_laser", GameData.DRONE_LASERS]]:
		for id in pair[1].keys():
			if not GameState.buy(pair[0], id):
				err("No se pudo comprar %s %s" % [pair[0], id])
			if not GameState.craft(pair[0], id):
				err("No se pudo fabricar %s %s" % [pair[0], id])
	# Munición y consumibles.
	for id in GameData.AMMO.keys():
		var shop_ok := GameState.in_shop("ammo", id)
		var bought := GameState.buy("ammo", id, 10)
		if not shop_ok and bought:
			warn("La API permite comprar %s aunque la tienda no lo ofrece (sólo fabricable según el GDD)" % id)
		GameState.craft("ammo", id, 50)
	for id in GameData.ITEMS.keys():
		GameState.buy("item", id, 20)
		GameState.craft("item", id, 20)
	eco["inventory_after_unlock"] = {"lasers": GameState.data["lasers"].size(), "gens": GameState.data["gens"].size(),
		"drone_lasers": GameState.data["drone_lasers"].size(), "ammo": GameState.data["ammo"].duplicate(), "items": GameState.data["items"].duplicate()}
	# Cajas de módulos: distribución real frente a la publicada y protección de mala suerte.
	var boxes := {}
	for box_id in GameData.MODULE_BOXES.keys():
		var n := 400 if box_id == "estandar" else 150
		var dist := [0, 0, 0, 0, 0]
		var streak := 0
		var max_streak := 0
		for k in n:
			var m := GameState.open_box(box_id)
			if m.is_empty():
				err("No se pudo abrir la caja %s" % box_id)
				break
			var r := int(m["rarity"])
			dist[r] += 1
			streak = 0 if r >= 3 else streak + 1
			max_streak = maxi(max_streak, streak)
		boxes[box_id] = {"opened": n, "dist": dist, "max_no_relic_streak": max_streak}
		if max_streak >= GameData.PITY_RELIC:
			err("Pity roto en %s: %d cajas seguidas sin Reliquia (límite %d)" % [box_id, max_streak, GameData.PITY_RELIC])
	eco["boxes"] = boxes
	eco["modules_total"] = GameState.data["modules"].size()
	# Regla de color: dos módulos del mismo color en la misma nave.
	GameState.select_ship("titan_b1")
	var greens: Array = GameState.data["modules"].filter(func(m): return m["family"] == "verde")
	if greens.size() >= 2:
		GameState.equip("mods", 0, int(greens[0]["uid"]))
		GameState.equip("mods", 1, int(greens[1]["uid"]))
		var lo := GameState.current_loadout()
		if int(lo["mods"][0]) == int(greens[0]["uid"]) and int(lo["mods"][1]) == int(greens[1]["uid"]):
			err("Se pudieron equipar dos módulos verdes en la misma nave")
	# Mejoras 1-16 de un láser: coste total y tope.
	var target_l := GameState.add_laser("l01")
	var before_up := _amounts()
	for k in 16:
		if not GameState.upgrade_item("lasers", int(target_l["uid"])):
			err("Falló la mejora al nivel %d" % (k + 1))
	if GameState.upgrade_item("lasers", int(target_l["uid"])):
		err("Se pudo mejorar por encima del nivel 16")
	eco["upgrade_l01_to_16_cost"] = _spent(before_up, _amounts())
	# Guardado y carga.
	GameState.save_game()
	var n_ships: int = GameState.data["ships"].size()
	var n_mods: int = GameState.data["modules"].size()
	GameState.load_game()
	if GameState.data["ships"].size() != n_ships or GameState.data["modules"].size() != n_mods:
		err("El guardado/carga pierde datos (naves %d→%d, módulos %d→%d)" % [n_ships, GameState.data["ships"].size(), n_mods, GameState.data["modules"].size()])
	_ship_table()


func _int_dict(dd: Dictionary) -> Dictionary:
	var o := {}
	for k in dd.keys():
		o[k] = int(dd[k])
	return o


## Estadísticas de cada nave con equipo base (L-01 nv0) y con equipo máximo (L-18 nv16 + mejores módulos).
func _ship_table() -> void:
	for id in GameData.SHIPS.keys():
		_equip(id, "l01", 0, "sg_aegis1", 0, -1)
		var base := GameState.ship_stats(id)
		var base_dps := GameState.theoretical_dps(id)
		_equip(id, "l18", 16, "sg_fortress", 16, 4)
		var top := GameState.ship_stats(id)
		report["ships"].append({"id": id, "class": GameData.SHIPS[id]["class"], "hull": int(base["hull"]), "speed": int(base["speed"]),
			"dps_base": int(base_dps), "dps_max": int(GameState.theoretical_dps(id)), "hull_max": int(top["hull"]), "shield_max": int(top["shield"])})


## Equipa una nave: todos sus slots de láser con `laser` al nivel dado, generadores, y módulos de rareza `mod_r`.
func _equip(ship_id: String, laser: String, lvl: int, gen: String, gen_lvl: int, mod_r: int) -> void:
	if not GameState.data["ships"].has(ship_id):
		GameState.data["ships"].append(ship_id)
	GameState.select_ship(ship_id)
	var lo := GameState.ensure_loadout(ship_id)
	for i in lo["lasers"].size():
		var it := GameState.add_laser(laser)
		it["level"] = lvl
		lo["lasers"][i] = int(it["uid"])
	for i in lo["gens"].size():
		var gid := gen if i % 2 == 0 else ("vg_comet" if gen_lvl >= 10 else "vg_thrust1")
		var g := GameState.add_generator(gid)
		g["level"] = gen_lvl
		lo["gens"][i] = int(g["uid"])
	var fams := ["rojo", "verde", "azul", "amarillo"]
	for i in lo["mods"].size():
		if mod_r < 0:
			lo["mods"][i] = -1
			continue
		var m := GameState.roll_module(mod_r, fams[i % 4])
		GameState.data["modules"].append(m)
		lo["mods"][i] = int(m["uid"])


# --- Fase 2: incursiones con bot ---------------------------------------------------------------
const SCENARIOS := [
	{"name": "Jugador nuevo · Kestrel de serie", "ship": "kestrel_a1", "laser": "l01", "lvl": 0, "gen": "sg_aegis1", "glvl": 0, "mods": -1, "biome": "ferron", "level": 1, "stock": true},
	{"name": "Kestrel de serie · nivel 3", "ship": "kestrel_a1", "laser": "l01", "lvl": 0, "gen": "sg_aegis1", "glvl": 0, "mods": -1, "biome": "ferron", "level": 3, "stock": true},
	{"name": "Mule C1 (carguera) · nivel 2", "ship": "mule_c1", "laser": "l01", "lvl": 2, "gen": "sg_aegis1", "glvl": 2, "mods": -1, "biome": "ferron", "level": 2},
	{"name": "Raptor V2 · L-02 nv4 · nivel 6", "ship": "raptor_v2", "laser": "l02", "lvl": 4, "gen": "sg_aegis2", "glvl": 4, "mods": 0, "biome": "ferron", "level": 6},
	{"name": "Kestrel de serie en Vesper 8 (salto de bioma)", "ship": "kestrel_a1", "laser": "l01", "lvl": 0, "gen": "sg_aegis1", "glvl": 0, "mods": -1, "biome": "vesper", "level": 8, "stock": true},
	{"name": "Bulwark T1 · L-04 nv8 · Vesper 8", "ship": "bulwark_t1", "laser": "l04", "lvl": 8, "gen": "sg_bulwark", "glvl": 8, "mods": 1, "biome": "vesper", "level": 8},
	{"name": "Vanguard M · L-05 nv10 · Prismáticos 16", "ship": "vanguard_m", "laser": "l05", "lvl": 10, "gen": "sg_flux", "glvl": 10, "mods": 2, "biome": "prismaticos", "level": 16},
	{"name": "Centurion P · L-09 nv12 · Vacío 24", "ship": "centurion_p", "laser": "l09", "lvl": 12, "gen": "sg_quantum", "glvl": 12, "mods": 2, "biome": "vacio", "level": 24},
	{"name": "Titan B1 · L-10 nv14 · Leviatán 32", "ship": "titan_b1", "laser": "l10", "lvl": 14, "gen": "sg_fortress", "glvl": 14, "mods": 3, "biome": "leviatan", "level": 32},
	{"name": "Event Horizon · L-18 nv16 · Leviatán 40", "ship": "event_horizon", "laser": "l18", "lvl": 16, "gen": "sg_fortress", "glvl": 16, "mods": 4, "biome": "leviatan", "level": 40},
]


func _phase_combat() -> void:
	var seed_i := 100
	for sc in SCENARIOS:
		seed_i += 1
		if _only >= 0 and SCENARIOS.find(sc) != _only:
			continue
		if sc.get("stock", false):
			GameState.new_profile()
			GameState.data["ammo"]["mk1"] = 3000
		else:
			_equip(sc["ship"], sc["laser"], sc["lvl"], sc["gen"], sc["glvl"], sc["mods"])
			GameState.data["ammo"]["mk1"] = 100000
			GameState.data["ammo"]["mk2"] = 20000
			GameState.data["items"]["repair"] = 10
			GameState.data["items"]["shield_cell"] = 6
		GameState.data["sector_max"] = 99
		var xp_before := int(GameState.data["xp"])
		var t0 := Time.get_ticks_msec()
		_frame_us.clear()
		_done = false
		_sector = Sector.new()
		_sector.params = {"level": sc["level"], "biome": sc["biome"], "seed": seed_i, "bot": true}
		_sector.finished.connect(func(_r): _done = true)
		get_tree().root.add_child(_sector)
		_last_us = Time.get_ticks_usec()
		while not _done:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			_frame_us.append(now - _last_us)
			_last_us = now
			if _sector.elapsed >= SIM_LIMIT and not _sector.ended:
				_sector._finish("extract")
		var s := _sector
		var run := _run_metrics(sc, s, xp_before, Time.get_ticks_msec() - t0)
		report["runs"].append(run)
		print("PT|RUN|", JSON.stringify(run))
		s.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame


func _run_metrics(sc: Dictionary, s: Sector, xp_before: int, real_ms: int) -> Dictionary:
	var mins := maxf(s.elapsed / 60.0, 0.01)
	var mats := 0
	for k in s.loot.keys():
		if not (k in ["credits", "nexo", "seals"]):
			mats += int(s.loot[k])
	var ammo := 0
	for k in s.ammo_used.keys():
		ammo += int(s.ammo_used[k])
	var fr := _frame_us.duplicate()
	fr.sort()
	var avg := 0.0
	for x in fr:
		avg += x
	avg /= maxf(1.0, fr.size())
	var p95: float = float(fr[int(fr.size() * 0.95)]) if fr.size() > 0 else 0.0
	return {
		"name": sc["name"], "biome": sc["biome"], "level": sc["level"], "ship": s.player.ship_id, "objective": s.objective,
		"outcome": "death" if not s.player.alive else ("extract" if s.objective_done else "timeout"),
		"sim_s": int(s.elapsed), "kills": s.kills, "kills_min": snappedf(s.kills / mins, 0.1),
		"dmg_taken_min": int(s.stat_damage_taken / mins), "hull_end_pct": int(100.0 * s.player.hull / s.player.hull_max),
		"xp": int(GameState.data["xp"]) - xp_before, "xp_min": int((int(GameState.data["xp"]) - xp_before) / mins),
		"credits": int(s.loot.get("credits", 0)), "credits_min": int(s.loot.get("credits", 0) / mins), "nexo": int(s.loot.get("nexo", 0)),
		"materials": mats, "cargo_cap": s.cargo_capacity(), "cargo_full_s": int(s.stat_cargo_full_t), "objective_s": int(s.stat_objective_t),
		"ammo_used": ammo, "ammo_min": int(ammo / mins), "items_used": s.stat_items_used, "refined": s.stat_refined,
		"boxes_left": s.boxes.size(), "max_enemies": s.stat_max_enemies, "max_aggro": s.stat_max_aggro, "spawned": s.stat_spawned, "dps_theory": int(GameState.theoretical_dps()),
		"frame_ms_avg": snappedf(avg / 1000.0, 0.01), "frame_ms_p95": snappedf(p95 / 1000.0, 0.01), "real_s": snappedf(real_ms / 1000.0, 0.1),
	}


# --- Fase 3: ritmo de progresión ---------------------------------------------------------------
func _phase_pacing() -> void:
	var pace: Dictionary = report["pacing"]
	var runs: Array = report["runs"]
	if runs.is_empty():
		return
	var early: Dictionary = runs[0]
	var xp_h := float(early["xp_min"]) * 60.0
	var cr_h := float(early["credits_min"]) * 60.0
	pace["early_xp_per_hour"] = int(xp_h)
	pace["early_credits_per_hour"] = int(cr_h)
	# Horas hasta cada rango con el ritmo de cada fase (usa la incursión de equipo más cercano).
	var ranks := []
	for lvl in range(2, GameData.MAX_LEVEL + 1):
		var need := GameData.xp_for_level(lvl)
		var best_rate := 1.0
		for r in runs:
			best_rate = maxf(best_rate, float(r["xp_min"]) * 60.0)
		ranks.append({"level": lvl, "rank": GameData.RANKS[lvl - 1], "xp": need,
			"h_early": snappedf(need / maxf(1.0, xp_h), 0.1), "h_best": snappedf(need / best_rate, 0.1)})
	pace["ranks"] = ranks
	var ships := []
	for sp in report["economy"]["ship_prices"]:
		ships.append({"ship": sp["ship"], "credits": sp["credits"], "h_early": snappedf(float(sp["credits"]) / maxf(1.0, cr_h), 0.1)})
	pace["ships"] = ships


func _write() -> void:
	var txt := JSON.stringify(report, "  ")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var f := FileAccess.open(ProjectSettings.globalize_path("res://build/playtest_report.json"), FileAccess.WRITE)
	f.store_string(txt)
	print("PLAYTEST_JSON_BEGIN")
	print(JSON.stringify(report))
	print("PLAYTEST_JSON_END")
