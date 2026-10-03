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
const DEATH_LOOT_LOSS := 0.9          # al morir se pierde el 90% de lo recolectado en el sector (sin aviso)
const VOLLEY_INTERVAL := 1.2          # la nave dispara una andanada con todos sus láseres cada 1.2 s
const ENEMY_DMG_MULT := 1.3           # con disparos teledirigidos (casi siempre aciertan) el daño efectivo ya es ~3x el de v0.3
const ENEMY_HP_MULT := 1.2
const ENEMY_BULLET_TURN := 1.2        # rad/s: persiguen a la nave; un impulso o un giro cerrado aún los esquiva
const ASC_UNLOCK_LEVEL := 50          # M9: limpiar este nivel abre la Ascensión
const ASC_MAX := 10
const NEXO_RATE := 587.0              # créditos equivalentes a 1 Cristal Nexo (Specter-X: 246.4K créditos o 420 Nexo)
const LOOT_BOX_LIFE := 120.0          # segundos que permanece una caja de botín
const MAX_ENEMIES := 160               # tope de enemigos vivos (rendimiento: más allá cae la tasa de fotogramas)

## Alcance de disparo por arquetipo (unidades de plano; el láser del jugador alcanza LASER_RANGE).
const ARCH_RANGE := {
	"harasser": 560.0, "swarm": 360.0, "tank": 480.0, "hunter": 440.0, "charger": 480.0, "support": 420.0,
	"miner": 95.0, "artillery": 820.0, "mother": 600.0, "nest": 0.0, "drainer": 330.0, "ambusher": 400.0,
	"defender": 500.0, "sniper": 980.0, "elite": 640.0, "control": 470.0, "trap": 520.0,
}

## Refinado en sector (por rareza de material: común … legendario).
## Escudo: +% de escudo máximo durante REFINE_SHIELD_TIME s por unidad (acumulable hasta REFINE_SHIELD_CAP).
## Láser: +% de daño en un disparo de láser por unidad.
const REFINE_SHIELD_PCT := [0.05, 0.07, 0.10, 0.14, 0.20, 0.30]
const REFINE_SHIELD_TIME := 300.0
const REFINE_SHIELD_CAP := 3600.0
const REFINE_LASER_PCT := [0.02, 0.03, 0.05, 0.08, 0.12, 0.18]

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
	"l01": {"name": "L-01 Pulse", "rarity": "comun", "dmg": 1.00, "shots": 1, "rate": 1.0, "effect": "", "color": Color("ff2e2e"), "adv": "Sin efecto adicional.", "dis": "Barato y fiable.", "cost": {"credits": 2000}},
	"l02": {"name": "L-02 Twin Pulse", "rarity": "comun", "dmg": 0.62, "shots": 2, "rate": 1.1, "effect": "twin", "color": Color("a6ff2e"), "adv": "Dos proyectiles paralelos.", "dis": "Peor precisión a distancia.", "cost": {"credits": 6000, "plata": 20}},
	"l03": {"name": "L-03 Prism Needle", "rarity": "poco_comun", "dmg": 1.15, "shots": 1, "rate": 1.0, "effect": "pierce_armor", "color": Color("2ef6ff"), "adv": "+12% penetración de armadura.", "dis": "Menor tamaño de impacto.", "cost": {"credits": 18000, "xenocristal": 4, "plata": 30}},
	"l04": {"name": "L-04 Cadence", "rarity": "poco_comun", "dmg": 0.90, "shots": 1, "rate": 1.3, "effect": "cadence", "color": Color("ffe62e"), "adv": "Cada 4.º disparo inflige 2x daño.", "dis": "Daño individual menor.", "cost": {"credits": 22000, "oro": 6, "cobalto": 20}},
	"l05": {"name": "L-05 Ion Lance", "rarity": "raro", "dmg": 0.95, "shots": 1, "rate": 1.0, "effect": "ion", "color": Color("2e6bff"), "adv": "+45% daño a escudos.", "dis": "-15% daño a casco.", "cost": {"credits": 40000, "paladio": 6, "plata": 40}},
	"l06": {"name": "L-06 Ember Ray", "rarity": "raro", "dmg": 0.85, "shots": 1, "rate": 1.3, "effect": "burn", "color": Color("ff7a1e"), "adv": "Aplica quemadura acumulable.", "dis": "Débil contra enemigos veloces.", "cost": {"credits": 42000, "resina_plasma": 30, "cobalto": 20}},
	"l07": {"name": "L-07 Cryo Beam", "rarity": "raro", "dmg": 0.39, "shots": 1, "rate": 2.4, "effect": "slow", "color": Color("c8f0ff"), "adv": "Ralentiza hasta 18%.", "dis": "DPS bajo.", "cost": {"credits": 38000, "xenocristal": 8, "nanoespuma": 30}},
	"l08": {"name": "L-08 Scatter Prism", "rarity": "raro", "dmg": 0.45, "shots": 5, "rate": 0.7, "effect": "scatter", "color": Color("ff2ec8"), "adv": "Abanico de 5 rayos.", "dis": "Ineficiente a distancia.", "cost": {"credits": 45000, "xenocristal": 10, "vidrio_estelar": 6}},
	"l09": {"name": "L-09 Arc Chain", "rarity": "epico", "dmg": 0.92, "shots": 1, "rate": 1.0, "effect": "chain", "color": Color("5ac8ff"), "adv": "Salta a 2 objetivos, -30% por salto.", "dis": "Peor contra objetivo único.", "cost": {"credits": 120000, "iridio": 12, "polvo_cuantico": 6}},
	"l10": {"name": "L-10 Siege Laser", "rarity": "epico", "dmg": 1.80, "shots": 1, "rate": 0.6, "effect": "siege", "color": Color("2effa0"), "adv": "+20% daño a unidades grandes.", "dis": "Cadencia lenta.", "cost": {"credits": 130000, "iridio": 15, "osmio": 10}},
	"l11": {"name": "L-11 Phase Cutter", "rarity": "epico", "dmg": 1.05, "shots": 1, "rate": 1.3, "effect": "phase", "color": Color("e0a8ff"), "adv": "8% de ignorar escudo y golpear casco.", "dis": "Coste energético alto.", "cost": {"credits": 140000, "fibra_fase": 2, "iridio": 12}},
	"l12": {"name": "L-12 Resonance", "rarity": "epico", "dmg": 0.88, "shots": 1, "rate": 1.3, "effect": "resonance", "color": Color("2edc4a"), "adv": "Golpes sucesivos: +3%, hasta +18%.", "dis": "Pierde acumulación al cambiar de objetivo.", "cost": {"credits": 135000, "polvo_cuantico": 10, "vidrio_estelar": 10}},
	"l13": {"name": "L-13 Solar Spear", "rarity": "reliquia", "dmg": 2.20, "shots": 1, "rate": 0.4, "effect": "pierce", "color": Color("fff7c2"), "adv": "Perfora varios enemigos.", "dis": "Recalentamiento.", "cost": {"credits": 500000, "aetherium": 4, "polvo_cuantico": 20}},
	"l14": {"name": "L-14 Null Ray", "rarity": "reliquia", "dmg": 1.12, "shots": 1, "rate": 1.0, "effect": "weaken", "color": Color("b8bcc8"), "adv": "Reduce 10% el daño enemigo 3 s.", "dis": "No se acumula.", "cost": {"credits": 480000, "materia_oscura": 4, "paladio": 20}},
	"l15": {"name": "L-15 Singularity Beam", "rarity": "reliquia", "dmg": 1.35, "shots": 1, "rate": 0.6, "effect": "pull", "color": Color("7a2eff"), "adv": "Pequeña atracción al impactar.", "dis": "Consume munición 20% más rápido.", "cost": {"credits": 520000, "graviton": 1, "materia_oscura": 4}},
	"l16": {"name": "L-16 Quantum Echo", "rarity": "exotico", "dmg": 1.00, "shots": 1, "rate": 1.0, "effect": "echo", "color": Color("ff9ee0"), "adv": "15% de repetir el disparo sin coste.", "dis": "Tirada aleatoria; no garantiza proc.", "cost": {"credits": 1500000, "polvo_cuantico": 60, "cronita": 6, "nexo": 500}},
	"l17": {"name": "L-17 Triune", "rarity": "exotico", "dmg": 0.72, "shots": 3, "rate": 1.0, "effect": "triune", "color": Color("ffb02e"), "adv": "Tres impactos convergentes.", "dis": "Sufre contra objetivos pequeños.", "cost": {"credits": 1500000, "aetherium": 8, "antimateria": 3, "nexo": 500}},
	"l18": {"name": "L-18 Oblivion", "rarity": "exotico", "dmg": 1.55, "shots": 1, "rate": 0.8, "effect": "oblivion", "color": Color("ff2e7a"), "adv": "Cada 10 impactos crea explosión 3x.", "dis": "Muy caro de fabricar/mejorar.", "cost": {"credits": 3000000, "antimateria": 6, "semilla_singular": 1, "nexo": 900}},
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

