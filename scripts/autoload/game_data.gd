extends Node
## Tablas de balance y contenido (GDD v0.2).
## Todas las cifras son valores iniciales de prototipo; se ajustan aquí sin tocar la lógica.

# --- Constantes globales de combate ---------------------------------------
const LASER_BASE_DAMAGE := 75.0       # v2: daño por disparo de un láser 1.00x con munición x1 (MP-1 de DarkOrbit)
const LASER_RANGE := 620.0            # alcance en unidades de plano
const SPEED_UNIT := 2.3               # 100 de "Velocidad" GDD = 230 unidades/s
const SHIELD_FROM_HULL := 0.0         # v2: sin escudo base; todo el escudo sale de los generadores (DarkOrbit)
const SHIELD_RECHARGE_DELAY := 4.0
const SHIELD_RECHARGE_RATE := 0.06    # fracción del escudo máximo por segundo
const CARGO_UNIT := 20                # 1 de "Carga" GDD = 20 unidades de material
const DEATH_LOOT_LOSS := 0.9          # al morir se pierde el 90% de lo recolectado en el sector (sin aviso)
const VOLLEY_INTERVAL := 1.2          # la nave dispara una andanada con todos sus láseres cada 1.2 s
const ENEMY_DMG_MULT := 1.0          # v2: daño de las tablas de DarkOrbit tal cual
const ENEMY_HP_MULT := 1.0           # v2: vida de las tablas de DarkOrbit tal cual
const ALIEN_HP_SCALE := 1.0          # v2: ajuste global de vida y escudo alienígena (1.0 = DarkOrbit exacto)
const ALIEN_SHIELD_ABSORB := 0.5      # v2: los escudos alienígenas absorben la mitad de cada impacto
const REPAIR_BOT_DELAY := 6.0         # v2: robot de reparación (DarkOrbit): empieza tras 6 s sin recibir daño
const REPAIR_BOT_RATE := 0.015        # v2: fracción del casco reparada por segundo
const ENEMY_BULLET_TURN := 1.2        # rad/s: persiguen a la nave; un impulso o un giro cerrado aún los esquiva
const ASC_UNLOCK_LEVEL := 50          # M9: limpiar este nivel abre la Ascensión
const ASC_MAX := 10
const NEXO_RATE := 2500.0             # v2: créditos equivalentes a 1 Cristal Nexo (1 Uridium de DarkOrbit ~ 2.500 créditos)
const LOOT_BOX_LIFE := 120.0          # segundos que permanece una caja de botín
const MAX_ENEMIES := 160               # tope de enemigos vivos (rendimiento: más allá cae la tasa de fotogramas)
const ENGAGE_BASE := 6                 # enemigos que atacan a la vez (+1 cada 12 niveles); el resto espera a distancia
const BEACON_SPAWN_CAP := 12           # enemigos vivos invocados por las balizas como máximo
const ESCORT_MAX_MOTHERS := 2          # nodrizas atacando a la vez en la escolta
const BEACON_RADIUS := 260.0           # radio de activación de las balizas
const WAIT_GIVE_UP := 20.0             # segundos esperando turno antes de abandonar la persecución

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
	"kestrel_a1": {"name": "Kestrel A1", "class": "caza", "hull": 105000, "speed": 118, "dmg": 1.00, "cargo": 70, "lasers": 5, "gens": 3, "mods": 1, "note": "Muy ágil; frágil.", "cost": {"credits": 0}},
	"raptor_v2": {"name": "Raptor V2", "class": "caza", "hull": 120000, "speed": 112, "dmg": 1.05, "cargo": 75, "lasers": 7, "gens": 3, "mods": 1, "note": "Mejor ofensiva; menor aceleración.", "cost": {"credits": 100000, "titanio": 30, "plata": 60}},
	"needle_s": {"name": "Needle S", "class": "caza", "hull": 97500, "speed": 128, "dmg": 0.95, "cargo": 60, "lasers": 5, "gens": 2, "mods": 1, "note": "Máxima velocidad; poca vida.", "cost": {"credits": 40000, "cobalto": 30, "plata": 40}},
	"falcon_r": {"name": "Falcon R", "class": "caza", "hull": 130000, "speed": 108, "dmg": 1.08, "cargo": 80, "lasers": 7, "gens": 3, "mods": 1, "note": "Equilibrado; coste alto de fabricación.", "cost": {"credits": 195000, "titanio": 60, "oro": 25, "platino": 4}},
	"bulwark_t1": {"name": "Bulwark T1", "class": "tanque", "hull": 312500, "speed": 70, "dmg": 0.92, "cargo": 105, "lasers": 5, "gens": 5, "mods": 2, "note": "Gran vida; lento.", "cost": {"credits": 1500000, "titanio": 180, "osmio": 16}},
	"bastion_h": {"name": "Bastion H", "class": "tanque", "hull": 355000, "speed": 64, "dmg": 0.95, "cargo": 110, "lasers": 7, "gens": 5, "mods": 2, "note": "Escudo eficiente; giro pesado.", "cost": {"credits": 4000000, "titanio": 240, "paladio": 30}},
	"mammoth_k": {"name": "Mammoth K", "class": "tanque", "hull": 420000, "speed": 58, "dmg": 0.88, "cargo": 130, "lasers": 7, "gens": 6, "mods": 2, "note": "Máxima resistencia; DPS bajo.", "cost": {"credits": 6000000, "osmio": 50, "titanio": 300}},
	"aegis_r": {"name": "Aegis R", "class": "tanque", "hull": 332500, "speed": 72, "dmg": 1.00, "cargo": 100, "lasers": 7, "gens": 5, "mods": 2, "note": "Tanque ofensivo; menor carga.", "cost": {"credits": 3000000, "iridio": 30, "titanio": 240}},
	"mule_c1": {"name": "Mule C1", "class": "carguera", "hull": 180000, "speed": 78, "dmg": 0.82, "cargo": 260, "lasers": 4, "gens": 4, "mods": 1, "note": "Carga alta; defensa limitada.", "cost": {"credits": 60000, "ferrita": 400, "nanoespuma": 120}},
	"atlas_c4": {"name": "Atlas C4", "class": "carguera", "hull": 215000, "speed": 74, "dmg": 0.86, "cargo": 340, "lasers": 5, "gens": 4, "mods": 2, "note": "Gran carga; lenta.", "cost": {"credits": 400000, "ferrita": 800, "titanio": 160}},
	"nomad_c": {"name": "Nomad C", "class": "carguera", "hull": 170000, "speed": 88, "dmg": 0.88, "cargo": 230, "lasers": 5, "gens": 3, "mods": 1, "note": "Carguera móvil; poca vida.", "cost": {"credits": 150000, "cobalto": 100, "plata": 200}},
	"prospector_ix": {"name": "Prospector IX", "class": "carguera", "hull": 235000, "speed": 70, "dmg": 0.90, "cargo": 390, "lasers": 5, "gens": 5, "mods": 2, "note": "Recolección máxima; silueta grande.", "cost": {"credits": 900000, "titanio": 300, "platino": 24}},
	"vanguard_m": {"name": "Vanguard M", "class": "crucero", "hull": 245000, "speed": 92, "dmg": 1.08, "cargo": 150, "lasers": 9, "gens": 5, "mods": 2, "note": "Versátil; coste de mantenimiento medio.", "cost": {"credits": 15000000, "iridio": 80, "xenocristal": 100}},
	"centurion_p": {"name": "Centurion P", "class": "crucero", "hull": 280000, "speed": 84, "dmg": 1.12, "cargo": 160, "lasers": 11, "gens": 5, "mods": 2, "note": "Alto DPS; menos movilidad.", "cost": {"credits": 35000000, "iridio": 140, "platino": 80}},
	"orion_m7": {"name": "Orion M7", "class": "crucero", "hull": 262500, "speed": 90, "dmg": 1.05, "cargo": 180, "lasers": 9, "gens": 6, "mods": 2, "note": "Buen balance de slots.", "cost": {"credits": 25000000, "xenocristal": 160, "paladio": 80}},
	"helios_d": {"name": "Helios D", "class": "crucero", "hull": 225000, "speed": 98, "dmg": 1.15, "cargo": 140, "lasers": 11, "gens": 4, "mods": 2, "note": "Ofensivo; menor resistencia.", "cost": {"credits": 30000000, "xenocristal": 180, "iridio": 120}},
	"titan_b1": {"name": "Titan B1", "class": "batalla", "hull": 445000, "speed": 70, "dmg": 1.15, "cargo": 190, "lasers": 12, "gens": 7, "mods": 3, "note": "Potencia bruta; lento.", "cost": {"credits": 60000000, "osmio": 480, "neutronio": 32}},
	"imperator_vx": {"name": "Imperator VX", "class": "batalla", "hull": 487500, "speed": 66, "dmg": 1.18, "cargo": 200, "lasers": 14, "gens": 7, "mods": 3, "note": "Muchos láseres; caro.", "cost": {"credits": 100000000, "iridio": 720, "neutronio": 48}},
	"leviathan_k": {"name": "Leviathan K", "class": "batalla", "hull": 560000, "speed": 60, "dmg": 1.12, "cargo": 220, "lasers": 12, "gens": 8, "mods": 3, "note": "Vida máxima; baja velocidad.", "cost": {"credits": 125000000, "osmio": 960, "neutronio": 64}},
	"nova_rex": {"name": "Nova Rex", "class": "batalla", "hull": 412500, "speed": 76, "dmg": 1.22, "cargo": 175, "lasers": 14, "gens": 6, "mods": 3, "note": "DPS alto; menos tanque que sus pares.", "cost": {"credits": 90000000, "xenocristal": 960, "neutronio": 48}},
	# Naves especiales (6.1): +8%..18% de poder efectivo y habilidad propia.
	"specter_x": {"name": "Specter-X", "class": "caza", "special": true, "hull": 115500, "speed": 127, "dmg": 1.08, "cargo": 70, "lasers": 7, "gens": 3, "mods": 1, "ability": "phase", "note": "Fase: 1.5 s de intangibilidad.", "cost": {"credits": 2500000, "fragmento_vacio": 60, "fibra_fase": 40, "nexo": 300}},
	"fortress_omega": {"name": "Fortress Ω", "class": "tanque", "special": true, "hull": 356250, "speed": 70, "dmg": 0.98, "cargo": 105, "lasers": 5, "gens": 5, "mods": 2, "ability": "anchor", "note": "Ancla defensiva: -35% velocidad, +35% escudo 6 s.", "cost": {"credits": 12000000, "osmio": 400, "paladio": 300, "nexo": 400}},
	"ark_meridian": {"name": "Ark Meridian", "class": "carguera", "special": true, "hull": 201500, "speed": 82, "dmg": 0.86, "cargo": 312, "lasers": 4, "gens": 4, "mods": 1, "ability": "compressor", "note": "Compresor: recoge botín cercano 8 s.", "cost": {"credits": 3000000, "bioaleacion": 400, "nucleo_biomecanico": 20}},
	"seraph_prime": {"name": "Seraph Prime", "class": "crucero", "special": true, "hull": 269500, "speed": 98, "dmg": 1.18, "cargo": 150, "lasers": 11, "gens": 5, "mods": 2, "ability": "prismatic", "note": "Sobrecarga prismática: +cadencia temporal.", "cost": {"credits": 60000000, "xenocristal": 1200, "aetherium": 60, "nexo": 600}},
	"event_horizon": {"name": "Event Horizon", "class": "batalla", "special": true, "hull": 511750, "speed": 74, "dmg": 1.27, "cargo": 190, "lasers": 14, "gens": 7, "mods": 3, "ability": "gravity_well", "note": "Pozo gravitacional: atrae y ralentiza.", "cost": {"credits": 250000000, "graviton": 40, "semilla_singular": 30, "nexo": 1500}},
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
# v2: el daño de un láser crece con su rareza como la escala de DarkOrbit (LF-1/MP-1 65-75, LF-2 140,
# LF-3 175, LF-4 200…); los nuestros llegan más lejos (exóticos x3,2) y conservan sus efectos.
const RARITY_DMG := {"comun": 1.0, "poco_comun": 1.4, "raro": 1.9, "epico": 2.3, "reliquia": 2.7, "exotico": 3.2}
# dmg = multiplicador por proyectil, shots = proyectiles por disparo, rate = disparos/s
const LASERS := {
	"l01": {"name": "L-01 Pulse", "rarity": "comun", "dmg": 1.00, "shots": 1, "rate": 1.0, "effect": "", "color": Color("ff2e2e"), "adv": "Sin efecto adicional.", "dis": "Barato y fiable.", "cost": {"credits": 10000}},
	"l02": {"name": "L-02 Twin Pulse", "rarity": "comun", "dmg": 0.62, "shots": 2, "rate": 1.1, "effect": "twin", "color": Color("a6ff2e"), "adv": "Dos proyectiles paralelos.", "dis": "Peor precisión a distancia.", "cost": {"credits": 40000, "plata": 20}},
	"l03": {"name": "L-03 Prism Needle", "rarity": "poco_comun", "dmg": 1.15, "shots": 1, "rate": 1.0, "effect": "pierce_armor", "color": Color("2ef6ff"), "adv": "+12% penetración de armadura.", "dis": "Menor tamaño de impacto.", "cost": {"credits": 250000, "xenocristal": 4, "plata": 30}},
	"l04": {"name": "L-04 Cadence", "rarity": "poco_comun", "dmg": 0.90, "shots": 1, "rate": 1.3, "effect": "cadence", "color": Color("ffe62e"), "adv": "Cada 4.º disparo inflige 2x daño.", "dis": "Daño individual menor.", "cost": {"credits": 300000, "oro": 6, "cobalto": 20}},
	"l05": {"name": "L-05 Ion Lance", "rarity": "raro", "dmg": 0.95, "shots": 1, "rate": 1.0, "effect": "ion", "color": Color("2e6bff"), "adv": "+45% daño a escudos.", "dis": "-15% daño a casco.", "cost": {"credits": 1500000, "paladio": 6, "plata": 40}},
	"l06": {"name": "L-06 Ember Ray", "rarity": "raro", "dmg": 0.85, "shots": 1, "rate": 1.3, "effect": "burn", "color": Color("ff7a1e"), "adv": "Aplica quemadura acumulable.", "dis": "Débil contra enemigos veloces.", "cost": {"credits": 1600000, "resina_plasma": 30, "cobalto": 20}},
	"l07": {"name": "L-07 Cryo Beam", "rarity": "raro", "dmg": 0.39, "shots": 1, "rate": 2.4, "effect": "slow", "color": Color("c8f0ff"), "adv": "Ralentiza hasta 18%.", "dis": "DPS bajo.", "cost": {"credits": 1400000, "xenocristal": 8, "nanoespuma": 30}},
	"l08": {"name": "L-08 Scatter Prism", "rarity": "raro", "dmg": 0.45, "shots": 5, "rate": 0.7, "effect": "scatter", "color": Color("ff2ec8"), "adv": "Abanico de 5 rayos.", "dis": "Ineficiente a distancia.", "cost": {"credits": 1700000, "xenocristal": 10, "vidrio_estelar": 6}},
	"l09": {"name": "L-09 Arc Chain", "rarity": "epico", "dmg": 0.92, "shots": 1, "rate": 1.0, "effect": "chain", "color": Color("5ac8ff"), "adv": "Salta a 2 objetivos, -30% por salto.", "dis": "Peor contra objetivo único.", "cost": {"credits": 8000000, "iridio": 12, "polvo_cuantico": 6}},
	"l10": {"name": "L-10 Siege Laser", "rarity": "epico", "dmg": 1.80, "shots": 1, "rate": 0.6, "effect": "siege", "color": Color("2effa0"), "adv": "+20% daño a unidades grandes.", "dis": "Cadencia lenta.", "cost": {"credits": 9000000, "iridio": 15, "osmio": 10}},
	"l11": {"name": "L-11 Phase Cutter", "rarity": "epico", "dmg": 1.05, "shots": 1, "rate": 1.3, "effect": "phase", "color": Color("e0a8ff"), "adv": "8% de ignorar escudo y golpear casco.", "dis": "Coste energético alto.", "cost": {"credits": 10000000, "fibra_fase": 2, "iridio": 12}},
	"l12": {"name": "L-12 Resonance", "rarity": "epico", "dmg": 0.88, "shots": 1, "rate": 1.3, "effect": "resonance", "color": Color("2edc4a"), "adv": "Golpes sucesivos: +3%, hasta +18%.", "dis": "Pierde acumulación al cambiar de objetivo.", "cost": {"credits": 9500000, "polvo_cuantico": 10, "vidrio_estelar": 10}},
	"l13": {"name": "L-13 Solar Spear", "rarity": "reliquia", "dmg": 2.20, "shots": 1, "rate": 0.4, "effect": "pierce", "color": Color("fff7c2"), "adv": "Perfora varios enemigos.", "dis": "Recalentamiento.", "cost": {"credits": 25000000, "aetherium": 4, "polvo_cuantico": 20}},
	"l14": {"name": "L-14 Null Ray", "rarity": "reliquia", "dmg": 1.12, "shots": 1, "rate": 1.0, "effect": "weaken", "color": Color("b8bcc8"), "adv": "Reduce 10% el daño enemigo 3 s.", "dis": "No se acumula.", "cost": {"credits": 24000000, "materia_oscura": 4, "paladio": 20}},
	"l15": {"name": "L-15 Singularity Beam", "rarity": "reliquia", "dmg": 1.35, "shots": 1, "rate": 0.6, "effect": "pull", "color": Color("7a2eff"), "adv": "Pequeña atracción al impactar.", "dis": "Consume munición 20% más rápido.", "cost": {"credits": 26000000, "graviton": 1, "materia_oscura": 4}},
	"l16": {"name": "L-16 Quantum Echo", "rarity": "exotico", "dmg": 1.00, "shots": 1, "rate": 1.0, "effect": "echo", "color": Color("ff9ee0"), "adv": "15% de repetir el disparo sin coste.", "dis": "Tirada aleatoria; no garantiza proc.", "cost": {"credits": 60000000, "polvo_cuantico": 60, "cronita": 6, "nexo": 500}},
	"l17": {"name": "L-17 Triune", "rarity": "exotico", "dmg": 0.72, "shots": 3, "rate": 1.0, "effect": "triune", "color": Color("ffb02e"), "adv": "Tres impactos convergentes.", "dis": "Sufre contra objetivos pequeños.", "cost": {"credits": 60000000, "aetherium": 8, "antimateria": 3, "nexo": 500}},
	"l18": {"name": "L-18 Oblivion", "rarity": "exotico", "dmg": 1.55, "shots": 1, "rate": 0.8, "effect": "oblivion", "color": Color("ff2e7a"), "adv": "Cada 10 impactos crea explosión 3x.", "dis": "Muy caro de fabricar/mejorar.", "cost": {"credits": 90000000, "antimateria": 6, "semilla_singular": 1, "nexo": 900}},
}

