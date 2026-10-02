extends Node
## Tablas de balance y contenido (GDD v0.2).
## Todas las cifras son valores iniciales de prototipo; se ajustan aquí sin tocar la lógica.

# --- Constantes globales de combate ---------------------------------------
const LASER_BASE_DAMAGE := 120.0      # daño por disparo de un láser 1.00x con munición x1
const LASER_RANGE := 620.0            # alcance en unidades de plano
const SPEED_UNIT := 2.3               # 100 de "Velocidad" GDD = 230 unidades/s
const SHIELD_FROM_HULL := 0.5         # escudo base = 50% del casco (el GDD no fija escudo base)
const SHIELD_RECHARGE_DELAY := 4.0
const SHIELD_RECHARGE_RATE := 0.06    # fracción del escudo máximo por segundo
const CARGO_UNIT := 20                # 1 de "Carga" GDD = 20 unidades de material
const DEATH_LOOT_LOSS := 0.5          # decisión provisional: al morir se pierde el 50% del botín

const RARITY_NAMES := ["Común", "Común+", "Raro", "Épico", "Muy raro", "Legendario"]
const RARITY_COLORS := [
	Color("a8b0b8"), Color("6fd17a"), Color("4aa3ff"), Color("b26bff"), Color("ff9a3c"), Color("ffd84a"),
]
const ITEM_RARITY_NAMES := {
	"comun": "Común", "poco_comun": "Poco común", "raro": "Raro", "epico": "Épico",
	"reliquia": "Reliquia", "exotico": "Exótico",
}
const ITEM_RARITY_COLORS := {
	"comun": Color("a8b0b8"), "poco_comun": Color("6fd17a"), "raro": Color("4aa3ff"),
	"epico": Color("b26bff"), "reliquia": Color("ff9a3c"), "exotico": Color("ff4fd8"),
}

# --- Materiales (13.2) -----------------------------------------------------
const MATERIALS := {
	"ferrita": {"name": "Ferrita", "rarity": 0},
	"plata": {"name": "Plata", "rarity": 0},
	"oro": {"name": "Oro", "rarity": 1},
	"platino": {"name": "Platino", "rarity": 2},
	"titanio": {"name": "Titanio", "rarity": 1},
	"cobalto": {"name": "Cobalto", "rarity": 1},
	"iridio": {"name": "Iridio", "rarity": 2},
	"osmio": {"name": "Osmio", "rarity": 2},
	"paladio": {"name": "Paladio", "rarity": 2},
	"neutronio": {"name": "Neutronio", "rarity": 4},
	"xenocristal": {"name": "Xenocristal", "rarity": 2},
	"aetherium": {"name": "Aetherium", "rarity": 4},
	"fragmento_vacio": {"name": "Fragmento del Vacío", "rarity": 4},
	"polvo_cuantico": {"name": "Polvo Cuántico", "rarity": 2},
	"resina_plasma": {"name": "Resina de Plasma", "rarity": 1},
	"bioaleacion": {"name": "Bioaleación", "rarity": 2},
	"quitina": {"name": "Quitina Estelar", "rarity": 1},
	"nanoespuma": {"name": "Nanoespuma", "rarity": 0},
	"materia_oscura": {"name": "Condensado de Materia Oscura", "rarity": 4},
	"antimateria": {"name": "Fragmento de Antimateria", "rarity": 4},
	"graviton": {"name": "Núcleo Gravitón", "rarity": 5},
	"cronita": {"name": "Cronita", "rarity": 4},
	"vidrio_estelar": {"name": "Vidrio Estelar", "rarity": 2},
	"fibra_fase": {"name": "Fibra de Fase", "rarity": 4},
	"semilla_singular": {"name": "Semilla Singular", "rarity": 5},
	"gel_entropico": {"name": "Gel Entrópico", "rarity": 2},
	"cristal_helix": {"name": "Cristal Helix", "rarity": 3},
	"nucleo_biomecanico": {"name": "Núcleo Biomecánico", "rarity": 3},
}

# --- Naves (6) -------------------------------------------------------------
# hull, speed (100 = estándar), dmg (multiplicador), cargo, lasers, gens, mods
const SHIP_CLASSES := {
	"caza": {"name": "Caza", "ability": "afterburner"},
	"tanque": {"name": "Tanque", "ability": "bulwark"},
	"carguera": {"name": "Carguera", "ability": "magnet"},
	"crucero": {"name": "Crucero", "ability": "overcharge"},
	"batalla": {"name": "Crucero de batalla", "ability": "barrage"},
}