# --- Bestiario (15) — 50 especies en 5 facciones ------------------------------------
# arch: arquetipo de IA (15.6). size: radio en unidades de plano. shape: silueta de respaldo sin sprite.
# nexo: probabilidad de Cristal Nexo (0.05% = 0.0005). spawns: especie que genera (nodrizas/invocadores).
const ENEMIES := {
	# Enjambre Ferron (1-10)
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
	# Biomancia Vesper (11-20)
	"larva_vesper": {"name": "Larva Vesper", "arch": "swarm", "hp": 700, "dmg": 42, "vel": 118, "size": 17, "shape": "needle", "color": Color("6a3a8a"), "accent": Color("c86bff"), "credits": 850, "drops": {"quitina": 18, "resina_plasma": 8, "bioaleacion": 2}, "nexo": 0.0004},
	"mantis_necral": {"name": "Mantis Necral", "arch": "hunter", "hp": 1500, "dmg": 92, "vel": 128, "size": 24, "shape": "insect", "color": Color("4a2a5a"), "accent": Color("6aff6a"), "credits": 1600, "drops": {"quitina": 20, "gel_entropico": 4, "oro": 2}, "nexo": 0.0006},
	"bulbo_sangrante": {"name": "Bulbo Sangrante", "arch": "artillery", "hp": 2100, "dmg": 135, "vel": 55, "size": 30, "shape": "oval", "color": Color("7a2a3a"), "accent": Color("ff2a4a"), "credits": 1950, "drops": {"bioaleacion": 8, "resina_plasma": 12, "gel_entropico": 5}, "nexo": 0.0007},
	"caparazon_orax": {"name": "Caparazón Orax", "arch": "tank", "hp": 4200, "dmg": 110, "vel": 52, "size": 44, "shape": "oval", "color": Color("2a2a2a"), "accent": Color("ff8a2a"), "credits": 2700, "drops": {"quitina": 35, "bioaleacion": 10, "platino": 1}, "nexo": 0.0009},
	"sifon_myr": {"name": "Sifón Myr", "arch": "drainer", "hp": 1900, "dmg": 75, "vel": 92, "size": 26, "shape": "claw", "color": Color("3a5a7a"), "accent": Color("4ab8ff"), "credits": 1850, "drops": {"resina_plasma": 14, "paladio": 3, "bioaleacion": 6}, "nexo": 0.0007},
	"espora_kraal": {"name": "Espora Kraal", "arch": "miner", "hp": 620, "dmg": 130, "vel": 80, "size": 17, "shape": "claw", "color": Color("4a6a3a"), "accent": Color("8aff4a"), "credits": 920, "drops": {"gel_entropico": 7, "quitina": 12, "nanoespuma": 6}, "nexo": 0.0004},
	"cirujano_vex": {"name": "Cirujano Vex", "arch": "support", "hp": 1700, "dmg": 50, "vel": 95, "size": 26, "shape": "insect", "color": Color("d8d0d0"), "accent": Color("ff3a3a"), "credits": 2050, "drops": {"bioaleacion": 9, "polvo_cuantico": 2, "plata": 12}, "nexo": 0.0008},
	"raptor_medula": {"name": "Raptor de Médula", "arch": "ambusher", "hp": 1300, "dmg": 105, "vel": 145, "size": 24, "shape": "needle", "color": Color("2a2a3a"), "accent": Color("8a6aff"), "credits": 1750, "drops": {"quitina": 17, "oro": 3, "fibra_fase": 1}, "nexo": 0.0007},
	"nexo_umbilical": {"name": "Nexo Umbilical", "arch": "mother", "hp": 3400, "dmg": 72, "vel": 60, "size": 40, "shape": "nest", "color": Color("6a3a4a"), "accent": Color("ff6ad8"), "credits": 2900, "drops": {"bioaleacion": 14, "gel_entropico": 8, "cristal_helix": 1}, "nexo": 0.0011, "spawns": "larva_vesper"},
	"matriarca_vesper": {"name": "Matriarca Vesper", "arch": "mother", "hp": 6500, "dmg": 125, "vel": 45, "size": 62, "shape": "mother", "color": Color("5a2a6a"), "accent": Color("c86bff"), "credits": 4800, "drops": {"bioaleacion": 25, "quitina": 40, "fragmento_vacio": 1}, "nexo": 0.0018, "spawns": "larva_vesper"},
	# Legión Prismática (21-30)
	"esquirla_lux": {"name": "Esquirla Lux", "arch": "harasser", "hp": 1000, "dmg": 65, "vel": 120, "size": 20, "shape": "hex", "color": Color("d8e8ff"), "accent": Color("ffffff"), "credits": 1150, "drops": {"xenocristal": 12, "vidrio_estelar": 10, "plata": 10}, "nexo": 0.0005},
	"prisma_rho": {"name": "Prisma Rho", "arch": "hunter", "hp": 1650, "dmg": 95, "vel": 116, "size": 24, "shape": "tri", "color": Color("8af7ff"), "accent": Color("ffffff"), "credits": 1750, "drops": {"xenocristal": 18, "oro": 4, "vidrio_estelar": 8}, "nexo": 0.0007},
	"espejo_kappa": {"name": "Espejo Kappa", "arch": "defender", "hp": 2400, "dmg": 70, "vel": 74, "size": 32, "shape": "hex", "color": Color("1a1a24"), "accent": Color("9ad8ff"), "credits": 2200, "drops": {"vidrio_estelar": 18, "paladio": 4, "xenocristal": 10}, "nexo": 0.0008},
	"lanza_solaris": {"name": "Lanza Solaris", "arch": "sniper", "hp": 1800, "dmg": 180, "vel": 68, "size": 28, "shape": "needle", "color": Color("fff0a0"), "accent": Color("ffd84a"), "credits": 2450, "drops": {"xenocristal": 20, "iridio": 4, "polvo_cuantico": 2}, "nexo": 0.0010},
	"corona_lumen": {"name": "Corona Lumen", "arch": "support", "hp": 2300, "dmg": 55, "vel": 72, "size": 30, "shape": "nest", "color": Color("c8d8ff"), "accent": Color("ffe8a0"), "credits": 2250, "drops": {"vidrio_estelar": 16, "paladio": 5, "polvo_cuantico": 2}, "nexo": 0.0009},
	"golem_faceta": {"name": "Gólem Faceta", "arch": "tank", "hp": 4700, "dmg": 115, "vel": 50, "size": 46, "shape": "hex", "color": Color("9ad8e8"), "accent": Color("ff9aff"), "credits": 3100, "drops": {"xenocristal": 30, "platino": 4, "osmio": 3}, "nexo": 0.0011},
	"cortador_helio": {"name": "Cortador Helio", "arch": "charger", "hp": 2200, "dmg": 125, "vel": 98, "size": 30, "shape": "drill", "color": Color("ff9a3a"), "accent": Color("fff0a0"), "credits": 2380, "drops": {"vidrio_estelar": 14, "oro": 5, "iridio": 3}, "nexo": 0.0009},
	"orbe_lambda": {"name": "Orbe Lambda", "arch": "artillery", "hp": 2600, "dmg": 145, "vel": 58, "size": 30, "shape": "oval", "color": Color("6ab8d8"), "accent": Color("aaffff"), "credits": 2700, "drops": {"polvo_cuantico": 4, "xenocristal": 20, "plata": 16}, "nexo": 0.0010},
	"arconte_espectral": {"name": "Arconte Espectral", "arch": "elite", "hp": 4200, "dmg": 165, "vel": 88, "size": 38, "shape": "insect", "color": Color("e8f0ff"), "accent": Color("8affff"), "credits": 3900, "drops": {"aetherium": 2, "xenocristal": 25, "vidrio_estelar": 20}, "nexo": 0.0016},
	"catedral_prismatica": {"name": "Catedral Prismática", "arch": "mother", "hp": 7600, "dmg": 135, "vel": 42, "size": 68, "shape": "mother", "color": Color("b8e8ff"), "accent": Color("ffffff"), "credits": 5400, "drops": {"xenocristal": 45, "aetherium": 3, "cristal_helix": 2}, "nexo": 0.0020, "spawns": "esquirla_lux"},
	# Culto del Vacío (31-40)
	"acaro_umbral": {"name": "Ácaro Umbral", "arch": "swarm", "hp": 950, "dmg": 68, "vel": 132, "size": 17, "shape": "claw", "color": Color("141418"), "accent": Color("ffffff"), "credits": 1250, "drops": {"fragmento_vacio": 2, "ferrita": 12, "gel_entropico": 3}, "nexo": 0.0006},
	"cuchilla_nula": {"name": "Cuchilla Nula", "arch": "ambusher", "hp": 1750, "dmg": 112, "vel": 138, "size": 24, "shape": "tri", "color": Color("101014"), "accent": Color("ff2ad8"), "credits": 1950, "drops": {"fibra_fase": 2, "fragmento_vacio": 3, "iridio": 2}, "nexo": 0.0008},
	"monje_graviton": {"name": "Monje Gravitón", "arch": "control", "hp": 2500, "dmg": 82, "vel": 70, "size": 30, "shape": "nest", "color": Color("2a2a3a"), "accent": Color("8a4aff"), "credits": 2550, "drops": {"graviton": 1, "materia_oscura": 2, "oro": 4}, "nexo": 0.0011},
	"pozo_menor": {"name": "Pozo Menor", "arch": "trap", "hp": 1800, "dmg": 95, "vel": 35, "size": 28, "shape": "oval", "color": Color("0a0a10"), "accent": Color("b86aff"), "credits": 2300, "drops": {"materia_oscura": 3, "polvo_cuantico": 3, "plata": 18}, "nexo": 0.0009},
	"profeta_nadir": {"name": "Profeta Nadir", "arch": "support", "hp": 2700, "dmg": 70, "vel": 78, "size": 30, "shape": "skull", "color": Color("3a3a48"), "accent": Color("d8a8ff"), "credits": 2750, "drops": {"aetherium": 2, "fibra_fase": 2, "paladio": 4}, "nexo": 0.0012},
	"carcelero_obsidiana": {"name": "Carcelero Obsidiana", "arch": "defender", "hp": 5200, "dmg": 130, "vel": 48, "size": 44, "shape": "hex", "color": Color("1a1418"), "accent": Color("ff2a2a"), "credits": 3450, "drops": {"materia_oscura": 5, "osmio": 4, "platino": 3}, "nexo": 0.0013},
	"hereje_fase": {"name": "Hereje de Fase", "arch": "ambusher", "hp": 2100, "dmg": 125, "vel": 110, "size": 26, "shape": "needle", "color": Color("1a2a4a"), "accent": Color("4ab8ff"), "credits": 2500, "drops": {"fibra_fase": 4, "aetherium": 1, "oro": 5}, "nexo": 0.0010},
	"campana_vacio": {"name": "Campana del Vacío", "arch": "artillery", "hp": 3300, "dmg": 175, "vel": 52, "size": 36, "shape": "oval", "color": Color("1a1a2a"), "accent": Color("d86aff"), "credits": 3200, "drops": {"fragmento_vacio": 5, "materia_oscura": 4, "iridio": 4}, "nexo": 0.0013},
	"hierofante_cero": {"name": "Hierofante Cero", "arch": "elite", "hp": 5000, "dmg": 180, "vel": 76, "size": 40, "shape": "skull", "color": Color("202028"), "accent": Color("ffffff"), "credits": 4300, "drops": {"aetherium": 3, "graviton": 1, "fragmento_vacio": 6}, "nexo": 0.0018},
	"arca_nadir": {"name": "Arca Nadir", "arch": "mother", "hp": 8600, "dmg": 145, "vel": 40, "size": 72, "shape": "mother", "color": Color("0e0e14"), "accent": Color("ff2ad8"), "credits": 6100, "drops": {"materia_oscura": 8, "fibra_fase": 5, "semilla_singular": 1}, "nexo": 0.0024, "spawns": "cuchilla_nula"},
	# Dominio Leviatán (41-50)
	"dardo_leviatan": {"name": "Dardo Leviatán", "arch": "hunter", "hp": 2400, "dmg": 135, "vel": 150, "size": 26, "shape": "needle", "color": Color("1a3a6a"), "accent": Color("6ac8ff"), "credits": 2850, "drops": {"bioaleacion": 8, "neutronio": 1, "quitina": 18}, "nexo": 0.0011},
	"mandibula_kron": {"name": "Mandíbula Kron", "arch": "charger", "hp": 3900, "dmg": 165, "vel": 92, "size": 36, "shape": "skull", "color": Color("1a1a1a"), "accent": Color("ff3a2a"), "credits": 3600, "drops": {"osmio": 4, "bioaleacion": 10, "gel_entropico": 6}, "nexo": 0.0014},
	"custodio_abisal": {"name": "Custodio Abisal", "arch": "tank", "hp": 6800, "dmg": 150, "vel": 50, "size": 50, "shape": "oval", "color": Color("1a2438"), "accent": Color("b86aff"), "credits": 4500, "drops": {"neutronio": 3, "materia_oscura": 4, "osmio": 5}, "nexo": 0.0017},
	"tejedor_cronal": {"name": "Tejedor Cronal", "arch": "control", "hp": 3400, "dmg": 105, "vel": 82, "size": 32, "shape": "insect", "color": Color("d8d0c0"), "accent": Color("6affe8"), "credits": 3800, "drops": {"cronita": 4, "fibra_fase": 3, "polvo_cuantico": 5}, "nexo": 0.0015},
	"sangre_quasar": {"name": "Sangre de Quásar", "arch": "artillery", "hp": 4100, "dmg": 205, "vel": 60, "size": 36, "shape": "oval", "color": Color("c82a2a"), "accent": Color("ffb84a"), "credits": 4300, "drops": {"resina_plasma": 20, "antimateria": 2, "iridio": 5}, "nexo": 0.0017},
	"pastor_nidos": {"name": "Pastor de Nidos", "arch": "mother", "hp": 4600, "dmg": 115, "vel": 62, "size": 44, "shape": "mother", "color": Color("e8e0d0"), "accent": Color("4a8aff"), "credits": 4200, "drops": {"nucleo_biomecanico": 1, "bioaleacion": 15, "cristal_helix": 2}, "nexo": 0.0018, "spawns": "dardo_leviatan"},
	"espectro_parallax": {"name": "Espectro Parallax", "arch": "ambusher", "hp": 3200, "dmg": 175, "vel": 118, "size": 30, "shape": "tri", "color": Color("e8e8f0"), "accent": Color("ff4a8a"), "credits": 4050, "drops": {"aetherium": 3, "fibra_fase": 4, "cronita": 2}, "nexo": 0.0017},
	"nexo_devorador": {"name": "Nexo Devorador", "arch": "drainer", "hp": 5100, "dmg": 140, "vel": 70, "size": 40, "shape": "claw", "color": Color("2a2a3a"), "accent": Color("8a2aff"), "credits": 4600, "drops": {"materia_oscura": 5, "graviton": 1, "bioaleacion": 12}, "nexo": 0.0019},
	"heraldo_singular": {"name": "Heraldo Singular", "arch": "elite", "hp": 7200, "dmg": 220, "vel": 84, "size": 46, "shape": "insect", "color": Color("f0f0f8"), "accent": Color("1a1a1a"), "credits": 5800, "drops": {"semilla_singular": 1, "neutronio": 4, "aetherium": 4}, "nexo": 0.0026},
	"leviatan_genesis": {"name": "Leviatán Génesis", "arch": "mother", "hp": 12500, "dmg": 240, "vel": 38, "size": 90, "shape": "mother", "color": Color("2a4a7a"), "accent": Color("e8e0d0"), "credits": 9000, "drops": {"semilla_singular": 2, "nucleo_biomecanico": 3, "antimateria": 4, "neutronio": 6}, "nexo": 0.0035, "spawns": "dardo_leviatan"},
}