# --- Munición (7.2) — receta por lote de 100 ---------------------------------
# v2: coste por disparo x1 10 (LCB-10 de DarkOrbit), x2 25, x3 50, x4 90, x5 150, x6 250 créditos: el daño por
# crédito baja x0,8 por nivel de carga (la v1 lo dividía hasta por 68). x1-x3 se compran con créditos; x4-x6 sólo se fabrican
# (materiales farmeados) o se pagan con Cristales Nexo como atajo (GameState.in_shop / nexo_only).
const AMMO := {
	"mk1": {"name": "Carga Mk-I", "short": "x1", "mult": 1.0, "color": Color("d8d8d8"), "recipe": {"credits": 1000}},
	"mk2": {"name": "Carga Mk-II", "short": "x2", "mult": 2.0, "color": Color("6fd17a"), "recipe": {"credits": 2360, "plata": 5, "resina_plasma": 2}},
	"mk3": {"name": "Carga Mk-III", "short": "x3", "mult": 3.0, "color": Color("4aa3ff"), "recipe": {"credits": 4640, "oro": 3, "titanio": 4, "xenocristal": 1}},
	"mk4": {"name": "Carga Mk-IV", "short": "x4", "mult": 4.0, "color": Color("b26bff"), "recipe": {"credits": 7710, "platino": 2, "iridio": 2, "polvo_cuantico": 1}},
	"mk5": {"name": "Carga Mk-V", "short": "x5", "mult": 5.0, "color": Color("ff9a3c"), "recipe": {"credits": 7200, "neutronio": 1, "antimateria": 1, "cronita": 1}},
	"mk6": {"name": "Carga Mk-VI", "short": "x6", "mult": 6.0, "color": Color("ffd84a"), "recipe": {"credits": 11400, "graviton": 1, "materia_oscura": 1}},
}

