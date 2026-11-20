#!/usr/bin/env python3
"""Trocea una losa de fichas en imágenes individuales.

Dos modos:

1) Rejilla uniforme (para bloques regulares):
   python3 tools/cut_counters.py assets/counters_20th/sheets/sheet_07_front.webp \
       /tmp/fichas --cols 5 --rows 8 --top 40 --bottom 20 --left 0 --right 0

2) Cajas explícitas (recomendado para las losas reales, que mezclan tamaños):
   python3 tools/cut_counters.py assets/counters_20th/sheets/sheet_07_front.webp \
       /tmp/fichas --boxes boxes.json

   boxes.json:
   [
     {"name": "finnish/squad/sissi_1_front", "box": [12, 640, 112, 710]},
     ...
   ]

El nombre se usa como ruta relativa (se crean las carpetas) y se añade .png.
"""
import argparse
import json
import os
from PIL import Image


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("sheet")
    ap.add_argument("out")
    ap.add_argument("--cols", type=int, default=0)
    ap.add_argument("--rows", type=int, default=0)
    ap.add_argument("--top", type=int, default=0)
    ap.add_argument("--bottom", type=int, default=0)
    ap.add_argument("--left", type=int, default=0)
    ap.add_argument("--right", type=int, default=0)
    ap.add_argument("--boxes")
    ap.add_argument("--prefix", default="")
    args = ap.parse_args()

    im = Image.open(args.sheet).convert("RGBA")
    os.makedirs(args.out, exist_ok=True)

    if args.boxes:
        with open(args.boxes, encoding="utf-8") as fh:
            boxes = json.load(fh)
        for item in boxes:
            name = str(item.get("name", "counter")).replace(" ", "_")
            box = [int(v) for v in item["box"]]
            crop = im.crop((box[0], box[1], box[2], box[3]))
            path = os.path.join(args.out, name + ".png")
            os.makedirs(os.path.dirname(path), exist_ok=True)
            crop.save(path)
        print(f"{len(boxes)} fichas -> {args.out}")
        return

    if not args.cols or not args.rows:
        ap.error("usa --boxes o indica --cols y --rows")
    x0, y0 = args.left, args.top
    x1, y1 = im.width - args.right, im.height - args.bottom
    cw = (x1 - x0) / args.cols
    ch = (y1 - y0) / args.rows
    n = 0
    for r in range(args.rows):
        for c in range(args.cols):
            box = (int(x0 + c * cw), int(y0 + r * ch), int(x0 + (c + 1) * cw), int(y0 + (r + 1) * ch))
            name = f"{args.prefix}{r + 1:02d}_{c + 1:02d}"
            im.crop(box).save(os.path.join(args.out, name + ".png"))
            n += 1
    print(f"{n} fichas -> {args.out}")


if __name__ == "__main__":
    main()
