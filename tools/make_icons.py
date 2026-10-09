"""Draw Snag A Goober's original UI icons (chunky shapes, thick dark outline).

Outputs Assets/UI/Icons/<name>.png (256x256, transparent). Drawn at 4x and
downsampled so edges stay smooth. Everything is drawn here from basic shapes.
"""
import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Assets", "UI", "Icons")
os.makedirs(OUT, exist_ok=True)

S = 1024  # working size
INK = (24, 14, 40, 255)
OUTLINE = 34  # px at working size


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


class Icon:
    def __init__(self):
        self.img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    def layer(self, draw_fn, color, outline=OUTLINE, gloss=True):
        mask = Image.new("L", (S, S), 0)
        draw_fn(ImageDraw.Draw(mask))
        if outline:
            grow = mask.filter(ImageFilter.GaussianBlur(outline / 2)).point(lambda v: 255 if v > 8 else 0)
            grow = grow.filter(ImageFilter.GaussianBlur(1.5))
            ink = Image.new("RGBA", (S, S), INK)
            self.img.paste(ink, (0, 0), grow)
        c = rgb(color) if isinstance(color, str) else color
        bbox = mask.getbbox()
        if not bbox:
            return
        grad = Image.new("RGBA", (S, S))
        gd = ImageDraw.Draw(grad)
        y0, y1 = bbox[1], bbox[3]
        for y in range(S):
            k = 1.18 - 0.36 * min(1, max(0, (y - y0) / max(1, y1 - y0)))
            gd.line([(0, y), (S, y)], fill=shade(c, k) + (255,))
        self.img.paste(grad, (0, 0), mask)
        if gloss:
            # soft white highlight on the upper-left of the shape
            hl = Image.new("L", (S, S), 0)
            hd = ImageDraw.Draw(hl)
            w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
            hd.ellipse([bbox[0] + w * 0.12, bbox[1] + h * 0.08, bbox[0] + w * 0.5, bbox[1] + h * 0.34], fill=90)
            hl = ImageChops.multiply(hl.filter(ImageFilter.GaussianBlur(18)), mask)
            self.img.paste(Image.new("RGBA", (S, S), (255, 255, 255, 255)), (0, 0), hl)

    def lines(self, pts_list, width, color=INK):
        d = ImageDraw.Draw(self.img)
        for pts in pts_list:
            d.line(pts, fill=color, width=width, joint="curve")
            r = width / 2
            for p in (pts[0], pts[-1]):
                d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=color)

    def save(self, name):
        out = self.img.resize((256, 256), Image.LANCZOS)
        out.save(os.path.join(OUT, name + ".png"))


