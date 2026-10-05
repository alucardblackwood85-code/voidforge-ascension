"""Economía v2 (estilo DarkOrbit): tablas del jugador en scripts/autoload/game_data.gd.

- Casco de las naves x25 (Kestrel 105.000, como la Phoenix/Liberator de DarkOrbit).
- Precios de naves, láseres, generadores, pet y cajas en la escala de créditos de DarkOrbit
  (los objetos que allí cuestan Uridium pasan a créditos con 1 Uridium ~ 2.500 créditos).
- Generadores de escudo con escudo fijo y absorción (SG3N-A01 1.000/40% … SG3N-B02 10.000/80%).
- Munición: x1 a 10 créditos por disparo (LCB-10); x2 y x3 con créditos; x4-x6 sólo fabricadas o con Nexo.
- Misiles: R-310 (1.000 de daño, 100 cr), PLT-2026 (2.000, 500 cr), PLT-2021 (4.000), PLT-3030 (6.000).

Uso: python tools/economia_v2_tablas.py
"""
import os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATH = os.path.join(ROOT, "scripts", "autoload", "game_data.gd")
src = open(PATH, encoding="utf-8").read()


def sub(pattern, repl, count=1, flags=0):
    global src
    new, n = re.subn(pattern, repl, src, count=count, flags=flags)
    if n == 0:
        raise SystemExit("No encontrado: " + pattern)
    src = new


# --- Constantes globales ---
sub(r'const LASER_BASE_DAMAGE := 120\.0[^\n]*', 'const LASER_BASE_DAMAGE := 75.0       # v2: daño por disparo de un láser 1.00x con munición x1 (MP-1 de DarkOrbit)')
sub(r'const SHIELD_FROM_HULL := 0\.5[^\n]*', 'const SHIELD_FROM_HULL := 0.0         # v2: sin escudo base; todo el escudo sale de los generadores (DarkOrbit)')
sub(r'const ENEMY_DMG_MULT := 1\.3[^\n]*', 'const ENEMY_DMG_MULT := 1.0          # v2: daño de las tablas de DarkOrbit tal cual')
sub(r'const ENEMY_HP_MULT := 1\.2', 'const ENEMY_HP_MULT := 1.0           # v2: vida de las tablas de DarkOrbit tal cual\nconst ALIEN_HP_SCALE := 1.0          # v2: ajuste global de vida y escudo alienígena (1.0 = DarkOrbit exacto)\nconst ALIEN_SHIELD_ABSORB := 0.5      # v2: los escudos alienígenas absorben la mitad de cada impacto\nconst REPAIR_BOT_DELAY := 6.0         # v2: robot de reparación (DarkOrbit): empieza tras 6 s sin recibir daño\nconst REPAIR_BOT_RATE := 0.015        # v2: fracción del casco reparada por segundo')
sub(r'const NEXO_RATE := 587\.0[^\n]*', 'const NEXO_RATE := 2500.0             # v2: créditos equivalentes a 1 Cristal Nexo (1 Uridium de DarkOrbit ~ 2.500 créditos)')

# --- Naves: casco x25 y precios ---
SHIP_COST = {
    "kestrel_a1": 0, "needle_s": 40000, "raptor_v2": 100000, "falcon_r": 195000,
    "mule_c1": 60000, "nomad_c": 150000, "atlas_c4": 400000, "prospector_ix": 900000,
    "bulwark_t1": 1500000, "aegis_r": 3000000, "bastion_h": 4000000, "mammoth_k": 6000000,
    "vanguard_m": 15000000, "helios_d": 30000000, "orion_m7": 25000000, "centurion_p": 35000000,
    "titan_b1": 60000000, "nova_rex": 90000000, "imperator_vx": 100000000, "leviathan_k": 125000000,
    "specter_x": 2500000, "ark_meridian": 3000000, "fortress_omega": 12000000, "seraph_prime": 60000000,
    "event_horizon": 250000000,
}
TIER = {"caza": 1, "tanque": 2, "carguera": 2, "crucero": 4, "batalla": 8}


