"""Cálculo de la economía a partir de las tablas de scripts/autoload/game_data.gd (v1 o v2).

Modelo por bioma con una nave y un equipo típicos de esa etapa: DPS, tiempo por baja, créditos, gasto
de munición y misiles, neto por minuto, supervivencia frente al grupo de enemigos que ataca a la vez,
XP por minuto y horas hasta cada nave. Es una estimación (no sustituye al bot de pruebas): ignora los
efectos especiales de los láseres, el refinado, los módulos y el pet.

Uso: python tools/economia_calculo.py [ruta a game_data.gd] [--json salida.json]
"""
import json, math, re, sys

PATH = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else "scripts/autoload/game_data.gd"
src = open(PATH, encoding="utf-8").read()


def num(name, default=None):
    m = re.search(r"const %s := ([\d.]+)" % name, src)
    return float(m.group(1)) if m else default


BASE = num("LASER_BASE_DAMAGE")
VOLLEY = num("VOLLEY_INTERVAL")
STEP = num("LASER_LEVEL_STEP")
HP_MULT = num("ENEMY_HP_MULT", 1.0) * num("ALIEN_HP_SCALE", 1.0)
DMG_MULT = num("ENEMY_DMG_MULT", 1.0)
CREDIT_MULT = num("CREDIT_MULT", 1.0)
V2 = "ALIEN_HP_SCALE" in src

enemies = {}
for m in re.finditer(r'^\t"([a-z_]+)": \{"name": "[^"]*", "arch": "[^"]*", "hp": (\d+), (?:"shield": (\d+), )?"dmg": (\d+).*?"credits": (\d+)(?:, "xp": (\d+))?', src, re.M):
    sid, hp, sh, dmg, cr, xp = m.groups()
    enemies[sid] = {"hp": int(hp), "shield": int(sh or 0), "dmg": int(dmg), "credits": int(cr), "xp": int(xp or 0)}
biomes = {}
for m in re.finditer(r'\n\t"([a-z_]+)": \{\n(.*?)\n\t\},', src, re.S):
    en = re.search(r'"enemies": \{([^}]*)\}', m.group(2))
    mn = re.search(r'"min_level": (\d+)', m.group(2))
    if en:
        biomes[m.group(1)] = {"min": int(mn.group(1)), "pool": {k: int(v) for k, v in re.findall(r'"([a-z_]+)": (\d+)', en.group(1))}}
lasers = {}
_rd = re.search(r"const RARITY_DMG := \{([^}]*)\}", src)
RARITY = {k: float(v) for k, v in re.findall(r'"([a-z_]+)": ([\d.]+)', _rd.group(1))} if _rd else {}
for m in re.finditer(r'^\t"(l\d+)": \{"name": "[^"]*", "rarity": "([a-z_]+)", "dmg": ([\d.]+), "shots": (\d+), "rate": ([\d.]+).*?"cost": \{"credits": (\d+)', src, re.M):
    lasers[m.group(1)] = {"dmg": float(m.group(3)) * RARITY.get(m.group(2), 1.0), "shots": int(m.group(4)), "rate": float(m.group(5)), "cost": int(m.group(6))}
ships = {}
for m in re.finditer(r'^\t"([a-z_0-9]+)": \{"name": "[^"]*", "class": "[a-z]+",.*?"hull": (\d+), "speed": \d+, "dmg": ([\d.]+), "cargo": \d+, "lasers": (\d+), "gens": (\d+).*?"cost": \{"credits": (\d+)', src, re.M):
    ships[m.group(1)] = {"hull": int(m.group(2)), "dmg": float(m.group(3)), "lasers": int(m.group(4)), "gens": int(m.group(5)), "cost": int(m.group(6))}
gens = {}
for m in re.finditer(r'^\t"(sg_[a-z0-9]+)": \{[^\n]*?(?:"shield_pts": (\d+), "absorb": ([\d.]+),)?[^\n]*?"stats": \{([^}]*)\}', src, re.M):
    pct = re.search(r'"shield": ([\d.]+)', m.group(4))
    gens[m.group(1)] = {"pts": int(m.group(2) or 0), "absorb": float(m.group(3) or 1.0), "pct": float(pct.group(1)) if pct else 0.0}
