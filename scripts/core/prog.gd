class_name Prog
extends RefCounted
## Progresión de largo plazo: misiones diarias y semanales con racha (M4), logros y maestría
## del códex (M13), modificador semanal y temporada de 8 semanas con 40 niveles (M18), y
## registros de pecios (lore, M19). Todo vive en GameState.data y se actualiza al terminar
## cada incursión con on_run(result).

const DAY := 86400
const MASTERY_KILLS := 100          # bajas de una especie para su maestría
const MASTERY_DMG := 0.02           # +2% de daño contra esa especie
const SEASON_WEEKS := 8
const SEASON_TIERS := 40
const SEASON_TIER_PTS := 250
const STREAK_BONUS := 0.1           # +10% de recompensa de misiones por día de racha (máx. +50%)

# --- Misiones (M4) --------------------------------------------------------------------------
## type: clave del contador que hace avanzar la misión; base: objetivo diario (las semanales x6).
const MISSION_TYPES := {
	"kills": {"text": "Elimina %s enemigos", "base": 60},
	"faction": {"text": "Elimina %s enemigos de la facción %s", "base": 30},
	"extract": {"text": "Extrae con éxito %s veces", "one": "Extrae con éxito una vez", "base": 2},
	"objective": {"text": "Completa %s objetivos de sector", "one": "Completa un objetivo de sector", "base": 2},
	"elites": {"text": "Derrota %s élites", "base": 6},
	"boss": {"text": "Derrota %s jefes de sector", "one": "Derrota a un jefe de sector", "base": 1},
	"boxes": {"text": "Recoge %s cajas de botín", "base": 25},
	"pois": {"text": "Explora %s puntos de interés", "base": 3},
	"events": {"text": "Supera %s eventos de sector", "one": "Supera un evento de sector (lluvia de meteoritos o convoy)", "base": 1},
}

# --- Modificador semanal (M18) --------------------------------------------------------------
const WEEKLY_MODS := [
	{"id": "cosecha", "name": "Semana de cosecha", "desc": "+50% de materiales en las cajas.", "mats": 1.5},
	{"id": "invasion", "name": "Invasión", "desc": "+30% de enemigos y +30% de experiencia.", "spawn": 1.3, "xp": 1.3},
	{"id": "tormenta", "name": "Tormenta iónica", "desc": "Los enemigos llevan +50% de escudo; +40% de créditos.", "shield": 1.5, "credits": 1.4},
	{"id": "fiebre", "name": "Fiebre del Nexo", "desc": "Doble probabilidad de Cristales Nexo.", "nexo": 2.0},
	{"id": "cazadores", "name": "Temporada de caza", "desc": "Élites el doble de frecuentes y +25% de recompensa por élite.", "elites": 2.0},
	{"id": "calma", "name": "Calma solar", "desc": "Los enemigos infligen un 15% menos de daño.", "enemy_dmg": 0.85},
]