def ship_line(m):
    line = m.group(0)
    sid = m.group(1)
    cls = re.search(r'"class": "([a-z]+)"', line).group(1)
    special = '"special": true' in line
    mult = 10 if special else TIER[cls]
    line = re.sub(r'"hull": (\d+)', lambda h: '"hull": %d' % (int(h.group(1)) * 25), line)

    def cost(c):
        parts = []
        for k, v in re.findall(r'"([a-z_]+)": (\d+)', c.group(1)):
            if k == "credits":
                parts.append('"credits": %d' % SHIP_COST[sid])
            elif k == "nexo":
                parts.append('"nexo": %s' % v)
            else:
                parts.append('"%s": %d' % (k, int(v) * mult))   # materiales ya multiplicados por clase
        return '"cost": {%s}' % ", ".join(parts)
    return re.sub(r'"cost": \{([^}]*)\}', cost, line)


sub(r'^\t"([a-z_0-9]+)": \{"name": "[^"]*", "class": [^\n]*$', ship_line, count=0, flags=re.M)
sub(r'const SHIP_TIER_MULT := \{[^}]*\}', 'const SHIP_TIER_MULT := {"caza": 1.0, "tanque": 1.0, "carguera": 1.0, "crucero": 1.0, "batalla": 1.0}  # v2: precios finales ya en la tabla')
sub(r'const SPECIAL_SHIP_MULT := 10\.0', 'const SPECIAL_SHIP_MULT := 1.0')

# --- Láseres ---
LASER_COST = {"l01": 10000, "l02": 40000, "l03": 250000, "l04": 300000, "l05": 1500000, "l06": 1600000,
              "l07": 1400000, "l08": 1700000, "l09": 8000000, "l10": 9000000, "l11": 10000000, "l12": 9500000,
              "l13": 25000000, "l14": 24000000, "l15": 26000000, "l16": 60000000, "l17": 60000000, "l18": 90000000}
for lid, c in LASER_COST.items():
    sub(r'(\t"%s": \{"name": [^\n]*"cost": \{"credits": )\d+' % lid, r'\g<1>%d' % c)

# --- Munición (lote de 100) ---
AMMO = {
    "mk1": '{"credits": 1000}',
    "mk2": '{"credits": 2900, "plata": 5, "resina_plasma": 2}',
    "mk3": '{"credits": 6500, "oro": 3, "titanio": 4, "xenocristal": 1}',
    "mk4": '{"credits": 11400, "platino": 2, "iridio": 2, "polvo_cuantico": 1}',
    "mk5": '{"credits": 15600, "neutronio": 1, "antimateria": 1, "cronita": 1}',
    "mk6": '{"credits": 19000, "graviton": 1, "materia_oscura": 1}',
}
for aid, rec in AMMO.items():
    sub(r'(\t"%s": \{"name": "Carga[^\n]*"recipe": )\{[^}]*\}' % aid, r'\g<1>' + rec)
sub(r'# --- Munición \(7\.2\) — receta por lote de 100 -+',
    '# --- Munición (7.2) — receta por lote de 100 ---------------------------------\n'
    '# v2: x1 = 10 créditos por disparo (LCB-10 de DarkOrbit). El daño por crédito baja x0,68 por nivel de carga\n'
    '# (52 -> 7,5 con el láser base) en vez de x0,15. x1-x3 se compran con créditos; x4-x6 sólo se fabrican\n'
    '# (materiales farmeados) o se pagan con Cristales Nexo como atajo (GameState.in_shop / nexo_only).')

# --- Misiles (lote de 10) ---
MISS = {
    "r1": ('1000.0', '{"credits": 1000}'),
    "r2": ('2000.0', '{"credits": 5000, "ferrita": 3}'),
    "r3": ('3000.0', '{"credits": 12000, "titanio": 3}'),
    "rt4": ('4000.0', '{"credits": 20000, "cobalto": 3, "paladio": 2}'),
    "r5": ('5000.0', '{"credits": 35000, "titanio": 4, "iridio": 2}'),
    "r6": ('6000.0', '{"credits": 60000, "osmio": 2, "neutronio": 1}'),
}
for mid, (dmg, rec) in MISS.items():
    sub(r'(\t"%s": \{"name": [^\n]*"dmg": )[\d.]+' % mid, r'\g<1>' + dmg)
    sub(r'(\t"%s": \{"name": [^\n]*"recipe": )\{[^}]*\}' % mid, r'\g<1>' + rec)

