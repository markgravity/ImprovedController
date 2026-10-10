"""The peek map's icons in the addon logo's style (line_icon.py: cream
outlines, green accents; shapes drawn with radial_icon's helpers):
  ic_map_peek       the feature: a folded map, an eye over it
  ic_map_opacity    a drop, its lower half filled with lines
  ic_map_size       a frame, a two-headed arrow across it
  ic_map_pos_<a>    a screen, the map's place on it (one per anchor:
                    center, top, bottom, left, right, topleft...)
  ic_map_offset     the map, arrows out of it four ways

Run: python3 tools/make_map_icons.py   (needs Pillow)
"""
import math
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(__file__))
from radial_icon import GOLD, GREEN, Icon, preview  # noqa: E402
from line_icon import render  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "ImprovedForever", "textures")
icon = Icon()
ALL = []


def save(name, layers):
    path = os.path.join(OUT, name + ".tga")
    render(path, layers)
    ALL.append(path)


def new():
    m = icon.mask()
    return m, icon.draw(m)


def eye(d, cx, cy, w, h):
    """An almond: two arcs meeting at its corners"""
    pts = []
    for i in range(41):
        t = i / 40
        x = cx - w / 2 + w * t
        pts.append((x, cy - h / 2 * math.sin(math.pi * t)))
    for i in range(41):
        t = i / 40
        x = cx + w / 2 - w * t
        pts.append((x, cy + h / 2 * math.sin(math.pi * t)))
    icon.polygon(d, pts)


def make():
    # Peek: a map folded in three, an eye in front of its lower right
    m, d = new()
    icon.polygon(d, [(14, 30), (44, 18), (84, 30), (114, 18), (114, 92), (84, 104), (44, 92), (14, 104)])
    folds, fd = new()
    icon.stroke(fd, [(44, 18), (44, 92)], 1.5)
    icon.stroke(fd, [(84, 30), (84, 104)], 1.5)
    m = icon.cut(m, folds)
    e, de = new()
    eye(de, 82, 92, 60, 34)
    pupil, dp = new()
    icon.circle(dp, 82, 92, 8)
    save("ic_map_peek", [(m, GOLD), (e, GREEN), (pupil, GREEN)])

    # Opacity: a drop, lines filling its lower half
    m, d = new()
    pts = [(64, 12)]
    for a in range(-35, 216, 5):
        r = math.radians(a)
        pts.append((64 + 38 * math.cos(r), 76 + 38 * math.sin(r)))
    icon.polygon(d, pts)
    lv, dl = new()
    for y, half in ((78, 22), (94, 18)):
        icon.stroke(dl, [(64 - half, y), (64 + half, y)], 6)
    save("ic_map_opacity", [(m, GOLD), (lv, GREEN)])

    # Size: a frame, an arrow corner to corner across it
    m, d = new()
    icon.polygon(d, [(14, 22), (114, 22), (114, 106), (14, 106)])
    ar, da = new()
    icon.stroke(da, [(38, 86), (90, 42)], 7)
    for (x, y), (ux, uy) in (((90, 42), (-1, 0)), ((90, 42), (0, 1)), ((38, 86), (1, 0)), ((38, 86), (0, -1))):
        icon.stroke(da, [(x, y), (x + ux * 18, y + uy * 18)], 7)
    save("ic_map_size", [(m, GOLD), (ar, GREEN)])

    # Position: a screen, the map's place on it
    L, T, R, B = 12, 24, 116, 104
    w, h = 36, 26
    inset = 12
    xs = {"left": L + inset + w / 2, "center": (L + R) / 2, "right": R - inset - w / 2}
    ys = {"top": T + inset + h / 2, "center": (T + B) / 2, "bottom": B - inset - h / 2}
    for v in ("top", "center", "bottom"):
        for hz in ("left", "center", "right"):
            name = "center" if v == hz == "center" else (hz if v == "center" else v if hz == "center" else v + hz)
            m, d = new()
            icon.polygon(d, [(L, T), (R, T), (R, B), (L, B)])
            p, dp = new()
            cx, cy = xs[hz], ys[v]
            icon.polygon(dp, [(cx - w / 2, cy - h / 2), (cx + w / 2, cy - h / 2), (cx + w / 2, cy + h / 2),
                              (cx - w / 2, cy + h / 2)])
            save("ic_map_pos_" + name, [(m, GOLD), (p, GREEN)])

    # Offset: the map, arrows out of it four ways
    m, d = new()
    icon.polygon(d, [(42, 46), (86, 46), (86, 82), (42, 82)])
    ar, da = new()
    for (x0, y0), (x1, y1) in (((64, 40), (64, 10)), ((64, 88), (64, 118)),
                               ((36, 64), (10, 64)), ((92, 64), (118, 64))):
        icon.stroke(da, [(x0, y0), (x1, y1)], 7)
        ux, uy = (x1 - x0) / abs(x1 - x0 + y1 - y0), (y1 - y0) / abs(x1 - x0 + y1 - y0)
        for side in (1, -1):
            icon.stroke(da, [(x1, y1), (x1 - ux * 12 + uy * side * 12, y1 - uy * 12 + ux * side * 12)], 7)
    save("ic_map_offset", [(m, GOLD), (ar, GREEN)])

if __name__ == "__main__":
    make()
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(tempfile.gettempdir(), "map_icons_preview.png")
    preview(ALL, out)
    print("preview:", out)
