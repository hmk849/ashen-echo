#!/usr/bin/env python3
"""生成全部程序化纹理与 UI 美术(原创,无版权问题)。"""
import os, math, random
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets")
TEX = os.path.join(ROOT, "textures")
UI = os.path.join(ROOT, "ui")
os.makedirs(TEX, exist_ok=True)
os.makedirs(UI, exist_ok=True)
rng = random.Random(20261113)

def noise_tex(size, base, variance, name, blotch=0.06):
    img = Image.new("RGB", (size, size), base)
    px = img.load()
    for y in range(size):
        for x in range(size):
            n = rng.uniform(-variance, variance)
            r, g, b = base
            px[x, y] = (max(0, min(255, int(r + n))), max(0, min(255, int(g + n))), max(0, min(255, int(b + n))))
    # 大斑块
    for _ in range(int(size * size * blotch / 100)):
        x, y = rng.randint(0, size - 1), rng.randint(0, size - 1)
        r = rng.randint(4, 16)
        dr = rng.randint(-22, 22)
        for dy in range(-r, r):
            for dx in range(-r, r):
                if dx * dx + dy * dy <= r * r:
                    xx, yy = (x + dx) % size, (y + dy) % size
                    pr, pg, pb = px[xx, yy]
                    px[xx, yy] = (max(0, min(255, pr + dr)), max(0, min(255, pg + dr)), max(0, min(255, pb + dr)))
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    img.save(os.path.join(TEX, name))
    print("texture:", name)

# 地面雪
noise_tex(256, (225, 230, 238), 14, "ground_snow.png", blotch=0.1)
# 岩石
noise_tex(256, (95, 95, 100), 26, "rock.png")
# 树皮
def bark():
    size = 256
    img = Image.new("RGB", (size, size), (62, 44, 32))
    d = ImageDraw.Draw(img)
    for _ in range(120):
        x = rng.randint(0, size)
        w = rng.randint(1, 3)
        d.line([(x, 0), (x + rng.randint(-10, 10), size)], fill=(rng.randint(30, 90), rng.randint(20, 65), rng.randint(15, 45)), width=w)
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    img.save(os.path.join(TEX, "bark.png"))
    print("texture: bark.png")
bark()
# 木板
def wood():
    size = 256
    img = Image.new("RGB", (size, size), (120, 88, 58))
    d = ImageDraw.Draw(img)
    for y in range(0, size, 32):
        d.line([(0, y), (size, y)], fill=(70, 50, 32), width=3)
        for _ in range(30):
            x = rng.randint(0, size)
            d.line([(x, y + 3), (x + rng.randint(-8, 8), y + 29)], fill=(rng.randint(90, 140), rng.randint(65, 100), rng.randint(40, 70)), width=1)
    img = img.filter(ImageFilter.GaussianBlur(0.5))
    img.save(os.path.join(TEX, "wood.png"))
    print("texture: wood.png")
wood()
# 石墙
def stone():
    size = 256
    img = Image.new("RGB", (size, size), (128, 126, 122))
    d = ImageDraw.Draw(img)
    y = 0
    row = 0
    while y < size:
        x = 0 if row % 2 == 0 else 32
        while x < size:
            w = rng.randint(48, 72)
            h = rng.randint(28, 40)
            shade = rng.randint(-25, 25)
            d.rectangle([x + 2, y + 2, x + w - 2, y + h - 2], fill=(128 + shade, 126 + shade, 122 + shade))
            x += w
        y += 36
        row += 1
    img = img.filter(ImageFilter.GaussianBlur(1.0))
    img.save(os.path.join(TEX, "stone.png"))
    print("texture: stone.png")
stone()
# 雪花粒子
def snow_particle():
    size = 32
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([8, 8, 24, 24], fill=(255, 255, 255, 230))
    d.ellipse([12, 12, 20, 20], fill=(255, 255, 255, 255))
    img = img.filter(ImageFilter.GaussianBlur(1.2))
    img.save(os.path.join(TEX, "particle_snow.png"))
    print("texture: particle_snow.png")
snow_particle()

# ---------------- 标题背景(程序化绘制雪山+灯塔) ----------------
def title_bg():
    W, H = 1600, 900
    img = Image.new("RGB", (W, H))
    px = img.load()
    # 天空渐变:深蓝到暖橙(地平线)
    top = (16, 22, 44)
    mid = (60, 48, 60)
    hor = (196, 110, 60)
    for y in range(H):
        t = y / H
        if t < 0.62:
            k = t / 0.62
            c = tuple(int(a + (b - a) * k) for a, b in zip(top, mid))
        else:
            k = (t - 0.62) / 0.38
            c = tuple(int(a + (b - a) * k) for a, b in zip(mid, hor))
        for x in range(W):
            px[x, y] = c
    # 星星
    for _ in range(140):
        x, y = rng.randint(0, W - 1), rng.randint(0, int(H * 0.5))
        b = rng.randint(120, 255)
        px[x, y] = (b, b, min(255, b + 30))
    # 灰烬粒子
    for _ in range(80):
        x, y = rng.randint(0, W - 1), rng.randint(int(H * 0.3), H - 1)
        b = rng.randint(150, 220)
        px[x, y] = (b, int(b * 0.6), int(b * 0.3))
    # 远山
    layers = [
        (0.60, (40, 44, 66), 0.35),
        (0.66, (32, 36, 56), 0.5),
        (0.72, (24, 27, 44), 0.7),
    ]
    for base_t, color, rough in layers:
        pts = [(0, H)]
        x = 0
        while x <= W:
            y = int(H * (base_t - rng.uniform(0, rough * 0.16)))
            pts.append((x, y))
            x += rng.randint(60, 160)
        pts.append((W, H))
        ImageDraw.Draw(img, "RGBA").polygon(pts, fill=color)
    # 雪地
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle([0, int(H * 0.72), W, H], fill=(232, 238, 246))
    for _ in range(2000):
        x, y = rng.randint(0, W - 1), rng.randint(int(H * 0.72), H - 1)
        shade = rng.randint(-14, 10)
        px[x, y] = (max(0, 232 + shade), max(0, 238 + shade), max(0, 246 + shade))
    # 灯塔剪影
    lx = int(W * 0.62)
    base_y = int(H * 0.74)
    d.polygon([(lx - 26, base_y), (lx - 14, base_y - 300), (lx + 14, base_y - 300), (lx + 26, base_y)], fill=(20, 22, 30))
    d.rectangle([lx - 16, base_y - 340, lx + 16, base_y - 300], fill=(16, 18, 26))
    # 灯火
    for r in range(60, 4, -2):
        alpha = int(60 * (r / 60.0) ** 2)
        d.ellipse([lx - r, base_y - 370 - r, lx + r, base_y - 370 + r], fill=(255, 170, 80, alpha))
    d.ellipse([lx - 10, base_y - 380, lx + 10, base_y - 360], fill=(255, 220, 150))
    # 光柱
    beam = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(beam)
    bd.polygon([(lx - 8, base_y - 370), (lx + 8, base_y - 370), (lx + 420, base_y - 260), (lx + 300, base_y - 190)], fill=(255, 200, 120, 40))
    img = Image.alpha_composite(img.convert("RGBA"), beam).convert("RGB")
    img = img.filter(ImageFilter.GaussianBlur(1.5))
    img.save(os.path.join(UI, "title_bg.png"), optimize=True)
    print("ui: title_bg.png")
title_bg()
print("ALL TEXTURES DONE")
