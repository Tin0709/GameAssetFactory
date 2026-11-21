"""Fetch two fixed public Tencent shape checkpoints into a local cache."""
import hashlib
import json
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parent / "weights"
MODELS = {
    "Hunyuan3D-2mini": ("f90a0f7df7d5e6f71109cf333f6a95a0ae3194a6", "hunyuan3d-dit-v2-mini-turbo"),
    "Hunyuan3D-2mv": ("3a761b539b29fe4ff64714813aa9560fd66f5de0", "hunyuan3d-dit-v2-mv-turbo"),
}

def download(item):
    model, (rev, subdir) = item
    base = f"https://huggingface.co/tencent/{model}"
    endpoint = f"https://huggingface.co/api/models/tencent/{model}/revision/{rev}?blobs=true"
    with urlopen(endpoint, timeout=40) as response:
        files = {x["rfilename"]: x for x in json.load(response)["siblings"]}
    for name in ("config.yaml", "model.fp16.safetensors"):
        remote = f"{subdir}/{name}"
        final = ROOT / model / remote
        final.parent.mkdir(parents=True, exist_ok=True)
        info = files[remote]
        if final.exists() and final.stat().st_size == info["size"]:
            print("Cached", final, flush=True)
            continue
        part = final.with_suffix(".download")
        digest = hashlib.sha256()
        print("Downloading", model, name, info["size"], flush=True)
        with urlopen(f"{base}/resolve/{rev}/{remote}", timeout=90) as response, part.open("wb") as output:
            for chunk in iter(lambda: response.read(2**20), b""):
                digest.update(chunk)
                output.write(chunk)
        assert part.stat().st_size == info["size"]
        if info.get("lfs"):
            assert digest.hexdigest() == info["lfs"]["sha256"]
        part.replace(final)
        print("Verified", digest.hexdigest(), final, flush=True)

if __name__ == "__main__":
    with ThreadPoolExecutor(max_workers=2) as pool:
        list(pool.map(download, MODELS.items()))

