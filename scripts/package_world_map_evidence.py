"""Package/inspect native Godot PNGs and decode the delivered MP4. No source art edits."""
from pathlib import Path
import json
import shutil
import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "game_mobile_3d/.validation/world_map"
OUT = ROOT / "docs/validation/world_map"
OUT.mkdir(parents=True, exist_ok=True)
for name in ["baseline_gameplay.png", "review_gameplay.png", "review_cliffs.png", "review_leaf_walk.png",
             "review_topdown_diagnostic.png", "review_isometric_diagnostic.png", "gameplay.mp4",
             "gpu_checks.json", "headless_checks.json", "movie.json"]:
    shutil.copyfile(RAW / name, OUT / name)

def panel(paths, labels, output, width=640):
    canvas = Image.new("RGB", (width * len(paths), 390), (24, 29, 27))
    draw = ImageDraw.Draw(canvas)
    for i, (path, label) in enumerate(zip(paths, labels)):
        frame = Image.open(path).convert("RGB")
        frame.thumbnail((width, 360))
        canvas.paste(frame, (i * width, 30))
        draw.text((i * width + 12, 9), label, fill="white")
    canvas.save(output, quality=93)

panel([OUT/"baseline_gameplay.png", OUT/"review_gameplay.png"],
      ["BEFORE - initial import", "REVIEW - softer ground / sky fill / plant light"], OUT/"comparison.jpg")
capture = cv2.VideoCapture(str(OUT/"gameplay.mp4"))
count, fps = int(capture.get(cv2.CAP_PROP_FRAME_COUNT)), capture.get(cv2.CAP_PROP_FPS)
assert capture.isOpened() and count >= 290 and abs(fps-30) < .1
frames = []
for n in [60, 100, 140, 204, 230, 275]:
    capture.set(cv2.CAP_PROP_POS_FRAMES, n-1)
    ok, bgr = capture.read()
    assert ok, f"Cannot decode delivered MP4 frame {n}"
    path = OUT/f"decoded_{n:03}.png"
    Image.fromarray(cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)).save(path)
    frames.append(path)
capture.release()
canvas = Image.new("RGB", (1280, 3*390), (24, 29, 27))
draw = ImageDraw.Draw(canvas)
for i, path in enumerate(frames):
    frame = Image.open(path);frame.thumbnail((640,360))
    x, y = (i%2)*640, (i//2)*390
    canvas.paste(frame, (x,y+30));draw.text((x+12,y+9), f"Native MP4 / frame {path.stem[8:]}", fill="white")
canvas.save(OUT/"motion_contact_sheet.jpg", quality=91)
for path in frames:path.unlink()

metrics = {"delivered_mp4_frames": count, "fps": fps, "duration_s": count/fps,
           "decoded_frames": [60,100,140,204,230,275], "synthetic_frames": False, "phone_verified": False}
for label, a, b in [("wind", "wind_phase_0.png", "wind_phase_1.png"),
                    ("player_reaction", "passage_on.png", "passage_off.png")]:
    first = np.asarray(Image.open(RAW/a).convert("RGB"),dtype=np.int16)
    second = np.asarray(Image.open(RAW/b).convert("RGB"),dtype=np.int16)
    delta = np.max(abs(first-second),axis=2)
    metrics[label] = {"pixels_changed_over_8": int((delta>8).sum()), "mean_absolute_rgb": float(abs(first-second).mean())}
    assert (delta>8).sum()>50, f"No visible native {label} effect"
    panel([RAW/a, RAW/b], [a,b], OUT/(label+"_comparison.jpg"))
(OUT/"pixel_video_checks.json").write_text(json.dumps(metrics,indent=2)+"\n",encoding="utf-8")
print(json.dumps(metrics,indent=2))