# --- Logros (M13) ---------------------------------------------------------------------------
## stat: contador que se compara con n. Recompensa en Nexo.
const ACHIEVEMENTS := [
	{"id": "kills_1", "name": "Primera sangre", "desc": "Elimina a tu primer enemigo.", "stat": "kills", "n": 1, "nexo": 5},
	{"id": "kills_500", "name": "Exterminador", "desc": "Elimina 500 enemigos.", "stat": "kills", "n": 500, "nexo": 20},
	{"id": "kills_5000", "name": "Azote alienígena", "desc": "Elimina 5000 enemigos.", "stat": "kills", "n": 5000, "nexo": 60},
	{"id": "kills_50000", "name": "Leyenda del vacío", "desc": "Elimina 50 000 enemigos.", "stat": "kills", "n": 50000, "nexo": 200},
	{"id": "extract_1", "name": "De vuelta a casa", "desc": "Extrae por primera vez.", "stat": "extractions", "n": 1, "nexo": 5},
	{"id": "extract_50", "name": "Contrabandista", "desc": "Extrae 50 veces.", "stat": "extractions", "n": 50, "nexo": 40},
	{"id": "boss_1", "name": "Matagigantes", "desc": "Derrota a un jefe de sector.", "stat": "boss_kills", "n": 1, "nexo": 15},
	{"id": "boss_25", "name": "Cazador de jefes", "desc": "Derrota 25 jefes de sector.", "stat": "boss_kills", "n": 25, "nexo": 80},
	{"id": "elites_100", "name": "Sin miedo", "desc": "Derrota 100 élites.", "stat": "elites", "n": 100, "nexo": 30},
	{"id": "sector_10", "name": "Explorador", "desc": "Desbloquea el sector de nivel 10.", "stat": "sector_max", "n": 10, "nexo": 20},
	{"id": "sector_25", "name": "Pionero", "desc": "Desbloquea el sector de nivel 25.", "stat": "sector_max", "n": 25, "nexo": 50},
	{"id": "sector_51", "name": "Más allá del límite", "desc": "Limpia el nivel 50.", "stat": "sector_max", "n": 51, "nexo": 150},
	{"id": "asc_1", "name": "Ascendido", "desc": "Desbloquea la Ascensión 1.", "stat": "asc_max", "n": 1, "nexo": 100},
	{"id": "rank_5", "name": "Cabo Primero", "desc": "Alcanza el nivel 5.", "stat": "level", "n": 5, "nexo": 20},
	{"id": "rank_10", "name": "Oficial", "desc": "Alcanza el nivel 10.", "stat": "level", "n": 10, "nexo": 60},
	{"id": "legendary_1", "name": "Premio gordo", "desc": "Abre una caja legendaria.", "stat": "legendary", "n": 1, "nexo": 15},
	{"id": "pois_20", "name": "Curioso", "desc": "Explora 20 puntos de interés.", "stat": "pois", "n": 20, "nexo": 20},
	{"id": "lore_all", "name": "Archivista", "desc": "Recupera todos los registros de pecios.", "stat": "lore", "n": 12, "nexo": 80},
	{"id": "mastery_1", "name": "Especialista", "desc": "Consigue la maestría de una especie.", "stat": "mastery", "n": 1, "nexo": 15},
	{"id": "mastery_25", "name": "Xenobiólogo", "desc": "Consigue la maestría de 25 especies.", "stat": "mastery", "n": 25, "nexo": 100},
	{"id": "missions_30", "name": "Disciplinado", "desc": "Completa 30 misiones.", "stat": "missions_done", "n": 30, "nexo": 40},
	{"id": "streak_7", "name": "Constancia", "desc": "Mantén una racha de 7 días de misiones.", "stat": "streak", "n": 7, "nexo": 50},
]

# --- Registros de pecios (M19) --------------------------------------------------------------
const LORE := [
	"Registro de la Aurelia: «El portal se abrió sin aviso. Los sensores marcaban metal vivo al otro lado.»",
	"Diario de minero: «La ferrita canta cuando la cortas. Nadie en la estación quiere hablar de ello.»",
	"Informe táctico 7-B: «Los Ferron no huyen; se reagrupan. Atacad siempre al más grande primero.»",
	"Mensaje sin cifrar: «Si alguien recibe esto, no sigáis la luz verde de Vesper. Respira.»",
	"Bitácora de la Cosechadora II: «Las esporas cubrieron el casco en minutos. El escudo no las detuvo.»",
	"Fragmento cristalino: una melodía grabada en el propio cristal, idéntica a la de los Prismáticos.",
	"Nota del ingeniero jefe: «La munición de alto grado atraviesa su blindaje. La barata sólo les hace cosquillas.»",
	"Registro de evacuación: «El Vacío no tiene fondo. Las sondas siguen cayendo, y siguen transmitiendo.»",
	"Último mensaje del Centinela: «Algo enorme se mueve bajo los arrecifes. Tiene nuestro rumbo.»",
	"Archivo del Consejo: «La Ascensión no es un rango. Es lo que queda cuando el sector deja de tener techo.»",
	"Diario personal: «Mi pet aprendió a interceptar disparos. Creo que me ha salvado la vida tres veces hoy.»",
	"Registro final, sin firma: «El Nexo no es un cristal. Es una puerta. Y alguien llama desde dentro.»",
]


