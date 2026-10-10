---
name: radial-icon
description: Draw new icons for the Improved Forever WoW addon in the style of WoW Forever's radial menu icons (painted gold shapes, dark outline, glossy top, soft shadow, transparent background) and wire them in as .tga textures. Use when the user asks for a new icon, an icon "like the native wheel/radial menu icons", or icons for a new feature, event, setting or pattern.
---

# Radial-menu style icons

The addon's custom icons (vibration patterns `textures/ic_vibe_*.tga`, vibration
events `textures/ic_event_*.tga`) are generated with Pillow, in the style of
Forever's own radial menu icons (Character, Bags, Talents...). Build new ones the
same way so they match.

## The pieces

- `tools/radial_icon.py`: the library. `Icon()` gives a 128 px icon drawn 4x
  supersampled. Shapes go on **masks** (white = shape); each mask is painted with a
  **palette** in `icon.save(path, [(mask, palette), ...])`, layers in order (first
  is at the back). Painting adds the look automatically: drop shadow, dark brown
  outline, vertical gradient fill, glossy top, darker bottom rim.
- `tools/make_vibe_icons.py`: worked examples (waves, spikes, a heart, bars, a
  star burst, a cracked shield). Copy its patterns.

### Helpers (coordinates in final 128 px pixels)

| Call | Draws |
|---|---|
| `icon.stroke(d, pts, width)` | thick polyline, round ends (waves, spikes, arrows' shafts) |
| `icon.arc(d, cx, cy, r, a0, a1, width)` | thick arc, degrees, 0 = right, 90 = down |
| `icon.circle(d, cx, cy, r)` | filled circle |
| `icon.polygon(d, pts)` | filled polygon (arrows, shields, hearts from a parametric curve) |
| `icon.bar(d, x, y0, y1, w)` | rounded vertical bar |
| `icon.star(d, cx, cy, r_out, r_in, points, turn=-90)` | star / jagged burst |
| `icon.cut(mask, other)` | mask minus other (cracks, holes) |
| `preview(paths, out)` | strip of icons on dark brown, to check by eye |

Palettes: `GOLD` (the default, like the native icons), `RED`, `GREY`, `STEEL`,
`GREEN`, `BLUE`, `LEATHER`. Add one as `(top, middle, bottom)` RGB if needed.

## Steps

1. **Design for 128 px, read at ~32 px**: one bold silhouette, strokes 7-11 px
   wide, keep it inside ~10..118 (the picker and slots crop ~7% and mask the icon
   to a circle). Use two layers at most: a main shape in `GOLD` and an accent
   (`RED` core, `STEEL` object...).
2. **Write the generator**: add a function to the relevant `tools/make_*_icons.py`
   (or a new `tools/make_<feature>_icons.py` that does
   `sys.path.insert(0, os.path.dirname(__file__)); from radial_icon import ...`).
   Name files `textures/ic_<feature>_<name>.tga`.
3. **Run it**: `python3 tools/make_<feature>_icons.py` (Pillow is installed).
4. **Look at it**: build a preview strip with `preview([...], "<scratchpad>/x.png")`
   and Read the PNG. Fix shapes that read badly (lopsided outlines, thin strokes,
   things touching the edge), regenerate, look again.
5. **Wire it in**: the texture path in Lua is
   `"Interface\\AddOns\\ImprovedForever\\textures\\ic_<feature>_<name>"`
   (no extension). Pictures go through `K.SetIcon(texture, path)` (ConfigKit) or
   `entry.icon` for pickers / rings.
6. **Check the Lua parses** (luaparse in the scratchpad) and tell the user to
   `/reload`; the game only reads new texture files after a reload (a brand new
   file sometimes needs a full client restart).

## Style notes

- The native icons are chunky and glossy, warm metal and leather: prefer `GOLD`,
  add `RED` for danger / emphasis, `STEEL` for armour and blades, `GREY` for "off".
- No text in icons; no thin details (they vanish at slot size).
- Keep a transparent background; the outline and shadow come from `render()`.

## The logo's line style (every icon now)

The addon's logo (`tools/addon_logo.png`, turned into `textures/ic_addon.tga`
by `tools/make_addon_icon.py`) is cream line art with green accents. The emote
icons follow it: `tools/line_icon.py`'s `render(path, layers)` takes the same
(mask, palette) layers as `icon.save` but draws each filled shape as a cream
outline (RED / GREEN / BLUE layers in green), gaps where a front shape crosses
one behind, and a soft dark shadow. `tools/make_emote_icons.py` and
`tools/make_vibe_icons.py` (patterns, events, spells) use it: every icon of
the addon is in this style now; draw
new shapes with the same helpers and pass them to `render`.