def star_pts(cx, cy, r1, r2, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def rr(d, box, r, **kw):
    d.rounded_rectangle(box, r, fill=255, **kw)


ICONS = {}


def icon(fn):
    ICONS[fn.__name__] = fn
    return fn


# ------------------------------------------------------------ navigation
@icon
def pumpkin():
    ic = Icon()
    ic.layer(lambda d: d.rectangle([470, 150, 560, 300], fill=255), "#4a8a3a", gloss=False)  # stem
    def body(d):
        for x0, x1 in ((170, 600), (420, 860), (300, 730)):
            d.ellipse([x0, 260, x1, 880], fill=255)
    ic.layer(body, "#ff8a1f")
    d = ImageDraw.Draw(ic.img)
    d.polygon([(330, 480), (420, 600), (300, 610)], fill=INK)
    d.polygon([(700, 480), (610, 600), (730, 610)], fill=INK)
    d.polygon([(290, 680), (360, 720), (420, 690), (480, 740), (550, 690), (610, 740), (670, 690), (740, 680), (680, 790), (350, 790)], fill=INK)
    ic.save("pumpkin")


@icon
def shop():
    ic = Icon()
    ic.layer(lambda d: d.arc([350, 150, 680, 480], 180, 360, fill=255, width=60), "#ffd27a", outline=26, gloss=False)
    ic.layer(lambda d: d.polygon([(200, 330), (830, 330), (790, 870), (240, 870)], fill=255), "#ffb02e")
    ic.layer(lambda d: d.rounded_rectangle([200, 300, 830, 420], 30, fill=255), "#ff5fa2")
    ic.layer(lambda d: d.ellipse([420, 520, 610, 710], fill=255), "#ffffff", outline=24, gloss=False)
    ic.save("shop")


@icon
def book():
    ic = Icon()
    ic.layer(lambda d: rr(d, [180, 160, 860, 870], 60), "#3da5ff")
    ic.layer(lambda d: rr(d, [260, 220, 820, 780], 30), "#e8f3ff", outline=20, gloss=False)
    ic.layer(lambda d: d.polygon(star_pts(540, 500, 190, 85), fill=255), "#ffc93c", outline=22)
    ic.layer(lambda d: rr(d, [180, 160, 290, 870], 40), "#2078d0", outline=20, gloss=False)
    ic.save("book")


@icon
def scroll():
    ic = Icon()
    ic.layer(lambda d: rr(d, [230, 200, 800, 840], 40), "#ffe7b0")
    ic.layer(lambda d: rr(d, [180, 150, 850, 270], 60), "#d9a45a")
    ic.layer(lambda d: rr(d, [180, 780, 850, 900], 60), "#d9a45a")
    ic.lines([[(320, 380), (710, 380)], [(320, 500), (710, 500)], [(320, 620), (600, 620)]], 44)
    ic.layer(lambda d: d.ellipse([620, 580, 820, 780], fill=255), "#ff4d5e", outline=22)
    ic.save("scroll")


@icon
def trophy():
    ic = Icon()
    ic.layer(lambda d: d.arc([130, 230, 450, 600], 90, 270, fill=255, width=60), "#ffc93c", outline=24, gloss=False)
    ic.layer(lambda d: d.arc([580, 230, 900, 600], 270, 90, fill=255, width=60), "#ffc93c", outline=24, gloss=False)
    ic.layer(lambda d: rr(d, [330, 760, 700, 880], 30), "#9b6bff")
    ic.layer(lambda d: d.rectangle([450, 600, 580, 780], fill=255), "#ffb02e", gloss=False)
    ic.layer(lambda d: d.chord([250, 50, 780, 720], 0, 180, fill=255) or d.rectangle([250, 200, 780, 390], fill=255), "#ffc93c")
    ic.layer(lambda d: d.polygon(star_pts(515, 400, 140, 62), fill=255), "#fff3c4", outline=18, gloss=False)
    ic.save("trophy")


@icon
def upgrade():
    ic = Icon()
    ic.layer(lambda d: d.polygon([(512, 120), (870, 520), (660, 520), (660, 880), (364, 880), (364, 520), (154, 520)], fill=255), "#7be35a")
    ic.save("upgrade")


@icon
def rebirth():
    ic = Icon()
    def ring(d):
        d.arc([180, 180, 840, 840], 200, 520, fill=255, width=120)
    ic.layer(ring, "#c06bff")
    ic.layer(lambda d: d.polygon([(130, 360), (370, 300), (260, 560)], fill=255), "#c06bff", gloss=False)
    ic.layer(lambda d: d.polygon(star_pts(510, 510, 150, 66), fill=255), "#ffc93c", outline=22)
    ic.save("rebirth")


@icon
def gear():
    ic = Icon()
    def g(d):
        pts = []
        for i in range(16):
            a = math.radians(i * 22.5)
            r = 380 if (i % 2 == 0) else 300
            for da in (-7, 7):
                pts.append((512 + r * math.cos(a + math.radians(da)), 512 + r * math.sin(a + math.radians(da))))
        d.polygon(pts, fill=255)
    ic.layer(g, "#b9a9d9")
    d = ImageDraw.Draw(ic.img)
    d.ellipse([400, 400, 624, 624], fill=INK)
    ic.layer(lambda d: d.ellipse([430, 430, 594, 594], fill=255), "#3b2a5a", outline=0, gloss=False)
    ic.save("gear")


# ------------------------------------------------------------ top tabs
@icon
def house():
    ic = Icon()
    ic.layer(lambda d: rr(d, [230, 450, 800, 880], 30), "#ffe7b0")
    ic.layer(lambda d: d.polygon([(130, 500), (512, 140), (894, 500)], fill=255), "#ff4d5e")
    ic.layer(lambda d: rr(d, [440, 640, 590, 880], 20), "#a0603a", outline=22, gloss=False)
    ic.save("house")


@icon
def belt():
    ic = Icon()
    ic.layer(lambda d: rr(d, [100, 560, 924, 820], 130), "#4a3a66")
    d = ImageDraw.Draw(ic.img)
    for x in (230, 400, 570, 740):
        d.polygon([(x, 600), (x + 80, 690), (x, 780), (x + 40, 690)], fill=(123, 227, 90, 255))
    ic.layer(lambda d: d.ellipse([330, 170, 690, 530], fill=255), "#7be35a")
    d.ellipse([420, 280, 470, 340], fill=INK)
    d.ellipse([550, 280, 600, 340], fill=INK)
    ic.save("belt")


@icon
def ghost():
    ic = Icon()
    def body(d):
        d.ellipse([230, 120, 790, 640], fill=255)
        d.rectangle([230, 380, 790, 800], fill=255)
        for i, x in enumerate((230, 370, 510, 650)):
            d.ellipse([x, 720, x + 140, 880], fill=255)
    ic.layer(body, "#f4eeff")
    d = ImageDraw.Draw(ic.img)
    d.ellipse([360, 330, 460, 470], fill=INK)
    d.ellipse([560, 330, 660, 470], fill=INK)
    d.ellipse([460, 520, 560, 640], fill=INK)
    ic.save("ghost")


# ------------------------------------------------------------ currency
@icon
def coin():
    ic = Icon()
    ic.layer(lambda d: d.ellipse([140, 140, 884, 884], fill=255), "#ffc93c")
    ic.layer(lambda d: d.ellipse([250, 250, 774, 774], fill=255), "#ffb02e", outline=18, gloss=False)
    d = ImageDraw.Draw(ic.img)
    # a chunky "$"-free goo drop mark so the coin reads as Slop
    ic.layer(lambda d: d.polygon([(512, 320), (620, 520), (404, 520)], fill=255) or d.ellipse([400, 440, 624, 680], fill=255), "#7be35a", outline=18)
    ic.save("coin")


@icon
def candy():
    ic = Icon()
    ic.layer(lambda d: d.polygon([(140, 330), (330, 450), (330, 580), (140, 700), (200, 512)], fill=255), "#ff9fd0", gloss=False)
    ic.layer(lambda d: d.polygon([(884, 330), (694, 450), (694, 580), (884, 700), (824, 512)], fill=255), "#ff9fd0", gloss=False)
    ic.layer(lambda d: d.ellipse([290, 290, 734, 734], fill=255), "#ff5fa2")
    d = ImageDraw.Draw(ic.img)
    for k in (-1, 0, 1):
        d.line([(420 + k * 110, 320), (520 + k * 110, 700)], fill=(255, 255, 255, 230), width=44)
    ic.save("candy")


# ------------------------------------------------------------ status
@icon
def bolt():
    ic = Icon()
    ic.layer(lambda d: d.polygon([(600, 100), (220, 560), (470, 560), (400, 920), (800, 420), (540, 420)], fill=255), "#ffc93c")
    ic.save("bolt")


@icon
def lock():
    ic = Icon()
    ic.layer(lambda d: d.arc([300, 120, 724, 560], 180, 360, fill=255, width=90) or d.rectangle([300, 330, 390, 470], fill=255) or d.rectangle([634, 330, 724, 470], fill=255), "#b9a9d9", gloss=False)
    ic.layer(lambda d: rr(d, [210, 430, 814, 900], 70), "#3da5ff")
    ic.layer(lambda d: d.ellipse([450, 560, 574, 684], fill=255) or d.rectangle([485, 640, 539, 780], fill=255), "#18304f", outline=0, gloss=False)
    ic.save("lock")


@icon
def gift():
    ic = Icon()
    ic.layer(lambda d: rr(d, [190, 420, 834, 880], 40), "#7be35a")
    ic.layer(lambda d: rr(d, [150, 300, 874, 460], 40), "#9cf27a")
    ic.layer(lambda d: d.rectangle([450, 300, 574, 880], fill=255), "#ff5fa2", outline=18, gloss=False)
    ic.layer(lambda d: d.ellipse([290, 140, 520, 330], fill=255) or d.ellipse([504, 140, 734, 330], fill=255), "#ff5fa2", outline=22, gloss=False)
    ic.save("gift")


@icon
def swirl():
    ic = Icon()
    ic.layer(lambda d: d.ellipse([140, 140, 884, 884], fill=255), "#b04bff")
    d = ImageDraw.Draw(ic.img)
    pts = []
    for i in range(200):
        a = i / 200 * 4.2 * math.pi
        r = 30 + i * 1.55
        pts.append((512 + r * math.cos(a), 512 + r * math.sin(a)))
    d.line(pts, fill=(255, 220, 255, 255), width=50, joint="curve")
    ic.save("swirl")


@icon
def check():
    ic = Icon()
    ic.layer(lambda d: d.ellipse([120, 120, 904, 904], fill=255), "#7be35a")
    ic.lines([[(320, 530), (460, 670), (720, 380)]], 110, (255, 255, 255, 255))
    ic.save("check")


@icon
def cross():
    ic = Icon()
    ic.layer(lambda d: d.ellipse([120, 120, 904, 904], fill=255), "#ff4d5e")
    ic.lines([[(350, 350), (674, 674)], [(674, 350), (350, 674)]], 110, (255, 255, 255, 255))
    ic.save("cross")


@icon
def shoe():
    ic = Icon()
    ic.layer(lambda d: d.polygon([(240, 300), (480, 300), (520, 520), (850, 620), (880, 760), (170, 760)], fill=255), "#ff4d5e")
    ic.layer(lambda d: rr(d, [150, 730, 900, 840], 40), "#ffffff", outline=22, gloss=False)
    ic.lines([[(310, 420), (430, 420)], [(320, 520), (470, 520)]], 36, (255, 255, 255, 255))
    ic.layer(lambda d: d.polygon([(90, 400), (210, 360), (210, 440)], fill=255) or d.polygon([(60, 560), (190, 520), (190, 600)], fill=255), "#ffc93c", outline=16, gloss=False)
    ic.save("shoe")


@icon
def stand():
    ic = Icon()
    ic.layer(lambda d: rr(d, [180, 640, 844, 820], 40), "#9b6bff")
    ic.layer(lambda d: rr(d, [280, 560, 744, 680], 30), "#c3a3ff")
    ic.layer(lambda d: d.ellipse([360, 220, 664, 560], fill=255), "#7be35a")
    d = ImageDraw.Draw(ic.img)
    d.ellipse([430, 330, 480, 390], fill=INK)
    d.ellipse([545, 330, 595, 390], fill=INK)
    ic.save("stand")


@icon
def flask():
    ic = Icon()
    ic.layer(lambda d: d.polygon([(420, 150), (604, 150), (604, 400), (830, 820), (194, 820), (420, 400)], fill=255), "#e6f6ff")
    ic.layer(lambda d: d.polygon([(330, 560), (694, 560), (800, 800), (224, 800)], fill=255), "#7be35a", outline=0)
    ic.layer(lambda d: rr(d, [380, 110, 644, 190], 30), "#b9a9d9", outline=20, gloss=False)
    d = ImageDraw.Draw(ic.img)
    for x, y, r in ((420, 660, 30), (560, 700, 22), (480, 610, 18)):
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, 200))
    ic.save("flask")


