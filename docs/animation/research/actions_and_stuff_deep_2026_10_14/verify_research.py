"""Validate research artifacts only; never runs Blender/Godot or changes assets."""
import csv
import hashlib
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import unquote
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
errors = []
counts = {}

def check(ok, message):
    if not ok:
        errors.append(message)

def read(name):
    return json.loads((HERE / name).read_text(encoding="utf-8-sig"))

def sha(path):
    return hashlib.file_digest(Path(path).open("rb"), "sha256").hexdigest()

def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True, encoding="utf-8").strip()

jsons = list(HERE.glob("*.json"))
for p in jsons:
    json.loads(p.read_text(encoding="utf-8-sig"))
counts["json_parsed"] = len(jsons)

images = list(HERE.glob("*.png")) + list(HERE.glob("*.jpg"))
for p in images:
    with Image.open(p) as im:
        im.verify()
counts["images_decodable"] = len(images)

markdown = list(HERE.glob("*.md")) + [ROOT / "docs/animation/ACTIONS_AND_STUFF_PLAYER_DEEP_RESEARCH.md"]
link_count = 0
for p in markdown:
    for target in re.findall(r"\]\(([^\n]+?)\)", p.read_text(encoding="utf-8-sig")):
        target = target.strip().strip("<>")
        if target.startswith(("http://", "https://", "#")):
            continue
        target = unquote(target.split("#")[0])
        line_match = re.search(r":(\d+)$", target)
        line = int(line_match.group(1)) if line_match else None
        if line_match:
            target = target[:line_match.start()]
        q = Path(target)
        if not q.is_absolute():
            q = p.parent / q
        check(q.exists(), f"Missing link: {p.name} -> {target}")
        if q.exists() and line is not None:
            check(1 <= line <= len(q.read_text(encoding="utf-8-sig").splitlines()), f"Line outside file: {q}:{line}")
        link_count += 1
counts["local_markdown_link_targets"] = link_count

cycles = read("cycles.json")
observations = read("frame_observations.json")
csv_rows = list(csv.DictReader((HERE / "frame_observations.csv").open(encoding="utf-8-sig", newline="")))
check(len(cycles) == 6, "Expected six original gait cycles")
check(len(observations) == len(csv_rows) == 117, "Expected117 observation rows including closing endpoints")
for c in cycles:
    source, number = c["id"].split("_")
    rows = [x for x in observations if x["source"] == source and x["cycle"] == int(number)]
    check(len(rows) == c["frame_intervals"] + 1, f"Incomplete cycle {c['id']}")
    check((HERE / c["sheet"]).exists(), f"Missing cycle sheet {c['id']}")
    for row in rows:
        f = row["source_frame_zero_based"]
        check(c["first_frame"] <= f <= c["closing_frame"], f"Frame outside cycle {c['id']}")
        check(abs(row["source_time_s"] - f / c["fps"]) < 1e-8, "Timestamp mismatch")
        check(abs(row["phase_percent"] - 100 * (f-c["first_frame"])/c["frame_intervals"]) < 1e-7, "Phase mismatch")
counts["cycles"] = len(cycles)
counts["observation_rows"] = len(observations)

sources = list(read("source_media.json").values())
sources += [read("showcase_decode_report.json"), read("supplement2_decode.json")]
for item in sources:
    path = item.get("path", item.get("source"))
    check(sha(path) == item["sha256"], f"Source changed: {path}")
counts["reference_video_hashes_unchanged"] = len(sources)
local_sources = read("local_evidence.json")["sources"]
for item in local_sources:
    check(sha(ROOT / item["path"]) == item["sha256"], f"Audited local source changed: {item['path']}")
counts["local_source_hashes_unchanged"] = len(local_sources)

initial = "fd593a51"
changed = git("diff", "--name-only", initial).splitlines()
changed += git("ls-files", "--others", "--exclude-standard").splitlines()
allowed = ("docs/animation/research/actions_and_stuff_deep_2026_10_14/",)
allowed_files = {"AGENTS.md", "docs/animation/ACTIONS_AND_STUFF_PLAYER_DEEP_RESEARCH.md"}
unexpected = sorted({x for x in changed if x not in allowed_files and not x.startswith(allowed)})
check(not unexpected, f"Outside research scope: {unexpected}")
diff_check = subprocess.run(["git", "diff", "--check", initial], cwd=ROOT, capture_output=True, text=True)
check(diff_check.returncode == 0, diff_check.stdout + diff_check.stderr)

report = {
    "verified_at_utc": datetime.now(timezone.utc).isoformat(),
    "scope": "Artifact integrity, relative file links, source hashes and Git scope; no engine, motion or artistic certification",
    "counts": counts, "branch": git("branch", "--show-current"), "head": git("rev-parse", "HEAD"),
    "worktrees": git("worktree", "list", "--porcelain"),
    "baseline_head": initial, "unexpected_changed_paths": unexpected,
    "git_diff_check_pass": diff_check.returncode == 0, "errors": errors,
    "pass": not errors,
}
(HERE / "verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report, ensure_ascii=False, indent=2))
raise SystemExit(bool(errors))