const SHIPS := {
	"kestrel_a1": {"name": "Kestrel A1", "class": "caza", "hull": 4200, "speed": 118, "dmg": 1.00, "cargo": 70, "lasers": 3, "gens": 3, "mods": 1, "note": "Muy ágil; frágil.", "cost": {"credits": 0}},
	"raptor_v2": {"name": "Raptor V2", "class": "caza", "hull": 4800, "speed": 112, "dmg": 1.05, "cargo": 75, "lasers": 4, "gens": 3, "mods": 1, "note": "Mejor ofensiva; menor aceleración.", "cost": {"credits": 45000, "titanio": 30, "plata": 60}},
	"needle_s": {"name": "Needle S", "class": "caza", "hull": 3900, "speed": 128, "dmg": 0.95, "cargo": 60, "lasers": 3, "gens": 2, "mods": 1, "note": "Máxima velocidad; poca vida.", "cost": {"credits": 38000, "cobalto": 30, "plata": 40}},
	"falcon_r": {"name": "Falcon R", "class": "caza", "hull": 5200, "speed": 108, "dmg": 1.08, "cargo": 80, "lasers": 4, "gens": 3, "mods": 1, "note": "Equilibrado; coste alto de fabricación.", "cost": {"credits": 90000, "titanio": 60, "oro": 25, "platino": 4}},
	"bulwark_t1": {"name": "Bulwark T1", "class": "tanque", "hull": 12500, "speed": 70, "dmg": 0.92, "cargo": 105, "lasers": 3, "gens": 5, "mods": 2, "note": "Gran vida; lento.", "cost": {"credits": 120000, "titanio": 90, "osmio": 8}},
	"bastion_h": {"name": "Bastion H", "class": "tanque", "hull": 14200, "speed": 64, "dmg": 0.95, "cargo": 110, "lasers": 4, "gens": 5, "mods": 2, "note": "Escudo eficiente; giro pesado.", "cost": {"credits": 180000, "titanio": 120, "paladio": 15}},
	"mammoth_k": {"name": "Mammoth K", "class": "tanque", "hull": 16800, "speed": 58, "dmg": 0.88, "cargo": 130, "lasers": 4, "gens": 6, "mods": 2, "note": "Máxima resistencia; DPS bajo.", "cost": {"credits": 240000, "osmio": 25, "titanio": 150}},
	"aegis_r": {"name": "Aegis R", "class": "tanque", "hull": 13300, "speed": 72, "dmg": 1.00, "cargo": 100, "lasers": 4, "gens": 5, "mods": 2, "note": "Tanque ofensivo; menor carga.", "cost": {"credits": 210000, "iridio": 15, "titanio": 120}},
	"mule_c1": {"name": "Mule C1", "class": "carguera", "hull": 7200, "speed": 78, "dmg": 0.82, "cargo": 260, "lasers": 2, "gens": 4, "mods": 1, "note": "Carga alta; defensa limitada.", "cost": {"credits": 60000, "ferrita": 200, "nanoespuma": 60}},
	"atlas_c4": {"name": "Atlas C4", "class": "carguera", "hull": 8600, "speed": 74, "dmg": 0.86, "cargo": 340, "lasers": 3, "gens": 4, "mods": 2, "note": "Gran carga; lenta.", "cost": {"credits": 140000, "ferrita": 400, "titanio": 80}},
	"nomad_c": {"name": "Nomad C", "class": "carguera", "hull": 6800, "speed": 88, "dmg": 0.88, "cargo": 230, "lasers": 3, "gens": 3, "mods": 1, "note": "Carguera móvil; poca vida.", "cost": {"credits": 85000, "cobalto": 50, "plata": 100}},
	"prospector_ix": {"name": "Prospector IX", "class": "carguera", "hull": 9400, "speed": 70, "dmg": 0.90, "cargo": 390, "lasers": 3, "gens": 5, "mods": 2, "note": "Recolección máxima; silueta grande.", "cost": {"credits": 260000, "titanio": 150, "platino": 12}},
	"vanguard_m": {"name": "Vanguard M", "class": "crucero", "hull": 9800, "speed": 92, "dmg": 1.08, "cargo": 150, "lasers": 5, "gens": 5, "mods": 2, "note": "Versátil; coste de mantenimiento medio.", "cost": {"credits": 350000, "iridio": 20, "xenocristal": 25}},
	"centurion_p": {"name": "Centurion P", "class": "crucero", "hull": 11200, "speed": 84, "dmg": 1.12, "cargo": 160, "lasers": 6, "gens": 5, "mods": 2, "note": "Alto DPS; menos movilidad.", "cost": {"credits": 480000, "iridio": 35, "platino": 20}},
	"orion_m7": {"name": "Orion M7", "class": "crucero", "hull": 10500, "speed": 90, "dmg": 1.05, "cargo": 180, "lasers": 5, "gens": 6, "mods": 2, "note": "Buen balance de slots.", "cost": {"credits": 420000, "xenocristal": 40, "paladio": 20}},
	"helios_d": {"name": "Helios D", "class": "crucero", "hull": 9000, "speed": 98, "dmg": 1.15, "cargo": 140, "lasers": 6, "gens": 4, "mods": 2, "note": "Ofensivo; menor resistencia.", "cost": {"credits": 460000, "xenocristal": 45, "iridio": 30}},
	"titan_b1": {"name": "Titan B1", "class": "batalla", "hull": 17800, "speed": 70, "dmg": 1.15, "cargo": 190, "lasers": 7, "gens": 7, "mods": 3, "note": "Potencia bruta; lento.", "cost": {"credits": 1200000, "osmio": 60, "neutronio": 4}},
	"imperator_vx": {"name": "Imperator VX", "class": "batalla", "hull": 19500, "speed": 66, "dmg": 1.18, "cargo": 200, "lasers": 8, "gens": 7, "mods": 3, "note": "Muchos láseres; caro.", "cost": {"credits": 1800000, "iridio": 90, "neutronio": 6}},
	"leviathan_k": {"name": "Leviathan K", "class": "batalla", "hull": 22400, "speed": 60, "dmg": 1.12, "cargo": 220, "lasers": 7, "gens": 8, "mods": 3, "note": "Vida máxima; baja velocidad.", "cost": {"credits": 2000000, "osmio": 120, "neutronio": 8}},
	"nova_rex": {"name": "Nova Rex", "class": "batalla", "hull": 16500, "speed": 76, "dmg": 1.22, "cargo": 175, "lasers": 8, "gens": 6, "mods": 3, "note": "DPS alto; menos tanque que sus pares.", "cost": {"credits": 1900000, "xenocristal": 120, "neutronio": 6}},
	# Naves especiales (6.1): +8%..18% de poder efectivo y habilidad propia.
	"specter_x": {"name": "Specter-X", "class": "caza", "special": true, "hull": 4620, "speed": 127, "dmg": 1.08, "cargo": 70, "lasers": 4, "gens": 3, "mods": 1, "ability": "phase", "note": "Fase: 1.5 s de intangibilidad.", "cost": {"credits": 150000, "fragmento_vacio": 6, "fibra_fase": 4, "nexo": 300}},
	"fortress_omega": {"name": "Fortress Ω", "class": "tanque", "special": true, "hull": 14250, "speed": 70, "dmg": 0.98, "cargo": 105, "lasers": 3, "gens": 5, "mods": 2, "ability": "anchor", "note": "Ancla defensiva: -35% velocidad, +35% escudo 6 s.", "cost": {"credits": 400000, "osmio": 40, "paladio": 30, "nexo": 400}},
	"ark_meridian": {"name": "Ark Meridian", "class": "carguera", "special": true, "hull": 8060, "speed": 82, "dmg": 0.86, "cargo": 312, "lasers": 2, "gens": 4, "mods": 1, "ability": "compressor", "note": "Compresor: recoge botín cercano 8 s.", "cost": {"credits": 220000, "bioaleacion": 40, "nucleo_biomecanico": 2}},
	"seraph_prime": {"name": "Seraph Prime", "class": "crucero", "special": true, "hull": 10780, "speed": 98, "dmg": 1.18, "cargo": 150, "lasers": 6, "gens": 5, "mods": 2, "ability": "prismatic", "note": "Sobrecarga prismática: +cadencia temporal.", "cost": {"credits": 900000, "xenocristal": 120, "aetherium": 6, "nexo": 600}},
	"event_horizon": {"name": "Event Horizon", "class": "batalla", "special": true, "hull": 20470, "speed": 74, "dmg": 1.27, "cargo": 190, "lasers": 8, "gens": 7, "mods": 3, "ability": "gravity_well", "note": "Pozo gravitacional: atrae y ralentiza.", "cost": {"credits": 5000000, "graviton": 4, "semilla_singular": 3, "nexo": 1500}},
}