# --- Puntos de ascenso (mejoras permanentes de nave y cuenta) -----------------------------------
# Se compran con Cristales Nexo, cada punto algo más caro que el anterior (ASCENT_COST_BASE +
# ASCENT_COST_STEP x puntos ya comprados: del 8 al 72, unos 2.600 en total) y se reparten entre
# 13 mejoras de 5 niveles. Reasignar todos cuesta ASCENT_RESET Nexo.
const ASCENT_COST_BASE := 8
const ASCENT_COST_STEP := 1
const ASCENT_RESET := 50
const ASCENT_MAX := 5
const ASCENT_SKILLS := {
	"hull": {"name": "Blindaje reforzado", "group": "Nave", "per": 0.02, "desc": "+%s de casco"},
	"shield": {"name": "Ingeniería de escudos", "group": "Nave", "per": 0.02, "desc": "+%s de escudo"},
	"speed": {"name": "Propulsión", "group": "Nave", "per": 0.01, "desc": "+%s de velocidad"},
	"cargo": {"name": "Logística", "group": "Nave", "per": 0.05, "desc": "+%s de bodega"},
	"repair": {"name": "Nanorreparación", "group": "Nave", "per": 0.06, "desc": "+%s de reparación de los kits"},
	"firepower": {"name": "Potencia de fuego", "group": "Combate", "per": 0.015, "desc": "+%s de daño"},
	"elite": {"name": "Cazador de élites", "group": "Combate", "per": 0.03, "desc": "+%s de daño a variantes y jefes"},
	"missile_dmg": {"name": "Pirotecnia", "group": "Combate", "per": 0.04, "desc": "+%s de daño de misiles"},
	"missile_acc": {"name": "Guiado avanzado", "group": "Combate", "per": 0.02, "desc": "+%s de precisión de misiles"},
	"pet": {"name": "Vínculo con el pet", "group": "Combate", "per": 0.03, "desc": "+%s de daño y experiencia del pet"},
	"credits": {"name": "Codicia", "group": "Cuenta", "per": 0.03, "desc": "+%s de créditos"},
	"materials": {"name": "Fortuna", "group": "Cuenta", "per": 0.03, "desc": "+%s de materiales"},
	"xp": {"name": "Instrucción", "group": "Cuenta", "per": 0.03, "desc": "+%s de experiencia"},
}


# --- Misiles teledirigidos ------------------------------------------------------------------
# El lanzamisiles dispara solo 1 misil cada MISSILE_INTERVAL s al objetivo fijado. Cada misil tiene
# daño base (varía ±20% por impacto, 8% de crítico x1,5), precisión (probabilidad de acertar, menor
# contra blancos rápidos) y, los caros, daño en área. Receta = lote de 10 (el R-1 cuesta ~15-20K créditos
# por hora de juego, como la munición básica: el lanzamisiles dispara unos 900 misiles por hora).
const MISSILE_INTERVAL := 4.0
const MISSILE_RANGE := 820.0
const MISSILE_LOT := 10
const MISSILES := {
	"r1": {"name": "R-1 Chispa", "short": "R1", "dmg": 1000.0, "acc": 0.84, "splash": 0.0, "speed": 520.0, "color": Color("ffb84a"), "recipe": {"credits": 1000}},
	"r2": {"name": "R-2 Aguja", "short": "R2", "dmg": 2000.0, "acc": 0.86, "splash": 0.0, "speed": 560.0, "color": Color("6fd17a"), "recipe": {"credits": 5000, "ferrita": 3}},
	"r3": {"name": "R-3 Martillo", "short": "R3", "dmg": 3000.0, "acc": 0.80, "splash": 0.0, "speed": 480.0, "color": Color("4aa3ff"), "recipe": {"credits": 12000, "titanio": 3}},
	"rt4": {"name": "RT-4 Rastreador", "short": "RT4", "dmg": 4000.0, "acc": 0.97, "splash": 0.0, "speed": 620.0, "color": Color("b26bff"), "recipe": {"credits": 20000, "cobalto": 3, "paladio": 2}},
	"r5": {"name": "R-5 Tormenta", "short": "R5", "dmg": 5000.0, "acc": 0.84, "splash": 140.0, "speed": 520.0, "color": Color("ff9a3c"), "recipe": {"credits": 35000, "titanio": 4, "iridio": 2}},
	"r6": {"name": "R-6 Singular", "short": "R6", "dmg": 6000.0, "acc": 0.88, "splash": 190.0, "speed": 540.0, "color": Color("ffd84a"), "recipe": {"credits": 60000, "osmio": 2, "neutronio": 1}},
}


## Probabilidad de acierto: la del misil, más la bonificación del piloto, menos hasta un 12% contra
## blancos rápidos (los que se mueven a 150 u/s o más).
static func missile_hit_chance(def: Dictionary, target_speed: float, bonus: float = 0.0) -> float:
	return clampf(float(def["acc"]) + bonus - 0.12 * clampf(target_speed / 150.0, 0.0, 1.0), 0.35, 0.98)


# --- Consumibles / desplegables (4.3) — receta por unidad --------------------
const ITEMS := {
	"repair": {"name": "Kit de reparación", "short": "REP", "kind": "instant", "cd": 10.0, "color": Color("6fd17a"), "desc": "Repara 30% del casco.", "recipe": {"credits": 5000, "nanoespuma": 6, "resina_plasma": 2}},
	"boost": {"name": "Impulso consumible", "short": "IMP", "kind": "instant", "cd": 12.0, "color": Color("ffe04a"), "desc": "+40% velocidad durante 5 s.", "recipe": {"credits": 3000, "resina_plasma": 3, "cobalto": 2}},
	"mine": {"name": "Mina de proximidad", "short": "MIN", "kind": "deploy", "cd": 3.0, "color": Color("ff5a5a"), "desc": "Desplegable. Explota cerca de enemigos (daño en área).", "recipe": {"credits": 8000, "ferrita": 10, "cobalto": 4}},
	"shield_cell": {"name": "Celda de escudo", "short": "ESC", "kind": "instant", "cd": 15.0, "color": Color("4ab8ff"), "desc": "Recarga 40% del escudo.", "recipe": {"credits": 6000, "paladio": 1, "plata": 6}},
}