SHIELD_FROM_HULL = num("SHIELD_FROM_HULL", 0.5)
ammo_cost = {}
MAT_VALUE = [20, 45, 160, 650, 2600, 11000]
rar = {k: int(v) for k, v in re.findall(r'"([a-z_]+)": \{"name": "[^"]*", "rarity": (\d)\}', src)}


def recipe_value(rec):
    v = 0.0
    for k, q in re.findall(r'"([a-z_]+)": (\d+)', rec):
        v += float(q) if k == "credits" else MAT_VALUE[rar.get(k, 0)] * float(q)
    return v


for m in re.finditer(r'^\t"(mk\d)": \{.*?"recipe": (\{[^}]*\})', src, re.M):
    ammo_cost[m.group(1)] = recipe_value(m.group(2)) / 100.0
miss = {}
for m in re.finditer(r'^\t"(r\d|rt4)": \{.*?"dmg": ([\d.]+), "acc": ([\d.]+).*?"recipe": (\{[^}]*\})', src, re.M):
    miss[m.group(1)] = {"dmg": float(m.group(2)), "acc": float(m.group(3)), "cost": recipe_value(m.group(4)) / 10.0}


def avg(bid, key):
    pool = biomes[bid]["pool"]
    return sum(enemies[s][key] * w for s, w in pool.items()) / sum(pool.values())


def level_hp(eff):
    return 1.0 + 0.08 * (eff - 1) if V2 else (1 + 0.085 * eff) ** 1.18


def level_dmg(eff):
    return 1.0 + 0.05 * (eff - 1) if V2 else (1 + 0.045 * eff) ** 1.10


def level_reward(eff, level):
    return 1.0 + 0.08 * (eff - 1) if V2 else 1 + 0.045 * level


# Etapas: bioma, nivel, nave, láser y nivel de mejora, munición, generador de escudo, misil.
STAGES = [
    ("ferron", 1, "kestrel_a1", "l01", 0, "mk1", "sg_aegis1", "r1"),
    ("ferron_forja", 5, "raptor_v2", "l02", 5, "mk1", "sg_aegis2", "r1"),
    ("vesper", 9, "falcon_r", "l03", 8, "mk2", "sg_flux", "r1"),
    ("vesper_colmena", 13, "bulwark_t1", "l04", 10, "mk2", "sg_bulwark", "r2"),
    ("prismaticos", 17, "vanguard_m", "l05", 12, "mk3", "sg_bulwark", "r2"),
    ("prismaticos_catedral", 21, "centurion_p", "l09", 14, "mk3", "sg_null", "r2"),
    ("vacio", 25, "helios_d", "l10", 16, "mk3", "sg_null", "r3"),
    ("vacio_abismo", 29, "titan_b1", "l13", 18, "mk4", "sg_fortress", "r3"),
    ("leviatan", 33, "imperator_vx", "l14", 20, "mk4", "sg_fortress", "r3"),
    ("leviatan_corazon", 37, "event_horizon", "l17", 25, "mk5", "sg_quantum", "r3"),
]
OVERHEAD = 3.0          # s por baja: acercarse, fijar, recoger
ENGAGED = 6             # enemigos atacando a la vez
ENEMY_SHOT_S = 1.5      # cadencia media de disparo enemigo
HIT = 0.7               # proporción de disparos enemigos que impactan
MISSILE_SHARE = 0.15 if "missile_mode" in open(PATH.replace("game_data.gd", "game_state.gd"), encoding="utf-8").read() else 1.0


