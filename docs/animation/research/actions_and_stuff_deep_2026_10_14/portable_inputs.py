"""Portable, hash-checked original media inputs. Historical reports stay intact."""
import hashlib
import json
from pathlib import Path
from PIL import ImageFont

ROOT = Path(__file__).resolve().parents[4]
MEDIA = ROOT / 'references/motion/actions_and_stuff'


def source(key):
    entry = json.loads((MEDIA / 'manifest.json').read_text())[key]
    path = MEDIA / entry['file']
    if hashlib.sha256(path.read_bytes()).hexdigest() != entry['sha256']:
        raise ValueError(f'Reference recording hash mismatch: {path}')
    return path


def font(size, monospace=False):
    names = (['C:/Windows/Fonts/consola.ttf', '/System/Library/Fonts/Menlo.ttc', 'DejaVuSansMono.ttf']
             if monospace else ['C:/Windows/Fonts/arial.ttf', '/System/Library/Fonts/Supplemental/Arial.ttf', 'DejaVuSans.ttf'])
    for name in names:
        try: return ImageFont.truetype(name, size)
        except OSError: pass
    return ImageFont.load_default(size=size)