# --- Biomas (11.1) -------------------------------------------------------------
# enemies: pesos de aparición. elites: nodriza/jefe del sector. border: color de la barrera del mapa.
const BIOMES := {
	"ferron": {
		"name": "Cinturón Ferron", "faction": "Enjambre Ferron", "min_level": 1,
		"desc": "Asteroides, metal oxidado y estaciones rotas.", "hazards": "Nubes de chatarra, minas.",
		"bg": Color("0a0c12"), "rock": Color("4a4038"), "rock_edge": Color("7a6250"), "border": Color(1.0, 0.55, 0.25),
		"enemies": {"xenomita": 30, "chatarrax": 26, "ferroclasto": 10, "aguijon_khepri": 12, "taladro_vorak": 8, "nodo_bastion": 5, "mina_garra": 10, "recolector_morbido": 7, "artillero_ciclope": 7},
		"elites": ["madre_remache"],
		"resources": {"ferrita": 50, "plata": 30, "oro": 12, "titanio": 8},
	},
	"vesper": {
		"name": "Nebulosa Vesper", "faction": "Biomancia Vesper", "min_level": 8,
		"desc": "Gas púrpura, membranas orgánicas, huevos.", "hazards": "Visibilidad reducida, zonas corrosivas.",
		"bg": Color("0e0814"), "rock": Color("3a2440"), "rock_edge": Color("7a4a8a"), "border": Color(0.8, 0.4, 1.0),
		"enemies": {"larva_vesper": 30, "mantis_necral": 14, "bulbo_sangrante": 9, "caparazon_orax": 8, "sifon_myr": 9, "espora_kraal": 10, "cirujano_vex": 6, "raptor_medula": 9, "nexo_umbilical": 5},
		"elites": ["matriarca_vesper"],
		"resources": {"bioaleacion": 25, "quitina": 40, "resina_plasma": 35},
	},
	"prismaticos": {
		"name": "Campos Prismáticos", "faction": "Legión Prismática", "min_level": 16,
		"desc": "Cristales gigantes y refracción.", "hazards": "Rayos reflejados, paredes energéticas.",
		"bg": Color("06101a"), "rock": Color("2a4a5a"), "rock_edge": Color("8ad8f0"), "border": Color(0.5, 1.0, 1.0),
		"enemies": {"esquirla_lux": 30, "prisma_rho": 14, "espejo_kappa": 8, "lanza_solaris": 8, "corona_lumen": 6, "golem_faceta": 8, "cortador_helio": 9, "orbe_lambda": 8, "arconte_espectral": 4},
		"elites": ["catedral_prismatica"],
		"resources": {"xenocristal": 50, "vidrio_estelar": 40, "oro": 10},
	},
	"vacio": {
		"name": "Fractura del Vacío", "faction": "Culto del Vacío", "min_level": 24,
		"desc": "Espacio deformado y materia oscura.", "hazards": "Portales, gravedad variable.",
		"bg": Color("06040a"), "rock": Color("1e1a24"), "rock_edge": Color("6a3a7a"), "border": Color(1.0, 0.3, 0.9),
		"enemies": {"acaro_umbral": 30, "cuchilla_nula": 14, "monje_graviton": 8, "pozo_menor": 7, "profeta_nadir": 6, "carcelero_obsidiana": 7, "hereje_fase": 10, "campana_vacio": 8, "hierofante_cero": 4},
		"elites": ["arca_nadir"],
		"resources": {"materia_oscura": 20, "fibra_fase": 20, "fragmento_vacio": 30, "plata": 30},
	},
	"leviatan": {
		"name": "Jardín Leviatán", "faction": "Dominio Leviatán", "min_level": 32,
		"desc": "Megaorganismos espaciales.", "hazards": "Tentáculos, esporas, zonas vivas.",
		"bg": Color("040a14"), "rock": Color("1a2a3a"), "rock_edge": Color("5a8ab0"), "border": Color(0.4, 0.7, 1.0),
		"enemies": {"dardo_leviatan": 28, "mandibula_kron": 12, "custodio_abisal": 8, "tejedor_cronal": 9, "sangre_quasar": 9, "pastor_nidos": 5, "espectro_parallax": 10, "nexo_devorador": 8, "heraldo_singular": 4},
		"elites": ["leviatan_genesis"],
		"resources": {"bioaleacion": 30, "gel_entropico": 30, "neutronio": 5, "osmio": 20},
	},
	"titan": {"name": "Cementerio Titán", "min_level": 40, "locked": true},
	"corona": {"name": "Corona Solar", "min_level": 48, "locked": true},
	"cronos": {"name": "Anillo de Cronos", "min_level": 56, "locked": true},
	"pozo": {"name": "Pozo Gravitacional", "min_level": 64, "locked": true},
	"umbral": {"name": "Umbral Singular", "min_level": 72, "locked": true},
}

