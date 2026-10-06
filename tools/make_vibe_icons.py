"""The Vibration tab's icons in the radial menu's style (radial_icon.py):
textures/ic_vibe_<pattern>.tga for the patterns and Off, and
textures/ic_event_<event>.tga for the events.

Run: python3 tools/make_vibe_icons.py   (needs Pillow)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from radial_icon import BLUE, GOLD, GREY, RED, STEEL, Icon, preview  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "textures")
icon = Icon()


def path(name):
    return os.path.join(OUT, name + ".tga")


def waves(d, cx, cy, n, r0, step, width, span=50):
    """Vibration arcs either side of a point"""
    for i in range(n):
        r = r0 + i * step
        icon.arc(d, cx, cy, r, -span, span, width)
        icon.arc(d, cx, cy, r, 180 - span, 180 + span, width)


def patterns():
    m = icon.mask(); d = icon.draw(m)
    icon.circle(d, 64, 64, 10)
    waves(d, 64, 64, 1, 26, 0, 6, 40)
    icon.save(path("ic_vibe_micro"), [(m, GOLD)])

    m = icon.mask(); d = icon.draw(m)
    icon.stroke(d, [(14, 76), (44, 76), (58, 28), (72, 100), (84, 76), (114, 76)], 10)
    icon.save(path("ic_vibe_tick"), [(m, GOLD)])

    m = icon.mask(); d = icon.draw(m)
    icon.stroke(d, [(10, 78), (28, 78), (38, 34), (50, 96), (60, 78), (68, 78), (78, 34), (90, 96), (100, 78),
                    (118, 78)], 9)
    icon.save(path("ic_vibe_double"), [(m, GOLD)])

    m = icon.mask(); d = icon.draw(m)
    icon.circle(d, 64, 64, 12)
    waves(d, 64, 64, 3, 24, 16, 7, 55)
    icon.save(path("ic_vibe_pulse"), [(m, GOLD)])

    m = icon.mask(); d = icon.draw(m)
    icon.stroke(d, [(x, 64 + 18 * math.sin((x - 12) / 104 * 6 * math.pi)) for x in range(12, 117, 2)], 10)
    icon.save(path("ic_vibe_long"), [(m, GOLD)])

    heart = icon.mask(); d = icon.draw(heart)
    pts = []
    for i in range(200):
        t = i / 200 * 2 * math.pi
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((64 + x * 3.1, 60 - y * 3.1))
    icon.polygon(d, pts)
    line = icon.mask(); d = icon.draw(line)
    icon.stroke(d, [(8, 66), (36, 66), (46, 44), (58, 90), (70, 34), (80, 66), (120, 66)], 7)
    icon.save(path("ic_vibe_heart"), [(heart, RED), (line, GOLD)])

    m = icon.mask(); d = icon.draw(m)
    icon.bar(d, 36, 74, 104, 18)
    icon.bar(d, 64, 52, 104, 18)
    icon.bar(d, 92, 26, 104, 18)
    icon.save(path("ic_vibe_rise"), [(m, GOLD)])

    # Impact: a heavy fist-like burst, short and hard: a wide star, waves
    burst = icon.mask(); d = icon.draw(burst)
    icon.star(d, 64, 64, 44, 22, 8, turn=-90)
    hit = icon.mask(); d = icon.draw(hit)
    waves(d, 64, 64, 1, 52, 0, 8, 35)
    icon.save(path("ic_vibe_impact"), [(burst, RED), (hit, GOLD)])

    m = icon.mask(); d = icon.draw(m)
    icon.stroke(d, [(8, 78), (20, 78), (28, 38), (38, 94), (46, 78), (52, 78), (60, 38), (70, 94), (78, 78),
                    (84, 78), (92, 38), (102, 94), (110, 78), (120, 78)], 8)
    icon.save(path("ic_vibe_triple"), [(m, GOLD)])

    # Purr: small soft bumps in a row, over and over
    m = icon.mask(); d = icon.draw(m)
    for x in (28, 64, 100):
        icon.arc(d, x, 72, 14, 180, 360, 8)
    loop = icon.mask(); d = icon.draw(loop)
    icon.arc(d, 64, 72, 46, 20, 160, 7)
    icon.polygon(d, [(22, 84), (40, 92), (24, 104)])
    icon.save(path("ic_vibe_purr"), [(m, GOLD), (loop, GREY)])

    # Fade out: bars stepping down
    m = icon.mask(); d = icon.draw(m)
    icon.bar(d, 36, 26, 104, 18)
    icon.bar(d, 64, 52, 104, 18)
    icon.bar(d, 92, 74, 104, 18)
    icon.save(path("ic_vibe_fade"), [(m, GOLD)])

    rings = icon.mask(); d = icon.draw(rings)
    icon.circle(d, 64, 64, 10)
    waves(d, 64, 64, 2, 26, 16, 7, 50)
    slash = icon.mask(); d = icon.draw(slash)
    icon.stroke(d, [(28, 100), (100, 28)], 11)
    icon.save(path("ic_vibe_off"), [(rings, GREY), (slash, RED)])


def events():
    # Level up: a gold up-arrow, a star above it
    arrow = icon.mask(); d = icon.draw(arrow)
    icon.polygon(d, [(64, 34), (100, 72), (78, 72), (78, 110), (50, 110), (50, 72), (28, 72)])
    star = icon.mask(); d = icon.draw(star)
    icon.star(d, 64, 22, 16, 7, 5)
    icon.save(path("ic_event_levelup"), [(arrow, GOLD), (star, GOLD)])

    # You crit: a jagged gold burst, a red core
    burst = icon.mask(); d = icon.draw(burst)
    icon.star(d, 64, 64, 56, 30, 10, turn=-72)
    core = icon.mask(); d = icon.draw(core)
    icon.star(d, 64, 64, 26, 14, 6, turn=-90)
    icon.save(path("ic_event_crit"), [(burst, GOLD), (core, RED)])

    # You get crit: a red burst behind a cracked steel shield
    burst = icon.mask(); d = icon.draw(burst)
    icon.star(d, 90, 36, 36, 16, 8)
    shield = icon.mask(); d = icon.draw(shield)
    # A heater shield: a flat top, sides curving in to a point
    right = [(100 - 36 * t * t, 28 + 84 * t) for t in (i / 20 for i in range(21))]
    left = [(128 - x, y) for x, y in reversed(right)]
    icon.polygon(d, [(28, 22), (100, 22)] + right + left)
    crack = icon.mask(); d = icon.draw(crack)
    icon.stroke(d, [(66, 24), (58, 46), (72, 60), (56, 82), (66, 98)], 4)
    icon.save(path("ic_event_critted"), [(burst, RED), (icon.cut(shield, crack), STEEL)])

    # Spell cast: a glowing orb in a cupped hand of waves (a cast's loop)
    orb = icon.mask(); d = icon.draw(orb)
    icon.circle(d, 64, 56, 24)
    sparks = icon.mask(); d = icon.draw(sparks)
    icon.star(d, 30, 26, 12, 4, 4)
    icon.star(d, 100, 30, 9, 3, 4)
    hand = icon.mask(); d = icon.draw(hand)
    icon.arc(d, 64, 56, 44, 20, 160, 10)
    icon.save(path("ic_event_cast"), [(hand, GOLD), (orb, BLUE), (sparks, GOLD)])


if __name__ == "__main__":
    patterns()
    events()
