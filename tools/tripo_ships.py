"""Modelos 3D de las naves con la API de Tripo (v3): calidad comercial, licencia válida en todos los países.

Sube la vista de cada nave (build/tsg_in/<id>/clean.png, la vista en tres cuartos limpiada con SDXL; si no
existe, el sprite build/3d_inputs/ships/<id>.png), lanza image-to-model, espera al resultado y descarga
build/tripo_models/ships/<id>/model.glb (con materiales PBR) y preview.png. El sprite se copia como
texture.png para el perfil de Blender que proyecta el color del juego.

La clave se lee de la variable de entorno TRIPO_API_KEY (empieza por «tsk_»); nunca se imprime.
Coste por nave (créditos de la plataforma API, 0,01 USD cada uno): 20 sólo geometría (por defecto, como
se hizo con Hunyuan3D), 30 con --texture (PBR estándar), +20 con --geo-detailed, +20 con --tex-detailed.

Uso (cualquier Python con «requests»):
    python tools/tripo_ships.py [ids...] [--force] [--model v3.1-20260211] [--texture] [--geo-detailed] [--tex-detailed]
                                [--sprite] [--faces 100000] [--seed 7] [--balance]
"""
import json, os, shutil, sys, time
import requests

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = "https://openapi.tripo3d.ai/v3"


def arg(name, default):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def api(method, path, key, **kw):
    r = requests.request(method, BASE + path, headers={"Authorization": f"Bearer {key}"}, timeout=120, **kw)
    try:
        body = r.json()
    except ValueError:
        raise RuntimeError(f"{path}: HTTP {r.status_code}")
    if body.get("code") != 0:
        raise RuntimeError(f"{path}: {body.get('code')} {body.get('message')} ({body.get('suggestion', '')})")
    return body["data"]


def download(url, dest):
    with requests.get(url, stream=True, timeout=300) as r:
        r.raise_for_status()
        with open(dest, "wb") as f:
            for chunk in r.iter_content(1 << 16):
                f.write(chunk)


def main() -> None:
    key = os.environ.get("TRIPO_API_KEY", "")
    if not key and os.name == "nt":
        # Variable de usuario recién creada: los procesos abiertos antes no la heredan; se lee del registro.
        import winreg
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as k:
                key = winreg.QueryValueEx(k, "TRIPO_API_KEY")[0]
        except OSError:
            pass
    if not key:
        sys.exit("Falta la variable de entorno TRIPO_API_KEY.")
    if "--balance" in sys.argv:
        print("Saldo:", json.dumps(api("GET", "/account/balance", key)))
        return
    flags = {"--model", "--faces", "--seed", "--quality", "--align", "--tag", "--tex-model", "--tex-seed", "--src"}
    ids = [a for i, a in enumerate(sys.argv[1:], 1) if not a.startswith("--") and sys.argv[i - 1] not in flags]
    src_dir = arg("--src", os.path.join(ROOT, "build", "3d_inputs", "ships"))   # --src: carpeta de sprites (p. ej. build/sprites_v2)
    if not ids:
        ids = sorted(os.path.splitext(f)[0] for f in os.listdir(src_dir) if f.endswith(".png"))
    if "--retexture" in sys.argv:
        retexture(key, ids, src_dir)
        return
    # Por defecto sólo geometría (como con Hunyuan): el color lo pone Blender proyectando el sprite del juego.
    tex = "--texture" in sys.argv or "--tex-detailed" in sys.argv
    body = {"model": arg("--model", "v3.1-20260211"), "texture": tex, "pbr": tex,
            "face_limit": int(arg("--faces", "100000")), "model_seed": int(arg("--seed", "7"))}
    if "--geo-detailed" in sys.argv:
        body["geometry_quality"] = "detailed"
    if "--tex-detailed" in sys.argv:
        body["texture_quality"] = "detailed"
    for sid in ids:
        out = os.path.join(ROOT, "build", "tripo_models", "ships", sid)
        if os.path.exists(os.path.join(out, "model.glb")) and "--force" not in sys.argv:
            continue
        os.makedirs(out, exist_ok=True)
        sprite = os.path.join(src_dir, sid + ".png")
        view = os.path.join(ROOT, "build", "tsg_in", sid, "clean.png")
        path = sprite if "--sprite" in sys.argv or not os.path.exists(view) else view
        t0 = time.time()
        try:
            with open(path, "rb") as f:
                token = api("POST", "/files", key, files={"file": (os.path.basename(path), f, "image/png")})["file_token"]
            task = api("POST", "/generation/image-to-model", key, json=dict(body, input=token))["task_id"]
            while True:
                time.sleep(5)
                st = api("GET", f"/tasks/{task}", key)
                if st["status"] in ("success", "failed", "cancelled"):
                    break
            if st["status"] != "success":
                print(f"FALLO {sid}: {st['status']} {st.get('error_code', '')} {st.get('error_message', '')}", flush=True)
                continue
            # Los enlaces de descarga caducan a los 60 s: se descargan en cuanto termina la tarea.
            o = st["output"]
            download(o.get("pbr_model_url") or o.get("model_url"), os.path.join(out, "model.glb"))
            if o.get("rendered_image_url"):
                download(o["rendered_image_url"], os.path.join(out, "preview.png"))
            shutil.copy(sprite, os.path.join(out, "texture.png"))
            json.dump({"task_id": task, "input": os.path.relpath(path, ROOT), "request": body,
                       "credits": st.get("credits_consumed")}, open(os.path.join(out, "info.json"), "w"), indent=2)
            print(f"OK {sid} ({time.time() - t0:.0f} s, {st.get('credits_consumed')} créditos)", flush=True)
        except Exception as e:   # sigue con la siguiente nave
            print(f"FALLO {sid}: {e}", flush=True)
    print("FIN", flush=True)