# --- Consumibles ---
ITEMS = {"repair": 5000, "boost": 3000, "mine": 8000, "shield_cell": 6000}
for iid, c in ITEMS.items():
    sub(r'(\t"%s": \{"name": [^\n]*"recipe": \{"credits": )\d+' % iid, r'\g<1>%d' % c)

# --- Generadores: escudo fijo + absorción (SG3N de DarkOrbit) y precios ---
GEN = {
    "sg_aegis1": (8000, 1000, 0.40), "sg_aegis2": (16000, 2000, 0.50), "sg_flux": (60000, 3000, 0.55),
    "sg_bulwark": (128000, 5000, 0.60), "sg_pulse": (250000, 4000, 0.60), "sg_reflect": (250000, 4000, 0.60),
    "sg_repair": (220000, 3500, 0.60), "sg_null": (1500000, 7000, 0.65), "sg_fortress": (6000000, 9500, 0.70),
    "sg_quantum": (15000000, 10000, 0.80),
    "vg_thrust1": (8000, 0, 0), "vg_thrust2": (16000, 0, 0), "vg_vector": (60000, 0, 0), "vg_inertia": (90000, 0, 0),
    "vg_blink": (128000, 0, 0), "vg_racer": (250000, 0, 0), "vg_overdrive": (1500000, 0, 0), "vg_phase": (3000000, 0, 0),
    "vg_comet": (6000000, 0, 0), "vg_horizon": (12000000, 0, 0),
}
for gid, (price, pts, ab) in GEN.items():
    def gline(m, price=price, pts=pts, ab=ab):
        line = m.group(0)
        line = re.sub(r'"cost": \{"credits": \d+', '"cost": {"credits": %d' % price, line)
        if pts:
            # El escudo pasa a puntos fijos con absorción; el % antiguo de escudo desaparece.
            line = re.sub(r'"stats": \{"shield": [\d.]+(, )?', lambda s: '"stats": {', line)
            line = line.replace('"stats": {}', '"stats": {}')
            line = line.replace('"type": "shield", ', '"type": "shield", "shield_pts": %d, "absorb": %.2f, ' % (pts, ab))
        return line
    sub(r'^\t"%s": \{[^\n]*$' % gid, gline, flags=re.M)

# --- Variantes (DarkOrbit: Boss x4, Uber x8 en vida y recompensa) ---
sub(r'"boss": \{"name": "Boss", "hp": 2\.0, "reward": 2\.0, "dmg": 1\.35', '"boss": {"name": "Boss", "hp": 4.0, "reward": 4.0, "dmg": 2.0')
sub(r'"mega": \{"name": "Mega", "hp": 3\.0, "reward": 3\.0, "dmg": 1\.60', '"mega": {"name": "Mega", "hp": 5.0, "reward": 5.0, "dmg": 2.4')
sub(r'"ultra": \{"name": "Ultra", "hp": 4\.0, "reward": 4\.0, "dmg": 1\.90', '"ultra": {"name": "Ultra", "hp": 6.0, "reward": 6.0, "dmg": 2.8')
sub(r'"uber": \{"name": "Uber", "hp": 5\.0, "reward": 5\.0, "dmg": 2\.25', '"uber": {"name": "Uber", "hp": 8.0, "reward": 8.0, "dmg": 3.2')

# --- Pet, láseres del pet, cajas ---
sub(r'const PET_RECIPE := \{"credits": 36000\}[^\n]*', 'const PET_RECIPE := {"credits": 500000}  # v2')
for did, c in {"pet_pulse": 10000, "pet_stinger": 150000, "pet_ion": 200000, "pet_arc": 1500000, "pet_guard": 800000, "pet_marker": 1000000}.items():
    sub(r'(\t"%s": \{"name": [^\n]*"cost": \{"credits": )\d+' % did, r'\g<1>%d' % c)
for bid, c in {"estandar": 100000, "afinada": 300000, "reliquia": 1500000, "anomala": 600000}.items():
    sub(r'(\t"%s": \{"name": "Caja[^\n]*"recipe": \{"credits": )\d+' % bid, r'\g<1>%d' % c)

# --- Recompensas de rango en créditos ---
sub(r'\{"kind": "credits", "amount": 250000\}', '{"kind": "credits", "amount": 2500000}')
sub(r'\{"kind": "credits", "amount": 5000000\}', '{"kind": "credits", "amount": 50000000}')

open(PATH, "w", encoding="utf-8").write(src)
print("OK tablas v2")