# --- Generadores (8) ---------------------------------------------------------
const GENERATORS := {
	"sg_aegis1": {"name": "SG-Aegis I", "type": "shield", "shield_pts": 1000, "absorb": 0.40, "stats": {}, "trait": "Sin penalización.", "cost": {"credits": 8000}},
	"sg_aegis2": {"name": "SG-Aegis II", "type": "shield", "shield_pts": 2000, "absorb": 0.50, "stats": {"speed": -0.01}, "trait": "+2% masa / -1% velocidad.", "cost": {"credits": 16000, "titanio": 10}},
	"sg_flux": {"name": "SG-Flux", "type": "shield", "shield_pts": 3000, "absorb": 0.55, "stats": {"recharge": 0.08, "hull": -0.04}, "trait": "-4% casco.", "cost": {"credits": 60000, "paladio": 3}},
	"sg_bulwark": {"name": "SG-Bulwark", "type": "shield", "shield_pts": 5000, "absorb": 0.60, "stats": {"speed": -0.04}, "trait": "-4% velocidad.", "cost": {"credits": 128000, "titanio": 30, "osmio": 2}},
	"sg_pulse": {"name": "SG-Pulse", "type": "shield", "shield_pts": 4000, "absorb": 0.60, "stats": {}, "trait": "Al romperse: onda que empuja enemigos; CD 30 s.", "cost": {"credits": 250000, "paladio": 5}},
	"sg_reflect": {"name": "SG-Reflect", "type": "shield", "shield_pts": 4000, "absorb": 0.60, "stats": {}, "trait": "3% de reflejar proyectil ligero.", "cost": {"credits": 250000, "vidrio_estelar": 6}},
	"sg_repair": {"name": "SG-Repair", "type": "shield", "shield_pts": 3500, "absorb": 0.60, "stats": {"shield_regen": 0.004}, "trait": "Regenera 0.4% escudo/s fuera de daño.", "cost": {"credits": 220000, "nanoespuma": 40}},
	"sg_null": {"name": "SG-Null", "type": "shield", "shield_pts": 7000, "absorb": 0.65, "stats": {}, "trait": "-8% duración de estados enemigos.", "cost": {"credits": 1500000, "gel_entropico": 6}},
	"sg_fortress": {"name": "SG-Fortress", "type": "shield", "shield_pts": 9500, "absorb": 0.70, "stats": {"speed": -0.06}, "trait": "-6% velocidad, +5% consumo energético.", "cost": {"credits": 6000000, "osmio": 8, "paladio": 6}},
	"sg_quantum": {"name": "SG-Quantum", "type": "shield", "shield_pts": 10000, "absorb": 0.80, "stats": {}, "trait": "10% de reducir un impacto en 35%; CD 5 s.", "cost": {"credits": 15000000, "polvo_cuantico": 10}},
	"vg_thrust1": {"name": "VG-Thrust I", "type": "speed", "stats": {"speed": 0.025}, "trait": "Sin penalización.", "cost": {"credits": 8000}},
	"vg_thrust2": {"name": "VG-Thrust II", "type": "speed", "stats": {"speed": 0.04, "shield": -0.02}, "trait": "-2% escudo.", "cost": {"credits": 16000, "cobalto": 10}},
	"vg_vector": {"name": "VG-Vector", "type": "speed", "stats": {"speed": 0.03, "accel": 0.08, "hull": -0.03}, "trait": "-3% casco.", "cost": {"credits": 60000, "cobalto": 20}},
	"vg_blink": {"name": "VG-Blink", "type": "speed", "stats": {"speed": 0.04, "boost_cd": -0.08}, "trait": "Reduce 8% CD de impulso.", "cost": {"credits": 128000, "cobalto": 25, "oro": 4}},
	"vg_racer": {"name": "VG-Racer", "type": "speed", "stats": {"speed": 0.07, "shield": -0.07}, "trait": "-7% escudo.", "cost": {"credits": 250000, "cobalto": 30}},
	"vg_inertia": {"name": "VG-Inertia", "type": "speed", "stats": {"speed": 0.03, "turn": 0.12}, "trait": "+12% control de giro.", "cost": {"credits": 90000, "titanio": 20}},
	"vg_overdrive": {"name": "VG-Overdrive", "type": "speed", "stats": {"speed": 0.05}, "trait": "Tras impulso: +6% 2 s; CD 8 s.", "cost": {"credits": 1500000, "resina_plasma": 40}},
	"vg_phase": {"name": "VG-Phase", "type": "speed", "stats": {"speed": 0.045}, "trait": "5% de ignorar ralentizaciones.", "cost": {"credits": 3000000, "fibra_fase": 1}},
	"vg_comet": {"name": "VG-Comet", "type": "speed", "stats": {"speed": 0.08, "hull": -0.08}, "trait": "-8% casco.", "cost": {"credits": 6000000, "cobalto": 60, "oro": 10}},
	"vg_horizon": {"name": "VG-Horizon", "type": "speed", "stats": {"speed": 0.06}, "trait": "Bajo 25% vida: +12% 4 s; CD 25 s.", "cost": {"credits": 12000000, "cronita": 1}},
}

# --- Variantes (12.1) --------------------------------------------------------
const VARIANTS := {
	"base": {"name": "", "hp": 1.0, "reward": 1.0, "dmg": 1.0, "scale": 1.0, "color": Color(0, 0, 0, 0)},
	"boss": {"name": "Boss", "hp": 4.0, "reward": 4.0, "dmg": 2.0, "scale": 1.25, "color": Color("ffb84a")},
	"mega": {"name": "Mega", "hp": 5.0, "reward": 5.0, "dmg": 2.4, "scale": 1.45, "color": Color("ff5a5a")},
	"ultra": {"name": "Ultra", "hp": 6.0, "reward": 6.0, "dmg": 2.8, "scale": 1.6, "color": Color("d05aff")},
	"uber": {"name": "Uber", "hp": 8.0, "reward": 8.0, "dmg": 3.2, "scale": 1.8, "color": Color("4affff")},
}

