"""Decide el volteo de cada nave usando la textura de Tripo (model_tex.glb).

tripo_orient.py elige qué cara va arriba por la silueta, que es igual en una nave y en su volteo; con el
sprite proyectado desde arriba el error no se veía, pero con la textura propia de Tripo una nave volteada
enseña la panza. Aquí se proyectan desde arriba los colores del modelo (vértice más alto por píxel) con la
orientación actual y con la volteada (giro de 180° sobre el eje de la proa), se comparan con los colores del
sprite y, si la volteada se parece claramente más, se corrige tools/tripo_fix.json.

Uso (entorno D:\\Proyectos\\herramientas\\hy3d_env):  python tools/tripo_flip_tex.py [ids...] [--dry]
"""
import json, math, os, sys
import numpy as np
import trimesh
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
N = 96


def euler_R(d):
    rx, ry, rz = (math.radians(d[k]) for k in ("rx", "ry", "rz"))
    X = np.array([[1, 0, 0], [0, math.cos(rx), -math.sin(rx)], [0, math.sin(rx), math.cos(rx)]])
    Y = np.array([[math.cos(ry), 0, math.sin(ry)], [0, 1, 0], [-math.sin(ry), 0, math.cos(ry)]])
    Z = np.array([[math.cos(rz), -math.sin(rz), 0], [math.sin(rz), math.cos(rz), 0], [0, 0, 1]])
    return Z @ Y @ X


def euler_xyz(R):
    ry = math.asin(max(-1.0, min(1.0, -R[2, 0])))
    return [round(math.degrees(a), 2) for a in (math.atan2(R[2, 1], R[2, 2]), ry, math.atan2(R[1, 0], R[0, 0]))]


def top_colors(v, col):
    """Imagen NxN vista desde arriba: color del vértice más alto en cada píxel (ajustada a su caja)."""
    xy = v[:, :2]
    mn, mx = xy.min(0), xy.max(0)
    s = (N - 1) / max(1e-6, (mx - mn).max())
    p = ((xy - mn) * s + ((N - 1) - (mx - mn) * s) / 2).astype(int)
    img = np.zeros((N, N, 3)); zb = np.full((N, N), -np.inf); mask = np.zeros((N, N), bool)
    order = np.argsort(v[:, 2])               # los más altos al final sobrescriben
    for i in order:
        x, y = p[i]
        img[N - 1 - y, x] = col[i]; mask[N - 1 - y, x] = True
    return img, mask


def hist_dist(a, b, bins=6):
    def h(x):
        q = np.clip((x * bins).astype(int), 0, bins - 1)
        idx = q[:, 0] * bins * bins + q[:, 1] * bins + q[:, 2]
        c = np.bincount(idx, minlength=bins ** 3).astype(float)
        return c / max(1.0, c.sum())
    return 0.5 * np.abs(h(a) - h(b)).sum()


def sprite_colors(path):
    im = np.array(Image.open(path).convert("RGBA")).astype(float) / 255.0
    a = im[:, :, 3] > 0.3
    ys, xs = np.nonzero(a)
    crop = im[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = crop.shape[:2]
    s = (N - 1) / max(w, h)
    pil = Image.fromarray((crop * 255).astype(np.uint8)).resize((max(1, int(w * s)), max(1, int(h * s))))
    out = np.zeros((N, N, 4))
    arr = np.array(pil).astype(float) / 255.0
    oy, ox = (N - arr.shape[0]) // 2, (N - arr.shape[1]) // 2
    out[oy:oy + arr.shape[0], ox:ox + arr.shape[1]] = arr
    return out[:, :, :3], out[:, :, 3] > 0.3


def main():
    base = os.path.join(ROOT, "build", "tripo_models", "ships")
    fpath = os.path.join(ROOT, "tools", "tripo_fix.json")
    fix = json.load(open(fpath, encoding="utf-8"))
    ids = [a for a in sys.argv[1:] if not a.startswith("--")] or sorted(d for d in os.listdir(base) if os.path.exists(os.path.join(base, d, "model_tex.glb")))
    for sid in ids:
        mesh = trimesh.load(os.path.join(base, sid, "model_tex.glb")).to_geometry()
        col = mesh.visual.to_color().vertex_colors[:, :3].astype(float) / 255.0
        v = np.asarray(mesh.vertices)
        v = np.stack([v[:, 0], -v[:, 2], v[:, 1]], 1)            # glTF -> Blender
        v = v - v.mean(0)
        R = euler_R(fix[sid])
        sc, sm = sprite_colors(os.path.join(base, sid, "texture.png"))
        scores = []
        for flip in (False, True):
            Rf = (np.diag([1.0, -1.0, -1.0]) @ R) if flip else R     # 180° sobre el eje X (proa) tras orientar
            img, m = top_colors(v @ Rf.T, col)
            # Distribución de colores (histograma 6x6x6) de lo que se ve desde arriba frente al sprite: no
            # depende de la alineación píxel a píxel (huecos de la proyección, espejo del volteo).
            scores.append(hist_dist(img[m], sc[sm]))
        better = scores[1] < scores[0] * 0.85
        print("%-15s actual %.3f  volteada %.3f  -> %s" % (sid, scores[0], scores[1], "VOLTEAR" if better else "se queda"), flush=True)
        if better and "--dry" not in sys.argv:
            rx, ry, rz = euler_xyz(np.diag([1.0, -1.0, -1.0]) @ R)
            fix[sid].update(rx=rx, ry=ry, rz=rz)
    if "--dry" not in sys.argv:
        json.dump(fix, open(fpath, "w", encoding="utf-8"), ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
