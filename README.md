# Improved Controller

Quality-of-life tweaks for playing **WoW Forever** with a gamepad. Everything is set up and used
from the controller: no keyboard step needed.

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

Double-tap **Menu** to open the configuration.

## Install

- **CurseForge app**: search *Improved Controller*.
- **Manual**: download `ImprovedController-<version>.zip` from
  [Releases](https://github.com/markgravity/ImprovedController/releases) and unzip it into
  `World of Warcraft/_forever_/Interface/AddOns/` so you get `AddOns/ImprovedController/`.

## Development

Clone the repo straight into the `AddOns` folder (or symlink it) and `/reload` in game.

`vendor/QuestieDB` is a git submodule of [QuestieDB](https://github.com/Questie/QuestieDB), for its API
types and data (`git submodule update --init`). `python tools/make_library_data.py` copies what the
Library shows from it into `LibraryData.lua`, which ships; the submodule itself isn't packaged.

- `tools/make_*.py` regenerate the TGA textures.
- `python tools/make_library.py` regenerates `LibraryRecipes.lua` from the game's recipe tables (wago.tools).
- `python tools/package.py` builds `dist/ImprovedController-<version>.zip`.

### Releasing

1. Bump `## Version:` in `ImprovedController.toc`.
2. Add a `## <version>` section on top of `CHANGELOG.md`.
3. Commit, then `git tag v<version> && git push origin main v<version>`.

The [release workflow](.github/workflows/release.yml) checks the tag matches the TOC, builds the
zip, creates the GitHub release with the changelog section, and uploads to CurseForge when
`CF_API_KEY` is set. A tag with a suffix (`v0.3.0-beta1`) makes a pre-release / beta.

## Support

Improved Controller is free and always will be. If it makes your game better and you'd like to
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