def retexture(key, ids, src_dir):
    """Vuelve a pintar el modelo ya generado (misma geometría y orientación) con la IA de texturas de Tripo,
    usando el sprite como referencia: pinta también laterales y panza, que la proyección desde arriba
    estiraba. Coste: 10 créditos (standard) o 20 (detailed) por nave.
    Opciones: --quality standard|detailed, --align original_image|geometry, --tex-model v3.5-20260815,
    --tag nombre (sufijo de los archivos de salida, para comparar pruebas sin pisarlas)."""
    quality = arg("--quality", "standard")
    align = arg("--align", "original_image")
    tex_model = arg("--tex-model", "v3.5-20260815")
    tag = arg("--tag", "tex")
    for sid in ids:
        out = os.path.join(ROOT, "build", "tripo_models", "ships", sid)
        dest = os.path.join(out, "model_%s.glb" % tag)
        if os.path.exists(dest) and "--force" not in sys.argv:
            print(f"YA EXISTE {sid} ({os.path.basename(dest)})", flush=True)
            continue
        info = json.load(open(os.path.join(out, "info.json")))
        sprite = os.path.join(src_dir, sid + ".png")
        t0 = time.time()
        try:
            with open(sprite, "rb") as f:
                token = api("POST", "/files", key, files={"file": (os.path.basename(sprite), f, "image/png")})["file_token"]
            body = {"input": info["task_id"], "model": tex_model, "texture_prompt": {"image": token},
                    "texture_quality": quality, "texture_alignment": align, "pbr": True, "texture_seed": int(arg("--tex-seed", "7"))}
            if tex_model.startswith("v3.5"):
                body["delight"] = True    # quita la iluminación pintada en el sprite
            task = api("POST", "/models/texture", key, json=body)["task_id"]
            while True:
                time.sleep(5)
                st = api("GET", f"/tasks/{task}", key)
                if st["status"] in ("success", "failed", "cancelled"):
                    break
            if st["status"] != "success":
                print(f"FALLO {sid}: {st['status']} {st.get('error_code', '')} {st.get('error_message', '')}", flush=True)
                continue
            o = st["output"]
            download(o.get("pbr_model_url") or o.get("model_url"), dest)
            if o.get("rendered_image_url"):
                download(o["rendered_image_url"], os.path.join(out, "preview_%s.png" % tag))
            info.setdefault("textures", {})[tag] = {"task_id": task, "request": dict(body, texture_prompt={"image": "sprite"}),
                                                   "credits": st.get("credits_consumed")}
            json.dump(info, open(os.path.join(out, "info.json"), "w"), indent=2)
            print(f"OK {sid} ({time.time() - t0:.0f} s, {st.get('credits_consumed')} créditos)", flush=True)
        except Exception as e:
            print(f"FALLO {sid}: {e}", flush=True)
    print("FIN", flush=True)


if __name__ == "__main__":
    main()