const ABILITIES := {
	"afterburner": {"name": "Postcombustión", "cd": 14.0, "dur": 3.0, "desc": "+60% velocidad durante 3 s."},
	"bulwark": {"name": "Baluarte", "cd": 20.0, "dur": 0.0, "desc": "Restaura 30% del escudo al instante."},
	"magnet": {"name": "Imán de carga", "cd": 18.0, "dur": 6.0, "desc": "Radio de recolección x4 durante 6 s."},
	"overcharge": {"name": "Sobrecarga", "cd": 22.0, "dur": 5.0, "desc": "+40% cadencia durante 5 s."},
	"barrage": {"name": "Andanada", "cd": 25.0, "dur": 6.0, "desc": "+30% daño durante 6 s."},
	"phase": {"name": "Fase", "cd": 30.0, "dur": 1.5, "desc": "1.5 s de intangibilidad."},
	"anchor": {"name": "Ancla defensiva", "cd": 26.0, "dur": 6.0, "desc": "-35% velocidad, +35% escudo durante 6 s."},
	"compressor": {"name": "Compresor", "cd": 20.0, "dur": 8.0, "desc": "Atrae todo el botín cercano durante 8 s."},
	"prismatic": {"name": "Sobrecarga prismática", "cd": 22.0, "dur": 6.0, "desc": "+60% cadencia durante 6 s."},
	"gravity_well": {"name": "Pozo gravitacional", "cd": 28.0, "dur": 4.0, "desc": "Atrae enemigos pequeños y ralentiza medianos."},
}