# --- Bestiario (15) — 50 especies en 5 facciones ------------------------------------
# arch: arquetipo de IA (15.6). size: radio en unidades de plano. shape: silueta de respaldo sin sprite.
# nexo: probabilidad de Cristal Nexo (0.05% = 0.0005). spawns: especie que genera (nodrizas/invocadores).
const ENEMIES := {
	# Enjambre Ferron (1-10)
	"xenomita": {"name": "Xenomita", "arch": "harasser", "hp": 750, "shield": 370, "dmg": 13, "vel": 115, "size": 22, "shape": "insect", "color": Color("8c8f96"), "accent": Color("ff3a3a"), "credits": 380, "xp": 380, "drops": {"ferrita": 20, "plata": 20, "platino": 1}, "nexo": 0.0005},
	"chatarrax": {"name": "Chatarrax", "arch": "swarm", "hp": 540, "shield": 270, "dmg": 9, "vel": 125, "size": 16, "shape": "scrap", "color": Color("7a6a50"), "accent": Color("ffd23a"), "credits": 280, "xp": 280, "drops": {"ferrita": 28, "nanoespuma": 8, "plata": 10}, "nexo": 0.0003},
	"ferroclasto": {"name": "Ferróclasto", "arch": "tank", "hp": 2700, "shield": 2700, "dmg": 73, "vel": 58, "size": 40, "shape": "oval", "color": Color("6b6f78"), "accent": Color("ff6a2a"), "credits": 1000, "xp": 1000, "drops": {"ferrita": 35, "titanio": 15, "osmio": 2}, "nexo": 0.0008},
	"aguijon_khepri": {"name": "Aguijón Khepri", "arch": "hunter", "hp": 1000, "shield": 1000, "dmg": 55, "vel": 135, "size": 20, "shape": "needle", "color": Color("2a2a30"), "accent": Color("ff8a2a"), "credits": 450, "xp": 450, "drops": {"plata": 18, "cobalto": 12, "oro": 3}, "nexo": 0.0006},
	"taladro_vorak": {"name": "Taladro Vorak", "arch": "charger", "hp": 2100, "shield": 2100, "dmg": 83, "vel": 82, "size": 30, "shape": "drill", "color": Color("8a7a2a"), "accent": Color("4ab8ff"), "credits": 830, "xp": 830, "drops": {"titanio": 18, "ferrita": 25, "iridio": 2}, "nexo": 0.0007},
	"nodo_bastion": {"name": "Nodo Bastión", "arch": "support", "hp": 1900, "shield": 1900, "dmg": 32, "vel": 55, "size": 30, "shape": "hex", "color": Color("2f4a3a"), "accent": Color("4ab8ff"), "credits": 770, "xp": 770, "drops": {"paladio": 6, "plata": 22, "ferrita": 20}, "nexo": 0.0008},
	"mina_garra": {"name": "Mina Garra", "arch": "miner", "hp": 420, "shield": 210, "dmg": 35, "vel": 90, "size": 16, "shape": "claw", "color": Color("5a5a60"), "accent": Color("ff2a2a"), "credits": 220, "xp": 220, "drops": {"ferrita": 12, "resina_plasma": 7, "cobalto": 5}, "nexo": 0.0004},
	"recolector_morbido": {"name": "Recolector Mórbido", "arch": "harasser", "hp": 1500, "shield": 750, "dmg": 14, "vel": 75, "size": 28, "shape": "skull", "color": Color("7a5a5a"), "accent": Color("aaff5a"), "credits": 700, "xp": 700, "drops": {"oro": 5, "plata": 15, "nanoespuma": 20}, "nexo": 0.0006},
	"artillero_ciclope": {"name": "Artillero Cíclope", "arch": "artillery", "hp": 2300, "shield": 2300, "dmg": 100, "vel": 62, "size": 32, "shape": "tri", "color": Color("3a3a40"), "accent": Color("ff2a2a"), "credits": 890, "xp": 890, "drops": {"iridio": 4, "titanio": 18, "ferrita": 18}, "nexo": 0.0009},
	"madre_remache": {"name": "Madre Remache", "arch": "mother", "hp": 4300, "shield": 2200, "dmg": 21, "vel": 48, "size": 56, "shape": "mother", "color": Color("5a4a40"), "accent": Color("ff3a3a"), "credits": 1800, "xp": 1800, "drops": {"ferrita": 50, "oro": 8, "platino": 3, "cristal_helix": 1}, "nexo": 0.0015, "spawns": "chatarrax"},
	# Biomancia Vesper (11-20)
	"larva_vesper": {"name": "Larva Vesper", "arch": "swarm", "hp": 3400, "shield": 1700, "dmg": 74, "vel": 118, "size": 17, "shape": "needle", "color": Color("6a3a8a"), "accent": Color("c86bff"), "credits": 960, "xp": 960, "drops": {"quitina": 18, "resina_plasma": 8, "bioaleacion": 2}, "nexo": 0.0004},
	"mantis_necral": {"name": "Mantis Necral", "arch": "hunter", "hp": 7300, "shield": 3700, "dmg": 160, "vel": 128, "size": 24, "shape": "insect", "color": Color("4a2a5a"), "accent": Color("6aff6a"), "credits": 1900, "xp": 1900, "drops": {"quitina": 20, "gel_entropico": 4, "oro": 2}, "nexo": 0.0006},
	"bulbo_sangrante": {"name": "Bulbo Sangrante", "arch": "artillery", "hp": 10000, "shield": 5100, "dmg": 240, "vel": 55, "size": 30, "shape": "oval", "color": Color("7a2a3a"), "accent": Color("ff2a4a"), "credits": 2600, "xp": 2600, "drops": {"bioaleacion": 8, "resina_plasma": 12, "gel_entropico": 5}, "nexo": 0.0007},
	"caparazon_orax": {"name": "Caparazón Orax", "arch": "tank", "hp": 34000, "shield": 17000, "dmg": 460, "vel": 52, "size": 44, "shape": "oval", "color": Color("2a2a2a"), "accent": Color("ff8a2a"), "credits": 10000, "xp": 5100, "drops": {"quitina": 35, "bioaleacion": 10, "platino": 1}, "nexo": 0.0009},
	"sifon_myr": {"name": "Sifón Myr", "arch": "drainer", "hp": 15000, "shield": 7600, "dmg": 320, "vel": 92, "size": 26, "shape": "claw", "color": Color("3a5a7a"), "accent": Color("4ab8ff"), "credits": 5000, "xp": 2500, "drops": {"resina_plasma": 14, "paladio": 3, "bioaleacion": 6}, "nexo": 0.0007},
	"espora_kraal": {"name": "Espora Kraal", "arch": "miner", "hp": 3000, "shield": 1500, "dmg": 230, "vel": 80, "size": 17, "shape": "claw", "color": Color("4a6a3a"), "accent": Color("8aff4a"), "credits": 860, "xp": 860, "drops": {"gel_entropico": 7, "quitina": 12, "nanoespuma": 6}, "nexo": 0.0004},
	"cirujano_vex": {"name": "Cirujano Vex", "arch": "support", "hp": 14000, "shield": 6800, "dmg": 210, "vel": 95, "size": 26, "shape": "insect", "color": Color("d8d0d0"), "accent": Color("ff3a3a"), "credits": 4500, "xp": 2300, "drops": {"bioaleacion": 9, "polvo_cuantico": 2, "plata": 12}, "nexo": 0.0008},
	"raptor_medula": {"name": "Raptor de Médula", "arch": "ambusher", "hp": 10000, "shield": 5200, "dmg": 450, "vel": 145, "size": 24, "shape": "needle", "color": Color("2a2a3a"), "accent": Color("8a6aff"), "credits": 3600, "xp": 1800, "drops": {"quitina": 17, "oro": 3, "fibra_fase": 1}, "nexo": 0.0007},
	"nexo_umbilical": {"name": "Nexo Umbilical", "arch": "mother", "hp": 27000, "shield": 14000, "dmg": 310, "vel": 60, "size": 40, "shape": "nest", "color": Color("6a3a4a"), "accent": Color("ff6ad8"), "credits": 8400, "xp": 4200, "drops": {"bioaleacion": 14, "gel_entropico": 8, "cristal_helix": 1}, "nexo": 0.0011, "spawns": "larva_vesper"},
	"matriarca_vesper": {"name": "Matriarca Vesper", "arch": "mother", "hp": 52000, "shield": 26000, "dmg": 530, "vel": 45, "size": 62, "shape": "mother", "color": Color("5a2a6a"), "accent": Color("c86bff"), "credits": 15000, "xp": 7600, "drops": {"bioaleacion": 25, "quitina": 40, "fragmento_vacio": 1}, "nexo": 0.0018, "spawns": "larva_vesper"},
	# Legión Prismática (21-30)
	"esquirla_lux": {"name": "Esquirla Lux", "arch": "harasser", "hp": 22000, "shield": 22000, "dmg": 640, "vel": 120, "size": 20, "shape": "hex", "color": Color("d8e8ff"), "accent": Color("ffffff"), "credits": 7500, "xp": 1900, "drops": {"xenocristal": 12, "vidrio_estelar": 10, "plata": 10}, "nexo": 0.0005},
	"prisma_rho": {"name": "Prisma Rho", "arch": "hunter", "hp": 36000, "shield": 36000, "dmg": 960, "vel": 116, "size": 24, "shape": "tri", "color": Color("8af7ff"), "accent": Color("ffffff"), "credits": 12000, "xp": 2900, "drops": {"xenocristal": 18, "oro": 4, "vidrio_estelar": 8}, "nexo": 0.0007},
	"espejo_kappa": {"name": "Espejo Kappa", "arch": "defender", "hp": 53000, "shield": 53000, "dmg": 690, "vel": 74, "size": 32, "shape": "hex", "color": Color("1a1a24"), "accent": Color("9ad8ff"), "credits": 16000, "xp": 4100, "drops": {"vidrio_estelar": 18, "paladio": 4, "xenocristal": 10}, "nexo": 0.0008},
	"lanza_solaris": {"name": "Lanza Solaris", "arch": "sniper", "hp": 29000, "shield": 23000, "dmg": 1400, "vel": 68, "size": 28, "shape": "needle", "color": Color("fff0a0"), "accent": Color("ffd84a"), "credits": 7800, "xp": 3900, "drops": {"xenocristal": 20, "iridio": 4, "polvo_cuantico": 2}, "nexo": 0.0010},
	"corona_lumen": {"name": "Corona Lumen", "arch": "support", "hp": 37000, "shield": 29000, "dmg": 440, "vel": 72, "size": 30, "shape": "nest", "color": Color("c8d8ff"), "accent": Color("ffe8a0"), "credits": 9700, "xp": 4900, "drops": {"vidrio_estelar": 16, "paladio": 5, "polvo_cuantico": 2}, "nexo": 0.0009},
	"golem_faceta": {"name": "Gólem Faceta", "arch": "tank", "hp": 75000, "shield": 60000, "dmg": 880, "vel": 50, "size": 46, "shape": "hex", "color": Color("9ad8e8"), "accent": Color("ff9aff"), "credits": 19000, "xp": 9300, "drops": {"xenocristal": 30, "platino": 4, "osmio": 3}, "nexo": 0.0011},
	"cortador_helio": {"name": "Cortador Helio", "arch": "charger", "hp": 49000, "shield": 49000, "dmg": 1220, "vel": 98, "size": 30, "shape": "drill", "color": Color("ff9a3a"), "accent": Color("fff0a0"), "credits": 15000, "xp": 3800, "drops": {"vidrio_estelar": 14, "oro": 5, "iridio": 3}, "nexo": 0.0009},
	"orbe_lambda": {"name": "Orbe Lambda", "arch": "artillery", "hp": 42000, "shield": 33000, "dmg": 1140, "vel": 58, "size": 30, "shape": "oval", "color": Color("6ab8d8"), "accent": Color("aaffff"), "credits": 11000, "xp": 5400, "drops": {"polvo_cuantico": 4, "xenocristal": 20, "plata": 16}, "nexo": 0.0010},
	"arconte_espectral": {"name": "Arconte Espectral", "arch": "elite", "hp": 67000, "shield": 54000, "dmg": 1310, "vel": 88, "size": 38, "shape": "insect", "color": Color("e8f0ff"), "accent": Color("8affff"), "credits": 17000, "xp": 8400, "drops": {"aetherium": 2, "xenocristal": 25, "vidrio_estelar": 20}, "nexo": 0.0016},
	"catedral_prismatica": {"name": "Catedral Prismática", "arch": "mother", "hp": 120000, "shield": 97000, "dmg": 1050, "vel": 42, "size": 68, "shape": "mother", "color": Color("b8e8ff"), "accent": Color("ffffff"), "credits": 29000, "xp": 14000, "drops": {"xenocristal": 45, "aetherium": 3, "cristal_helix": 2}, "nexo": 0.0020, "spawns": "esquirla_lux"},
	# Culto del Vacío (31-40)
	"acaro_umbral": {"name": "Ácaro Umbral", "arch": "swarm", "hp": 30000, "shield": 25000, "dmg": 880, "vel": 132, "size": 17, "shape": "claw", "color": Color("141418"), "accent": Color("ffffff"), "credits": 6900, "xp": 3500, "drops": {"fragmento_vacio": 2, "ferrita": 12, "gel_entropico": 3}, "nexo": 0.0006},
	"cuchilla_nula": {"name": "Cuchilla Nula", "arch": "ambusher", "hp": 56000, "shield": 47000, "dmg": 1490, "vel": 138, "size": 24, "shape": "tri", "color": Color("101014"), "accent": Color("ff2ad8"), "credits": 12000, "xp": 6000, "drops": {"fibra_fase": 2, "fragmento_vacio": 3, "iridio": 2}, "nexo": 0.0008},
	"monje_graviton": {"name": "Monje Gravitón", "arch": "control", "hp": 70000, "shield": 70000, "dmg": 650, "vel": 70, "size": 30, "shape": "nest", "color": Color("2a2a3a"), "accent": Color("8a4aff"), "credits": 37000, "xp": 4700, "drops": {"graviton": 1, "materia_oscura": 2, "oro": 4}, "nexo": 0.0011},
	"pozo_menor": {"name": "Pozo Menor", "arch": "trap", "hp": 51000, "shield": 51000, "dmg": 750, "vel": 35, "size": 28, "shape": "oval", "color": Color("0a0a10"), "accent": Color("b86aff"), "credits": 28000, "xp": 3500, "drops": {"materia_oscura": 3, "polvo_cuantico": 3, "plata": 18}, "nexo": 0.0009},
	"profeta_nadir": {"name": "Profeta Nadir", "arch": "support", "hp": 86000, "shield": 72000, "dmg": 880, "vel": 78, "size": 30, "shape": "skull", "color": Color("3a3a48"), "accent": Color("d8a8ff"), "credits": 18000, "xp": 8900, "drops": {"aetherium": 2, "fibra_fase": 2, "paladio": 4}, "nexo": 0.0012},
	"carcelero_obsidiana": {"name": "Carcelero Obsidiana", "arch": "defender", "hp": 150000, "shield": 150000, "dmg": 1050, "vel": 48, "size": 44, "shape": "hex", "color": Color("1a1418"), "accent": Color("ff2a2a"), "credits": 72000, "xp": 9000, "drops": {"materia_oscura": 5, "osmio": 4, "platino": 3}, "nexo": 0.0013},
	"hereje_fase": {"name": "Hereje de Fase", "arch": "ambusher", "hp": 67000, "shield": 56000, "dmg": 1660, "vel": 110, "size": 26, "shape": "needle", "color": Color("1a2a4a"), "accent": Color("4ab8ff"), "credits": 14000, "xp": 7100, "drops": {"fibra_fase": 4, "aetherium": 1, "oro": 5}, "nexo": 0.0010},
	"campana_vacio": {"name": "Campana del Vacío", "arch": "artillery", "hp": 93000, "shield": 93000, "dmg": 1400, "vel": 52, "size": 36, "shape": "oval", "color": Color("1a1a2a"), "accent": Color("d86aff"), "credits": 48000, "xp": 6000, "drops": {"fragmento_vacio": 5, "materia_oscura": 4, "iridio": 4}, "nexo": 0.0013},
	"hierofante_cero": {"name": "Hierofante Cero", "arch": "elite", "hp": 140000, "shield": 140000, "dmg": 1400, "vel": 76, "size": 40, "shape": "skull", "color": Color("202028"), "accent": Color("ffffff"), "credits": 70000, "xp": 8700, "drops": {"aetherium": 3, "graviton": 1, "fragmento_vacio": 6}, "nexo": 0.0018},
	"arca_nadir": {"name": "Arca Nadir", "arch": "mother", "hp": 240000, "shield": 240000, "dmg": 1140, "vel": 40, "size": 72, "shape": "mother", "color": Color("0e0e14"), "accent": Color("ff2ad8"), "credits": 110000, "xp": 14000, "drops": {"materia_oscura": 8, "fibra_fase": 5, "semilla_singular": 1}, "nexo": 0.0024, "spawns": "cuchilla_nula"},
	# Dominio Leviatán (41-50)
	"dardo_leviatan": {"name": "Dardo Leviatán", "arch": "hunter", "hp": 150000, "shield": 150000, "dmg": 1840, "vel": 150, "size": 26, "shape": "needle", "color": Color("1a3a6a"), "accent": Color("6ac8ff"), "credits": 78000, "xp": 9800, "drops": {"bioaleacion": 8, "neutronio": 1, "quitina": 18}, "nexo": 0.0011},
	"mandibula_kron": {"name": "Mandíbula Kron", "arch": "charger", "hp": 240000, "shield": 240000, "dmg": 2240, "vel": 92, "size": 36, "shape": "skull", "color": Color("1a1a1a"), "accent": Color("ff3a2a"), "credits": 120000, "xp": 15000, "drops": {"osmio": 4, "bioaleacion": 10, "gel_entropico": 6}, "nexo": 0.0014},
	"custodio_abisal": {"name": "Custodio Abisal", "arch": "tank", "hp": 370000, "shield": 240000, "dmg": 3150, "vel": 50, "size": 50, "shape": "oval", "color": Color("1a2438"), "accent": Color("b86aff"), "credits": 250000, "xp": 31000, "drops": {"neutronio": 3, "materia_oscura": 4, "osmio": 5}, "nexo": 0.0017},
	"tejedor_cronal": {"name": "Tejedor Cronal", "arch": "control", "hp": 210000, "shield": 210000, "dmg": 1440, "vel": 82, "size": 32, "shape": "insect", "color": Color("d8d0c0"), "accent": Color("6affe8"), "credits": 110000, "xp": 13000, "drops": {"cronita": 4, "fibra_fase": 3, "polvo_cuantico": 5}, "nexo": 0.0015},
	"sangre_quasar": {"name": "Sangre de Quásar", "arch": "artillery", "hp": 220000, "shield": 150000, "dmg": 4290, "vel": 60, "size": 36, "shape": "oval", "color": Color("c82a2a"), "accent": Color("ffb84a"), "credits": 160000, "xp": 19000, "drops": {"resina_plasma": 20, "antimateria": 2, "iridio": 5}, "nexo": 0.0017},
	"pastor_nidos": {"name": "Pastor de Nidos", "arch": "mother", "hp": 250000, "shield": 170000, "dmg": 2450, "vel": 62, "size": 44, "shape": "mother", "color": Color("e8e0d0"), "accent": Color("4a8aff"), "credits": 170000, "xp": 22000, "drops": {"nucleo_biomecanico": 1, "bioaleacion": 15, "cristal_helix": 2}, "nexo": 0.0018, "spawns": "dardo_leviatan"},
	"espectro_parallax": {"name": "Espectro Parallax", "arch": "ambusher", "hp": 200000, "shield": 200000, "dmg": 2360, "vel": 118, "size": 30, "shape": "tri", "color": Color("e8e8f0"), "accent": Color("ff4a8a"), "credits": 100000, "xp": 13000, "drops": {"aetherium": 3, "fibra_fase": 4, "cronita": 2}, "nexo": 0.0017},
	"nexo_devorador": {"name": "Nexo Devorador", "arch": "drainer", "hp": 280000, "shield": 180000, "dmg": 2980, "vel": 70, "size": 40, "shape": "claw", "color": Color("2a2a3a"), "accent": Color("8a2aff"), "credits": 190000, "xp": 24000, "drops": {"materia_oscura": 5, "graviton": 1, "bioaleacion": 12}, "nexo": 0.0019},
	"heraldo_singular": {"name": "Heraldo Singular", "arch": "elite", "hp": 390000, "shield": 260000, "dmg": 4640, "vel": 84, "size": 46, "shape": "insect", "color": Color("f0f0f8"), "accent": Color("1a1a1a"), "credits": 260000, "xp": 32000, "drops": {"semilla_singular": 1, "neutronio": 4, "aetherium": 4}, "nexo": 0.0026},
	"leviatan_genesis": {"name": "Leviatán Génesis", "arch": "mother", "hp": 670000, "shield": 450000, "dmg": 5080, "vel": 38, "size": 90, "shape": "mother", "color": Color("2a4a7a"), "accent": Color("e8e0d0"), "credits": 420000, "xp": 53000, "drops": {"semilla_singular": 2, "nucleo_biomecanico": 3, "antimateria": 4, "neutronio": 6}, "nexo": 0.0035, "spawns": "dardo_leviatan"},
}

