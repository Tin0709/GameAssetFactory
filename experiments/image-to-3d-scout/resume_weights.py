"""Resume pinned safetensors downloads with parallel HTTP ranges and full-file SHA-256."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
from pathlib import Path
from time import sleep, time_ns
from urllib.request import Request, urlopen
import json
from download_weights import MODELS, ROOT

CHUNK = 64 * 1024 * 1024

def fetch(task):
    url, target, start, end, size = task
    if target.exists() and target.stat().st_size == end - start + 1:
        return
    temp = target.with_name(target.name + ".pending")
    for retry in range(4):
        request = Request(url + f"?download=true&chunk={start}&retry={retry}", headers={"Range": f"bytes={start}-{end}"})
        try:
            with urlopen(request, timeout=30) as response, temp.open("wb") as output:
                assert response.status == 206
                assert response.headers["Content-Range"] == f"bytes {start}-{end}/{size}"
                for chunk in iter(lambda: response.read(2**20), b""):
                    output.write(chunk)
            assert temp.stat().st_size == end - start + 1
            temp.replace(target)
            return
        except Exception as error:
            if retry == 3:
                raise
            print("Retry segment", start, str(error), flush=True)
            sleep(retry + 1)

def job(item):
    model, (rev, subfolder) = item
    remote = f"{subfolder}/model.fp16.safetensors"
    url = f"https://huggingface.co/tencent/{model}/resolve/{rev}/{remote}"
    endpoint = f"https://huggingface.co/api/models/tencent/{model}/revision/{rev}?blobs=true"
    with urlopen(endpoint, timeout=30) as response:
        info = next(x for x in json.load(response)["siblings"] if x["rfilename"] == remote)
    target = ROOT / model / remote
    begin = target.with_suffix(".download")
    final = target.with_suffix(".joining")
    if target.is_file():
        return
    start = begin.stat().st_size if begin.exists() else 0
    size = info["size"]
    tasks = []
    for cursor in range(start, size, CHUNK):
        part = target.with_suffix(f".part-{cursor:010}")
        end = min(size-1, cursor+CHUNK-1)
        tasks.append((url, part, cursor, end, size))
    print("Starting", model, start, size, len(tasks), flush=True)
    with ThreadPoolExecutor(max_workers=10) as workers:
        list(workers.map(fetch, tasks))
    digest = hashlib.sha256()
    with final.open("wb") as out:
        for f in [begin] + [x[1] for x in tasks]:
            if f.exists():
                with f.open("rb") as stream:
                    for chunk in iter(lambda: stream.read(2**20), b""):
                        out.write(chunk)
                        digest.update(chunk)
    assert final.stat().st_size == size and digest.hexdigest() == info["lfs"]["sha256"]
    final.replace(target)
    print("Verified", model, digest.hexdigest(), flush=True)
    for f in [begin] + [x[1] for x in tasks]:
        f.unlink(missing_ok=True)

if __name__ == "__main__":
    with ThreadPoolExecutor(max_workers=2) as pool:
        list(pool.map(job, MODELS.items()))


