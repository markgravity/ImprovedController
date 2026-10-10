"""The modules' icons (each addon's TOC icon and its tab in the configuration
panel), in the addon logo's colours, solid (line_icon.py's render_solid: cream
shapes, green accents, holes cut; shapes drawn with radial_icon's helpers):
  ic_mod_controller   a gamepad, its face buttons in green
  ic_mod_wheel        a disc of eight slots, its picked one in green
  ic_mod_vibration    a gamepad's grip, green waves either side
  ic_mod_gather       a leaf and an ore nugget
  ic_mod_map          a folded map, a green pin on it
  ic_mod_auction      a stack of coins, a green tag
  ic_mod_destroy      a bin, a green cross over it
  ic_mod_library      an open book, a green bookmark

Run: python3 tools/make_module_icons.py   (needs Pillow)
"""
import math
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(__file__))
from radial_icon import GOLD, GREEN, Icon, preview  # noqa: E402
from line_icon import render_solid  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "ImprovedForever", "textures")
icon = Icon()
ALL = []


def save(name, layers):
    path = os.path.join(OUT, name + ".tga")
    render_solid(path, layers)
    ALL.append(path)


def new():
    m = icon.mask()
    return m, icon.draw(m)


def rounded(d, x0, y0, x1, y1, r):
    px = icon.px
    d.rounded_rectangle((px(x0), px(y0), px(x1), px(y1)), radius=px(r), fill=255)


def make():
    # Controller: a gamepad's body, a D-pad cross, the face buttons (green)
    m, d = new()
    icon.circle(d, 34, 70, 26)
    icon.circle(d, 94, 70, 26)
    rounded(d, 30, 44, 98, 92, 22)
    pad, dp = new()
    icon.stroke(dp, [(22, 68), (46, 68)], 7)
    icon.stroke(dp, [(34, 56), (34, 80)], 7)
    m = icon.cut(m, pad)
    face, df = new()
    for x, y in ((94, 57), (94, 81), (82, 69), (106, 69)):
        icon.circle(df, x, y, 5.5)
    save("ic_mod_controller", [(m, GOLD), (face, GREEN)])

    # Wheel: a disc, eight slots and its hub cut in it, the top slot picked
    # (green)
    disc, dd = new()
    icon.circle(dd, 64, 64, 52)
    holes, dh = new()
    icon.circle(dh, 64, 64, 11)
    picked, dk = new()
    for i in range(8):
        a = math.radians(-90 + i * 45)
        x, y = 64 + 34 * math.cos(a), 64 + 34 * math.sin(a)
        icon.circle(dk if i == 0 else dh, x, y, 9)
    disc = icon.cut(disc, holes)
    save("ic_mod_wheel", [(disc, GOLD), (picked, GREEN)])

    # Vibration: a grip in the middle, waves (green) either side
    m, d = new()
    rounded(d, 46, 26, 82, 104, 18)
    btn, db = new()
    icon.circle(db, 64, 50, 6)
    m = icon.cut(m, btn)
    waves, dw = new()
    for r in (34, 48):
        icon.arc(dw, 64, 64, r, 145, 215, 7)
        icon.arc(dw, 64, 64, r, -35, 35, 7)
    save("ic_mod_vibration", [(m, GOLD), (waves, GREEN)])

    # Gather: a leaf (green, its vein cut) and an ore nugget
    ore, do = new()
    icon.polygon(do, [(58, 74), (82, 62), (108, 72), (112, 98), (90, 112), (62, 104)])
    leaf, dl = new()
    pts = []
    for i in range(41):
        t = i / 40
        pts.append((18 + 64 * t, 84 - 64 * t - 22 * math.sin(math.pi * t)))
    for i in range(41):
        t = i / 40
        pts.append((82 - 64 * t, 20 + 64 * t + 22 * math.sin(math.pi * t)))
    icon.polygon(dl, pts)
    vein, dv = new()
    icon.stroke(dv, [(14, 88), (70, 32)], 4)
    leaf = icon.cut(leaf, vein)
    save("ic_mod_gather", [(ore, GOLD), (leaf, GREEN)])

    # Map: folded in three, a pin (green) on it
    m, d = new()
    icon.polygon(d, [(12, 34), (44, 22), (84, 34), (116, 22), (116, 96), (84, 108), (44, 96), (12, 108)])
    folds, fd = new()
    icon.stroke(fd, [(44, 22), (44, 96)], 4)
    icon.stroke(fd, [(84, 34), (84, 108)], 4)
    m = icon.cut(m, folds)
    pin, dp = new()
    pts = [(64, 92)]
    for a in range(-200, 21, 5):
        r = math.radians(a)
        pts.append((64 + 18 * math.cos(r), 50 + 18 * math.sin(r)))
    icon.polygon(dp, pts)
    hole, dh = new()
    icon.circle(dh, 64, 50, 6)
    pin = icon.cut(pin, hole)
    save("ic_mod_map", [(m, GOLD), (pin, GREEN)])

    # Auction: three coins stacked, a price tag (green) leaning on them
    # (each coin its own shape, the lower in front: the stack's gaps show)
    coins = []
    for y in (52, 70, 88):
        c, dc = new()
        rounded(dc, 14, y - 11, 74, y + 11, 11)
        coins.append((c, GOLD))
    tag, dt = new()
    icon.polygon(dt, [(74, 40), (100, 40), (116, 64), (100, 88), (74, 88)])
    eye, de = new()
    icon.circle(de, 96, 64, 5)
    tag = icon.cut(tag, eye)
    save("ic_mod_auction", coins + [(tag, GREEN)])

    # Destroy: a bin, a cross (green) over it
    m, d = new()
    icon.polygon(d, [(30, 40), (98, 40), (90, 112), (38, 112)])
    lid, dl = new()
    rounded(dl, 22, 26, 106, 36, 4)
    rounded(dl, 52, 16, 76, 28, 4)
    x, dx = new()
    icon.stroke(dx, [(44, 56), (84, 96)], 7)
    icon.stroke(dx, [(84, 56), (44, 96)], 7)
    save("ic_mod_destroy", [(m, GOLD), (lid, GOLD), (x, GREEN)])

    # Library: an open book, a bookmark (green) hanging from its spine
    book, db = new()
    icon.polygon(db, [(12, 34), (40, 26), (64, 36), (88, 26), (116, 34), (116, 100), (88, 92), (64, 102),
                      (40, 92), (12, 100)])
    spine, ds = new()
    icon.stroke(ds, [(64, 36), (64, 102)], 4)
    book = icon.cut(book, spine)
    mark, dm = new()
    icon.polygon(dm, [(84, 20), (100, 20), (100, 60), (92, 52), (84, 60)])
    save("ic_mod_library", [(book, GOLD), (mark, GREEN)])


if __name__ == "__main__":
    make()
    out = os.path.join(tempfile.gettempdir(), "module_icons_preview.png")
    preview(ALL, out)
    print("preview", out)