# --- Láseres (7.1) -----------------------------------------------------------
# dmg = multiplicador por proyectil, shots = proyectiles por disparo, rate = disparos/s
const LASERS := {
	"l01": {"name": "L-01 Pulse", "rarity": "comun", "dmg": 1.00, "shots": 1, "rate": 1.0, "effect": "", "color": Color("ff4a4a"), "adv": "Sin efecto adicional.", "dis": "Barato y fiable.", "cost": {"credits": 2000}},
	"l02": {"name": "L-02 Twin Pulse", "rarity": "comun", "dmg": 0.62, "shots": 2, "rate": 1.1, "effect": "twin", "color": Color("ff7a3a"), "adv": "Dos proyectiles paralelos.", "dis": "Peor precisión a distancia.", "cost": {"credits": 6000, "plata": 20}},
	"l03": {"name": "L-03 Prism Needle", "rarity": "poco_comun", "dmg": 1.15, "shots": 1, "rate": 1.0, "effect": "pierce_armor", "color": Color("8af7ff"), "adv": "+12% penetración de armadura.", "dis": "Menor tamaño de impacto.", "cost": {"credits": 18000, "xenocristal": 4, "plata": 30}},
	"l04": {"name": "L-04 Cadence", "rarity": "poco_comun", "dmg": 0.90, "shots": 1, "rate": 1.3, "effect": "cadence", "color": Color("ffe04a"), "adv": "Cada 4.º disparo inflige 2x daño.", "dis": "Daño individual menor.", "cost": {"credits": 22000, "oro": 6, "cobalto": 20}},
	"l05": {"name": "L-05 Ion Lance", "rarity": "raro", "dmg": 0.95, "shots": 1, "rate": 1.0, "effect": "ion", "color": Color("4ab8ff"), "adv": "+45% daño a escudos.", "dis": "-15% daño a casco.", "cost": {"credits": 40000, "paladio": 6, "plata": 40}},
	"l06": {"name": "L-06 Ember Ray", "rarity": "raro", "dmg": 0.85, "shots": 1, "rate": 1.3, "effect": "burn", "color": Color("ff8a1e"), "adv": "Aplica quemadura acumulable.", "dis": "Débil contra enemigos veloces.", "cost": {"credits": 42000, "resina_plasma": 30, "cobalto": 20}},
	"l07": {"name": "L-07 Cryo Beam", "rarity": "raro", "dmg": 0.39, "shots": 1, "rate": 2.4, "effect": "slow", "color": Color("9fe8ff"), "adv": "Ralentiza hasta 18%.", "dis": "DPS bajo.", "cost": {"credits": 38000, "xenocristal": 8, "nanoespuma": 30}},
	"l08": {"name": "L-08 Scatter Prism", "rarity": "raro", "dmg": 0.45, "shots": 5, "rate": 0.7, "effect": "scatter", "color": Color("ff5ad8"), "adv": "Abanico de 5 rayos.", "dis": "Ineficiente a distancia.", "cost": {"credits": 45000, "xenocristal": 10, "vidrio_estelar": 6}},
	"l09": {"name": "L-09 Arc Chain", "rarity": "epico", "dmg": 0.92, "shots": 1, "rate": 1.0, "effect": "chain", "color": Color("b8a4ff"), "adv": "Salta a 2 objetivos, -30% por salto.", "dis": "Peor contra objetivo único.", "cost": {"credits": 120000, "iridio": 12, "polvo_cuantico": 6}},
	"l10": {"name": "L-10 Siege Laser", "rarity": "epico", "dmg": 1.80, "shots": 1, "rate": 0.6, "effect": "siege", "color": Color("ff2a2a"), "adv": "+20% daño a unidades grandes.", "dis": "Cadencia lenta.", "cost": {"credits": 130000, "iridio": 15, "osmio": 10}},
	"l11": {"name": "L-11 Phase Cutter", "rarity": "epico", "dmg": 1.05, "shots": 1, "rate": 1.3, "effect": "phase", "color": Color("d0a8ff"), "adv": "8% de ignorar escudo y golpear casco.", "dis": "Coste energético alto.", "cost": {"credits": 140000, "fibra_fase": 2, "iridio": 12}},
	"l12": {"name": "L-12 Resonance", "rarity": "epico", "dmg": 0.88, "shots": 1, "rate": 1.3, "effect": "resonance", "color": Color("5affc8"), "adv": "Golpes sucesivos: +3%, hasta +18%.", "dis": "Pierde acumulación al cambiar de objetivo.", "cost": {"credits": 135000, "polvo_cuantico": 10, "vidrio_estelar": 10}},
	"l13": {"name": "L-13 Solar Spear", "rarity": "reliquia", "dmg": 2.20, "shots": 1, "rate": 0.4, "effect": "pierce", "color": Color("fff07a"), "adv": "Perfora varios enemigos.", "dis": "Recalentamiento.", "cost": {"credits": 500000, "aetherium": 4, "polvo_cuantico": 20}},
	"l14": {"name": "L-14 Null Ray", "rarity": "reliquia", "dmg": 1.12, "shots": 1, "rate": 1.0, "effect": "weaken", "color": Color("c8c8c8"), "adv": "Reduce 10% el daño enemigo 3 s.", "dis": "No se acumula.", "cost": {"credits": 480000, "materia_oscura": 4, "paladio": 20}},
	"l15": {"name": "L-15 Singularity Beam", "rarity": "reliquia", "dmg": 1.35, "shots": 1, "rate": 0.6, "effect": "pull", "color": Color("8a4aff"), "adv": "Pequeña atracción al impactar.", "dis": "Consume munición 20% más rápido.", "cost": {"credits": 520000, "graviton": 1, "materia_oscura": 4}},
	"l16": {"name": "L-16 Quantum Echo", "rarity": "exotico", "dmg": 1.00, "shots": 1, "rate": 1.0, "effect": "echo", "color": Color("4affff"), "adv": "15% de repetir el disparo sin coste.", "dis": "Tirada aleatoria; no garantiza proc.", "cost": {"credits": 1500000, "polvo_cuantico": 60, "cronita": 6, "nexo": 500}},
	"l17": {"name": "L-17 Triune", "rarity": "exotico", "dmg": 0.72, "shots": 3, "rate": 1.0, "effect": "triune", "color": Color("ffb84a"), "adv": "Tres impactos convergentes.", "dis": "Sufre contra objetivos pequeños.", "cost": {"credits": 1500000, "aetherium": 8, "antimateria": 3, "nexo": 500}},
	"l18": {"name": "L-18 Oblivion", "rarity": "exotico", "dmg": 1.55, "shots": 1, "rate": 0.8, "effect": "oblivion", "color": Color("ff2a8a"), "adv": "Cada 10 impactos crea explosión 3x.", "dis": "Muy caro de fabricar/mejorar.", "cost": {"credits": 3000000, "antimateria": 6, "semilla_singular": 1, "nexo": 900}},
}