const OBJECTIVES := {
	"limpieza": {"name": "Limpieza", "desc": "Elimina el %d%% de la presencia hostil."},
	"nidos": {"name": "Destruir nidos", "desc": "Destruye %d puntos de aparición."},
}

# --- Rangos y experiencia --------------------------------------------------------
# XP total necesaria para alcanzar el nivel N (N >= 2) = 10 000 x 2^(N-1): 20K, 40K, 80K… nivel 21 máximo.
const MAX_LEVEL := 21
const RANKS := [
	"Soldado Básico", "Soldado", "Soldado de Primera", "Cabo", "Cabo Primero", "Sargento",
	"Sargento Primero", "Sargento Mayor", "Suboficial", "Alférez", "Subteniente", "Teniente",
	"Teniente Primero", "Capitán", "Mayor", "Teniente Coronel", "Coronel", "General de Brigada",
	"General de División", "Teniente General", "General de Ejército",
]

static func xp_for_level(lvl: int) -> int:
	if lvl <= 1:
		return 0
	return 10000 * int(pow(2.0, lvl - 1))

static func level_from_xp(xp: int) -> int:
	var lvl := 1
	while lvl < MAX_LEVEL and xp >= xp_for_level(lvl + 1):
		lvl += 1
	return lvl

## M2: XP por baja = vida base / 8, escalada como la vida enemiga del nivel (x5,8 en el 40) y por la variante.
static func enemy_xp(base_hp: float, level: int, reward_mult: float) -> int:
	return int(round(base_hp / 8.0 * level_hp(1.0, level) / level_hp(1.0, 1) * reward_mult))


