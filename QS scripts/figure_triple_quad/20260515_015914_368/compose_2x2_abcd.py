# -*- coding: utf-8 -*-
"""Compose alphabetically sorted images in each subfolder into one 2x2 panel with (a)-(d) labels."""

from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SUBDIRS = ("hyst_Binhibit", "hyst_Bpromote", "nohyst_Binhibit", "nohyst_Bpromote")
IMAGE_EXTS = (".png", ".jpg", ".jpeg", ".webp", ".tif", ".tiff")
LABELS = ("(a)", "(b)", "(c)", "(d)")
OUTPUT_NAME = "composite_2x2_abcd.png"
LABEL_BAND = 48
FONT_SIZE = 28
PAD = 8


def _sorted_image_paths(folder: Path) -> list[Path]:
    files = [
        p
        for p in folder.iterdir()
        if p.is_file() and p.suffix.lower() in IMAGE_EXTS and p.name != OUTPUT_NAME
    ]
    return sorted(files, key=lambda p: p.name.lower())


def _load_font() -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        r"C:\Windows\Fonts\arial.ttf",
        r"C:\Windows\Fonts\calibri.ttf",
        r"C:\Windows\Fonts\msyh.ttc",
    ]
    for fp in candidates:
        if os.path.isfile(fp):
            try:
                return ImageFont.truetype(fp, FONT_SIZE)
            except OSError:
                continue
    return ImageFont.load_default()


def _to_rgb_on_white(im: Image.Image) -> Image.Image:
    if im.mode == "RGBA":
        base = Image.new("RGB", im.size, (255, 255, 255))
        base.paste(im, mask=im.split()[3])
        return base
    return im.convert("RGB")


def _pad_to_size(im: Image.Image, w: int, h: int, bg: tuple[int, int, int] = (255, 255, 255)) -> Image.Image:
    rgb = _to_rgb_on_white(im)
    if rgb.size == (w, h):
        return rgb
    canvas = Image.new("RGB", (w, h), bg)
    x = (w - rgb.size[0]) // 2
    y = (h - rgb.size[1]) // 2
    canvas.paste(rgb, (x, y))
    return canvas


def compose_folder(folder: Path, font: ImageFont.FreeTypeFont | ImageFont.ImageFont) -> Path:
    paths = _sorted_image_paths(folder)
    if len(paths) != 4:
        raise SystemExit(f"{folder}: need exactly 4 images, found {len(paths)}")

    images = [Image.open(p) for p in paths]
    try:
        max_w = max(im.size[0] for im in images)
        max_h = max(im.size[1] for im in images)
        cell_w = max_w + 2 * PAD
        cell_h_img = max_h + 2 * PAD
        cell_h = cell_h_img + LABEL_BAND

        total_w = cell_w * 2
        total_h = cell_h * 2
        out = Image.new("RGB", (total_w, total_h), (255, 255, 255))
        draw = ImageDraw.Draw(out)

        positions = [(0, 0), (cell_w, 0), (0, cell_h), (cell_w, cell_h)]
        for idx, (im, label, (ox, oy)) in enumerate(zip(images, LABELS, positions)):
            padded = _pad_to_size(im, cell_w - 2 * PAD, cell_h_img - 2 * PAD)
            sub = Image.new("RGB", (cell_w, cell_h_img), (255, 255, 255))
            sx = (cell_w - padded.size[0]) // 2
            sy = (cell_h_img - padded.size[1]) // 2
            sub.paste(padded, (sx, sy))
            out.paste(sub, (ox, oy))

            bbox = draw.textbbox((0, 0), label, font=font)
            tw = bbox[2] - bbox[0]
            th = bbox[3] - bbox[1]
            tx = ox + (cell_w - tw) // 2
            ty = oy + cell_h_img + (LABEL_BAND - th) // 2
            draw.text((tx, ty), label, fill=(0, 0, 0), font=font)
    finally:
        for im in images:
            im.close()

    out_path = folder / OUTPUT_NAME
    out.save(out_path, dpi=(150, 150))
    return out_path


def main() -> None:
    root = Path(__file__).resolve().parent
    font = _load_font()
    for name in SUBDIRS:
        d = root / name
        if not d.is_dir():
            print(f"skip missing: {d}")
            continue
        out = compose_folder(d, font)
        print(f"saved: {out}")


if __name__ == "__main__":
    main()