# --- Munición (7.2) — receta por lote de 100 ---------------------------------
const AMMO := {
	"mk1": {"name": "Carga Mk-I", "short": "x1", "mult": 1.0, "color": Color("d8d8d8"), "recipe": {"credits": 150, "ferrita": 4}},
	"mk2": {"name": "Carga Mk-II", "short": "x2", "mult": 2.0, "color": Color("6fd17a"), "recipe": {"credits": 500, "ferrita": 6, "plata": 5, "resina_plasma": 2}},
	"mk3": {"name": "Carga Mk-III", "short": "x3", "mult": 3.0, "color": Color("4aa3ff"), "recipe": {"credits": 1600, "oro": 3, "titanio": 4, "xenocristal": 1}},
	"mk4": {"name": "Carga Mk-IV", "short": "x4", "mult": 4.0, "color": Color("b26bff"), "recipe": {"credits": 5000, "platino": 2, "iridio": 2, "polvo_cuantico": 1}},
	"mk5": {"name": "Carga Mk-V", "short": "x5", "mult": 5.0, "color": Color("ff9a3c"), "recipe": {"credits": 15000, "neutronio": 1, "antimateria": 1, "cronita": 1}},
	"mk6": {"name": "Carga Mk-VI", "short": "x6", "mult": 6.0, "color": Color("ffd84a"), "recipe": {"credits": 50000, "graviton": 1, "materia_oscura": 2, "semilla_singular": 1}},
}

# --- Consumibles / desplegables (4.3) — receta por unidad --------------------
const ITEMS := {
	"repair": {"name": "Kit de reparación", "short": "REP", "kind": "instant", "cd": 10.0, "color": Color("6fd17a"), "desc": "Repara 30% del casco.", "recipe": {"credits": 800, "nanoespuma": 6, "resina_plasma": 2}},
	"boost": {"name": "Impulso consumible", "short": "IMP", "kind": "instant", "cd": 12.0, "color": Color("ffe04a"), "desc": "+40% velocidad durante 5 s.", "recipe": {"credits": 600, "resina_plasma": 3, "cobalto": 2}},
	"mine": {"name": "Mina de proximidad", "short": "MIN", "kind": "deploy", "cd": 3.0, "color": Color("ff5a5a"), "desc": "Desplegable. Explota cerca de enemigos (daño en área).", "recipe": {"credits": 1200, "ferrita": 10, "cobalto": 4}},
	"shield_cell": {"name": "Celda de escudo", "short": "ESC", "kind": "instant", "cd": 15.0, "color": Color("4ab8ff"), "desc": "Recarga 40% del escudo.", "recipe": {"credits": 1000, "paladio": 1, "plata": 6}},
}