## XP de referencia de una baja media del nivel (para objetivos y primeras limpiezas).
static func level_kill_xp(level: int) -> int:
	return enemy_xp(2000.0, level, 1.0)


# --- M1: economía ------------------------------------------------------------------------
const CREDIT_MULT := 0.15              # créditos por baja (antes x1: la flota se compraba en ~3 h; objetivo EH ~150 h)
## Multiplicador de precio de nave por clase (receta completa: créditos y materiales).
const SHIP_TIER_MULT := {"caza": 1.0, "tanque": 2.0, "carguera": 2.0, "crucero": 4.0, "batalla": 8.0}
const SPECIAL_SHIP_MULT := 10.0
const OBJECTIVE_XP_KILLS := 10         # M2: completar el objetivo = 10 bajas medias del nivel
const FIRST_CLEAR_XP_KILLS := 50       # M2: primera limpieza = 50 bajas medias

static func ship_price_mult(id: String) -> float:
	var s: Dictionary = SHIPS[id]
	if s.get("special", false):
		return SPECIAL_SHIP_MULT
	return float(SHIP_TIER_MULT.get(s["class"], 1.0))


# --- M2: nivel del pet ------------------------------------------------------------------------
## El pet recibe el 25% de la XP del jugador; 12 niveles cortos (1→12 ≈ 10 h de juego).
const PET_MAX_LEVEL := 12
const PET_XP_SHARE := 0.25
const PET_XP_BASE := 5200.0  # nivel 1 → 12 en ~8-13 h según el ritmo (playtest: 6700 daba ~17 h, 3950 ~6 h)
const PET_XP_GROWTH := 1.35
const PET_DMG_PER_LEVEL := 0.08        # +8% de daño por nivel del pet
const PET_RATE_PER_LEVEL := 0.03       # -3% de intervalo de disparo por nivel
const PET_THIRD_SLOT_LEVEL := 8        # tercer slot de láser del pet

