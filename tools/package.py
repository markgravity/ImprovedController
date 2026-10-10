"""Build the release zips, one per addon (each its own CurseForge project):
    dist/ImprovedForever-<version>.zip           the core
    dist/ImprovedForever_<Module>-<version>.zip  each module
    dist/ImprovedForever-All-<version>.zip       every addon, for a manual install

Each addon folder holds what the game loads: its TOC and the files it lists,
its Bindings.xml, the licence; the core also the TGA textures (every module's
too), the EasyController licence, README and CHANGELOG. Tools, icon sources
and tpl.lua (a dev reference) are left out. The version is the core TOC's;
every module's must match it.

Usage:
    python tools/package.py
"""
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CORE = "ImprovedForever"
CORE_EXTRA = ["LICENSE-EasyController.md", "README.md", "CHANGELOG.md"]


def toc_of(folder):
    toc = (ROOT / folder / f"{folder}.toc").read_text(encoding="utf-8")
    version = re.search(r"^## Version:\s*(\S+)", toc, re.M).group(1)
    listed = [line.strip() for line in toc.splitlines() if line.strip() and not line.startswith("#")]
    return version, listed


def main():
    folders = sorted(p.parent.name for p in ROOT.glob(f"{CORE}*/{CORE}*.toc") if p.stem == p.parent.name)
    if CORE not in folders:
        sys.exit(f"No {CORE}/{CORE}.toc")
    version = toc_of(CORE)[0]

    entries = {}      # folder: [(source, path in the zip)]
    code = ""
    for folder in folders:
        ver, listed = toc_of(folder)
        if ver != version:
            sys.exit(f"{folder} is on version {ver}, the core on {version}")
        files = [f"{folder}.toc"] + listed
        if (ROOT / folder / "Bindings.xml").is_file():
            files.append("Bindings.xml")
        if folder == CORE:
            files += sorted(p.relative_to(ROOT / folder).as_posix() for p in (ROOT / folder / "textures").glob("*.tga"))
        missing = [f for f in files if not (ROOT / folder / f).is_file()]
        if missing:
            sys.exit(f"{folder}: missing files: " + ", ".join(missing))
        entries[folder] = [(ROOT / folder / f, f"{folder}/{f}") for f in files] + [(ROOT / "LICENSE", f"{folder}/LICENSE")]
        code += "".join((ROOT / folder / f).read_text(encoding="utf-8") for f in listed if f.endswith(".lua"))
    entries[CORE] += [(ROOT / f, f"{CORE}/{f}") for f in CORE_EXTRA]

    # Every texture the code names in full must be packaged (they're the core's)
    names = set(re.findall(r'"(ic_[a-z0-9_]+)"', code))
    packaged = {Path(path).stem for _, path in entries[CORE] if "/textures/" in path}
    absent = sorted(n for n in names if n not in packaged and not n.endswith("_"))
    if absent:
        sys.exit("Textures used but not packaged: " + ", ".join(absent))

    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    for old in dist.glob(f"{CORE}*.zip"):
        old.unlink()
    zips = dict(entries)
    zips[f"{CORE}-All"] = [e for files in entries.values() for e in files]
    for name, files in zips.items():
        out = dist / f"{name}-{version}.zip"
        with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
            for source, path in files:
                z.write(source, path)
        print(f"{out.relative_to(ROOT)}: {len(files)} files, {out.stat().st_size / 1024:.0f} KB")


if __name__ == "__main__":
    main()