# --- Biomas (11.1) -------------------------------------------------------------
# Dos mapas por facción: el primero con sus especies débiles y el segundo con las fuertes. Dentro de un
# mapa las especies no cambian: subir el nivel de amenaza endurece a los enemigos y trae más variantes
# (Boss, Mega, Ultra, Uber). theme: facción visual (fondo, música, obstáculos, sonido de disparo).
# temper: distancia (u) a la que sus enemigos detectan al jugador: los débiles sólo atacan si te acercas.
# enemies: pesos de aparición. elites: [jefe del sector, comandante]. border: color de la barrera.
const BIOMES := {
	"ferron": {
		"name": "Cinturón Ferron", "faction": "Enjambre Ferron", "theme": "ferron", "min_level": 1, "temper": 380.0,
		"desc": "Asteroides, metal oxidado y estaciones rotas. Chatarreros y mineros débiles.", "hazards": "Nubes de chatarra, minas.",
		"bg": Color("0a0c12"), "rock": Color("4a4038"), "rock_edge": Color("7a6250"), "border": Color(1.0, 0.55, 0.25),
		"enemies": {"xenomita": 35, "chatarrax": 30, "recolector_morbido": 20, "mina_garra": 15},
		"elites": ["madre_remache", "recolector_morbido"],
		"resources": {"ferrita": 50, "plata": 30, "oro": 12, "titanio": 8},
	},
	"ferron_forja": {
		"name": "Forja Ferron", "faction": "Enjambre Ferron", "theme": "ferron", "min_level": 5, "temper": 480.0,
		"desc": "Astilleros y fundiciones del Enjambre: su maquinaria de guerra.", "hazards": "Artillería, embestidas.",
		"bg": Color("0c0a0a"), "rock": Color("50382c"), "rock_edge": Color("9a5a38"), "border": Color(1.0, 0.45, 0.2),
		"enemies": {"aguijon_khepri": 25, "ferroclasto": 20, "taladro_vorak": 20, "artillero_ciclope": 20, "nodo_bastion": 15},
		"elites": ["ferroclasto", "taladro_vorak"],
		"resources": {"ferrita": 40, "titanio": 30, "oro": 15, "plata": 15},
	},
	"vesper": {
		"name": "Nebulosa Vesper", "faction": "Biomancia Vesper", "theme": "vesper", "min_level": 9, "temper": 420.0,
		"desc": "Gas púrpura y criaderos: larvas, esporas y cazadores jóvenes.", "hazards": "Visibilidad reducida, esporas.",
		"bg": Color("0e0814"), "rock": Color("3a2440"), "rock_edge": Color("7a4a8a"), "border": Color(0.8, 0.4, 1.0),
		"enemies": {"larva_vesper": 35, "mantis_necral": 25, "espora_kraal": 20, "bulbo_sangrante": 20},
		"elites": ["nexo_umbilical", "mantis_necral"],
		"resources": {"quitina": 45, "resina_plasma": 40, "bioaleacion": 15},
	},
	"vesper_colmena": {
		"name": "Colmena Vesper", "faction": "Biomancia Vesper", "theme": "vesper", "min_level": 13, "temper": 520.0,
		"desc": "El corazón orgánico de la colmena y su guardia.", "hazards": "Drenadores, emboscadas, zonas corrosivas.",
		"bg": Color("100612"), "rock": Color("4a2040"), "rock_edge": Color("9a3a8a"), "border": Color(0.9, 0.3, 0.9),
		"enemies": {"raptor_medula": 23, "sifon_myr": 22, "caparazon_orax": 20, "nexo_umbilical": 20, "cirujano_vex": 15},
		"elites": ["matriarca_vesper", "caparazon_orax"],
		"resources": {"bioaleacion": 35, "quitina": 30, "resina_plasma": 25, "gel_entropico": 10},
	},
	"prismaticos": {
		"name": "Campos Prismáticos", "faction": "Legión Prismática", "theme": "prismaticos", "min_level": 17, "temper": 450.0,
		"desc": "Cristales gigantes y refracción: la vanguardia de la Legión.", "hazards": "Rayos reflejados.",
		"bg": Color("06101a"), "rock": Color("2a4a5a"), "rock_edge": Color("8ad8f0"), "border": Color(0.5, 1.0, 1.0),
		"enemies": {"esquirla_lux": 35, "prisma_rho": 25, "cortador_helio": 20, "espejo_kappa": 20},
		"elites": ["golem_faceta", "prisma_rho"],
		"resources": {"xenocristal": 50, "vidrio_estelar": 40, "oro": 10},
	},
	"prismaticos_catedral": {
		"name": "Catedral de Cristal", "faction": "Legión Prismática", "theme": "prismaticos", "min_level": 21, "temper": 550.0,
		"desc": "Santuario de la Legión: francotiradores, artillería y arcontes.", "hazards": "Paredes energéticas, disparos lejanos.",
		"bg": Color("081220"), "rock": Color("34506a"), "rock_edge": Color("a8e0ff"), "border": Color(0.6, 0.9, 1.0),
		"enemies": {"orbe_lambda": 25, "lanza_solaris": 20, "golem_faceta": 20, "arconte_espectral": 20, "corona_lumen": 15},
		"elites": ["catedral_prismatica", "arconte_espectral"],
		"resources": {"xenocristal": 40, "vidrio_estelar": 30, "polvo_cuantico": 15, "aetherium": 5},
	},
	"vacio": {
		"name": "Fractura del Vacío", "faction": "Culto del Vacío", "theme": "vacio", "min_level": 25, "temper": 480.0,
		"desc": "Espacio deformado donde acechan los acólitos del Culto.", "hazards": "Emboscadas en fase.",
		"bg": Color("06040a"), "rock": Color("1e1a24"), "rock_edge": Color("6a3a7a"), "border": Color(1.0, 0.3, 0.9),
		"enemies": {"acaro_umbral": 35, "cuchilla_nula": 25, "hereje_fase": 20, "profeta_nadir": 20},
		"elites": ["carcelero_obsidiana", "hereje_fase"],
		"resources": {"fragmento_vacio": 35, "fibra_fase": 25, "plata": 30, "materia_oscura": 10},
	},
	"vacio_abismo": {
		"name": "Abismo Nadir", "faction": "Culto del Vacío", "theme": "vacio", "min_level": 29, "temper": 580.0,
		"desc": "El templo del Culto: gravedad rota, pozos y campanas.", "hazards": "Portales, gravedad variable.",
		"bg": Color("05030a"), "rock": Color("221a2a"), "rock_edge": Color("8a3a9a"), "border": Color(0.9, 0.2, 1.0),
		"enemies": {"campana_vacio": 25, "monje_graviton": 20, "carcelero_obsidiana": 20, "hierofante_cero": 20, "pozo_menor": 15},
		"elites": ["arca_nadir", "hierofante_cero"],
		"resources": {"materia_oscura": 30, "fragmento_vacio": 25, "graviton": 5, "fibra_fase": 20},
	},
	"leviatan": {
		"name": "Jardín Leviatán", "faction": "Dominio Leviatán", "theme": "leviatan", "min_level": 33, "temper": 500.0,
		"desc": "Praderas de megaorganismos y sus depredadores.", "hazards": "Tentáculos, esporas.",
		"bg": Color("040a14"), "rock": Color("1a2a3a"), "rock_edge": Color("5a8ab0"), "border": Color(0.4, 0.7, 1.0),
		"enemies": {"dardo_leviatan": 35, "mandibula_kron": 25, "tejedor_cronal": 20, "espectro_parallax": 20},
		"elites": ["pastor_nidos", "mandibula_kron"],
		"resources": {"bioaleacion": 35, "gel_entropico": 30, "osmio": 20, "cronita": 5},
	},
	"leviatan_corazon": {
		"name": "Corazón Leviatán", "faction": "Dominio Leviatán", "theme": "leviatan", "min_level": 37, "temper": 600.0,
		"desc": "Dentro del Leviatán Génesis: sus guardianes más antiguos.", "hazards": "Zonas vivas, devoradores.",
		"bg": Color("030812"), "rock": Color("1a2440"), "rock_edge": Color("6a7ad0"), "border": Color(0.5, 0.6, 1.0),
		"enemies": {"sangre_quasar": 25, "custodio_abisal": 20, "nexo_devorador": 20, "pastor_nidos": 20, "heraldo_singular": 15},
		"elites": ["leviatan_genesis", "heraldo_singular"],
		"resources": {"neutronio": 8, "osmio": 25, "antimateria": 4, "bioaleacion": 30, "gel_entropico": 25},
	},
	"titan": {"name": "Cementerio Titán", "min_level": 41, "locked": true},
	"corona": {"name": "Corona Solar", "min_level": 49, "locked": true},
	"cronos": {"name": "Anillo de Cronos", "min_level": 57, "locked": true},
	"pozo": {"name": "Pozo Gravitacional", "min_level": 65, "locked": true},
	"umbral": {"name": "Umbral Singular", "min_level": 73, "locked": true},
}


