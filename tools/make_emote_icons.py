"""The emotes' icons in the addon logo's style (line_icon.py: cream
outlines, green accents; shapes drawn with radial_icon's helpers):
textures/ic_emote_<token>.tga, one per emote in RingContent.lua's IC.EMOTES.

Run: python3 tools/make_emote_icons.py   (needs Pillow)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from radial_icon import BLUE, GOLD, GREEN, GREY, LEATHER, RED, STEEL, Icon, preview  # noqa: E402
from line_icon import render  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "textures")
icon = Icon()
ALL = []


def save(token, layers):
    path = os.path.join(OUT, "ic_emote_" + token + ".tga")
    render(path, layers)
    ALL.append(path)


def new():
    m = icon.mask()
    return m, icon.draw(m)


def ellipse(d, cx, cy, rx, ry, turn=0, fill=255):
    t = math.radians(turn)
    pts = []
    for i in range(72):
        a = i / 72 * 2 * math.pi
        x, y = rx * math.cos(a), ry * math.sin(a)
        pts.append((cx + x * math.cos(t) - y * math.sin(t), cy + x * math.sin(t) + y * math.cos(t)))
    icon.polygon(d, pts, fill)


def heart(d, cx, cy, s, fill=255):
    pts = []
    for i in range(120):
        t = i / 120 * 2 * math.pi
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((cx + x * s, cy - y * s))
    icon.polygon(d, pts, fill)


def hand(d, cx, cy, s=1.0, turn=0):
    """An open hand, fingers up: a palm, four fingers, a thumb"""
    def p(x, y):
        t = math.radians(turn)
        return (cx + (x * math.cos(t) - y * math.sin(t)) * s, cy + (x * math.sin(t) + y * math.cos(t)) * s)
    ellipse(d, *p(0, 12), 24 * s, 26 * s, turn)
    for x, top in ((-17, -30), (-6, -38), (6, -40), (17, -32)):
        icon.stroke(d, [p(x, 4), p(x, top)], 10 * s)
    icon.stroke(d, [p(-20, 18), p(-36, 0)], 11 * s)


def face(d, cx=64, cy=64, r=50):
    icon.circle(d, cx, cy, r)


def eyes(d, cx=64, cy=64, dy=-12, gap=18, r=6, fill=0):
    icon.circle(d, cx - gap, cy + dy, r, fill)
    icon.circle(d, cx + gap, cy + dy, r, fill)


def person(d, x, y, s=1.0):
    """Head at x, y"""
    icon.circle(d, x, y, 11 * s)


def make():
    # Wave: a raised hand, motion arcs beside it
    m, d = new(); hand(d, 58, 70, 1.0, -12)
    w, dw = new()
    icon.arc(dw, 58, 60, 52, -60, -20, 7)
    icon.arc(dw, 58, 60, 52, 200, 240, 7)
    save("wave", [(m, GOLD), (w, GOLD)])

    # Hello: a speech bubble, a raised hand in it
    b, db = new()
    ellipse(db, 64, 56, 52, 40)
    icon.polygon(db, [(34, 80), (24, 114), (60, 90)])
    h, dh = new(); hand(dh, 64, 62, 0.62)
    save("hello", [(icon.cut(b, h), GOLD)])

    # Thank: a heart held in a cupped hand
    hh, dh = new(); heart(dh, 64, 50, 2.0)
    c, dc = new(); icon.arc(dc, 64, 66, 46, 20, 160, 13)
    save("thank", [(c, GOLD), (hh, RED)])

    # Cheer: three bursting stars
    m, d = new()
    icon.star(d, 64, 46, 34, 14, 5)
    icon.star(d, 28, 92, 20, 8, 5)
    icon.star(d, 100, 92, 20, 8, 5)
    save("cheer", [(m, GOLD)])

    # Dance: two beamed notes
    m, d = new()
    ellipse(d, 38, 96, 16, 12, -20)
    ellipse(d, 92, 86, 16, 12, -20)
    icon.stroke(d, [(52, 92), (52, 26)], 8)
    icon.stroke(d, [(106, 82), (106, 16)], 8)
    icon.polygon(d, [(48, 22), (110, 10), (110, 28), (48, 40)])
    save("dance", [(m, GOLD)])

    # Laugh: a face, eyes shut tight, mouth wide open
    f, df = new(); face(df)
    icon.arc(df, 46, 52, 9, 200, 340, 5)
    icon.arc(df, 82, 52, 9, 200, 340, 5)
    # (the shut eyes cut as dark arcs)
    cut, dc = new()
    icon.arc(dc, 46, 52, 9, 200, 340, 5)
    icon.arc(dc, 82, 52, 9, 200, 340, 5)
    icon.polygon(dc, [(36, 70)] + [(64 + 28 * math.cos(math.radians(a)), 70 + 28 * math.sin(math.radians(a)))
                                   for a in range(0, 181, 6)] + [(92, 70)])
    save("laugh", [(icon.cut(f, cut), GOLD)])

    # Bow: a figure bowing low, one arm across its chest
    m, d = new()
    icon.circle(d, 92, 58, 14)
    icon.stroke(d, [(76, 52), (40, 34)], 16)
    icon.stroke(d, [(40, 34), (38, 76), (34, 116)], 14)
    icon.stroke(d, [(40, 34), (46, 76), (54, 116)], 12)
    icon.stroke(d, [(62, 44), (72, 72)], 9)
    save("bow", [(m, GOLD)])

    # Roar: a jaw wide open, sound waves out
    j, dj = new()
    icon.polygon(dj, [(14, 40), (70, 30), (70, 52), (30, 58)])
    icon.polygon(dj, [(14, 92), (70, 100), (70, 78), (30, 72)])
    t, dt = new()
    for x in (26, 40, 54):
        icon.polygon(dt, [(x, 54), (x + 12, 54), (x + 6, 66)])
        icon.polygon(dt, [(x, 76), (x + 12, 76), (x + 6, 64)])
    wv, dw = new()
    for r in (30, 46):
        icon.arc(dw, 62, 65, r, -40, 40, 7)
    save("roar", [(j, RED), (t, GREY), (wv, GOLD)])

    # Bye: a hand, an arrow going away
    m, d = new(); hand(d, 46, 64, 0.8, -10)
    a, da = new()
    icon.stroke(da, [(76, 98), (110, 98)], 8)
    icon.polygon(da, [(104, 84), (122, 98), (104, 112)])
    save("bye", [(m, GOLD), (a, GOLD)])

    # Clap: two open hands tilted together, sparks above
    m, d = new()
    hand(d, 44, 74, 0.78, 24)
    hand(d, 84, 74, 0.78, -24)
    sp, ds = new()
    for x0, y0, x1, y1 in ((64, 30, 64, 12), (46, 34, 36, 18), (82, 34, 92, 18)):
        icon.stroke(ds, [(x0, y0), (x1, y1)], 6)
    save("clap", [(m, GOLD), (sp, GOLD)])

    # Cry: a sad face, a tear
    f, df = new(); face(df, 60, 64, 48)
    c, dc = new()
    eyes(dc, 60, 64, -10, 18, 6, 255)
    icon.arc(dc, 60, 100, 18, 215, 325, 6)
    tear, dt = new()
    icon.polygon(dt, [(96, 62), (86, 84), (106, 84)])
    icon.circle(dt, 96, 88, 10)
    save("cry", [(icon.cut(f, c), GOLD), (tear, BLUE)])

    # Flex: an arm bent up, fist at the top, the bicep bulging
    m, d = new()
    icon.stroke(d, [(12, 100), (70, 100)], 22)
    icon.stroke(d, [(70, 100), (86, 44)], 20)
    ellipse(d, 44, 84, 30, 20, -8)
    icon.circle(d, 88, 32, 18)
    save("flex", [(m, GOLD)])

    # Kiss: a red heart, a small one rising
    m, d = new(); heart(d, 58, 70, 2.3)
    s, ds = new(); heart(ds, 100, 28, 1.0)
    save("kiss", [(m, RED), (s, RED)])

    # Kneel: a figure on one knee
    m, d = new()
    icon.circle(d, 58, 24, 13)
    icon.stroke(d, [(58, 40), (58, 76)], 14)
    icon.stroke(d, [(58, 76), (92, 78), (92, 112)], 12)
    icon.stroke(d, [(58, 76), (40, 110), (22, 110)], 12)
    save("kneel", [(m, GOLD)])

    # Lol: a laughing face with tears of joy
    f, df = new(); face(df)
    c, dc = new()
    icon.arc(dc, 46, 52, 9, 200, 340, 5)
    icon.arc(dc, 82, 52, 9, 200, 340, 5)
    icon.polygon(dc, [(38, 72)] + [(64 + 26 * math.cos(math.radians(a)), 72 + 24 * math.sin(math.radians(a)))
                                   for a in range(0, 181, 6)] + [(90, 72)])
    tears, dt = new()
    for x, s in ((18, 1), (110, -1)):
        icon.polygon(dt, [(x, 50), (x - 8 * s, 70), (x + 8 * s, 70)])
        icon.circle(dt, x, 72, 8)
    save("lol", [(icon.cut(f, c), GOLD), (tears, BLUE)])

    # No: a red cross
    m, d = new()
    icon.stroke(d, [(30, 30), (98, 98)], 20)
    icon.stroke(d, [(98, 30), (30, 98)], 20)
    save("no", [(m, RED)])

    # Yes: a green tick
    m, d = new()
    icon.stroke(d, [(22, 68), (50, 96), (106, 32)], 20)
    save("yes", [(m, GREEN)])

    # Point: a fist, its finger pointing ahead
    m, d = new()
    icon.polygon(d, [(16, 50), (60, 46), (64, 104), (22, 106)])
    icon.circle(d, 22, 78, 14)
    icon.stroke(d, [(56, 56), (114, 56)], 15)
    k, dk = new()
    for y in (74, 88):
        icon.stroke(dk, [(34, y), (62, y)], 3)
    save("point", [(icon.cut(m, k), GOLD)])

    # Rude: a face sticking its tongue out
    f, df = new(); face(df)
    c, dc = new()
    eyes(dc, 64, 64, -14, 18, 7, 255)
    icon.stroke(dc, [(42, 76), (86, 76)], 7)
    t, dt = new()
    icon.polygon(dt, [(54, 76), (76, 76), (76, 96), (54, 96)])
    icon.circle(dt, 65, 96, 11)
    save("rude", [(icon.cut(f, c), GOLD), (t, RED)])

    # Salute: a sword raised, point up
    b, db = new()
    icon.polygon(db, [(64, 6), (74, 22), (74, 84), (54, 84), (54, 22)])
    h, dh = new()
    icon.stroke(dh, [(36, 88), (92, 88)], 10)
    icon.bar(dh, 64, 88, 118, 11)
    save("salute", [(b, STEEL), (h, GOLD)])

    # Sit: a stool
    m, d = new()
    ellipse(d, 64, 46, 46, 14)
    icon.stroke(d, [(30, 54), (24, 112)], 9)
    icon.stroke(d, [(98, 54), (104, 112)], 9)
    icon.stroke(d, [(64, 58), (64, 112)], 9)
    icon.stroke(d, [(28, 88), (100, 88)], 7)
    save("sit", [(m, LEATHER)])

    # Sleep: a crescent moon, Zs rising
    moon, dm = new()
    icon.circle(dm, 52, 72, 40)
    icon.circle(dm, 74, 58, 34, 0)
    z, dz = new()
    for x, y, s in ((84, 30, 18), (104, 10, 12)):
        icon.stroke(dz, [(x, y), (x + s, y), (x, y + s), (x + s, y + s)], 6)
    save("sleep", [(moon, GOLD), (z, BLUE)])

    # Shy: a face looking down, blushing
    f, df = new(); face(df)
    c, dc = new()
    icon.arc(dc, 46, 60, 8, 20, 160, 5)
    icon.arc(dc, 82, 60, 8, 20, 160, 5)
    icon.arc(dc, 64, 76, 12, 30, 150, 5)
    blush, db = new()
    ellipse(db, 36, 76, 10, 6)
    ellipse(db, 92, 76, 10, 6)
    save("shy", [(icon.cut(f, c), GOLD), (blush, RED)])

    # Train: a little engine
    body, dbody = new()
    icon.polygon(dbody, [(14, 50), (78, 50), (78, 90), (14, 90)])
    icon.polygon(dbody, [(78, 30), (114, 30), (114, 90), (78, 90)])
    icon.polygon(dbody, [(26, 22), (42, 22), (40, 50), (28, 50)])
    win, dw = new()
    icon.polygon(dw, [(86, 38), (106, 38), (106, 58), (86, 58)])
    wheels, dwh = new()
    for x in (32, 64, 96):
        icon.circle(dwh, x, 98, 14)
    save("train", [(icon.cut(body, win), RED), (wheels, STEEL)])

    # Chicken: a round body, its head, a red comb
    b, db = new()
    ellipse(db, 58, 80, 42, 32)
    icon.circle(db, 92, 42, 20)
    icon.polygon(db, [(18, 60), (30, 40), (36, 66)])
    beak, dk = new()
    icon.polygon(dk, [(108, 40), (124, 46), (108, 52)])
    comb, dc = new()
    icon.circle(dc, 86, 22, 7)
    icon.circle(dc, 98, 20, 7)
    eye, de = new()
    icon.circle(de, 96, 40, 4)
    save("chicken", [(icon.cut(b, eye), GREY), (comb, RED), (beak, GOLD)])

    # Thanks: a flower
    p, dp = new()
    for k in range(6):
        a = math.radians(k * 60)
        icon.circle(dp, 64 + 24 * math.cos(a), 48 + 24 * math.sin(a), 16)
    stem, ds = new()
    icon.stroke(ds, [(64, 70), (64, 118)], 8)
    ellipse(ds, 80, 98, 14, 7, -30)
    core, dc = new()
    icon.circle(dc, 64, 48, 14)
    save("thanks", [(stem, GREEN), (p, RED), (core, GOLD)])

    # Follow me: a banner on a pole
    pole, dp = new()
    icon.bar(dp, 30, 10, 118, 9)
    flag, df = new()
    icon.polygon(df, [(34, 16), (112, 26), (92, 46), (112, 66), (34, 64)])
    save("followme", [(pole, LEATHER), (flag, RED)])

    # Charge: a lunging arrow, speed lines behind
    a, da = new()
    icon.stroke(da, [(42, 64), (100, 64)], 14)
    icon.polygon(da, [(92, 40), (122, 64), (92, 88)])
    s, ds = new()
    for y, x0 in ((42, 18), (64, 8), (86, 18)):
        icon.stroke(ds, [(x0, y), (x0 + 22, y)], 6)
    save("charge", [(a, GOLD), (s, GREY)])

    # Attack target: a red crosshair
    m, d = new()
    icon.arc(d, 64, 64, 40, 0, 360, 10)
    for x0, y0, x1, y1 in ((64, 6, 64, 40), (64, 88, 64, 122), (6, 64, 40, 64), (88, 64, 122, 64)):
        icon.stroke(d, [(x0, y0), (x1, y1)], 9)
    dot, dd = new()
    icon.circle(dd, 64, 64, 9)
    save("attacktarget", [(m, RED), (dot, GOLD)])

    # Heal me: a green cross
    m, d = new()
    icon.polygon(d, [(48, 14), (80, 14), (80, 48), (114, 48), (114, 80), (80, 80), (80, 114), (48, 114),
                     (48, 80), (14, 80), (14, 48), (48, 48)])
    save("healme", [(m, GREEN)])

    # Out of mana: a mana drop, emptied, struck through
    drop, dd = new()
    icon.polygon(dd, [(64, 8), (34, 66), (94, 66)])
    icon.circle(dd, 64, 78, 34)
    inner, di = new()
    icon.polygon(di, [(64, 34), (46, 70), (82, 70)])
    icon.circle(di, 64, 80, 22)
    slash, ds = new()
    icon.stroke(ds, [(22, 110), (106, 26)], 10)
    save("oom", [(icon.cut(drop, inner), BLUE), (slash, RED)])

    # Flee: an arrow running off left, speed lines behind
    a, da = new()
    icon.stroke(da, [(28, 64), (86, 64)], 14)
    icon.polygon(da, [(36, 40), (6, 64), (36, 88)])
    s, ds = new()
    for y, x0 in ((42, 88), (64, 98), (86, 88)):
        icon.stroke(ds, [(x0, y), (x0 + 22, y)], 6)
    save("flee", [(a, GREY), (s, GREY)])


if __name__ == "__main__":
    make()
    if len(sys.argv) > 1:
        preview(ALL, sys.argv[1])