static func pet_xp_for_level(lvl: int) -> int:
	if lvl <= 1:
		return 0
	return int(PET_XP_BASE * (pow(PET_XP_GROWTH, lvl - 1) - 1.0) / (PET_XP_GROWTH - 1.0))

static func pet_level_from_xp(xp: int) -> int:
	var lvl := 1
	while lvl < PET_MAX_LEVEL and xp >= pet_xp_for_level(lvl + 1):
		lvl += 1
	return lvl


# --- M3: recompensas por rango (se entregan al ascender) ----------------------------------------
## kind: nexo | credits | item | ammo | module (rareza) | perma (bonificación permanente) | ship | unlock
const RANK_REWARDS := {
	2: [{"kind": "nexo", "amount": 25}, {"kind": "item", "id": "repair", "amount": 5}],
	3: [{"kind": "module", "rarity": 1}],
	4: [{"kind": "nexo", "amount": 50}, {"kind": "ammo", "id": "mk2", "amount": 500}],
	5: [{"kind": "unlock", "id": "modules"}, {"kind": "module", "rarity": 2}],
	6: [{"kind": "perma", "stat": "dmg", "amount": 0.01}],
	7: [{"kind": "ship", "id": "raptor_v2"}],
	8: [{"kind": "perma", "stat": "hull", "amount": 0.01}, {"kind": "ammo", "id": "mk3", "amount": 500}],
	9: [{"kind": "module", "rarity": 3}],
	10: [{"kind": "nexo", "amount": 150}, {"kind": "credits", "amount": 250000}],
	11: [{"kind": "perma", "stat": "dmg", "amount": 0.01}],
	12: [{"kind": "ship", "id": "vanguard_m"}],
	13: [{"kind": "module", "rarity": 3}, {"kind": "ammo", "id": "mk4", "amount": 500}],
	14: [{"kind": "perma", "stat": "shield", "amount": 0.02}],
	15: [{"kind": "nexo", "amount": 300}],
	16: [{"kind": "perma", "stat": "dmg", "amount": 0.01}],
	17: [{"kind": "module", "rarity": 4}],
	18: [{"kind": "ship", "id": "seraph_prime"}],
	19: [{"kind": "perma", "stat": "hull", "amount": 0.02}],
	20: [{"kind": "nexo", "amount": 500}, {"kind": "credits", "amount": 5000000}],
	21: [{"kind": "ship", "id": "event_horizon"}, {"kind": "perma", "stat": "dmg", "amount": 0.02}],
}