# --- Generadores (8) ---------------------------------------------------------
const GENERATORS := {
	"sg_aegis1": {"name": "SG-Aegis I", "type": "shield", "stats": {"shield": 0.04}, "trait": "Sin penalización.", "cost": {"credits": 3000}},
	"sg_aegis2": {"name": "SG-Aegis II", "type": "shield", "stats": {"shield": 0.07, "speed": -0.01}, "trait": "+2% masa / -1% velocidad.", "cost": {"credits": 9000, "titanio": 10}},
	"sg_flux": {"name": "SG-Flux", "type": "shield", "stats": {"shield": 0.05, "recharge": 0.08, "hull": -0.04}, "trait": "-4% casco.", "cost": {"credits": 14000, "paladio": 3}},
	"sg_bulwark": {"name": "SG-Bulwark", "type": "shield", "stats": {"shield": 0.11, "speed": -0.04}, "trait": "-4% velocidad.", "cost": {"credits": 20000, "titanio": 30, "osmio": 2}},
	"sg_pulse": {"name": "SG-Pulse", "type": "shield", "stats": {"shield": 0.06}, "trait": "Al romperse: onda que empuja enemigos; CD 30 s.", "cost": {"credits": 26000, "paladio": 5}},
	"sg_reflect": {"name": "SG-Reflect", "type": "shield", "stats": {"shield": 0.05}, "trait": "3% de reflejar proyectil ligero.", "cost": {"credits": 26000, "vidrio_estelar": 6}},
	"sg_repair": {"name": "SG-Repair", "type": "shield", "stats": {"shield": 0.04, "shield_regen": 0.004}, "trait": "Regenera 0.4% escudo/s fuera de daño.", "cost": {"credits": 24000, "nanoespuma": 40}},
	"sg_null": {"name": "SG-Null", "type": "shield", "stats": {"shield": 0.08}, "trait": "-8% duración de estados enemigos.", "cost": {"credits": 40000, "gel_entropico": 6}},
	"sg_fortress": {"name": "SG-Fortress", "type": "shield", "stats": {"shield": 0.13, "speed": -0.06}, "trait": "-6% velocidad, +5% consumo energético.", "cost": {"credits": 60000, "osmio": 8, "paladio": 6}},
	"sg_quantum": {"name": "SG-Quantum", "type": "shield", "stats": {"shield": 0.09}, "trait": "10% de reducir un impacto en 35%; CD 5 s.", "cost": {"credits": 90000, "polvo_cuantico": 10}},
	"vg_thrust1": {"name": "VG-Thrust I", "type": "speed", "stats": {"speed": 0.025}, "trait": "Sin penalización.", "cost": {"credits": 3000}},
	"vg_thrust2": {"name": "VG-Thrust II", "type": "speed", "stats": {"speed": 0.04, "shield": -0.02}, "trait": "-2% escudo.", "cost": {"credits": 9000, "cobalto": 10}},
	"vg_vector": {"name": "VG-Vector", "type": "speed", "stats": {"speed": 0.03, "accel": 0.08, "hull": -0.03}, "trait": "-3% casco.", "cost": {"credits": 14000, "cobalto": 20}},
	"vg_blink": {"name": "VG-Blink", "type": "speed", "stats": {"speed": 0.04, "boost_cd": -0.08}, "trait": "Reduce 8% CD de impulso.", "cost": {"credits": 20000, "cobalto": 25, "oro": 4}},
	"vg_racer": {"name": "VG-Racer", "type": "speed", "stats": {"speed": 0.07, "shield": -0.07}, "trait": "-7% escudo.", "cost": {"credits": 26000, "cobalto": 30}},
	"vg_inertia": {"name": "VG-Inertia", "type": "speed", "stats": {"speed": 0.03, "turn": 0.12}, "trait": "+12% control de giro.", "cost": {"credits": 18000, "titanio": 20}},
	"vg_overdrive": {"name": "VG-Overdrive", "type": "speed", "stats": {"speed": 0.05}, "trait": "Tras impulso: +6% 2 s; CD 8 s.", "cost": {"credits": 40000, "resina_plasma": 40}},
	"vg_phase": {"name": "VG-Phase", "type": "speed", "stats": {"speed": 0.045}, "trait": "5% de ignorar ralentizaciones.", "cost": {"credits": 50000, "fibra_fase": 1}},
	"vg_comet": {"name": "VG-Comet", "type": "speed", "stats": {"speed": 0.08, "hull": -0.08}, "trait": "-8% casco.", "cost": {"credits": 60000, "cobalto": 60, "oro": 10}},
	"vg_horizon": {"name": "VG-Horizon", "type": "speed", "stats": {"speed": 0.06}, "trait": "Bajo 25% vida: +12% 4 s; CD 25 s.", "cost": {"credits": 80000, "cronita": 1}},
}

