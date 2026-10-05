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
var _only: Array = []
var _out := "res://build/playtest_report.json"


func _ready() -> void:
	await get_tree().process_frame
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pt-only="):
			for x in a.get_slice("=", 1).split(","):
				_only.append(int(x))
		if a.begins_with("--pt-out="):
			_out = a.get_slice("=", 1)
	_phase_economy()
	_phase_features()
	await _phase_combat()
	_phase_pacing()
	_write()
	# Suelta la música y deja que el servidor de audio libere sus reproducciones antes de cerrar.
	Music.stop_all()
	for i in 3:
		await get_tree().process_frame
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
	# El pet se compra una sola vez (no viene de inicio).
	if GameState.data["unlocks"].get("pet", false):
		err("El pet viene desbloqueado sin comprarlo")
	if not GameState.buy("pet", "pet"):
		err("No se pudo comprar el pet")
	elif GameState.buy("pet", "pet"):
		err("Se pudo comprar dos veces el pet")
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
	# Mejoras de un láser hasta el máximo: coste total y tope.
	var target_l := GameState.add_laser("l01")
	var before_up := _amounts()
	for k in GameData.LASER_MAX_LEVEL:
		if not GameState.upgrade_item("lasers", int(target_l["uid"])):
			err("Falló la mejora al nivel %d" % (k + 1))
	if GameState.upgrade_item("lasers", int(target_l["uid"])):
		err("Se pudo mejorar por encima del nivel %d" % GameData.LASER_MAX_LEVEL)
	eco["upgrade_l01_to_max_cost"] = _spent(before_up, _amounts())
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
		var gid := gen if i % 2 == 0 or i >= int(GameData.SHIPS[ship_id]["gens"]) else ("vg_comet" if gen_lvl >= 10 else "vg_thrust1")
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
	{"name": "Kestrel de serie · nidos nivel 4", "ship": "kestrel_a1", "laser": "l01", "lvl": 0, "gen": "sg_aegis1", "glvl": 0, "mods": -1, "biome": "ferron", "level": 4, "stock": true, "objective": "nidos"},
	{"name": "Mule C1 (carguera) · nivel 2", "ship": "mule_c1", "laser": "l01", "lvl": 2, "gen": "sg_aegis1", "glvl": 2, "mods": -1, "biome": "ferron", "level": 2},
	{"name": "Raptor V2 · L-02 nv4 · Forja 6", "ship": "raptor_v2", "laser": "l02", "lvl": 4, "gen": "sg_aegis2", "glvl": 4, "mods": 0, "biome": "ferron_forja", "level": 6},
	{"name": "Kestrel de serie en Vesper 9 (salto de bioma)", "ship": "kestrel_a1", "laser": "l01", "lvl": 0, "gen": "sg_aegis1", "glvl": 0, "mods": -1, "biome": "vesper", "level": 9, "stock": true},
	{"name": "Bulwark T1 · L-04 nv8 · Vesper 10", "ship": "bulwark_t1", "laser": "l04", "lvl": 8, "gen": "sg_bulwark", "glvl": 8, "mods": 1, "biome": "vesper", "level": 10, "objective": "baliza"},
	{"name": "Vanguard M · L-05 nv10 · Prismáticos 17", "ship": "vanguard_m", "laser": "l05", "lvl": 10, "gen": "sg_flux", "glvl": 10, "mods": 2, "biome": "prismaticos", "level": 17, "objective": "baliza"},
	{"name": "Centurion P · L-09 nv12 · Catedral 24", "ship": "centurion_p", "laser": "l09", "lvl": 12, "gen": "sg_quantum", "glvl": 12, "mods": 2, "biome": "prismaticos_catedral", "level": 24},
	{"name": "Titan B1 · L-10 nv14 · Abismo 32", "ship": "titan_b1", "laser": "l10", "lvl": 14, "gen": "sg_fortress", "glvl": 14, "mods": 3, "biome": "vacio_abismo", "level": 32},
	{"name": "Event Horizon · L-18 nv16 · Corazón Leviatán 40", "ship": "event_horizon", "laser": "l18", "lvl": 16, "gen": "sg_fortress", "glvl": 16, "mods": 4, "biome": "leviatan_corazon", "level": 40, "objective": "escolta"},
	{"name": "Objetivo balizas · Raptor V2 L-02 nv6 · Forja 5", "ship": "raptor_v2", "laser": "l02", "lvl": 6, "gen": "sg_aegis2", "glvl": 6, "mods": 0, "biome": "ferron_forja", "level": 5, "objective": "baliza"},
	{"name": "Objetivo socorro · Raptor V2 L-02 nv6 · Forja 5", "ship": "raptor_v2", "laser": "l02", "lvl": 6, "gen": "sg_aegis2", "glvl": 6, "mods": 0, "biome": "ferron_forja", "level": 5, "objective": "socorro"},
	{"name": "Objetivo escolta · Raptor V2 L-02 nv6 · Forja 5", "ship": "raptor_v2", "laser": "l02", "lvl": 6, "gen": "sg_aegis2", "glvl": 6, "mods": 0, "biome": "ferron_forja", "level": 5, "objective": "escolta"},
	{"name": "Objetivo comandante · Raptor V2 L-02 nv6 · Forja 5", "ship": "raptor_v2", "laser": "l02", "lvl": 6, "gen": "sg_aegis2", "glvl": 6, "mods": 0, "biome": "ferron_forja", "level": 5, "objective": "comandante"},
	{"name": "Variantes · Vanguard M L-05 nv10 · Cinturón Ferron 20", "ship": "vanguard_m", "laser": "l05", "lvl": 10, "gen": "sg_flux", "glvl": 10, "mods": 2, "biome": "ferron", "level": 20, "objective": "limpieza"},
]


