# Improved Forever

Quality-of-life tweaks for playing **WoW Forever** with a gamepad. Everything is set up and used
from the controller: no keyboard step needed.

Each feature is its own addon (enable only the ones you want in the AddOns list); all of them need
the core, **Improved Forever**:

| Addon | What it does |
|---|---|
| `ImprovedForever` | The core: button glyphs, bindings, the configuration panel. Required. |
| `ImprovedForever_Controller` | Bag clean-up, touchpad corners, the Controller tab: every press on one drawing of the controller. |
| `ImprovedForever_Wheel` | Wheels on R3 combos, the recent action slot. |
| `ImprovedForever_Vibration` | Vibration on game events and spell casts. |
| `ImprovedForever_Gather` | Names beside the minimap's gathering dots, alerts. |
| `ImprovedForever_Map` | The peek map. |
| `ImprovedForever_Auction` | The controller auction window, prices over time, tasks. |
| `ImprovedForever_Destroy` | Destroy junk from the bags or the loot window. |
| `ImprovedForever_Library` | Everything about an item. |

## Features

- **Wheels** on R3 combos, laid out like the game's radial menu: spells, items, emotes,
  consumables (paged by category), several wheels per combo. Aim with the right stick.
- **Recent action slot** on R3, placed in Edit Mode.
- **Touchpad** corner actions.
- **Button overrides** for L3 click and double-click.
- **Vibration** on game events and spell casts, with per-action patterns.
- **Destroy** to destroy junk from the controller (with no junk, white items too: gear, food and trade goods, unusable, low level and cheapest first); from the loot window when the bags are full, it destroys junk and loots in its place.
- **Library**: hold R3 on an item (bags, loot window, auction house) for everything about it: what drops
  it, who sells it, the recipes that make or use it, its quests and auction prices. Drops, vendors and
  quests come from [QuestieDB](https://github.com/Questie/QuestieDB)'s data: the addon when installed, else
  a copy that ships with this one.

Double-tap **Menu** (or `/if`) to open the configuration: a tab per loaded module down the right
(L1 / R1, or the right stick), the module's sections down the left (the left stick, or L2 / R2), its
settings in the middle (left / right change one, Cross picks from its list on the right).

## Install

- **CurseForge app**: search *Improved Forever*.
- **Manual**: download `ImprovedForever-<version>.zip` from
  [Releases](https://github.com/markgravity/ImprovedForever/releases) and unzip it into
  `World of Warcraft/_forever_/Interface/AddOns/` so you get `AddOns/ImprovedForever/`,
  `AddOns/ImprovedForever_Wheel/`... (remove an old `AddOns/ImprovedController/`).

## Development

One repo, one folder per addon (`ImprovedForever/` the core, `ImprovedForever_<Module>/` each module).
Link them into the game with `tools/link.sh "<game>/Interface/AddOns"` and `/reload` in game.

A module reaches the core through the global `ImprovedForever` (`local IF = ImprovedForever`), says it
is there with `IF.AddModule`, adds its presses with `IF.Binds.Add`, its commands with `IF.AddCommand`
and its settings tab with `IF.SettingsPage` (form fields) or `IF.Menu.AddTab` (a page of its own).
Another module's table (`IF.Auction`, `IF.Vibe`...) is used only after checking it is loaded.

`luajit tools/loadcheck.lua each` loads the core with each module alone, then all of them, against a
stand-in for the game's API, and drives the configuration panel: it catches a module reaching for
one that isn't loaded.

`vendor/QuestieDB` is a git submodule of [QuestieDB](https://github.com/Questie/QuestieDB), for its API
types and data (`git submodule update --init`). `python tools/make_library_data.py` copies what the
Library shows from it into `ImprovedForever_Library/LibraryData.lua`, which ships; the submodule itself isn't packaged.

- `tools/make_*.py` regenerate the TGA textures.
- `python tools/make_library.py` regenerates `ImprovedForever_Library/LibraryRecipes.lua` from the game's recipe tables (wago.tools).
- `python tools/package.py` builds `dist/ImprovedForever-<version>.zip` (every addon folder).

### Releasing

1. Bump `## Version:` in every addon's TOC (`ImprovedForever*/ImprovedForever*.toc`).
2. Add a `## <version>` section on top of `CHANGELOG.md`.
3. Commit, then `git tag v<version> && git push origin main v<version>`.

The [release workflow](.github/workflows/release.yml) checks the tag matches the TOC, builds the
zip, creates the GitHub release with the changelog section, and uploads to CurseForge when
`CF_API_KEY` is set. A tag with a suffix (`v0.3.0-beta1`) makes a pre-release / beta.

## Support

Improved Forever is free and always will be. If it makes your game better and you'd like to
say thanks, you can buy me a coffee:

- [Ko-fi](https://ko-fi.com/markgravity)
- [PayPal](https://paypal.me/markgravity)

## Credits

The Library's drop, vendor and quest data comes from [QuestieDB](https://github.com/Questie/QuestieDB)
by the Questie team; creatures' display ids (their portraits) from
[cMaNGOS classic-db](https://github.com/cmangos/classic-db) (GPL-3.0).

Parts of the code are adapted from
[Easy Controller - Forever](https://github.com/moust4ki/EasyControllerWowForever) by moust4ki
(MIT): see [LICENSE-EasyController.md](LICENSE-EasyController.md).

## License

[MIT](LICENSE)