# --- Variantes (12.1) --------------------------------------------------------
const VARIANTS := {
	"base": {"name": "", "hp": 1.0, "reward": 1.0, "dmg": 1.0, "scale": 1.0, "color": Color(0, 0, 0, 0)},
	"boss": {"name": "Boss", "hp": 2.0, "reward": 2.0, "dmg": 1.35, "scale": 1.25, "color": Color("ffb84a")},
	"mega": {"name": "Mega", "hp": 3.0, "reward": 3.0, "dmg": 1.60, "scale": 1.45, "color": Color("ff5a5a")},
	"ultra": {"name": "Ultra", "hp": 4.0, "reward": 4.0, "dmg": 1.90, "scale": 1.6, "color": Color("d05aff")},
	"uber": {"name": "Uber", "hp": 5.0, "reward": 5.0, "dmg": 2.25, "scale": 1.8, "color": Color("4affff")},
}

# --- Bestiario (15) — Facción Enjambre Ferron (1-10) --------------------------
# arch: arquetipo de IA. size: radio en unidades de plano. shape: silueta procedural.
const ENEMIES := {
	"xenomita": {"name": "Xenomita", "arch": "harasser", "hp": 900, "dmg": 55, "vel": 115, "size": 22, "shape": "insect", "color": Color("8c8f96"), "accent": Color("ff3a3a"), "credits": 1000, "drops": {"ferrita": 20, "plata": 20, "platino": 1}, "nexo": 0.0005},
	"chatarrax": {"name": "Chatarrax", "arch": "swarm", "hp": 650, "dmg": 38, "vel": 125, "size": 16, "shape": "scrap", "color": Color("7a6a50"), "accent": Color("ffd23a"), "credits": 780, "drops": {"ferrita": 28, "nanoespuma": 8, "plata": 10}, "nexo": 0.0003},
	"ferroclasto": {"name": "Ferróclasto", "arch": "tank", "hp": 3100, "dmg": 105, "vel": 58, "size": 40, "shape": "oval", "color": Color("6b6f78"), "accent": Color("ff6a2a"), "credits": 2200, "drops": {"ferrita": 35, "titanio": 15, "osmio": 2}, "nexo": 0.0008},
	"aguijon_khepri": {"name": "Aguijón Khepri", "arch": "hunter", "hp": 1200, "dmg": 80, "vel": 135, "size": 20, "shape": "needle", "color": Color("2a2a30"), "accent": Color("ff8a2a"), "credits": 1450, "drops": {"plata": 18, "cobalto": 12, "oro": 3}, "nexo": 0.0006},
	"taladro_vorak": {"name": "Taladro Vorak", "arch": "charger", "hp": 2400, "dmg": 120, "vel": 82, "size": 30, "shape": "drill", "color": Color("8a7a2a"), "accent": Color("4ab8ff"), "credits": 1900, "drops": {"titanio": 18, "ferrita": 25, "iridio": 2}, "nexo": 0.0007},
	"nodo_bastion": {"name": "Nodo Bastión", "arch": "support", "hp": 2200, "dmg": 45, "vel": 55, "size": 30, "shape": "hex", "color": Color("2f4a3a"), "accent": Color("4ab8ff"), "credits": 2100, "drops": {"paladio": 6, "plata": 22, "ferrita": 20}, "nexo": 0.0008},
	"mina_garra": {"name": "Mina Garra", "arch": "miner", "hp": 500, "dmg": 150, "vel": 90, "size": 16, "shape": "claw", "color": Color("5a5a60"), "accent": Color("ff2a2a"), "credits": 900, "drops": {"ferrita": 12, "resina_plasma": 7, "cobalto": 5}, "nexo": 0.0004},
	"recolector_morbido": {"name": "Recolector Mórbido", "arch": "harasser", "hp": 1800, "dmg": 60, "vel": 75, "size": 28, "shape": "skull", "color": Color("7a5a5a"), "accent": Color("aaff5a"), "credits": 1700, "drops": {"oro": 5, "plata": 15, "nanoespuma": 20}, "nexo": 0.0006},
	"artillero_ciclope": {"name": "Artillero Cíclope", "arch": "artillery", "hp": 2600, "dmg": 155, "vel": 62, "size": 32, "shape": "tri", "color": Color("3a3a40"), "accent": Color("ff2a2a"), "credits": 2350, "drops": {"iridio": 4, "titanio": 18, "ferrita": 18}, "nexo": 0.0009},
	"madre_remache": {"name": "Madre Remache", "arch": "mother", "hp": 5200, "dmg": 90, "vel": 48, "size": 56, "shape": "mother", "color": Color("5a4a40"), "accent": Color("ff3a3a"), "credits": 4200, "drops": {"ferrita": 50, "oro": 8, "platino": 3, "cristal_helix": 1}, "nexo": 0.0015, "spawns": "chatarrax"},
}

