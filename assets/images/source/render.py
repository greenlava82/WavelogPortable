import sys, math, numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops
S = 1024; K = 4; W = S*K
scrib = Image.open(sys.argv[1]).convert('L').filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(0.6))
outdir = sys.argv[2]

DARK = (11, 92, 6)        # brand green #0C6403-ish
DEEP = (7, 64, 4)
INK = (38, 44, 36)

def grad_v(w, h, top, bot):
    t = np.linspace(0, 1, h)[:, None, None]
    arr = np.array(top)[None, None, :] * (1 - t) + np.array(bot)[None, None, :] * t
    return Image.fromarray(np.repeat(arr, w, 1).astype(np.uint8), 'RGB')

def background():
    bg = grad_v(S, S, (236, 244, 222), (140, 186, 128)).convert('RGBA')
    # soft glow behind the book / waves
    glow = Image.new('L', (S, S), 0)
    ImageDraw.Draw(glow).ellipse((150, 120, 874, 760), fill=120)
    glow = glow.filter(ImageFilter.GaussianBlur(120))
    white = Image.new('RGBA', (S, S), (255, 255, 250, 255))
    return Image.composite(white, bg, glow)

def bez(p0, p1, p2, n=60):
    return [((1-t)**2*p0[0]+2*(1-t)*t*p1[0]+t*t*p2[0], (1-t)**2*p0[1]+2*(1-t)*t*p1[1]+t*t*p2[1]) for t in [i/n for i in range(n+1)]]

def sc(pts): return [(x*K, y*K) for x, y in pts]

def art():
    """Book + waves on transparent, 1024 canvas."""
    L = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(L)
    # --- radio waves: concentric, rounded caps, getting bolder outward
    cx, cy = 512, 428
    for r, w in [(96, 26), (176, 30), (256, 34), (336, 38)]:
        half = 44 if r > 100 else 40
        R, Wd = r*K, w*K
        box = (cx*K-R-Wd/2, cy*K-R-Wd/2, cx*K+R+Wd/2, cy*K+R+Wd/2)
        d.arc(box, 270-half, 270+half, fill=DARK+(255,), width=int(Wd))
        for a in (270-half, 270+half):
            x = cx*K + R*math.cos(math.radians(a)); y = cy*K + R*math.sin(math.radians(a))
            d.ellipse((x-Wd/2, y-Wd/2, x+Wd/2, y+Wd/2), fill=DARK+(255,))
    # --- book
    top_l = bez((178, 392), (330, 336), (512, 396))
    top_r = [(1024-x, y) for x, y in reversed(top_l)]
    bot_l = bez((512, 884), (340, 860), (178, 874))
    bot_r = [(1024-x, y) for x, y in reversed(bez((512, 884), (340, 860), (178, 874)))]
    # cover (slightly larger, peeks out on sides and bottom)
    cover = sc([(160, 400)] + [(x, y+14) for x, y in bez((512, 884), (340, 868), (160, 884))][::-1][::-1] )
    cov = [(160, 398), (512, 404), (864, 398), (864, 896)] + [(1024-x, y) for x, y in bez((160, 896), (340, 880), (512, 902))][::-1][1:] + bez((512, 902), (340, 880), (160, 896))[1:]
    # simpler: build left half then mirror
    left_cov = [(512, 404), (160, 398), (160, 898)] + bez((160, 898), (340, 884), (512, 906))[1:]
    right_cov = [(1024-x, y) for x, y in left_cov]
    d.polygon(sc(left_cov), fill=DEEP+(255,)); d.polygon(sc(right_cov), fill=DEEP+(255,))
    # page stacks (thin cream layers under the top page)
    for off, col in [(14, (214, 204, 186)), (8, (232, 224, 208))]:
        lp = [(178, 392+off)] + [(x, y+off) for x, y in bot_l[::-1]][::-1]
        lp = top_l + [(512, 884+off)] + [(x, y+off) for x, y in bot_l][1:]
        rp = [(1024-x, y) for x, y in lp]
        d.polygon(sc(lp), fill=col+(255,)); d.polygon(sc(rp), fill=col+(255,))
    # top pages with horizontal shading toward the gutter
    for side in (0, 1):
        poly = top_l + bot_l if side == 0 else [(1024-x, y) for x, y in top_l + bot_l]
        m = Image.new('L', (W, W), 0); ImageDraw.Draw(m).polygon(sc(poly), fill=255)
        x = np.linspace(0, 1, W)
        t = np.clip((x*1024 - 178)/(512-178), 0, 1) if side == 0 else np.clip((846 - x*1024)/(846-512), 0, 1)
        t = t**1.6
        c0, c1 = np.array((253, 248, 238)), np.array((214, 196, 172))
        row = (c0*(1-t[:, None]) + c1*t[:, None]).astype(np.uint8)
        page = Image.fromarray(np.repeat(row[None, :, :], W, 0), 'RGB').convert('RGBA')
        L.paste(page, (0, 0), m)
    # outlines
    for poly in (top_l + bot_l, [(1024-x, y) for x, y in top_l + bot_l]):
        d.line(sc(poly + poly[:1]), fill=(60, 54, 40, 255), width=3*K, joint='curve')
    d.line(sc([(512, 396), (512, 884)]), fill=(120, 100, 76, 255), width=3*K)
    L = L.resize((S, S), Image.LANCZOS)
    # teen's handwriting, re-inked
    ink = Image.new('RGBA', (S, S), INK + (255,))
    ink.putalpha(ImageChops.multiply(scrib, Image.new('L', (S, S), 235)))
    L.alpha_composite(ink)
    return L

def shadowed(a):
    sh = Image.new('L', (S, S), 0)
    ImageDraw.Draw(sh).rounded_rectangle((150, 470, 874, 930), radius=60, fill=110)
    sh = sh.filter(ImageFilter.GaussianBlur(26))
    layer = Image.new('RGBA', (S, S), (20, 50, 16, 0)); layer.putalpha(sh)
    out = Image.new('RGBA', (S, S), (0, 0, 0, 0)); out.alpha_composite(layer); out.alpha_composite(a)
    return out

def fit(a, scale, dy=0):
    """Shrink the art about the canvas centre (content centre ~ y 510)."""
    n = int(S*scale); small = a.resize((n, n), Image.LANCZOS)
    c = Image.new('RGBA', (S, S), (0, 0, 0, 0)); c.alpha_composite(small, ((S-n)//2, (S-n)//2 + dy)); return c

a = shadowed(art())
full = background(); full.alpha_composite(fit(a, 0.86, 8)); full.convert('RGB').save(f'{outdir}/app_icon.png')
fg = fit(a, 0.615, -2); fg.save(f'{outdir}/icon_foreground.png')
background().convert('RGB').save(f'{outdir}/icon_background.png')
# preview: masked as rounded square and circle
def mask(img, kind):
    m = Image.new('L', (S, S), 0); dd = ImageDraw.Draw(m)
    (dd.ellipse if kind == 'circle' else lambda b, **k: dd.rounded_rectangle(b, radius=230, **k))((0, 0, S, S), fill=255)
    o = Image.new('RGBA', (S, S), (0, 0, 0, 0)); o.paste(img, (0, 0), m); return o
