"""Adds an orange "DEV" badge to the launcher icon for development builds.

Usage: python dev_badge.py <assets/images dir> <android/app/src/debug/res dir> <font.ttf>
Writes drawable-*/ic_launcher_foreground.png (adaptive icon) and
mipmap-*/launcher_icon.png (pre-Android 8) into the debug resource set.
"""
import os, sys
from PIL import Image, ImageDraw, ImageFont

src, out, font_path = sys.argv[1:4]
ORANGE = (230, 110, 0, 255)

def badge(img, cx, cy, w, h):
    s = img.size[0]
    d = ImageDraw.Draw(img)
    box = (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)
    d.rounded_rectangle(box, radius=h / 2, fill=ORANGE, outline=(255, 255, 255, 255), width=max(2, s // 128))
    font = ImageFont.truetype(font_path, int(h * 0.72))
    d.text((cx, cy + h * 0.02), "DEV", font=font, fill="white", anchor="mm")
    return img

S = 1024
fg = Image.open(os.path.join(src, "icon_foreground.png")).convert("RGBA")
fg = badge(fg, S / 2, S * 0.735, S * 0.30, S * 0.105)
full = Image.open(os.path.join(src, "app_icon.png")).convert("RGBA")
full = badge(full, S / 2, S * 0.80, S * 0.40, S * 0.15)

for dens, fgpx, mippx in [("mdpi", 108, 48), ("hdpi", 162, 72), ("xhdpi", 216, 96), ("xxhdpi", 324, 144), ("xxxhdpi", 432, 192)]:
    for folder, img, px, name in [(f"drawable-{dens}", fg, fgpx, "ic_launcher_foreground.png"),
                                  (f"mipmap-{dens}", full, mippx, "launcher_icon.png")]:
        os.makedirs(os.path.join(out, folder), exist_ok=True)
        img.resize((px, px), Image.LANCZOS).save(os.path.join(out, folder, name))
fg.save(os.path.join(src, "source", "dev_preview_foreground.png")) if os.path.isdir(os.path.join(src, "source")) else None