@icon
def music():
    ic = Icon()
    ic.layer(lambda d: d.polygon([(380, 200), (800, 120), (800, 230), (450, 300)], fill=255) or d.rectangle([380, 220, 450, 700], fill=255) or d.rectangle([730, 140, 800, 640], fill=255), "#ff9fd0", gloss=False)
    ic.layer(lambda d: d.ellipse([210, 600, 450, 800], fill=255), "#ff5fa2")
    ic.layer(lambda d: d.ellipse([560, 540, 800, 740], fill=255), "#ff5fa2")
    ic.save("music")


@icon
def speaker():
    ic = Icon()
    ic.layer(lambda d: d.polygon([(150, 390), (330, 390), (560, 190), (560, 834), (330, 634), (150, 634)], fill=255), "#3da5ff")
    d = ImageDraw.Draw(ic.img)
    for r in (150, 260):
        d.arc([560 - r + 60, 512 - r, 560 + r + 60, 512 + r], -50, 50, fill=INK, width=60)
    ic.save("speaker")


@icon
def map_pin():
    ic = Icon()
    ic.layer(lambda d: d.ellipse([250, 120, 774, 640], fill=255) or d.polygon([(290, 500), (734, 500), (512, 920)], fill=255), "#ff8a1f")
    ic.layer(lambda d: d.ellipse([400, 270, 624, 494], fill=255), "#fff3c4", outline=20, gloss=False)
    ic.save("map_pin")