# --- Tiempo -----------------------------------------------------------------------------------
static func now() -> int:
	return int(Time.get_unix_time_from_system())


static func day_index() -> int:
	return now() / DAY


static func week_index() -> int:
	# Semanas que empiezan en lunes (el 1/1/1970 fue jueves: +3 días).
	return (day_index() + 3) / 7


static func weekly_mod() -> Dictionary:
	return WEEKLY_MODS[week_index() % WEEKLY_MODS.size()]


static func mod_value(key: String, default: float = 1.0) -> float:
	return float(weekly_mod().get(key, default))


static func season_index() -> int:
	return week_index() / SEASON_WEEKS


static func season_week() -> int:
	return week_index() % SEASON_WEEKS + 1


static func season_days_left() -> int:
	return (SEASON_WEEKS - season_week()) * 7 + (7 - (day_index() + 3) % 7)


static func time_to_next_day() -> int:
	return DAY - now() % DAY


# --- Estado -----------------------------------------------------------------------------------
# --- Entrenamiento: los primeros pasos guiados (GDD 21.1) --------------------------------------
# Siete pasos en orden, cada uno con su recompensa; se ven en el Hangar hasta reclamarlos todos.
const TRAINING := [
	{"id": "extract", "name": "Primera incursión", "desc": "Cumple el objetivo de un sector y extrae por el portal.", "reward": {"credits": 3000}},
	{"id": "upgrade", "name": "Mejora un láser", "desc": "En Crafteo → Mejoras 1-16, sube un láser al nivel 1 (la recompensa anterior lo paga).", "reward": {"credits": 5000}},
	{"id": "mk2", "name": "Munición fuerte", "desc": "Usa munición Mk-II (tecla 2) contra un enemigo duro durante una incursión.", "reward": {"mk2": 500}},
	{"id": "gens", "name": "Generadores", "desc": "Compra un generador en la Tienda y llena los 3 espacios de generador de tu Kestrel.", "reward": {"credits": 4000}},
	{"id": "pet", "name": "Tu pet", "desc": "Compra un pet en la Tienda → Pet y elige su rol en Equipamiento → Pet.", "reward": {"pet_laser": "pet_stinger"}},
	{"id": "module", "name": "Primer módulo", "desc": "Al llegar al rango Cabo Primero se abren los módulos: fabrica y abre tu primera caja.", "reward": {"nexo": 10}},
	{"id": "forja", "name": "Forja Ferron", "desc": "Alcanza el nivel de amenaza 5 para abrir la Forja Ferron y sus especies fuertes.", "reward": {"credits": 10000, "nexo": 15}},
]


## ¿Se cumple el paso `id` del entrenamiento?
static func training_done(id: String) -> bool:
	var d: Dictionary = GameState.data
	match id:
		"extract":
			return int(d["stats"].get("extractions", 0)) >= 1
		"upgrade":
			for it in d["lasers"]:
				if int(it["level"]) >= 1:
					return true
			return false
		"mk2":
			return d.get("used_mk2", false)
		"gens":
			var gens: Array = GameState.ensure_loadout(d["current_ship"])["gens"]
			return gens.filter(func(u): return int(u) >= 0).size() >= mini(3, gens.size())
		"pet":
			return d["unlocks"].get("pet", false)
		"module":
			return int(d["pity"].get("opened", 0)) >= 1
		"forja":
			return int(d.get("sector_max", 1)) >= 5
	return false


## Índice del primer paso sin reclamar (TRAINING.size() si ya terminó).
static func training_index() -> int:
	var claimed: Array = GameState.data.get("training_claimed", [])
	for i in TRAINING.size():
		if not claimed.has(TRAINING[i]["id"]):
			return i
	return TRAINING.size()