def run():
    out = []
    for bid, lvl, sid, lid, lup, ammo, gid, mid in STAGES:
        sh, ls = ships[sid], lasers[lid]
        lvl_mult = 1 + STEP * min(lup, 30 if V2 else 16)
        amult = float(ammo[2])
        per_volley = BASE * ls["dmg"] * ls["rate"] * lvl_mult * VOLLEY * ls["shots"] * sh["lasers"]
        dps = per_volley / VOLLEY * sh["dmg"] * amult
        heavy = 2 if sid in ("bulwark_t1", "titan_b1", "imperator_vx", "event_horizon") else 0
        g = gens[gid]
        n_gen = sh["gens"] + heavy
        if V2:
            shield = g["pts"] * n_gen
            absorb = g["absorb"]
        else:
            shield = sh["hull"] * SHIELD_FROM_HULL * (1 + g["pct"] * n_gen)
            absorb = 1.0
        eff = max(1, lvl - biomes[bid]["min"]) if not V2 else 1
        e_ehp = (avg(bid, "hp") + avg(bid, "shield")) * level_hp(eff) * HP_MULT
        e_dmg = avg(bid, "dmg") * level_dmg(eff) * DMG_MULT
        e_cr = avg(bid, "credits") * level_reward(eff, lvl) * CREDIT_MULT
        e_xp = avg(bid, "xp") * level_reward(eff, lvl) if V2 else avg(bid, "hp") / 8 * level_hp(eff) / level_hp(1)
        ttk = e_ehp / dps
        cycle = ttk + OVERHEAD
        kills_min = 60.0 / cycle
        firing = ttk / cycle
        shots_min = sh["lasers"] * (60.0 / VOLLEY) * firing      # 1 carga por láser y andanada
        ammo_min = shots_min * ammo_cost[ammo]
        m = miss[mid]
        miss_min = 15.0 * firing * m["cost"] * MISSILE_SHARE   # 1 misil cada 4 s mientras dispara
        gross = kills_min * e_cr
        net = gross - ammo_min - miss_min
        incoming = ENGAGED * e_dmg / ENEMY_SHOT_S * HIT
        ehp_p = sh["hull"] + (shield / absorb if absorb > 0 else 0) if V2 else sh["hull"] + shield
        survive = ehp_p / max(1.0, incoming)
        out.append({
            "bioma": bid, "nivel": lvl, "nave": sid, "laser": "%s nv%d" % (lid, lup), "municion": ammo,
            "dps": round(dps), "vida_ef_jugador": round(ehp_p), "vida_ef_alien": round(e_ehp), "dano_alien": round(e_dmg),
            "seg_por_baja": round(ttk, 1), "bajas_min": round(kills_min, 1), "bruto_min": round(gross), "municion_min": round(ammo_min),
            "misiles_min": round(miss_min), "neto_min": round(net), "xp_min": round(kills_min * e_xp),
            "seg_hasta_morir": round(survive), "grupo_seg": round(ENGAGED * ttk), "ratio_supervivencia": round(survive / max(1.0, ENGAGED * ttk), 2),
        })
    return out


rows = run()
cols = ["bioma", "nivel", "nave", "municion", "dps", "seg_por_baja", "bajas_min", "bruto_min", "municion_min", "misiles_min", "neto_min", "xp_min", "ratio_supervivencia"]
print(("v2" if V2 else "v1"), PATH)
print(" | ".join(cols))
for r in rows:
    print(" | ".join(str(r[c]) for c in cols))
# Horas hasta cada nave con el neto de la etapa en que se compra.
buy = [("raptor_v2", 0), ("falcon_r", 1), ("bulwark_t1", 2), ("vanguard_m", 3), ("centurion_p", 4), ("helios_d", 5), ("titan_b1", 6), ("imperator_vx", 7), ("event_horizon", 8)]
hours = []
for sid, st in buy:
    n = max(1, rows[st]["neto_min"])
    hours.append({"nave": sid, "precio": ships[sid]["cost"], "neto_min": n, "horas": round(ships[sid]["cost"] / n / 60.0, 1)})
print("\nHoras de combate por nave (neto de la etapa anterior):")
for h in hours:
    print("  %(nave)-14s %(precio)12d cr  a %(neto_min)8d/min  -> %(horas)6.1f h" % h)
print("  total %.0f h" % sum(h["horas"] for h in hours))
# Mejoras de láser al máximo.
upg = []
for lid in ("l01", "l05", "l10", "l13", "l17", "l18"):
    price = lasers[lid]["cost"]
    if V2:
        base = max(1000, round(2500 * math.sqrt(price / 10000)))
        tot = sum(round(base * 1.15 ** (n - 1) / 100) * 100 for n in range(1, 31))
    else:
        base = max(800, price // 4)
        tot = sum(round(base * 1.32 ** (n - 1)) for n in range(1, 17))
    upg.append({"laser": lid, "precio": price, "mejora_total": tot})
print("\nMejora al máximo por láser:", ", ".join("%s %s" % (u["laser"], "{:,}".format(u["mejora_total"])) for u in upg))
if "--json" in sys.argv:
    json.dump({"etapas": rows, "naves": hours, "mejoras": upg, "municion_por_disparo": ammo_cost, "misiles": miss}, open(sys.argv[sys.argv.index("--json") + 1], "w"), indent=1)
