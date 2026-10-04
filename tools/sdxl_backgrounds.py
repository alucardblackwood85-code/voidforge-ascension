"""Fondos espaciales de los mapas fuertes de cada facción con Stable Diffusion XL local.

Cada mapa fuerte tenía el fondo de su facción; aquí se genera uno propio (1536x1024, poco contraste para que
las naves se lean encima), en assets/backgrounds/<bioma>.png.

Uso (entorno D:\\Proyectos\\herramientas\\sdxl_env):
    python tools/sdxl_backgrounds.py [ids...] [--force]
"""
import os, sys
import torch
from diffusers import StableDiffusionXLPipeline
from PIL import Image, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "backgrounds")

STYLE = "deep space background, top-down view, no planets in foreground, dark, low contrast, subtle stars, matte painting, game background"
NEGATIVE = "text, watermark, ship, spaceship, character, frame, border, bright, high contrast, lens flare, planet close-up, blurry"
SCENES = {
    "ferron_forja": "vast orbital shipyard ruins and glowing orange furnace debris drifting in space, rusty metal scaffolds, embers, dark brown and orange nebula",
    "vesper_colmena": "giant organic hive membranes and pulsing magenta egg clusters floating in a dark purple nebula, wet organic tendrils",
    "prismaticos_catedral": "aerial view looking straight down at scattered floating crystal shards and broken glass platforms in space, faint cyan and gold glow, dark blue nebula",
    "vacio_abismo": "aerial view looking straight down into pitch black void with faint magenta ritual circles and drifting black stone fragments, thin violet dust",
    "leviatan_corazon": "aerial view looking straight down at faint deep blue bioluminescent veins and soft ivory tissue patterns in dark indigo space, subtle",
}


def main() -> None:
    ids = [a for a in sys.argv[1:] if not a.startswith("--")] or list(SCENES)
    force = "--force" in sys.argv
    torch.set_num_threads(8)
    pipe = StableDiffusionXLPipeline.from_pretrained("stabilityai/stable-diffusion-xl-base-1.0", torch_dtype=torch.float16,
                                                     variant="fp16", use_safetensors=True)
    pipe.enable_model_cpu_offload()  # cabe en 8 GB de VRAM
    pipe.vae.enable_tiling()         # 1536 px sin agotar la VRAM al decodificar
    for bid in ids:
        path = os.path.join(OUT, f"{bid}.png")
        if os.path.exists(path) and not force:
            continue
        g = torch.Generator("cpu").manual_seed(4100 + len(bid) * 13)
        img = pipe(prompt=f"{SCENES[bid]}, {STYLE}", negative_prompt=NEGATIVE, width=1536, height=1024,
                   num_inference_steps=34, guidance_scale=6.5, generator=g).images[0]
        # Como los fondos actuales: oscuro y con poco contraste para que las naves resalten.
        img = ImageEnhance.Brightness(img).enhance(0.42)
        img = ImageEnhance.Contrast(img).enhance(0.75)
        img = ImageEnhance.Color(img).enhance(0.8)
        img.convert("RGB").save(path)
        print(f"OK {bid}", flush=True)
    print("FIN", flush=True)


if __name__ == "__main__":
    main()
