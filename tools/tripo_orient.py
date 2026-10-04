"""Orientación automática de los modelos de Tripo (build/tripo_models/ships/<id>/model.glb).

Con el sprite cenital como entrada, la orientación automática de Tripo deja a veces la nave ladeada.
Aquí se alinea el eje más fino de la malla (análisis de componentes principales) con la vertical y el más
largo con +X, y se prueba cada giro de 90° (y la nave volteada) quedándose con el que mejor encaja con la
silueta del sprite. Entre una nave y su volteo la silueta es casi igual: desempata el lado que más
sobresale del plano medio (cabina, torretas). Se guarda como ángulos de Euler XYZ de Blender en
tools/tripo_fix.json, que lee tools/blender_ship.py para los modelos GLB.
Correcciones manuales: {"<id>": {"flip": true}} invierte el volteo elegido; "rz_add": grados extra.

Uso (entorno D:\\Proyectos\\herramientas\\hy3d_env):
    python tools/tripo_orient.py [ids...]
"""
import json, math, os, sys
import numpy as np
import trimesh

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tsg_orient import silhouette as _silhouette, sprite_mask   # noqa: E402
from scipy.ndimage import binary_closing, binary_fill_holes   # noqa: E402


def silhouette(v, f):
    # Con una muestra de las caras la silueta queda calada: se cierra y se rellena.
    return binary_fill_holes(binary_closing(_silhouette(v, f), iterations=2))

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def rz_mat(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def euler_xyz(R):
    ry = math.asin(max(-1.0, min(1.0, -R[2, 0])))
    rx = math.atan2(R[2, 1], R[2, 2])
    rz = math.atan2(R[1, 0], R[0, 0])
    return [round(math.degrees(a), 2) for a in (rx, ry, rz)]


def main() -> None:
    base = os.path.join(ROOT, "build", "tripo_models", "ships")
    ids = sys.argv[1:] or sorted(d for d in os.listdir(base) if os.path.exists(os.path.join(base, d, "model.glb")))
    fpath = os.path.join(ROOT, "tools", "tripo_fix.json")
    fix = json.load(open(fpath, encoding="utf-8")) if os.path.exists(fpath) else {}
    for sid in ids:
        sc = trimesh.load(os.path.join(base, sid, "model.glb"))
        m = sc.to_geometry() if hasattr(sc, "to_geometry") else sc
        v = np.asarray(m.vertices, dtype=np.float64)
        v = np.stack([v[:, 0], -v[:, 2], v[:, 1]], 1)        # glTF (Y arriba) -> Blender (Z arriba)
        f = np.asarray(m.faces)
        fs = f[:: len(f) // 6000 + 1]                          # búsqueda gruesa con menos caras
        if len(f) > 40000:
            f = f[:: len(f) // 40000 + 1]
        c = v - v.mean(0)
        w, U = np.linalg.eigh(np.cov(c.T))                     # varianza ascendente: U[:,0] = eje fino
        target = sprite_mask(os.path.join(base, sid, "texture.png"))
        user = fix.get(sid, {})
        cands = []
        # Normalmente el eje fino es la altura, pero en naves macizas (torretas, bloques) puede no serlo:
        # se prueba cada eje principal como vertical («up» fija uno a mano).
        ups = [int(user["up"])] if "up" in user else [0, 1, 2]
        for ui in ups:
            rest = [k for k in (2, 1, 0) if k != ui]
            R0 = np.stack([U[:, rest[0]], U[:, rest[1]], U[:, ui]])
            if np.linalg.det(R0) < 0:
                R0[1] *= -1
            for flip in (False, True):
                F = np.diag([1.0, -1.0, -1.0]) if flip else np.eye(3)
                # Naves casi tan anchas como largas: el eje largo del análisis puede salir en diagonal,
                # así que el giro se busca cada 10° y luego se afina cada 2°.
                def score(rz, faces):
                    R = rz_mat(rz + float(user.get("rz_add", 0))) @ F @ R0
                    p = c @ R.T
                    sil = silhouette(p, faces)
                    return (sil & target).sum() / max(1, (sil | target).sum()), p, R
                coarse = max(range(0, 360, 10), key=lambda a: score(a, fs)[0])
                for rz in range(coarse - 8, coarse + 9, 2):
                    iou, p, R = score(rz, fs)
                    bulge = p[:, 2].max() + p[:, 2].min()      # > 0: sobresale más por arriba
                    cands.append((iou, bulge, flip, rz, R))
        best = max(cands, key=lambda t: t[0])
        # El volteo de la mejor (misma silueta en espejo): candidato del otro volteo con el mismo eje vertical.
        twins = [t for t in cands if t[2] != best[2] and abs(abs(np.dot(t[4][2], best[4][2])) - 1) < 1e-6
                 and abs(t[0] - best[0]) < 0.03]
        pick = best
        if twins:
            pool = [best, max(twins, key=lambda t: t[0])]
            pick = max(pool, key=lambda t: t[1])
        if user.get("flip"):
            pick = max((t for t in cands if t[2] != pick[2] and abs(abs(np.dot(t[4][2], pick[4][2])) - 1) < 1e-6),
                       key=lambda t: t[0])
        rx, ry, rz = euler_xyz(pick[4])
        fix[sid] = dict(user, rx=rx, ry=ry, rz=rz)
        print(f"{sid}: rx={rx} ry={ry} rz={rz} (coincidencia {pick[0]:.2f}, volteada={pick[2]})", flush=True)
    json.dump(fix, open(fpath, "w", encoding="utf-8"), ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
