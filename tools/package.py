"""Build the release zip: dist/ImprovedController-<version>.zip

The zip holds a single ImprovedController/ folder with what the game loads:
the TOC and its files, Bindings.xml, the TGA textures, the licences, README
and CHANGELOG. Tools, icon sources and tpl.lua (a dev reference) are left out.

Usage:
    python tools/package.py
"""
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ADDON = "ImprovedController"
EXTRA = ["Bindings.xml", "LICENSE", "LICENSE-EasyController.md", "README.md", "CHANGELOG.md"]


def main():
    toc = (ROOT / f"{ADDON}.toc").read_text(encoding="utf-8")
    version = re.search(r"^## Version:\s*(\S+)", toc, re.M).group(1)
    listed = [line.strip() for line in toc.splitlines()
              if line.strip() and not line.startswith("#")]

    files = [f"{ADDON}.toc"] + listed + EXTRA
    files += sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / "textures").glob("*.tga"))

    missing = [f for f in files if not (ROOT / f).is_file()]
    if missing:
        sys.exit("Missing files: " + ", ".join(missing))

    # Every texture the code names in full must be packaged
    code = "".join((ROOT / f).read_text(encoding="utf-8") for f in listed if f.endswith(".lua"))
    names = set(re.findall(r'"(ic_[a-z0-9_]+)"', code))
    packaged = {Path(f).stem for f in files if f.startswith("textures/")}
    absent = sorted(n for n in names if n not in packaged and not n.endswith("_"))
    if absent:
        sys.exit("Textures used but not packaged: " + ", ".join(absent))

    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    out = dist / f"{ADDON}-{version}.zip"
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for f in files:
            z.write(ROOT / f, f"{ADDON}/{f}")
    size = out.stat().st_size / 1024
    print(f"{out.relative_to(ROOT)}: {len(files)} files, {size:.0f} KB")


if __name__ == "__main__":
    main()