@icon
def lantern():
    ic = Icon()
    ic.layer(lambda d: d.arc([400, 60, 624, 300], 180, 360, fill=255, width=40), "#b9a9d9", outline=18, gloss=False)
    ic.layer(lambda d: rr(d, [300, 180, 724, 290], 30), "#4a3a66")
    ic.layer(lambda d: rr(d, [330, 280, 694, 780], 60), "#ffc93c")
    ic.layer(lambda d: rr(d, [300, 760, 724, 870], 30), "#4a3a66")
    ic.layer(lambda d: d.ellipse([440, 420, 584, 640], fill=255), "#fff3c4", outline=0, gloss=False)
    ic.save("lantern")


@icon
def crown():
    ic = Icon()
    ic.layer(lambda d: d.polygon([(150, 760), (180, 300), (360, 520), (512, 220), (664, 520), (844, 300), (874, 760)], fill=255), "#ffc93c")
    ic.layer(lambda d: rr(d, [140, 720, 884, 860], 40), "#ffb02e")
    for x in (300, 512, 724):
        ic.layer(lambda d, x=x: d.ellipse([x - 55, 735, x + 55, 845], fill=255), "#ff5fa2", outline=18, gloss=False)
    for x, y in ((180, 300), (512, 220), (844, 300)):
        ic.layer(lambda d, x=x, y=y: d.ellipse([x - 55, y - 55, x + 55, y + 55], fill=255), "#fff3c4", outline=18, gloss=False)
    ic.save("crown")


