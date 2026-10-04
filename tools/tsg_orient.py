"""Orientación automática de los modelos de TripoSG: elige, para cada nave, el giro cuya silueta vista desde
arriba coincide más con la del sprite (intersección sobre unión de las máscaras).

TripoSG deja la nave tumbada (arriba = +Y del OBJ) y no siempre con la proa al mismo lado. Se prueba
rx = 90 (o -90, volteada) y rz = 0/90/180/270 en coordenadas de Blender (el OBJ entra con Y arriba ->
Z arriba) y se guarda el mejor en tools/hy3d_fix.json (lo lee el perfil «hy3d» de blender_ship.py).

Uso (entorno D:\\Proyectos\\herramientas\\hy3d_env):
    python tools/tsg_orient.py [ids...]
"""
import json, math, os, sys
import numpy as np
import trimesh
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
N = 160


def rot(rx, rz):
    a, c = math.radians(rx), math.radians(rz)
    Rx = np.array([[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]])
    Rz = np.array([[math.cos(c), -math.sin(c), 0], [math.sin(c), math.cos(c), 0], [0, 0, 1]])
    return Rz @ Rx


def silhouette(v, f):
    xy = v[:, :2]
    mn, mx = xy.min(0), xy.max(0)
    s = (N - 1) / max(1e-6, (mx - mn).max())
    pts = (xy - mn) * s
    off = ((N - 1) - (mx - mn) * s) / 2
    pts = pts + off
    img = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(img)
    for tri in f:
        p = pts[tri]
        d.polygon([(p[0, 0], N - 1 - p[0, 1]), (p[1, 0], N - 1 - p[1, 1]), (p[2, 0], N - 1 - p[2, 1])], fill=255)
    return np.array(img) > 127


def sprite_mask(path):
    im = Image.open(path).convert("RGBA")
    a = np.array(im)[:, :, 3] > 25
    ys, xs = np.nonzero(a)
    crop = Image.fromarray((a[ys.min():ys.max() + 1, xs.min():xs.max() + 1] * 255).astype(np.uint8))
    w, h = crop.size
    s = (N - 1) / max(w, h)
    crop = crop.resize((max(1, int(w * s)), max(1, int(h * s))))
    img = Image.new("L", (N, N), 0)
    img.paste(crop, ((N - crop.width) // 2, (N - crop.height) // 2))
    return np.array(img) > 127


def main() -> None:
    base = os.path.join(ROOT, "build", "tsg_models", "ships")
    ids = sys.argv[1:] or sorted(os.listdir(base))
    fpath = os.path.join(ROOT, "tools", "hy3d_fix.json")
    fix = json.load(open(fpath, encoding="utf-8")) if os.path.exists(fpath) else {}
    for sid in ids:
        mesh = trimesh.load(os.path.join(base, sid, "mesh.obj"), force="mesh", process=False)
        v = np.asarray(mesh.vertices, dtype=np.float64)
        # Blender importa estos OBJ sin convertir ejes: coordenadas tal cual.
        f = np.asarray(mesh.faces)
        if len(f) > 40000:
            f = f[:: len(f) // 40000 + 1]
        target = sprite_mask(os.path.join(base, sid, "texture.png"))
        best = None
        for rx in (90,):   # TripoSG deja siempre la parte de arriba en +Y del OBJ: sólo se busca hacia dónde mira la proa
            for rz in (0, 90, 180, 270):
                m = silhouette(v @ rot(rx, rz).T, f)
                iou = (m & target).sum() / max(1, (m | target).sum())
                if best is None or iou > best[0]:
                    best = (iou, rx, rz)
        fix[sid] = {"rx": best[1], "rz": best[2]}
        print(f"{sid}: rx={best[1]} rz={best[2]} (coincidencia {best[0]:.2f})", flush=True)
    fix["_info"] = "Orientación de los modelos de TripoSG por nave (tools/tsg_orient.py); lo lee el perfil hy3d de tools/blender_ship.py."
    json.dump(fix, open(fpath, "w", encoding="utf-8"), ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
