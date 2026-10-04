"""Genera la tipografía propia del juego, «Voidforge Tech», como fuente de mapa de bits BMFont.

Letras angulares de trazo uniforme con esquinas achaflanadas (estilo consola militar sci-fi), diseñadas
sobre una rejilla de 8x12 unidades. Mayúsculas, versalitas para las minúsculas, cifras, acentos del
español (ÁÉÍÓÚÜÑ ¿¡) y puntuación. Se dibuja a 4x y se reduce para suavizar los bordes.
Salida: assets/fonts/voidforge_tech.fnt + voidforge_tech.png (Godot la importa como FontFile).

Uso (entorno con Pillow, p. ej. D:\\Proyectos\\herramientas\\sdxl_env):
    python tools/make_font.py
"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fonts")
NAME = "voidforge_tech"

SIZE = 80            # tamaño base (Godot escala a partir de este)
CAP = 56             # altura de mayúscula en px
U = CAP / 12.0       # px por unidad de rejilla
STROKE = 1.75        # grosor del trazo en unidades
BASE = 76            # línea base desde arriba de la celda
LINE = 98            # altura de línea
SS = 4               # supersampling
GAP = 1.6            # espacio entre letras (unidades)

O = [(2, 0), (6, 0), (8, 2), (8, 10), (6, 12), (2, 12), (0, 10), (0, 2), (2, 0)]
P = [(0, 12), (0, 0), (6, 0), (8, 2), (8, 5), (6, 7), (0, 7)]
GLYPHS = {
    "A": (8, [[(0, 12), (0, 3), (3, 0), (5, 0), (8, 3), (8, 12)], [(0, 7), (8, 7)]]),
    "B": (8, [[(0, 0), (6, 0), (8, 2), (8, 4), (6, 6), (0, 6)], [(6, 6), (8, 8), (8, 10), (6, 12), (0, 12), (0, 0)]]),
    "C": (8, [[(8, 0), (2, 0), (0, 2), (0, 10), (2, 12), (8, 12)]]),
    "D": (8, [[(0, 0), (5, 0), (8, 3), (8, 9), (5, 12), (0, 12), (0, 0)]]),
    "E": (8, [[(8, 0), (0, 0), (0, 12), (8, 12)], [(0, 6), (6, 6)]]),
    "F": (8, [[(8, 0), (0, 0), (0, 12)], [(0, 6), (6, 6)]]),
    "G": (8, [[(8, 0), (2, 0), (0, 2), (0, 10), (2, 12), (8, 12), (8, 6), (4, 6)]]),
    "H": (8, [[(0, 0), (0, 12)], [(8, 0), (8, 12)], [(0, 6), (8, 6)]]),
    "I": (4, [[(2, 0), (2, 12)], [(0, 0), (4, 0)], [(0, 12), (4, 12)]]),
    "J": (8, [[(8, 0), (8, 10), (6, 12), (2, 12), (0, 10)]]),
    "K": (8, [[(0, 0), (0, 12)], [(8, 0), (2, 6), (0, 6)], [(2, 6), (8, 12)]]),
    "L": (8, [[(0, 0), (0, 12), (8, 12)]]),
    "M": (10, [[(0, 12), (0, 0), (5, 6), (10, 0), (10, 12)]]),
    "N": (8, [[(0, 12), (0, 0), (8, 12), (8, 0)]]),
    "O": (8, [O]),
    "P": (8, [P]),
    "Q": (8, [O, [(5, 9), (8, 12)]]),
    "R": (8, [P, [(4, 7), (8, 12)]]),
    "S": (8, [[(8, 0), (2, 0), (0, 2), (0, 4), (2, 6), (6, 6), (8, 8), (8, 10), (6, 12), (0, 12)]]),
    "T": (8, [[(0, 0), (8, 0)], [(4, 0), (4, 12)]]),
    "U": (8, [[(0, 0), (0, 10), (2, 12), (6, 12), (8, 10), (8, 0)]]),
    "V": (8, [[(0, 0), (4, 12), (8, 0)]]),
    "W": (10, [[(0, 0), (2, 12), (5, 6), (8, 12), (10, 0)]]),
    "X": (8, [[(0, 0), (8, 12)], [(8, 0), (0, 12)]]),
    "Y": (8, [[(0, 0), (4, 6), (8, 0)], [(4, 6), (4, 12)]]),
    "Z": (8, [[(0, 0), (8, 0), (0, 12), (8, 12)]]),
    "0": (8, [O, [(6, 3), (2, 9)]]),
    "1": (6, [[(0, 2), (3, 0), (3, 12)], [(0, 12), (6, 12)]]),
    "2": (8, [[(0, 2), (2, 0), (6, 0), (8, 2), (8, 5), (0, 12), (8, 12)]]),
    "3": (8, [[(0, 0), (8, 0), (4, 5), (6, 5), (8, 7), (8, 10), (6, 12), (0, 12)]]),
    "4": (8, [[(6, 12), (6, 0), (0, 8), (8, 8)]]),
    "5": (8, [[(8, 0), (0, 0), (0, 5), (6, 5), (8, 7), (8, 10), (6, 12), (0, 12)]]),
    "6": (8, [[(7, 0), (2, 0), (0, 2), (0, 10), (2, 12), (6, 12), (8, 10), (8, 7), (6, 5), (0, 5)]]),
    "7": (8, [[(0, 0), (8, 0), (3, 12)]]),
    "8": (8, [[(2, 6), (0, 4), (0, 2), (2, 0), (6, 0), (8, 2), (8, 4), (6, 6), (2, 6), (0, 8), (0, 10), (2, 12), (6, 12), (8, 10), (8, 8), (6, 6)]]),
    "9": (8, [[(1, 12), (6, 12), (8, 10), (8, 2), (6, 0), (2, 0), (0, 2), (0, 5), (2, 7), (8, 7)]]),
    ".": (2, [[(1, 11.2), (1, 12)]]),
    ",": (2, [[(1.4, 11), (0.6, 13.4)]]),
    ":": (2, [[(1, 3.6), (1, 4.4)], [(1, 11.2), (1, 12)]]),
    ";": (2, [[(1, 3.6), (1, 4.4)], [(1.4, 11), (0.6, 13.4)]]),
    "!": (2, [[(1, 0), (1, 8)], [(1, 11.2), (1, 12)]]),
    "¡": (2, [[(1, 0), (1, 0.8)], [(1, 4), (1, 12)]]),
    "?": (8, [[(0, 2), (2, 0), (6, 0), (8, 2), (8, 4), (4, 7), (4, 8.4)], [(4, 11.2), (4, 12)]]),
    "¿": (8, [[(4, 0), (4, 0.8)], [(4, 3.6), (4, 5), (0, 8), (0, 10), (2, 12), (6, 12), (8, 10)]]),
    "-": (6, [[(0.5, 7), (5.5, 7)]]),
    "+": (8, [[(1, 7), (7, 7)], [(4, 4), (4, 10)]]),
    "=": (8, [[(1, 5), (7, 5)], [(1, 9), (7, 9)]]),
    "/": (6, [[(0, 12), (6, 0)]]),
    "%": (8, [[(0, 12), (8, 0)], [(0, 0), (2, 0), (2, 2), (0, 2), (0, 0)], [(6, 10), (8, 10), (8, 12), (6, 12), (6, 10)]]),
    "(": (4, [[(4, 0), (1, 3), (1, 9), (4, 12)]]),
    ")": (4, [[(0, 0), (3, 3), (3, 9), (0, 12)]]),
    "[": (4, [[(4, 0), (1, 0), (1, 12), (4, 12)]]),
    "]": (4, [[(0, 0), (3, 0), (3, 12), (0, 12)]]),
    "'": (2, [[(1, 0), (1, 3)]]),
    '"': (5, [[(1, 0), (1, 3)], [(4, 0), (4, 3)]]),
    "_": (8, [[(0, 12), (8, 12)]]),
    "×": (8, [[(1.5, 4.5), (6.5, 9.5)], [(6.5, 4.5), (1.5, 9.5)]]),
    "·": (2, [[(1, 6.6), (1, 7.4)]]),
    "#": (9, [[(3, 1), (2, 11)], [(7, 1), (6, 11)], [(0.5, 4), (8.5, 4)], [(0.5, 8), (8.5, 8)]]),
    "<": (6, [[(6, 3), (0, 7), (6, 11)]]),
    ">": (6, [[(0, 3), (6, 7), (0, 11)]]),
    "*": (6, [[(3, 1), (3, 7)], [(0.5, 2.5), (5.5, 5.5)], [(5.5, 2.5), (0.5, 5.5)]]),
    "|": (2, [[(1, -1), (1, 13)]]),
    "&": (8, [[(8, 12), (1, 4), (1, 2), (3, 0), (5, 0), (6, 2), (6, 3), (0, 8), (0, 10), (2, 12), (5, 12), (8, 8)]]),
    "@": (10, [[(7, 4), (4, 4), (3, 5), (3, 8), (4, 9), (7, 9), (7, 4), (7, 9), (9, 9), (10, 7), (10, 2), (8, 0), (2, 0), (0, 2), (0, 10), (2, 12), (9, 12)]]),
    "$": (8, [[(8, 1), (2, 1), (0, 3), (0, 4), (2, 6), (6, 6), (8, 8), (8, 9), (6, 11), (0, 11)], [(4, -0.5), (4, 12.5)]]),
}
ACCENT = {
    "Á": ("A", [[(3, -1.4), (5.5, -3.2)]]), "É": ("E", [[(3, -1.4), (5.5, -3.2)]]), "Í": ("I", [[(1, -1.4), (3.5, -3.2)]]),
    "Ó": ("O", [[(3, -1.4), (5.5, -3.2)]]), "Ú": ("U", [[(3, -1.4), (5.5, -3.2)]]),
    "Ü": ("U", [[(2.5, -2.4), (2.5, -1.6)], [(5.5, -2.4), (5.5, -1.6)]]),
    "Ñ": ("N", [[(1, -1.6), (3, -3), (5, -1.6), (7, -3)]]),
}


def seg_poly(a, b, w):
    """Trazo recto como polígono (extremos cuadrados)."""
    import math
    (x1, y1), (x2, y2) = a, b
    dx, dy = x2 - x1, y2 - y1
    l = math.hypot(dx, dy) or 1e-6
    ux, uy = dx / l, dy / l
    nx, ny = -uy * w / 2, ux * w / 2
    ex, ey = ux * w / 2, uy * w / 2
    return [(x1 - ex + nx, y1 - ey + ny), (x2 + ex + nx, y2 + ey + ny), (x2 + ex - nx, y2 + ey - ny), (x1 - ex - nx, y1 - ey - ny)]


def render(strokes, width, small=False):
    """Dibuja un glifo; devuelve (imagen, xoffset, yoffset, avance) en px finales."""
    sx = 0.82 if small else 1.0
    sy = 0.72 if small else 1.0
    pad = 2.5
    wpx = int((width * sx + pad * 2) * U) + 2
    top_u, bot_u = -4.0, 14.0
    hpx = int((bot_u - top_u) * U) + 2
    img = Image.new("L", (wpx * SS, hpx * SS), 0)
    d = ImageDraw.Draw(img)
    w = STROKE * U * SS
    for pl in strokes:
        pts = [((pad + x * sx) * U * SS, ((y * sy + (12 - 12 * sy)) - top_u) * U * SS) for x, y in pl]
        for k in range(len(pts) - 1):
            d.polygon(seg_poly(pts[k], pts[k + 1], w), fill=255)
        # Uniones: octógono en cada vértice (sin muescas entre tramos, esquina achaflanada).
        import math
        for (x, y) in pts:
            r = w / 2 * math.cos(math.pi / 8) / math.cos(math.pi / 8) * 0.98
            d.polygon([(x + r * math.cos(math.pi / 8 + k * math.pi / 4), y + r * math.sin(math.pi / 8 + k * math.pi / 4)) for k in range(8)], fill=255)
        if len(pts) == 1:
            x, y = pts[0]
            d.rectangle([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=255)
    img = img.resize((wpx, hpx), Image.BOX)
    bbox = img.getbbox()
    adv = int(round((width * sx + GAP) * U))
    if not bbox:
        return None, 0, 0, adv
    img = img.crop(bbox)
    xo = bbox[0] - int(pad * U)
    yo = bbox[1] + int(top_u * U) + (BASE - CAP)
    return img, xo, yo, adv


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    chars = {}
    for ch, (w, st) in GLYPHS.items():
        chars[ch] = render(st, w)
    for ch, (base, extra) in ACCENT.items():
        w, st = GLYPHS[base]
        chars[ch] = render(st + extra, w)
    # Minúsculas como versalitas (mismo dibujo, más bajas y estrechas).
    for ch in list(GLYPHS.keys()) + list(ACCENT.keys()):
        if ch.isalpha() and ch.upper() == ch and ch.lower() != ch:
            if ch in ACCENT:
                b, extra = ACCENT[ch]
                w, st = GLYPHS[b]
                chars[ch.lower()] = render(st + extra, w, small=True)
            else:
                w, st = GLYPHS[ch]
                chars[ch.lower()] = render(st, w, small=True)
    chars[" "] = (None, 0, 0, int(5 * U))
    # Empaquetado en filas sobre un atlas de 1024 de ancho.
    W = 1024
    x = y = 2
    row_h = 0
    placed = {}
    for ch, (img, xo, yo, adv) in chars.items():
        if img is None:
            placed[ch] = (0, 0, 0, 0, xo, yo, adv)
            continue
        if x + img.width + 2 > W:
            x = 2
            y += row_h + 2
            row_h = 0
        placed[ch] = (x, y, img.width, img.height, xo, yo, adv)
        x += img.width + 2
        row_h = max(row_h, img.height)
    H = 1
    while H < y + row_h + 2:
        H *= 2
    atlas = Image.new("RGBA", (W, H), (255, 255, 255, 0))
    for ch, (img, xo, yo, adv) in chars.items():
        if img is None:
            continue
        px, py = placed[ch][0], placed[ch][1]
        rgba = Image.new("RGBA", img.size, (255, 255, 255, 0))
        rgba.putalpha(img)
        atlas.paste(rgba, (px, py))
    atlas.save(os.path.join(OUT, NAME + ".png"))
    lines = [
        f'info face="Voidforge Tech" size={SIZE} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=2,2',
        f"common lineHeight={LINE} base={BASE} scaleW={W} scaleH={H} pages=1 packed=0",
        f'page id=0 file="{NAME}.png"',
        f"chars count={len(placed)}",
    ]
    for ch, (px, py, w, h, xo, yo, adv) in placed.items():
        lines.append(f"char id={ord(ch)} x={px} y={py} width={w} height={h} xoffset={xo} yoffset={yo} xadvance={adv} page=0 chnl=15")
    open(os.path.join(OUT, NAME + ".fnt"), "w", encoding="utf-8").write("\n".join(lines) + "\n")
    # Muestra para revisar el diseño.
    sample = Image.new("RGB", (1500, 360), (11, 16, 26))
    txt = ["VOIDFORGE ASCENSION 0123456789", "HANGAR TIENDA FABRICACIÓN ¿AÑO? ¡SÍ!", "Créditos · Misiles · Puntos de ascenso 75%"]
    yy = 20
    for t in txt:
        xx = 20
        for ch in t:
            if ch not in placed:
                continue
            px, py, w, h, xo, yo, adv = placed[ch]
            if w:
                g = atlas.crop((px, py, px + w, py + h))
                tint = Image.new("RGB", g.size, (110, 230, 255))
                sample.paste(tint, (xx + xo, yy + yo), g)
            xx += adv
        yy += 110
    sample.save(os.path.join(ROOT, "build", "font_sample.png"))
    print("OK", len(placed), "glifos", W, "x", H)


if __name__ == "__main__":
    main()