## Reclama el paso actual si está cumplido.
static func claim_training() -> bool:
	var i := training_index()
	if i >= TRAINING.size() or not training_done(TRAINING[i]["id"]):
		return false
	var r: Dictionary = TRAINING[i]["reward"]
	for k in r.keys():
		match k:
			"mk2":
				GameState.data["ammo"]["mk2"] = int(GameState.data["ammo"].get("mk2", 0)) + int(r[k])
			"pet_laser":
				GameState.add_drone_laser(r[k])
			_:
				GameState.add_amount(k, int(r[k]))
	if not GameState.data.has("training_claimed"):
		GameState.data["training_claimed"] = []
	GameState.data["training_claimed"].append(TRAINING[i]["id"])
	GameState.save_game()
	GameState.changed.emit()
	return true


static func training_reward_text(r: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in r.keys():
		match k:
			"credits":
				parts.append("%s créditos" % GameData.format_num(r[k]))
			"nexo":
				parts.append("%d Cristales Nexo" % r[k])
			"mk2":
				parts.append("%d cargas Mk-II" % r[k])
			"pet_laser":
				parts.append("láser %s" % GameData.DRONE_LASERS[r[k]]["name"])
	return ", ".join(parts)


static func ensure() -> void:
	var d: Dictionary = GameState.data
	if not d.has("missions"):
		d["missions"] = {"day": -1, "daily": [], "week": -1, "weekly": [], "streak": 0, "last_full_day": -1}
	if not d.has("achievements"):
		d["achievements"] = {}
	if not d.has("season"):
		d["season"] = {"id": season_index(), "pts": 0, "claimed": 0}
	if not d.has("lore"):
		d["lore"] = []
	for k in ["boss_kills", "elites", "legendary", "pois", "missions_done", "events"]:
		if not d["stats"].has(k):
			d["stats"][k] = 0
	_roll_if_needed()


static func _roll_if_needed() -> void:
	var m: Dictionary = GameState.data["missions"]
	if int(m["day"]) != day_index():
		# Racha: se rompe si ayer no se completaron las tres diarias.
		if int(m["last_full_day"]) < day_index() - 1:
			m["streak"] = 0
		m["day"] = day_index()
		m["daily"] = _make_missions(3, 1, day_index())
	if int(m["week"]) != week_index():
		m["week"] = week_index()
		m["weekly"] = _make_missions(3, 6, week_index() * 7919)
	var s: Dictionary = GameState.data["season"]
	if int(s["id"]) != season_index():
		GameState.data["season"] = {"id": season_index(), "pts": 0, "claimed": 0}


static func _make_missions(n: int, scale: int, seed_v: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var types: Array = MISSION_TYPES.keys()
	if int(GameState.data["sector_max"]) < 4:
		types.erase("boss")  # aún no hay jefes por debajo del nivel 4
	var out: Array = []
	var used: Array = []
	var factions: Array = []
	for bid in GameData.BIOMES.keys():
		var b: Dictionary = GameData.BIOMES[bid]
		if b.has("enemies") and GameData.theme_of(bid) == bid and int(GameState.data["sector_max"]) >= int(b["min_level"]):
			factions.append(bid)
	while out.size() < n:
		var t: String = types[rng.randi() % types.size()]
		if used.has(t):
			continue
		used.append(t)
		var target := int(MISSION_TYPES[t]["base"]) * scale
		var mi := {"type": t, "target": target, "progress": 0, "claimed": false, "key": ""}
		if t == "faction":
			mi["key"] = factions[rng.randi() % factions.size()] if not factions.is_empty() else "ferron"
		out.append(mi)
	return out


static func mission_text(mi: Dictionary) -> String:
	var t: Dictionary = MISSION_TYPES[mi["type"]]
	if mi["type"] == "faction":
		return t["text"] % [GameData.format_num(mi["target"]), GameData.BIOMES[mi["key"]]["faction"]]
	if int(mi["target"]) == 1 and t.has("one"):
		return t["one"]
	return t["text"] % GameData.format_num(mi["target"])


## Recompensa escalada con el sector máximo; las semanales valen 5 veces más.
static func mission_reward(weekly: bool) -> Array:
	var lvl := int(GameState.data["sector_max"])
	var mult := (5.0 if weekly else 1.0) * (1.0 + minf(0.5, STREAK_BONUS * int(GameState.data["missions"]["streak"])))
	return [
		{"kind": "credits", "amount": int(1500.0 * GameData.level_reward(1.0, lvl) * mult)},
		{"kind": "nexo", "amount": int((25 if weekly else 4) * (1.0 + minf(0.5, STREAK_BONUS * int(GameState.data["missions"]["streak"]))))},
		{"kind": "xp", "amount": int(GameData.level_kill_xp(lvl) * (60 if weekly else 12) * mult)},
	]


static func reward_line(rs: Array) -> String:
	var parts: PackedStringArray = []
	for r in rs:
		parts.append("%s XP" % GameData.format_num(r["amount"]) if r["kind"] == "xp" else GameData.reward_text(r))
	return ", ".join(parts)


static func claim_mission(weekly: bool, i: int) -> bool:
	var m: Dictionary = GameState.data["missions"]
	var list: Array = m["weekly" if weekly else "daily"]
	var mi: Dictionary = list[i]
	if mi["claimed"] or int(mi["progress"]) < int(mi["target"]):
		return false
	mi["claimed"] = true
	for r in mission_reward(weekly):
		if r["kind"] == "xp":
			GameState.add_xp(int(r["amount"]))
		else:
			GameState._grant(r)
	GameState.data["stats"]["missions_done"] = int(GameState.data["stats"]["missions_done"]) + 1
	add_season_pts(400 if weekly else 100)
	# Racha: las tres diarias reclamadas hoy.
	if not weekly:
		var all_done := true
		for x in m["daily"]:
			all_done = all_done and x["claimed"]
		if all_done and int(m["last_full_day"]) != day_index():
			m["last_full_day"] = day_index()
			m["streak"] = int(m["streak"]) + 1
	check_achievements()
	GameState.save_game()
	GameState.changed.emit()
	return true


static func unclaimed_count() -> int:
	ensure()
	var n := 0
	var m: Dictionary = GameState.data["missions"]
	for list_key in ["daily", "weekly"]:
		for mi in m[list_key]:
			if not mi["claimed"] and int(mi["progress"]) >= int(mi["target"]):
				n += 1
	return n


# --- Al terminar una incursión ------------------------------------------------------------------
static func on_run(result: Dictionary) -> void:
	ensure()
	var st: Dictionary = GameState.data["stats"]
	var ok: bool = result.get("outcome", "") != "death"
	var counters := {
		"kills": int(result.get("kills", 0)),
		"extract": 1 if ok else 0,
		"objective": 1 if result.get("objective_done", false) else 0,
		"elites": int(result.get("elites", 0)),
		"boss": 1 if result.get("boss_killed", false) else 0,
		"boxes": int(result.get("boxes", 0)),
		"pois": int(result.get("pois", 0)),
		"events": int(result.get("events", 0)),
	}
	st["boss_kills"] = int(st["boss_kills"]) + counters["boss"]
	st["elites"] = int(st["elites"]) + counters["elites"]
	st["legendary"] = int(st["legendary"]) + int(result.get("legendary", 0))
	st["pois"] = int(st["pois"]) + counters["pois"]
	st["events"] = int(st["events"]) + counters["events"]
	var biome: String = result.get("biome", "")
	var m: Dictionary = GameState.data["missions"]
	for list_key in ["daily", "weekly"]:
		for mi in m[list_key]:
			if mi["claimed"]:
				continue
			var add := 0
			if mi["type"] == "faction":
				add = counters["kills"] if GameData.theme_of(mi["key"]) == GameData.theme_of(biome) else 0
			else:
				add = int(counters.get(mi["type"], 0))
			mi["progress"] = mini(int(mi["target"]), int(mi["progress"]) + add)
	# Temporada: 1 punto cada 5 bajas, 40 por objetivo, 60 por jefe.
	add_season_pts(counters["kills"] / 5 + counters["objective"] * 40 + counters["boss"] * 60)
	result["new_achievements"] = check_achievements()


# --- Logros y maestría (M13) ---------------------------------------------------------------------
static func mastery_count() -> int:
	var n := 0
	var kb: Dictionary = GameState.data["kills_by"]
	for k in kb.keys():
		if int(kb[k]) >= MASTERY_KILLS:
			n += 1
	return n


static func has_mastery(enemy_id: String) -> bool:
	return int(GameState.data["kills_by"].get(enemy_id, 0)) >= MASTERY_KILLS


static func stat_value(stat: String) -> int:
	var d: Dictionary = GameState.data
	match stat:
		"sector_max", "asc_max":
			return int(d.get(stat, 0))
		"level":
			return GameState.level()
		"lore":
			return d["lore"].size()
		"mastery":
			return mastery_count()
		"streak":
			return int(d["missions"]["streak"])
	return int(d["stats"].get(stat, 0))


## Concede los logros nuevos (Nexo) y devuelve sus nombres.
static func check_achievements() -> Array:
	var got: Array = []
	var a: Dictionary = GameState.data["achievements"]
	for ach in ACHIEVEMENTS:
		if a.has(ach["id"]):
			continue
		if stat_value(ach["stat"]) >= int(ach["n"]):
			a[ach["id"]] = now()
			GameState.add_amount("nexo", int(ach["nexo"]))
			got.append(ach["name"])
			if not GameState.data.has("ach_log"):
				GameState.data["ach_log"] = []
			GameState.data["ach_log"].append(ach["name"])
	return got


# --- Temporada (M18) ------------------------------------------------------------------------------
static func add_season_pts(n: int) -> void:
	if n <= 0:
		return
	var s: Dictionary = GameState.data["season"]
	s["pts"] = mini(SEASON_TIERS * SEASON_TIER_PTS, int(s["pts"]) + n)


static func season_tier() -> int:
	return int(GameState.data["season"]["pts"]) / SEASON_TIER_PTS


static func tier_reward(t: int) -> Array:
	if t == SEASON_TIERS:
		return [{"kind": "module", "rarity": 4}, {"kind": "nexo", "amount": 300}]
	if t % 10 == 0:
		return [{"kind": "module", "rarity": mini(3, 1 + t / 10)}, {"kind": "nexo", "amount": 50}]
	if t % 5 == 0:
		return [{"kind": "nexo", "amount": 20 + t}]
	if t % 3 == 0:
		return [{"kind": "ammo", "id": "mk3" if t < 20 else "mk4", "amount": 300}]
	if t % 2 == 0:
		return [{"kind": "credits", "amount": int(4000 * GameData.level_reward(1.0, int(GameState.data["sector_max"])) * (1.0 + t * 0.05))}]
	return [{"kind": "item", "id": "repair" if t % 4 == 1 else "shield_cell", "amount": 3}]


## Reclama todos los niveles alcanzados pendientes; devuelve los textos concedidos.
static func claim_season() -> Array:
	var s: Dictionary = GameState.data["season"]
	var out: Array = []
	while int(s["claimed"]) < season_tier():
		s["claimed"] = int(s["claimed"]) + 1
		for r in tier_reward(int(s["claimed"])):
			out.append("Nv %d: %s" % [s["claimed"], GameState._grant(r)])
	if not out.is_empty():
		GameState.save_game()
		GameState.changed.emit()
	return out


# --- Pecios (M19) ---------------------------------------------------------------------------------
## Devuelve el siguiente registro no leído (o "" si ya están todos).
static func next_lore() -> String:
	var got: Array = GameState.data["lore"]
	for i in LORE.size():
		if not got.has(i):
			got.append(i)
			return LORE[i]
	return ""