# --- Biomas (11.1) -------------------------------------------------------------
const BIOMES := {
	"ferron": {
		"name": "Cinturón Ferron", "bg": Color("0a0c12"), "grid": Color(0.55, 0.42, 0.3, 0.07),
		"rock": Color("4a4038"), "rock_edge": Color("7a6250"), "nebula": Color(0.6, 0.35, 0.18, 0.05),
		"enemies": {"xenomita": 30, "chatarrax": 26, "ferroclasto": 10, "aguijon_khepri": 12, "taladro_vorak": 8, "nodo_bastion": 5, "mina_garra": 10, "recolector_morbido": 7, "artillero_ciclope": 7},
		"elites": ["madre_remache"],
		"resources": {"ferrita": 50, "plata": 30, "oro": 12, "titanio": 8},
		"min_level": 1,
	},
	"vesper": {"name": "Nebulosa Vesper", "min_level": 10, "locked": true},
	"prismaticos": {"name": "Campos Prismáticos", "min_level": 20, "locked": true},
	"titan": {"name": "Cementerio Titán", "min_level": 30, "locked": true},
	"vacio": {"name": "Fractura del Vacío", "min_level": 40, "locked": true},
	"corona": {"name": "Corona Solar", "min_level": 50, "locked": true},
	"leviatan": {"name": "Jardín Leviatán", "min_level": 60, "locked": true},
	"cronos": {"name": "Anillo de Cronos", "min_level": 70, "locked": true},
	"pozo": {"name": "Pozo Gravitacional", "min_level": 80, "locked": true},
	"umbral": {"name": "Umbral Singular", "min_level": 90, "locked": true},
}

const OBJECTIVES := {
	"limpieza": {"name": "Limpieza", "desc": "Elimina el %d%% de la presencia hostil."},
	"nidos": {"name": "Destruir nidos", "desc": "Destruye %d puntos de aparición."},
}


# --- Fórmulas (12.2, 14.1, 23) -----------------------------------------------
static func level_hp(base: float, level: int) -> float:
	return base * pow(1.0 + 0.085 * level, 1.18)

static func level_dmg(base: float, level: int) -> float:
	return base * pow(1.0 + 0.060 * level, 1.10)

static func level_reward(base: float, level: int) -> float:
	return base * (1.0 + 0.045 * level)

## Multiplicador de componente por nivel: +1% por nivel sobre el valor base.
static func component_mult(level: int) -> float:
	return 1.0 + 0.01 * level

## Coste para subir un componente desde `level` a `level + 1` (Coste(n) = Base x 1.32^(n-1)).
static func upgrade_cost(level: int, base_credits: int) -> Dictionary:
	var n := level + 1
	var credits := int(round(base_credits * pow(1.32, n - 1)))
	var cost := {"credits": credits}
	if n <= 4:
		cost["ferrita"] = 10 * n
		cost["plata"] = 8 * n
	elif n <= 8:
		cost["oro"] = 2 * (n - 3)
		cost["titanio"] = 4 * (n - 3)
		cost["xenocristal"] = n - 4
	elif n <= 12:
		cost["platino"] = n - 7
		cost["iridio"] = n - 7
		cost["polvo_cuantico"] = n - 8
	else:
		cost["neutronio"] = n - 11
		cost["aetherium"] = n - 12
		cost["nexo"] = 10 * (n - 12)
	return cost

static func format_num(v: float) -> String:
	var a := absf(v)
	if a < 10000.0:
		return str(int(round(v)))
	var units := ["K", "M", "B", "T"]
	var i := -1
	while a >= 1000.0 and i < units.size() - 1:
		a /= 1000.0
		i += 1
	if a >= 1000.0:
		return "%.2e" % v
	return ("%.1f" % (signf(v) * a)) + units[i]

static func mat_name(id: String) -> String:
	if id == "credits":
		return "Créditos"
	if id == "nexo":
		return "Cristales Nexo"
	if id == "seals":
		return "Sellos de Sector"
	return MATERIALS.get(id, {}).get("name", id)

static func mat_color(id: String) -> Color:
	if id == "credits":
		return Color("ffd84a")
	if id == "nexo":
		return Color("ff4fd8")
	var r: int = MATERIALS.get(id, {}).get("rarity", 0)
	return RARITY_COLORS[r]