func _phase_combat() -> void:
	var seed_i := 100
	for sc in SCENARIOS:
		seed_i += 1
		if not _only.is_empty() and not _only.has(SCENARIOS.find(sc)):
			continue
		if sc.get("stock", false):
			GameState.new_profile()
			GameState.data["ammo"]["mk1"] = 3000
		else:
			_equip(sc["ship"], sc["laser"], sc["lvl"], sc["gen"], sc["glvl"], sc["mods"])
			GameState.data["ammo"]["mk1"] = 100000
			GameState.data["ammo"]["mk2"] = 20000
			GameState.data["missiles"] = {"r1": 200, "r2": 200, "r3": 100}
			GameState.data["items"]["repair"] = 10
			GameState.data["items"]["shield_cell"] = 6
		GameState.data["sector_max"] = 99
		var xp_before := int(GameState.data["xp"])
		_biome = sc["biome"]
		var t0 := Time.get_ticks_msec()
		_frame_us.clear()
		_done = false
		_sector = Sector.new()
		_sector.params = {"level": sc["level"], "biome": sc["biome"], "seed": seed_i, "bot": true}
		if sc.has("objective"):
			_sector.params["objective"] = sc["objective"]
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
	# Gasto de la incursión al coste de fabricarlo (créditos + materiales a su valor), para medir el neto.
	var spent := 0.0
	for k in s.ammo_used.keys():
		spent += _recipe_value(GameData.AMMO[k]["recipe"]) * int(s.ammo_used[k]) / 100.0
	for k in s.missiles_used.keys():
		spent += _recipe_value(GameData.MISSILES[k]["recipe"]) * int(s.missiles_used[k])
	for k in s.items_used.keys():
		spent += _recipe_value(GameData.ITEMS[k]["recipe"]) * int(s.items_used[k])
	return {
		"spent": int(spent), "net_credits_min": int((int(s.loot.get("credits", 0)) - spent) / mins), "ammo_by": s.ammo_used.duplicate(),
		"name": sc["name"], "biome": sc["biome"], "level": sc["level"], "ship": s.player.ship_id, "objective": s.objective,
		"outcome": "death" if not s.player.alive else ("extract" if s.ended and s.elapsed < SIM_LIMIT - 1.0 else "timeout"),
		"sim_s": int(s.elapsed), "kills": s.kills, "kills_min": snappedf(s.kills / mins, 0.1),
		"dmg_taken_min": int(s.stat_damage_taken / mins), "hull_end_pct": int(100.0 * s.player.hull / s.player.hull_max),
		"xp": int(GameState.data["xp"]) - xp_before, "xp_min": int((int(GameState.data["xp"]) - xp_before) / mins),
		"credits": int(s.loot.get("credits", 0)), "credits_min": int(s.loot.get("credits", 0) / mins), "nexo": int(s.loot.get("nexo", 0)),
		"materials": mats, "cargo_cap": s.cargo_capacity(), "cargo_full_s": int(s.stat_cargo_full_t), "objective_s": int(s.stat_objective_t),
		"ammo_used": ammo, "ammo_min": int(ammo / mins), "items_used": s.stat_items_used, "refined": s.stat_refined,
		"boxes_left": s.boxes.size(), "max_enemies": s.stat_max_enemies, "max_aggro": s.stat_max_aggro, "max_engaged": s.stat_max_engaged, "stuck_s": int(s.stat_stuck_s), "variants": s.stat_variants, "missiles": s.stat_missiles, "missile_hits": s.stat_missile_hits, "spawned": s.stat_spawned, "dps_theory": int(GameState.theoretical_dps()),
		"boss": "muerto" if s.boss_dead else ("%d%%" % int(100.0 * s.boss.hp / s.boss.hp_max) if is_instance_valid(s.boss) else "-"),
		"obj_progress": "%d/%d" % [s.objective_progress, s.objective_target], "clear_pct": s._clear_percent(),
		"dmg_by": s.dmg_by, "pois": s.run_pois, "events": s.run_events, "boxes": s.run_boxes, "elites": s.run_elites, "legendary": s.run_legendary,
		"power_pct": int(100.0 * _power() / _rec_power(int(sc["level"]))),
		"frame_ms_avg": snappedf(avg / 1000.0, 0.01), "frame_ms_p95": snappedf(p95 / 1000.0, 0.01), "real_s": snappedf(real_ms / 1000.0, 0.1),
	}


