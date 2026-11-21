"""Run Tencent's shape-only pipeline offline against local PNGs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import time

ROOT = Path(__file__).resolve().parent
os.environ["HF_HUB_OFFLINE"] = "1"
os.environ["TRANSFORMERS_OFFLINE"] = "1"
os.environ["HF_HUB_DISABLE_TELEMETRY"] = "1"
sys.path.insert(0, str(ROOT / "vendor" / "hunyuan"))

def run(args):
    import torch
    from PIL import Image
    from hy3dgen.shapegen import Hunyuan3DDiTFlowMatchingPipeline

    if not torch.cuda.is_available():
        raise RuntimeError("CUDA is unavailable in the pinned local environment.")
    repo, folder = {
        "single": ("Hunyuan3D-2mini", "hunyuan3d-dit-v2-mini-turbo"),
        "multi": ("Hunyuan3D-2mv", "hunyuan3d-dit-v2-mv-turbo"),
    }[args.mode]
    files = {v: args.inputs / f"{v}.png" for v in (
        ("hero",) if args.mode == "single" else ("front", "right", "back", "left")
    )}
    images = {view: Image.open(path).convert("RGBA") for view, path in files.items()}
    conditioning = images["hero"] if args.mode == "single" else images
    print("Preflight", torch.__version__, torch.cuda.get_device_name(), torch.cuda.mem_get_info(), flush=True)
    started = time.perf_counter()
    pipeline = Hunyuan3DDiTFlowMatchingPipeline.from_pretrained(
        str(ROOT / "weights" / repo), subfolder=folder, variant="fp16", use_safetensors=True,
        device="cuda", dtype=torch.float16,
    )
    if args.resolution >= 256:
        # Hierarchical native PyTorch decoder; no custom CUDA extensions.
        pipeline.enable_flashvdm(replace_vae=False)
    for seed in args.seeds:
        torch.cuda.reset_peak_memory_stats()
        sample_start = time.perf_counter()
        mesh = pipeline(
            image=conditioning, num_inference_steps=args.steps,
            octree_resolution=args.resolution, num_chunks=16000,
            generator=torch.Generator("cuda").manual_seed(seed),
        )[0]
        if mesh is None or not len(mesh.faces):
            raise RuntimeError(f"No surface for seed {seed}.")
        args.out.mkdir(parents=True, exist_ok=True)
        target = args.out / f"{args.mode}-{seed}.glb"
        mesh.export(target)
        metadata = {
            "seed": seed, "mode": args.mode, "model": folder,
            "steps": args.steps, "resolution": args.resolution,
            "vertices": len(mesh.vertices), "faces": len(mesh.faces),
            "watertight": bool(mesh.is_watertight),
            "seconds": round(time.perf_counter() - sample_start, 2),
            "load_seconds": round(sample_start - started, 2),
            "peak_cuda_allocated_gib": round(torch.cuda.max_memory_allocated() / 2**30, 2),
            "peak_cuda_reserved_gib": round(torch.cuda.max_memory_reserved() / 2**30, 2),
            "inputs_sha256": {v: hashlib.sha256(p.read_bytes()).hexdigest() for v, p in files.items()},
            "output_sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        }
        target.with_suffix(".json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
        print(target, metadata, flush=True)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("single", "multi"))
    parser.add_argument("--inputs", type=Path, default=ROOT / "private" / "inputs")
    parser.add_argument("--out", type=Path, default=ROOT / "private" / "models")
    parser.add_argument("--seeds", type=int, nargs="+", default=[12345])
    parser.add_argument("--steps", type=int, default=8)
    parser.add_argument("--resolution", type=int, default=224)
    run(parser.parse_args())