static func reward_text(r: Dictionary) -> String:
	match r["kind"]:
		"nexo":
			return "%d Cristales Nexo" % r["amount"]
		"credits":
			return "%s créditos" % format_num(r["amount"])
		"item":
			return "%d x %s" % [r["amount"], ITEMS[r["id"]]["name"]]
		"ammo":
			return "%d x %s" % [r["amount"], AMMO[r["id"]]["name"]]
		"module":
			return "Módulo %s" % ITEM_RARITY_NAMES[MODULE_RARITIES[int(r["rarity"])]]
		"perma":
			var names := {"dmg": "daño", "hull": "casco", "shield": "escudo"}
			return "+%d%% de %s permanente" % [int(round(float(r["amount"]) * 100.0)), names.get(r["stat"], r["stat"])]
		"ship":
			return "Nave %s" % SHIPS[r["id"]]["name"]
		"unlock":
			return "Desbloquea los módulos"
	return "?"


# --- M12: seguro de carga -------------------------------------------------------------------
const INSURED_KEEP := 0.5              # con seguro, al morir se conserva el 50% del botín

static func insurance_cost(level: int) -> int:
	return int(round(1500.0 * level_reward(1.0, level) * (1.0 + level * 0.15) / 100.0)) * 100

# --- Dron: láseres exclusivos (10.2) ---------------------------------------------------
const DRONE_LASERS := {
	"pet_pulse": {"name": "Pet-Pulse", "dmg": 0.55, "color": Color("d8ffd0"), "effect": "", "desc": "Disparo estable, bajo consumo.", "cost": {"credits": 3000}},
	"pet_stinger": {"name": "Pet-Stinger", "dmg": 0.50, "color": Color("ffe86a"), "effect": "stinger", "desc": "Cada 5 impactos aplica un golpe 2x.", "cost": {"credits": 15000, "cobalto": 20}},
	"pet_ion": {"name": "Pet-Ion", "dmg": 0.50, "color": Color("6aa8ff"), "effect": "pet_ion", "desc": "+35% daño a escudos.", "cost": {"credits": 18000, "paladio": 4}},
	"pet_arc": {"name": "Pet-Arc", "dmg": 0.45, "color": Color("8ad8ff"), "effect": "chain", "desc": "Puede saltar a un segundo enemigo.", "cost": {"credits": 30000, "iridio": 6}},
	"pet_guard": {"name": "Pet-Guard", "dmg": 0.30, "color": Color("e8e8f0"), "effect": "guard", "desc": "Daño bajo; 5% de destruir proyectiles cercanos.", "cost": {"credits": 25000, "titanio": 30}},
	"pet_marker": {"name": "Pet-Marker", "dmg": 0.35, "color": Color("ff6a6a"), "effect": "marker", "desc": "Marca al objetivo: la nave inflige +3% de daño 3 s.", "cost": {"credits": 28000, "xenocristal": 8}},
}
const DRONE_SLOTS := 2

# --- Módulos (9) ----------------------------------------------------------------------
const MODULE_FAMILIES := {
	"verde": {"name": "Casco", "stat": "hull", "color": Color("5ad16a"), "subs": ["hull_regen", "repair_bonus", "collision_res"]},
	"azul": {"name": "Escudo", "stat": "shield", "color": Color("3aa0ff"), "subs": ["recharge", "recharge_delay", "shield_break"]},
	"rojo": {"name": "Daño", "stat": "dmg", "color": Color("ff4a4a"), "subs": ["crit", "pierce", "elite_dmg"]},
	"amarillo": {"name": "Velocidad", "stat": "speed", "color": Color("ffd84a"), "subs": ["accel", "turn", "boost_cd"]},
}
const MODULE_RARITIES := ["comun", "raro", "epico", "reliquia", "exotico"]
# Bandas del atributo principal (9.3), en %.
const MODULE_BANDS := {
	"hull": [[1, 14], [10, 28], [24, 45], [40, 60], [56, 70]],
	"shield": [[1, 8], [6, 16], [14, 26], [24, 34], [32, 40]],
	"dmg": [[1, 4], [3, 8], [7, 12], [11, 17], [16, 20]],
	"speed": [[1, 3], [2, 6], [5, 9], [8, 12], [11, 15]],
}
const MODULE_LINES := [[1, 1], [1, 2], [2, 2], [2, 3], [3, 3]]   # líneas por rareza (incluye la principal)
const MODULE_SUB_NAMES := {
	"hull_regen": "Regeneración de casco", "repair_bonus": "Reparación recibida", "collision_res": "Resistencia a colisión",
	"recharge": "Recarga de escudo", "recharge_delay": "Retraso de recarga", "shield_break": "Eficiencia al romperse",
	"crit": "Probabilidad crítica", "pierce": "Penetración", "elite_dmg": "Daño a élites",
	"accel": "Aceleración", "turn": "Giro", "boost_cd": "Enfriamiento de impulso",
}
# Cajas crafteables (14.2): pesos por rareza [común, raro, épico, reliquia, exótico].
const MODULE_BOXES := {
	"estandar": {"name": "Caja Estándar", "weights": [60.0, 28.0, 10.0, 1.8, 0.2], "recipe": {"credits": 8000, "polvo_cuantico": 3, "cristal_helix": 1}},
	"afinada": {"name": "Caja Afinada", "weights": [35.0, 40.0, 20.0, 4.4, 0.6], "recipe": {"credits": 20000, "cristal_helix": 3, "xenocristal": 10}},
	"reliquia": {"name": "Caja Reliquia", "weights": [0.0, 0.0, 80.0, 18.0, 2.0], "recipe": {"credits": 60000, "aetherium": 2, "cristal_helix": 4, "seals": 5}},
	"anomala": {"name": "Caja Anómala", "weights": [20.0, 35.0, 30.0, 12.0, 3.0], "recipe": {"credits": 40000, "fragmento_vacio": 3, "materia_oscura": 2, "nexo": 50}},
}
const PITY_RELIC := 40    # Reliquia garantizada tras 40 cajas sin Reliquia/Exótico
const PITY_EXOTIC := 100  # a partir de 100 sin Exótico, su probabilidad sube

