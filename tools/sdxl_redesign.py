"""Propuestas de rediseño de enemigos con Stable Diffusion XL local.

Por cada enemigo genera 4 propuestas: 2 partiendo de su sprite actual (imagen a imagen, conservan la
esencia y la orientación) y 2 nuevas a partir del concepto (texto, la cabeza arriba y luego se giran
para que miren a la derecha). Guarda build/redesign/enemies/<id>_<n>.png (1024, fondo transparente).

Uso (entorno D:\\Proyectos\\herramientas\\sdxl_env):
    python tools/sdxl_redesign.py [ids...]
"""
import os, sys
import torch
from diffusers import StableDiffusionXLPipeline, StableDiffusionXLImg2ImgPipeline
from PIL import Image
from rembg import remove, new_session

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "build", "redesign", "enemies")

STYLE = "top-down view from directly above, sci-fi game sprite, pre-rendered 3D, studio lighting, isolated on black background"
NEGATIVE = ("pixel art, cartoon, drawing, text, watermark, frame, perspective, side view, planet, stars, "
            "multiple objects, cropped, blurry, deformed, low quality")
# Concepto de cada enemigo (lo primero que lee el modelo: SDXL sólo atiende ~77 tokens).
CONCEPTS = {
    "campana_vacio": "void cult artillery construct shaped like a huge inverted bell, black metal bell with glowing purple starry interior, "
                     "concentric metal rings around it, purple energy runes, menacing",
    "madre_remache": "huge riveted scrap-metal mothership hive, rusty brown and dark iron armor plates with big rivets, "
                     "red glowing hangar bays and red eye lights, insect-like mechanical carrier, bilateral symmetry",
    "ferroclasto": "heavy armored iron beetle war machine, thick grey steel carapace plates, glowing orange joints and orange eyes, "
                   "huge crushing mandibles at the front, six mechanical legs, bilateral symmetry",
    "carcelero_obsidiana": "obsidian jailer guardian warship, sleek black volcanic glass armor with sharp angular crystal facets, "
                           "glowing red energy cracks, red energy chains, hexagonal shield wings, bilateral symmetry",
    "leviatan_genesis": "colossal organic space whale creature, deep blue whale body, pale bone-white external ribs, "
                        "biomechanical city with towers embedded on its back, glowing fins, long tail, bilateral symmetry",
    "monje_graviton": "hooded faceless mechanical monk floating inside a glowing purple gravity ring halo, dark flowing robes, "
                      "long thin mechanical arms emitting gravity waves",
}


def fit(img: Image.Image) -> Image.Image:
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    scale = 820 / max(img.size)
    img = img.resize((max(1, int(img.width * scale)), max(1, int(img.height * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    canvas.paste(img, ((1024 - img.width) // 2, (1024 - img.height) // 2), img)
    return canvas


def _load(cls):
    pipe = cls.from_pretrained("stabilityai/stable-diffusion-xl-base-1.0", torch_dtype=torch.float16,
                               variant="fp16", use_safetensors=True)
    pipe.enable_model_cpu_offload()  # cabe en 8 GB de VRAM
    return pipe


def main() -> None:
    ids = [a for a in sys.argv[1:] if not a.startswith("--")] or list(CONCEPTS)
    force = "--force" in sys.argv
    os.makedirs(OUT, exist_ok=True)
    torch.set_num_threads(8)
    session = new_session("isnet-general-use")
    # Fase 1: desde el sprite actual (imagen a imagen; misma orientación, proa a la derecha).
    # Las dos fases van por separado: dos pipelines compartiendo el modelo con descarga a CPU
    # chocan y cada paso tarda ~20 s en lugar de <1 s.
    pipe = _load(StableDiffusionXLImg2ImgPipeline)
    for sid in ids:
        old = Image.open(os.path.join(ROOT, "assets", "sprites", "enemies", f"{sid}.png")).convert("RGBA")
        base = Image.new("RGBA", old.size, (0, 0, 0, 255)); base.alpha_composite(old)
        init = base.convert("RGB").resize((1024, 1024), Image.LANCZOS)
        for k in range(2):
            path = os.path.join(OUT, f"{sid}_{k + 1}.png")
            if os.path.exists(path) and not force:
                continue
            g = torch.Generator("cpu").manual_seed(500 + k * 31 + len(sid))
            img = pipe(prompt=f"{CONCEPTS[sid]}, facing right, {STYLE}", negative_prompt=NEGATIVE, image=init,
                       strength=0.62 + 0.08 * k, num_inference_steps=34, guidance_scale=7.0, generator=g).images[0]
            fit(remove(img, session=session).convert("RGBA")).save(path)
            print(f"OK {sid}_{k + 1}", flush=True)
    del pipe
    torch.cuda.empty_cache()
    # Fase 2: desde el concepto (cabeza arriba) y giro de 90° para que mire a la derecha.
    pipe = _load(StableDiffusionXLPipeline)
    for sid in ids:
        for k in range(2):
            path = os.path.join(OUT, f"{sid}_{k + 3}.png")
            if os.path.exists(path) and not force:
                continue
            g = torch.Generator("cpu").manual_seed(900 + k * 53 + len(sid) * 7)
            img = pipe(prompt=f"{CONCEPTS[sid]}, head pointing up, {STYLE}", negative_prompt=NEGATIVE, width=1024,
                       height=1024, num_inference_steps=34, guidance_scale=7.0, generator=g).images[0]
            out = remove(img, session=session).convert("RGBA").rotate(-90, expand=True)
            fit(out).save(path)
            print(f"OK {sid}_{k + 3}", flush=True)
    print("FIN", flush=True)


if __name__ == "__main__":
    main()
