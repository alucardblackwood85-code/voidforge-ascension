"""Propuestas de la evolución visual del pet con Stable Diffusion XL local.

El pet cambia de aspecto por etapas al subir de nivel. La etapa 1 es el sprite actual (esfera); para las
etapas 2-5 se generan 3 propuestas por etapa con la misma paleta (gris perla, verde azulado y luces cian;
dorado en las últimas) para que la secuencia se lea como una evolución.
Guarda build/redesign/pet/pet_s<etapa>_<n>.png (1024, fondo transparente, proa a la derecha).

Uso (entorno D:\\Proyectos\\herramientas\\sdxl_env):
    python tools/sdxl_pet.py [--force]
"""
import os, sys
import torch
from diffusers import StableDiffusionXLPipeline
from PIL import Image
from rembg import remove, new_session

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "build", "redesign", "pet")

STYLE = "top-down view from directly above, sci-fi game sprite, pre-rendered 3D, nose pointing up, symmetric, studio lighting, isolated on black background"
NEGATIVE = ("pixel art, cartoon, drawing, text, watermark, frame, perspective, side view, planet, stars, "
            "multiple objects, cropped, blurry, deformed, asymmetric, human, animal")
# La paleta va dentro de cada concepto (SDXL sólo atiende ~77 tokens: el sujeto primero).
STAGES = {
    2: "small robotic pet drone, rounded pearl grey and teal hull, two short stubby wings, one glowing cyan lens eye, twin small cyan engines",
    3: "compact robotic escort drone, arrowhead pearl grey and teal armored hull, two swept wings, cyan glowing core, small laser emitter at the nose",
    4: "sleek robotic escort drone fighter, sharp arrowhead hull with pearl grey, teal and gold armor plates, swept wings, twin laser cannons, cyan engines",
    5: "advanced robotic guardian drone, elegant sharp hull in pearl white and gold armor, glowing cyan energy lines, four swept wings, twin heavy laser cannons",
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


def main() -> None:
    force = "--force" in sys.argv
    os.makedirs(OUT, exist_ok=True)
    torch.set_num_threads(8)
    session = new_session("isnet-general-use")
    pipe = StableDiffusionXLPipeline.from_pretrained("stabilityai/stable-diffusion-xl-base-1.0", torch_dtype=torch.float16,
                                                     variant="fp16", use_safetensors=True)
    pipe.enable_model_cpu_offload()  # cabe en 8 GB de VRAM
    for stage, concept in STAGES.items():
        for k in range(3):
            path = os.path.join(OUT, f"pet_s{stage}_{k + 1}.png")
            if os.path.exists(path) and not force:
                continue
            g = torch.Generator("cpu").manual_seed(1200 + stage * 101 + k * 37)
            img = pipe(prompt=f"{concept}, {STYLE}", negative_prompt=NEGATIVE, width=1024, height=1024,
                       num_inference_steps=34, guidance_scale=7.0, generator=g).images[0]
            # Generado con la proa arriba: se gira para que mire a la derecha como el resto de sprites.
            out = remove(img, session=session).convert("RGBA").rotate(-90, expand=True)
            fit(out).save(path)
            print(f"OK pet_s{stage}_{k + 1}", flush=True)
    print("FIN", flush=True)


if __name__ == "__main__":
    main()