## Facción visual de un bioma (fondo, música, obstáculos y sonidos los comparten los dos mapas de una facción).
static func theme_of(biome_id: String) -> String:
	return String(BIOMES.get(biome_id, {}).get("theme", biome_id))


const OBJECTIVES := {
	"limpieza": {"name": "Limpieza", "desc": "Elimina el %d%% de la presencia hostil."},
	"nidos": {"name": "Destruir nidos", "desc": "Destruye %d puntos de aparición."},
}

# --- Rangos y experiencia --------------------------------------------------------
# v2: XP total necesaria para alcanzar el nivel N (N >= 2) = 10 000 x 2^(N-2): 10K, 20K, 40K… (DarkOrbit).
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
	return 10000 * int(pow(2.0, lvl - 2))

static func level_from_xp(xp: int) -> int:
	var lvl := 1
	while lvl < MAX_LEVEL and xp >= xp_for_level(lvl + 1):
		lvl += 1
	return lvl

## v2: XP por baja = la del alien (tabla de DarkOrbit), por el escalado dentro del bioma y la variante.
static func enemy_xp(def: Dictionary, eff: int, reward_mult: float) -> int:
	return int(round(float(def.get("xp", 0)) * level_reward(1.0, eff) * reward_mult))


## v2: alien de referencia del bioma de un nivel (el bioma con mayor nivel mínimo que no lo supera).
static func tier_biome(level: int) -> String:
	var best := "ferron"
	var best_min := 0
	for bid in BIOMES.keys():
		var b: Dictionary = BIOMES[bid]
		if b.get("locked", false) or not b.has("enemies"):
			continue
		var mn := int(b.get("min_level", 1))
		if mn <= level and mn > best_min:
			best = bid
			best_min = mn
	return best


## Media de una columna de las especies del bioma (ponderada por su peso de aparición).
static func biome_avg(biome_id: String, key: String) -> float:
	var pool: Dictionary = BIOMES[biome_id].get("enemies", {})
	var s := 0.0
	var w := 0.0
	for id in pool.keys():
		s += float(ENEMIES[id].get(key, 0)) * float(pool[id])
		w += float(pool[id])
	return s / maxf(1.0, w)


## XP de referencia de una baja media del nivel (para objetivos y primeras limpiezas).
static func level_kill_xp(level: int) -> int:
	var bid := tier_biome(level)
	return int(round(biome_avg(bid, "xp") * level_reward(1.0, eff_level(level, bid))))


## v2: créditos de una baja media del nivel: la unidad de las recompensas en créditos (misiones, objetivos,
## temporada, seguro), para que sigan a la escala de DarkOrbit en cada bioma.
static func level_credits(level: int) -> int:
	var bid := tier_biome(level)
	return int(round(biome_avg(bid, "credits") * level_reward(1.0, eff_level(level, bid))))


# --- M1: economía ------------------------------------------------------------------------
const CREDIT_MULT := 1.0               # v2: créditos de la tabla de DarkOrbit tal cual (v1: 0,15)
## Multiplicador de precio de nave por clase (receta completa: créditos y materiales).
const SHIP_TIER_MULT := {"caza": 1.0, "tanque": 1.0, "carguera": 1.0, "crucero": 1.0, "batalla": 1.0}  # v2: precios finales ya en la tabla
const SPECIAL_SHIP_MULT := 1.0
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
# El pet se compra en la tienda y evoluciona en 5 formas; cada forma nueva abre un láser más y, desde la
# tercera, un generador de escudo (sus escudos se proyectan sobre la nave al 50%).
const PET_STAGE_LEVELS := [1, 3, 6, 9, 12]
const PET_STAGE_NAMES := ["Esfera", "Explorador", "Vigía", "Centinela", "Guardián"]
const PET_MAX_LASERS := 5
const PET_MAX_GENS := 3
const PET_GEN_SHARE := 0.5
const PET_RECIPE := {"credits": 500000}  # v2


