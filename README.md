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
- **Bag cleaner** to destroy junk from the controller.

Double-tap **Menu** to open the configuration.

## Install

- **CurseForge app**: search *Improved Controller*.
- **Manual**: download `ImprovedController-<version>.zip` from
  [Releases](https://github.com/markgravity/ImprovedController/releases) and unzip it into
  `World of Warcraft/_forever_/Interface/AddOns/` so you get `AddOns/ImprovedController/`.

## Development

Clone the repo straight into the `AddOns` folder (or symlink it) and `/reload` in game.

- `tools/make_*.py` regenerate the TGA textures.
- `python tools/package.py` builds `dist/ImprovedController-<version>.zip`.

### Releasing

1. Bump `## Version:` in `ImprovedController.toc`.
2. Add a `## <version>` section on top of `CHANGELOG.md`.
3. Commit, then `git tag v<version> && git push origin main v<version>`.

The [release workflow](.github/workflows/release.yml) checks the tag matches the TOC, builds the
zip, creates the GitHub release with the changelog section, and uploads to CurseForge when
`CF_API_KEY` is set. A tag with a suffix (`v0.3.0-beta1`) makes a pre-release / beta.

## Credits

Parts of the code are adapted from
[Easy Controller - Forever](https://github.com/moust4ki/EasyControllerWowForever) by moust4ki
(MIT): see [LICENSE-EasyController.md](LICENSE-EasyController.md).

## License

[MIT](LICENSE)
