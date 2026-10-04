"""Geometría limpia para las naves con TripoSG (VAST-AI, licencia MIT: uso comercial en todo el mundo).

Sustituye a Hunyuan3D-2 (cuya licencia excluye la UE, el Reino Unido y Corea del Sur). Genera la forma
de cada nave a partir de su sprite (build/3d_inputs/<grupo>/<id>.png, con fondo transparente: no se usa
el quitafondos RMBG-1.4 de BRIA, que es no comercial) y guarda build/tsg_models/<grupo>/<id>/mesh.obj
junto al sprite como texture.png. El color y el material los pone Blender (perfil «hy3d»).

Uso (entorno D:\\Proyectos\\herramientas\\hy3d_env):
    python tools/triposg_ships.py [ids...] [--group ships] [--force] [--steps 50] [--faces 120000]
"""
import os, sys, time
os.environ.setdefault("HF_HOME", r"D:\Proyectos\herramientas\hf_cache")
TSG = r"D:\Proyectos\herramientas\TripoSG"
sys.path.insert(0, TSG)
sys.path.insert(0, os.path.join(TSG, "scripts"))
import numpy as np
import torch
import trimesh

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def arg(name, default):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def main() -> None:
    from huggingface_hub import snapshot_download
    from triposg.pipelines.pipeline_triposg import TripoSGPipeline
    from image_process import prepare_image
    import pymeshlab
    group = arg("--group", "ships")
    steps = int(arg("--steps", "50"))
    n_faces = int(arg("--faces", "120000"))
    force = "--force" in sys.argv
    flags = {"--group", "--steps", "--faces"}
    ids = [a for i, a in enumerate(sys.argv[1:], 1) if not a.startswith("--") and sys.argv[i - 1] not in flags]
    src = os.path.join(ROOT, "build", "3d_inputs", group)
    if not ids:
        ids = sorted(os.path.splitext(f)[0] for f in os.listdir(src) if f.endswith(".png"))
    torch.set_num_threads(8)
    wdir = os.path.join(TSG, "pretrained_weights", "TripoSG")
    snapshot_download(repo_id="VAST-AI/TripoSG", local_dir=wdir)
    pipe = TripoSGPipeline.from_pretrained(wdir).to("cuda", torch.float16)
    for sid in ids:
        out = os.path.join(ROOT, "build", "tsg_models", group, sid)
        if os.path.exists(os.path.join(out, "mesh.obj")) and not force:
            continue
        os.makedirs(out, exist_ok=True)
        path = os.path.join(src, sid + ".png")
        sprite = path
        if "--view" in sys.argv:
            # Entrada en tres cuartos (render del modelo antiguo de TripoSR, MIT): TripoSG entiende mucho
            # mejor el volumen así que con el sprite cenital. El color sigue saliendo del sprite.
            path = os.path.join(ROOT, "build", "tsg_in", sid, "05.png")
            clean = os.path.join(ROOT, "build", "tsg_in", sid, "clean.png")
            if os.path.exists(clean):
                path = clean   # versión limpiada con SDXL (tools/sdxl_clean_views.py)
        if "--up" in sys.argv:
            # Variante: sprite con la proa hacia arriba (algunos modelos interpretan mejor así la forma).
            from PIL import Image as _I
            up = os.path.join(out, "input_up.png")
            _I.open(path).rotate(90, expand=True).save(up)
            path = up
        t0 = time.time()
        img = prepare_image(path, bg_color=np.array([1.0, 1.0, 1.0]), rmbg_net=None)
        res = pipe(image=img, generator=torch.Generator(device="cuda").manual_seed(42),
                   num_inference_steps=steps, guidance_scale=7.0).samples[0]
        mesh = trimesh.Trimesh(res[0].astype(np.float32), np.ascontiguousarray(res[1]))
        # Sin piezas sueltas: se conservan los trozos con al menos el 2% de las caras.
        parts = mesh.split(only_watertight=False)
        if len(parts) > 1:
            big = max(len(p.faces) for p in parts)
            mesh = trimesh.util.concatenate([p for p in parts if len(p.faces) >= big * 0.02])
        if len(mesh.faces) > n_faces:
            ms = pymeshlab.MeshSet()
            ms.add_mesh(pymeshlab.Mesh(vertex_matrix=mesh.vertices, face_matrix=mesh.faces))
            ms.meshing_merge_close_vertices()
            ms.meshing_decimation_quadric_edge_collapse(targetfacenum=n_faces)
            m = ms.current_mesh()
            mesh = trimesh.Trimesh(m.vertex_matrix(), m.face_matrix())
        trimesh.repair.fix_normals(mesh)   # caras hacia fuera (el marching cubes de reserva puede invertirlas)
        mesh.export(os.path.join(out, "mesh.obj"))
        from PIL import Image
        Image.open(sprite).save(os.path.join(out, "texture.png"))
        print(f"OK {sid} ({time.time() - t0:.0f} s, {len(mesh.faces)} caras)", flush=True)
        torch.cuda.empty_cache()
    print("FIN", flush=True)


if __name__ == "__main__":
    main()