## Nombre de quien lleva equipado un objeto: una nave o el pet ("drone").
static func holder_name(where: String) -> String:
	return "Pet" if where == "drone" else String(SHIPS.get(where, {}).get("name", where))


## Forma del pet (1-5) según su nivel.
static func pet_stage(lvl: int) -> int:
	var st := 1
	for i in PET_STAGE_LEVELS.size():
		if lvl >= int(PET_STAGE_LEVELS[i]):
			st = i + 1
	return st


static func pet_laser_slots(lvl: int) -> int:
	return pet_stage(lvl)


static func pet_gen_slots(lvl: int) -> int:
	return maxi(0, pet_stage(lvl) - 2)


## Sprite del pet para su forma (cae al de la esfera si esa forma aún no tiene fotogramas).
static func pet_sprite(lvl: int) -> String:
	var id := "pet_s%d" % pet_stage(lvl)
	return id if SpriteLib.has_frames("drone", id) else "drone"

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
	10: [{"kind": "nexo", "amount": 150}, {"kind": "credits", "amount": 2500000}],
	11: [{"kind": "perma", "stat": "dmg", "amount": 0.01}],
	12: [{"kind": "ship", "id": "vanguard_m"}],
	13: [{"kind": "module", "rarity": 3}, {"kind": "ammo", "id": "mk4", "amount": 500}],
	14: [{"kind": "perma", "stat": "shield", "amount": 0.02}],
	15: [{"kind": "nexo", "amount": 300}],
	16: [{"kind": "perma", "stat": "dmg", "amount": 0.01}],
	17: [{"kind": "module", "rarity": 4}],
	18: [{"kind": "ship", "id": "seraph_prime"}],
	19: [{"kind": "perma", "stat": "hull", "amount": 0.02}],
	20: [{"kind": "nexo", "amount": 500}, {"kind": "credits", "amount": 50000000}],
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

## v2: el seguro vale 12 bajas medias del nivel.
static func insurance_cost(level: int) -> int:
	return maxi(100, int(round(12.0 * level_credits(level) / 100.0)) * 100)

# --- Dron: láseres exclusivos (10.2) ---------------------------------------------------
const DRONE_LASERS := {
	"pet_pulse": {"name": "Pet-Pulse", "dmg": 0.55, "color": Color("d8ffd0"), "effect": "", "desc": "Disparo estable, bajo consumo.", "cost": {"credits": 10000}},
	"pet_stinger": {"name": "Pet-Stinger", "dmg": 0.50, "color": Color("ffe86a"), "effect": "stinger", "desc": "Cada 5 impactos aplica un golpe 2x.", "cost": {"credits": 150000, "cobalto": 20}},
	"pet_ion": {"name": "Pet-Ion", "dmg": 0.50, "color": Color("6aa8ff"), "effect": "pet_ion", "desc": "+35% daño a escudos.", "cost": {"credits": 200000, "paladio": 4}},
	"pet_arc": {"name": "Pet-Arc", "dmg": 0.45, "color": Color("8ad8ff"), "effect": "chain", "desc": "Puede saltar a un segundo enemigo.", "cost": {"credits": 1500000, "iridio": 6}},
	"pet_guard": {"name": "Pet-Guard", "dmg": 0.30, "color": Color("e8e8f0"), "effect": "guard", "desc": "Daño bajo; 5% de destruir proyectiles cercanos.", "cost": {"credits": 800000, "titanio": 30}},
	"pet_marker": {"name": "Pet-Marker", "dmg": 0.35, "color": Color("ff6a6a"), "effect": "marker", "desc": "Marca al objetivo: la nave inflige +3% de daño 3 s.", "cost": {"credits": 1000000, "xenocristal": 8}},
}

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
	"estandar": {"name": "Caja Estándar", "weights": [60.0, 28.0, 10.0, 1.8, 0.2], "recipe": {"credits": 100000, "polvo_cuantico": 3, "cristal_helix": 1}},
	"afinada": {"name": "Caja Afinada", "weights": [35.0, 40.0, 20.0, 4.4, 0.6], "recipe": {"credits": 300000, "cristal_helix": 3, "xenocristal": 10}},
	"reliquia": {"name": "Caja Reliquia", "weights": [0.0, 0.0, 80.0, 18.0, 2.0], "recipe": {"credits": 1500000, "aetherium": 2, "cristal_helix": 4, "seals": 5}},
	"anomala": {"name": "Caja Anómala", "weights": [20.0, 35.0, 30.0, 12.0, 3.0], "recipe": {"credits": 600000, "fragmento_vacio": 3, "materia_oscura": 2, "nexo": 50}},
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
## v2: en DarkOrbit la dificultad la dan los aliens de cada mapa (bioma), no un nivel. Dentro de un bioma
## cada nivel de amenaza por encima del mínimo suma +8% de vida y recompensa y +5% de daño. `level` aquí es
## el nivel efectivo (eff_level: 1 = nivel mínimo del bioma).
static func level_hp(base: float, level: int) -> float:
	return base * (1.0 + 0.08 * maxi(0, level - 1))

static func level_dmg(base: float, level: int) -> float:
	return base * (1.0 + 0.05 * maxi(0, level - 1))

static func level_reward(base: float, level: int) -> float:
	return base * (1.0 + 0.08 * maxi(0, level - 1))

## Multiplicador de componente por nivel: +1% por nivel sobre el valor base.
## v2: los láseres tienen 30 niveles de mejora de +2% (hasta +60%); los generadores, 16 de +1%.
const LASER_LEVEL_STEP := 0.02
const LASER_MAX_LEVEL := 30
const GEN_MAX_LEVEL := 16
const UPGRADE_GROWTH := 1.15           # v2: cada nivel cuesta un 15% más (v1: 32%; DarkOrbit: 21,5%)


static func max_item_level(list_key: String) -> int:
	return LASER_MAX_LEVEL if list_key == "lasers" else GEN_MAX_LEVEL


static func laser_mult(level: int) -> float:
	return 1.0 + LASER_LEVEL_STEP * level


static func component_mult(level: int) -> float:
	return 1.0 + 0.01 * level

## Coste para subir un componente desde `level` a `level + 1` (v2: Coste(n) = Base x 1,15^(n-1)).
## Los materiales suben de rareza por tramos: el jugador tiene que farmear cada bioma para completar el
## equipo (sin Cristales Nexo obligatorios, a diferencia de la v1).
static func upgrade_cost(level: int, base_credits: int) -> Dictionary:
	var n := level + 1
	var credits := int(round(base_credits * pow(UPGRADE_GROWTH, n - 1) / 100.0)) * 100
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
	elif n <= 20:
		cost["neutronio"] = int(ceil((n - 12) / 2.0))
		cost["aetherium"] = int(ceil((n - 12) / 3.0))
		cost["polvo_cuantico"] = n - 8
	else:
		cost["graviton"] = int(ceil((n - 20) / 3.0))
		cost["materia_oscura"] = int(ceil((n - 20) / 3.0))
		cost["neutronio"] = n - 18
	return cost


## v2: base de la mejora = 2.500 x raíz(precio / 10.000): crece más despacio que el precio, así que los
## objetos caros no disparan el coste (L-01: 2.500; L-18: 237.000 por el primer nivel).
static func upgrade_base(price: int) -> int:
	return maxi(1000, int(round(2500.0 * sqrt(maxf(1.0, float(price)) / 10000.0))))

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
	# v2: duelo equilibrado = vida efectiva x daño del enemigo frente a la del jugador (power_index):
	# 1000 x raíz((vida + escudo) x daño medios del bioma respecto a Ferron).
	var e := eff_level(level, biome_id)
	var bid := biome_id if BIOMES.get(biome_id, {}).has("enemies") else "ferron"
	var ehp := (biome_avg(bid, "hp") + biome_avg(bid, "shield")) * level_hp(1.0, e) * pow(2.0, asc)
	var dmg := biome_avg(bid, "dmg") * level_dmg(1.0, e) * pow(1.55, asc)
	var base := (biome_avg("ferron", "hp") + biome_avg("ferron", "shield")) * biome_avg("ferron", "dmg")
	return 1000.0 * sqrt(ehp * dmg / maxf(1.0, base))


## v2: índice de poder del jugador en la misma escala: 1000 x raíz(vida efectiva x DPS) respecto a la
## Kestrel de serie (105.000 + 2.000 de escudo, 5 L-01), que vale ~1.440 en Ferron 1 (144% del recomendado).
const POWER_REF := 107000.0 * 312.5
static func power_index(ehp: float, dps: float) -> float:
	return 1440.0 * sqrt(maxf(1.0, ehp * dps) / POWER_REF)


# --- Naves pesadas y especiales ---------------------------------------------------------------
## Las naves pesadas (lentas, esquivan peor) llevan espacios extra sólo para generadores de escudo.
const HEAVY_SHIELD_SLOTS := {"tanque": 2, "batalla": 2}
## Blindaje de las naves especiales: reducción de daño según su precio (escala logarítmica).
const SPECIAL_DR_BASE := 0.03            # la especial más barata
const SPECIAL_DR_PER_DOUBLING := 0.03    # +3% cada vez que el precio se duplica
const SPECIAL_DR_MAX := 0.15


## Tope de enemigos atacando a la vez (los que sobran esperan y entran cuando cae uno).
static func engage_cap(level: int, asc: int = 0) -> int:
	return ENGAGE_BASE + level / 12 + asc


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