func _recipe_value(rec: Dictionary) -> float:
	var v := float(rec.get("credits", 0))
	for k in rec.keys():
		if GameData.MATERIALS.has(k):
			v += GameData.MAT_VALUE[int(GameData.MATERIALS[k]["rarity"])] * float(rec[k])
	return v


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
	pace["pet_h_to_12"] = snappedf(GameData.pet_xp_for_level(GameData.PET_MAX_LEVEL) / maxf(1.0, xp_h * GameData.PET_XP_SHARE), 0.1)
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
	var f := FileAccess.open(ProjectSettings.globalize_path(_out), FileAccess.WRITE)
	f.store_string(txt)
	print("PLAYTEST_JSON_BEGIN")
	print(JSON.stringify(report))
	print("PLAYTEST_JSON_END")


# --- Fase 1b: funciones de progresión (misiones, temporada, logros, copia, Ascensión) ----------
func _phase_features() -> void:
	var feat := {}
	GameState.new_profile()
	Prog.ensure()
	var m: Dictionary = GameState.data["missions"]
	if m["daily"].size() != 3 or m["weekly"].size() != 3:
		err("Misiones: se esperaban 3 diarias y 3 semanales (%d/%d)" % [m["daily"].size(), m["weekly"].size()])
	for mi in m["daily"]:
		if mi["type"] == "boss":
			err("Misión diaria de jefe con sector máximo 1 (no hay jefes hasta el nivel 4)")
	# Incursión simulada que completa todo lo posible.
	var fake := {"outcome": "extract", "level": 5, "loot": {"credits": 5000}, "kills": 400, "kills_by": {"chatarrax": 120},
		"objective_done": true, "time": 300, "xp": 1000, "biome": "ferron", "elites": 50, "boss_killed": true,
		"boxes": 60, "pois": 10, "events": 3, "legendary": 1, "modules": [], "asc": 0}
	var nexo0 := int(GameState.data["nexo"])
	GameState.apply_run_result(fake.duplicate(true))
	GameState.apply_run_result(fake.duplicate(true))
	var claimed := 0
	for i in 3:
		if Prog.claim_mission(false, i):
			claimed += 1
	feat["daily_claimable_after_big_run"] = claimed
	feat["streak_after_claims"] = int(m["streak"])
	if claimed == 3 and int(m["streak"]) != 1:
		err("Racha: al reclamar las 3 diarias debería pasar a 1 (está en %d)" % int(m["streak"]))
	if Prog.claim_mission(false, 0):
		err("Misiones: se pudo reclamar dos veces la misma misión")
	feat["achievements"] = GameState.data["achievements"].size()
	feat["nexo_gained"] = int(GameState.data["nexo"]) - nexo0
	feat["mastery"] = Prog.has_mastery("chatarrax")
	if not Prog.has_mastery("chatarrax"):
		err("Maestría: 120 bajas de chatarrax no dan maestría")
	feat["season_tier"] = Prog.season_tier()
	var got := Prog.claim_season()
	feat["season_claimed"] = got.size()
	if Prog.season_tier() > 0 and got.is_empty():
		err("Temporada: niveles alcanzados sin poder reclamar")
	# Copia de seguridad
	var code := GameState.export_code()
	var xp_before := int(GameState.data["xp"])
	GameState.data["xp"] = 0
	if not GameState.import_code(code) or int(GameState.data["xp"]) != xp_before:
		err("Copia de seguridad: importar el código exportado no restaura la partida")
	if GameState.import_code("basura"):
		err("Copia de seguridad: acepta un código no válido")
	feat["export_len"] = code.length()
	# Ascensión: limpiar el nivel 50 la desbloquea
	GameState.apply_run_result({"outcome": "extract", "level": 50, "objective_done": true, "loot": {}, "asc": 0})
	feat["asc_max_after_50"] = int(GameState.data["asc_max"])
	if int(GameState.data["asc_max"]) != 1:
		err("Ascensión: limpiar el nivel 50 no la desbloquea")
	# Bloqueo de módulos antes del nivel 5
	GameState.new_profile()
	var mod := GameState.roll_module(1)
	GameState.data["modules"].append(mod)
	GameState.equip("mods", 0, int(mod["uid"]))
	if int(GameState.current_loadout()["mods"][0]) >= 0:
		err("Módulos: se pueden equipar antes del nivel 5")
	feat["pet_unlocked_new_profile"] = GameState.data["unlocks"]["pet"]
	# Pet: horas hasta el nivel 12 con el ritmo de XP de la primera incursión (se rellena al final)
	feat["pet_xp_to_12"] = GameData.pet_xp_for_level(GameData.PET_MAX_LEVEL)
	report["features"] = feat
	print("PT|FEAT|", JSON.stringify(feat))


## Mismas fórmulas que el mapa estelar (poder propio y recomendado).
func _power() -> float:
	var st := GameState.ship_stats()
	var dps := maxf(1.0, GameState.theoretical_dps())
	return GameData.power_index(float(st["hull"]) + float(st["shield"]), dps)


var _biome := "ferron"


func _rec_power(level: int) -> float:
	return GameData.recommended_power(level, _biome)