@icon
def breach():
    ic = Icon()
    ic.layer(lambda d: d.ellipse([120, 700, 904, 900], fill=255), "#3e3460")
    def claws(d):
        for x0 in (190, 700):
            d.polygon([(x0, 760), (x0 + 130, 760), (x0 + 90 if x0 < 500 else x0 + 40, 300), (x0 + 30 if x0 < 500 else x0 + 100, 300)], fill=255)
    ic.layer(claws, "#6a5aa0")
    ic.layer(lambda d: d.ellipse([200, 170, 824, 620], fill=255) or None, "#ffc93c", gloss=False)
    ic.layer(lambda d: d.ellipse([270, 230, 754, 560], fill=255), "#7be35a")
    d = ImageDraw.Draw(ic.img)
    pts = []
    for i in range(160):
        a = i / 160 * 3.4 * math.pi
        r = 20 + i * 1.25
        pts.append((512 + r * math.cos(a), 395 + r * 0.7 * math.sin(a)))
    d.line(pts, fill=(235, 255, 220, 255), width=34, joint="curve")
    ic.save("breach")


@icon
def blaster():
    ic = Icon()
    ic.layer(lambda d: d.polygon([(330, 560), (470, 560), (430, 860), (280, 860)], fill=255), "#3b2a5a")
    ic.layer(lambda d: rr(d, [150, 380, 760, 600], 90), "#9b6bff")
    ic.layer(lambda d: d.rectangle([740, 430, 900, 550], fill=255), "#ffc93c")
    ic.layer(lambda d: d.ellipse([300, 160, 560, 420], fill=255), "#7be35a")
    ic.layer(lambda d: d.ellipse([850, 380, 990, 600], fill=255), "#9cf27a", outline=22, gloss=False)
    ic.save("blaster")


if __name__ == "__main__":
    for name, fn in ICONS.items():
        fn()
    # contact sheet for review
    names = sorted(ICONS)
    cols = 8
    rows = math.ceil(len(names) / cols)
    sheet = Image.new("RGBA", (cols * 140, rows * 160), (60, 38, 98, 255))
    d = ImageDraw.Draw(sheet)
    for i, n in enumerate(names):
        im = Image.open(os.path.join(OUT, n + ".png")).resize((120, 120), Image.LANCZOS)
        x, y = (i % cols) * 140 + 10, (i // cols) * 160 + 8
        sheet.paste(im, (x, y), im)
        d.text((x, y + 124), n, fill=(255, 255, 255, 255))
    sheet.save(os.path.join(ROOT, "Assets", "UI", "icon_sheet.png"))
    print(len(names), "icons ->", OUT)
