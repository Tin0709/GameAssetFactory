"""Prepare and register concept views from a local turnaround and traced landmarks."""
import argparse
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

def prepare(sheet, specification, output):
    rgb = np.array(Image.open(sheet).convert("RGB"))
    output.mkdir(parents=True, exist_ok=True)
    for view, spec in specification.items():
        x0, y0, x1, y1 = spec["crop"]
        crop = np.ascontiguousarray(rgb[y0:y1, x0:x1])
        guide = np.zeros(crop.shape[:2], "uint8")
        points = np.int32(spec["outline"]) - np.int32([x0, y0])
        cv2.fillPoly(guide, [points], 255)
        inside = cv2.erode(guide, np.ones((7, 7), "uint8"))
        outside = cv2.dilate(guide, np.ones((9, 9), "uint8"))
        mask = np.uint8(np.where(inside, 1, np.where(guide, 3, np.where(outside, 2, 0))))
        cv2.setRNGSeed(218)
        cv2.grabCut(crop, mask, None, np.zeros((1, 65)), np.zeros((1, 65)), 3, cv2.GC_INIT_WITH_MASK)
        alpha = np.uint8(mask % 2) * 255
        full = Image.fromarray(np.dstack([crop, alpha]))
        box = full.getchannel("A").getbbox()
        if not box:
            raise ValueError(f"Empty registered view: {view}")
        full.save(output / f"{view}-registered.png")
        cut = full.crop(box)
        cut.save(output / f"{view}.png")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sheet", type=Path)
    parser.add_argument("spec", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    prepare(args.sheet, json.loads(args.spec.read_text(encoding="utf-8-sig")), args.output)