# --- Obstáculos por bioma (sprites en assets/sprites/obstacles/) ---------------------------
const OBSTACLES_COMMON := ["rock_1", "rock_2", "rock_3", "rock_4", "junk_1", "junk_2", "junk_3", "wreck_1", "wreck_2"]
const OBSTACLES_BIOME := {
	"ferron": ["ferron_1", "ferron_2", "junk_1", "junk_3", "wreck_1"],
	"vesper": ["vesper_1", "vesper_2", "vesper_1"],
	"prismaticos": ["prismaticos_1", "prismaticos_2", "prismaticos_1"],
	"vacio": ["vacio_1", "vacio_2", "vacio_1"],
	"leviatan": ["leviatan_1", "leviatan_2", "leviatan_1"],
}

# --- Tienda: precio en créditos (y Nexo si la receta lo pide) --------------------------------
const MAT_VALUE := [20, 45, 160, 650, 2600, 11000]   # valor en créditos por rareza de material

## Precio en la tienda pagando SÓLO con créditos (los materiales de la receta se convierten a créditos;
## la parte en Nexo de la receta no se cobra: la moneda premium es una alternativa, no un extra).
static func shop_price(recipe: Dictionary, markup: float = 1.4) -> Dictionary:
	var credits := float(recipe.get("credits", 0))
	for k in recipe.keys():
		if k in ["credits", "nexo", "seals"]:
			continue
		var r: int = MATERIALS.get(k, {}).get("rarity", 0)
		credits += MAT_VALUE[r] * float(recipe[k])
	return {"credits": maxi(100, int(round(credits * markup / 100.0)) * 100)}


## Precio alternativo pagando SÓLO con Cristales Nexo (equivalente al precio en créditos).
static func nexo_price(recipe: Dictionary) -> Dictionary:
	var credits := float(shop_price(recipe)["credits"])
	var n := credits / NEXO_RATE
	var rounded := int(ceil(n)) if n < 50.0 else int(round(n / 10.0)) * 10
	return {"nexo": maxi(1, rounded)}



# --- Fórmulas (12.2, 14.1, 23) -----------------------------------------------
static func level_hp(base: float, level: int) -> float:
	return base * pow(1.0 + 0.085 * level, 1.18)

## M7: el daño enemigo crece algo más despacio (0,045 en vez de 0,060) para que el equipo pueda seguirle el paso.
static func level_dmg(base: float, level: int) -> float:
	return base * pow(1.0 + 0.045 * level, 1.10)

static func level_reward(base: float, level: int) -> float:
	return base * (1.0 + 0.045 * level)

## Multiplicador de componente por nivel: +1% por nivel sobre el valor base.
## Los láseres ganan +3% por nivel de mejora (antes +1%: mejorar casi no se notaba).
const LASER_LEVEL_STEP := 0.03


static func laser_mult(level: int) -> float:
	return 1.0 + LASER_LEVEL_STEP * level


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


# --- Escalado por bioma ---------------------------------------------------------------------
## Cada facción ya trae estadísticas base más altas según su bioma; el multiplicador de nivel se
## calcula desde el nivel mínimo del bioma (si no, la dificultad contaba dos veces).
const EFF_LEVEL_OFFSET := 1.0

static var _biome_factor_cache: Dictionary = {}


static func eff_level(level: int, biome_id: String) -> int:
	var mn := int(BIOMES.get(biome_id, {}).get("min_level", 1))
	return maxi(1, level - int(mn * EFF_LEVEL_OFFSET))


## Vida y daño medios de las especies de un bioma respecto a Ferron.
static func biome_factor(biome_id: String) -> Dictionary:
	if _biome_factor_cache.has(biome_id):
		return _biome_factor_cache[biome_id]
	var avg := func(bid: String) -> Vector2:
		var s := Vector2.ZERO
		var ids: Array = BIOMES[bid].get("enemies", {}).keys()
		for id in ids:
			s += Vector2(float(ENEMIES[id]["hp"]), float(ENEMIES[id]["dmg"]))
		return s / maxf(1.0, ids.size())
	var base: Vector2 = avg.call("ferron")
	var mine: Vector2 = avg.call(biome_id) if BIOMES.get(biome_id, {}).has("enemies") else base
	var f := {"hp": mine.x / base.x, "dmg": mine.y / base.y}
	_biome_factor_cache[biome_id] = f
	return f


## Poder recomendado para un bioma, nivel y Ascensión (mismas potencias que el índice de poder).
static func recommended_power(level: int, biome_id: String, asc: int = 0) -> float:
	var e := eff_level(level, biome_id)
	var f := biome_factor(biome_id)
	var hp: float = f["hp"] * level_hp(1.0, e) / level_hp(1.0, 1) * pow(2.0, asc)
	var dmg: float = f["dmg"] * level_dmg(1.0, e) / level_dmg(1.0, 1) * pow(1.55, asc)
	return 1000.0 * pow(hp, 0.9) * pow(dmg, 0.5)


# --- Naves pesadas y especiales ---------------------------------------------------------------
## Las naves pesadas (lentas, esquivan peor) llevan espacios extra sólo para generadores de escudo.
const HEAVY_SHIELD_SLOTS := {"tanque": 2, "batalla": 2}
## Blindaje de las naves especiales: reducción de daño según su precio (escala logarítmica).
const SPECIAL_DR_BASE := 0.03            # la especial más barata
const SPECIAL_DR_PER_DOUBLING := 0.03    # +3% cada vez que el precio se duplica
const SPECIAL_DR_MAX := 0.15


static func shield_slots(ship_id: String) -> int:
	return int(HEAVY_SHIELD_SLOTS.get(SHIPS[ship_id]["class"], 0))


static func gen_slots_total(ship_id: String) -> int:
	return int(SHIPS[ship_id]["gens"]) + shield_slots(ship_id)


static func special_dr(ship_id: String) -> float:
	var s: Dictionary = SHIPS[ship_id]
	if not s.get("special", false):
		return 0.0
	var cheapest := INF
	for id in SHIPS.keys():
		if SHIPS[id].get("special", false):
			cheapest = minf(cheapest, float(SHIPS[id]["cost"].get("credits", 1)))
	var ratio := float(s["cost"].get("credits", 1)) / maxf(1.0, cheapest)
	return clampf(SPECIAL_DR_BASE + SPECIAL_DR_PER_DOUBLING * log(ratio) / log(2.0), 0.0, SPECIAL_DR_MAX)
