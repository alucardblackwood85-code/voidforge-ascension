"""Economía v2 (estilo DarkOrbit): reescribe vida, escudo, daño, XP y créditos de las 50 especies.

Cada bioma toma como enemigo «estándar» un alien real de DarkOrbit (wiki: darkorbit.fandom.com) y cada
especie conserva su papel dentro del bioma: su vida y su daño respecto a la media de su bioma en la
economía v1 multiplican los del alien de referencia. La XP y los créditos crecen con la vida efectiva
(vida + escudo) elevada a 0,9, como la tabla de recompensas de DarkOrbit.

Uso: python tools/economia_v2_enemigos.py   (edita scripts/autoload/game_data.gd en su sitio)
"""
import os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATH = os.path.join(ROOT, "scripts", "autoload", "game_data.gd")

# Alien estándar por bioma: (vida, escudo, daño máximo, XP, créditos) de DarkOrbit. Tras generar, el daño
# se multiplica por 0,875: la media del rango de daño de cada alien en la wiki (p. ej. Sibelon 2.250-3.000).
ANCHORS = {
    "ferron": ("Streuner", 800, 400, 20, 400, 400),
    "ferron_forja": ("Lordakia", 2000, 2000, 80, 800, 800),
    "vesper": ("Saimon", 6000, 3000, 200, 1600, 1600),
    "vesper_colmena": ("Mordon", 20000, 10000, 400, 3200, 6400),
    "prismaticos": ("Sibelonit", 40000, 40000, 1000, 3200, 12800),
    "prismaticos_catedral": ("Kristallin", 50000, 40000, 1200, 6400, 12800),
    "vacio": ("Protegit", 60000, 50000, 1400, 6400, 12800),
    "vacio_abismo": ("Devolarium", 100000, 100000, 1200, 6400, 51200),
    "leviatan": ("Sibelon", 200000, 200000, 3000, 12800, 102400),
    "leviatan_corazon": ("Lordakium", 300000, 200000, 4000, 25600, 204800),
}


def nice(v):
    """Redondea a 2 cifras significativas (como las tablas de DarkOrbit)."""
    if v < 100:
        return int(round(v))
    mag = 10 ** (len(str(int(v))) - 2)
    return int(round(v / mag) * mag)


def main():
    src = open(PATH, encoding="utf-8").read()
    # Biomas: pesos de aparición y élites.
    biomes = {}
    for m in re.finditer(r'\n\t"([a-z_]+)": \{\n(.*?)\n\t\},', src, re.S):
        bid, body = m.group(1), m.group(2)
        en = re.search(r'"enemies": \{([^}]*)\}', body)
        el = re.search(r'"elites": \[([^\]]*)\]', body)
        biomes[bid] = {
            "pool": re.findall(r'"([a-z_]+)":', en.group(1)) if en else [],
            "elites": re.findall(r'"([a-z_]+)"', el.group(1)) if el else [],
        }
    line_re = re.compile(r'^(\t"([a-z_]+)": \{"name": "[^"]*", "arch": "[^"]*", )"hp": (\d+), "dmg": (\d+)(, .*?"credits": )(\d+)(.*)$', re.M)
    enemies = {m.group(2): (int(m.group(3)), int(m.group(4))) for m in line_re.finditer(src)}
    home = {}
    for bid in ANCHORS:
        for sid in biomes.get(bid, {}).get("pool", []):
            home.setdefault(sid, bid)
    for bid in ANCHORS:
        for sid in biomes.get(bid, {}).get("elites", []):
            home.setdefault(sid, bid)
    avg = {}
    for bid in ANCHORS:
        pool = biomes[bid]["pool"]
        avg[bid] = (sum(enemies[s][0] for s in pool) / len(pool), sum(enemies[s][1] for s in pool) / len(pool))
    rows = []

    def repl(m):
        sid = m.group(2)
        if sid not in home:
            return m.group(0)
        bid = home[sid]
        _, a_hp, a_sh, a_dmg, a_xp, a_cr = ANCHORS[bid]
        hp_role = enemies[sid][0] / avg[bid][0]
        dmg_role = enemies[sid][1] / avg[bid][1]
        reward_role = hp_role ** 0.9
        hp, sh, dmg = nice(a_hp * hp_role), nice(a_sh * hp_role), nice(a_dmg * dmg_role)
        xp, cr = nice(a_xp * reward_role), nice(a_cr * reward_role)
        rows.append((bid, sid, hp, sh, dmg, xp, cr))
        rest = m.group(7)
        rest = re.sub(r', "shield": \d+|, "xp": \d+', "", rest)
        return f'{m.group(1)}"hp": {hp}, "shield": {sh}, "dmg": {dmg}{m.group(5)}{cr}, "xp": {xp}{rest}'

    src = line_re.sub(repl, src)
    open(PATH, "w", encoding="utf-8").write(src)
    for r in sorted(rows, key=lambda r: list(ANCHORS).index(r[0])):
        print("%-22s %-22s vida %8d escudo %8d daño %6d xp %7d créditos %8d" % r)


if __name__ == "__main__":
    main()
