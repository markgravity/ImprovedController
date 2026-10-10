"""Build LibraryData.lua: the Library's drops, vendors and quests, taken from
QuestieDB's Forever data (the vendor/QuestieDB submodule:
git submodule update --init).

Only what the Library shows is kept: for each item its sources (creatures,
objects and containers that drop it, vendors, quests); for each creature,
object and quest those name, its name, level, zone and a few spawn points.
Rows are strings, decoded in game only when an item's page opens (Library.lua),
so the data costs little memory until then. An installed QuestieDB is read
instead when there is one (newer data).

Row formats (fields split by "|", lists by ","):
    items[id]   = "npcDrops|objectDrops|itemDrops|vendors|questRewards|startQuest|relatedQuests"
    npcs[id]    = "name|minLevel|maxLevel|rank|zoneID|subName|friendlyToFaction|spawns"
    objects[id] = "name|zoneID|spawns"
    quests[id]  = "name|questLevel|zoneOrSort"
    spawns      = "zone:x,y,x,y;zone:x,y"   (at most SPAWNS_PER_ZONE points a zone)
    displays[npcID] = displayID              (the creature's look, for its portrait)
    trainerSets[n]  = "npcID,npcID,..."      (trainers, a list shared by recipes)
    trainers[spellID] = n                    (the trainers who teach a recipe)
    professionTrainers[skillLine] = n        (a profession's trainers: its first
                                              recipes come with the profession)
    trainerSkill[spellID] = rank             (the skill a trainer asks to teach it)
    trainerLevel[spellID] = level            (the level a trainer asks, when it does)
    starters[spellID] = 1                    (recipes learnt with the profession:
                                              SkillLineAbility's AcquireMethod 1)

The creatures' display ids and the trainers come from cMaNGOS's Classic
database (github.com/cmangos/classic-db, GPL-3.0): creature_template's
ModelId1-4, kept only when the client's own CreatureDisplayInfo table has
them, and npc_trainer / npc_trainer_template (through TrainerTemplateId). A
trainer teaches a spell that teaches the recipe (the client's SpellEffect,
LEARN_SPELL); the recipes are LibraryRecipes.lua's. Client tables from
wago.tools, the latest Classic Era build.

Usage:
    python tools/make_library_data.py
"""
import csv
import gzip
import io
import json
import re
import subprocess
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QDB = ROOT / "vendor" / "QuestieDB"
OUT = ROOT / "ImprovedForever_Library" / "LibraryData.lua"
SPAWNS_PER_ZONE = 40
CMANGOS_DUMP = "https://raw.githubusercontent.com/cmangos/classic-db/master/Full_DB/ClassicDB_1_12_1_z2815.sql.gz"
WAGO = "https://wago.tools"

# item / npc / object / quest field positions (QuestieDB's *Keys, 1-based)
ITEM = {"npcDrops": 2, "objectDrops": 3, "itemDrops": 4, "startQuest": 5, "questRewards": 6,
        "vendors": 14, "relatedQuests": 15}
NPC = {"name": 1, "minLevel": 4, "maxLevel": 5, "rank": 6, "spawns": 7, "zoneID": 9,
       "friendlyToFaction": 13, "subName": 14}
OBJECT = {"name": 1, "spawns": 4, "zoneID": 5}
QUEST = {"name": 1, "questLevel": 5, "zoneOrSort": 17}


# ---------------------------------------------------------------------------
# A reader for the Lua table literals QuestieDB's data is written in
# ---------------------------------------------------------------------------
TOKEN = re.compile(r"""
    (?P<space>\s+|--[^\n]*)
  | (?P<num>-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)
  | (?P<str>'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*")
  | (?P<word>[A-Za-z_][A-Za-z_0-9]*)
  | (?P<sym>[{}\[\]=,;])
""", re.X)
ESCAPES = {"n": "\n", "t": "\t", "\\": "\\", "'": "'", '"': '"'}


def tokens(text):
    pos = 0
    while pos < len(text):
        m = TOKEN.match(text, pos)
        if not m:
            raise ValueError(f"unexpected {text[pos:pos + 30]!r}")
        pos = m.end()
        kind = m.lastgroup
        if kind == "space":
            continue
        value = m.group(kind)
        if kind == "num":
            value = float(value) if any(c in value for c in ".eE") else int(value)
        elif kind == "str":
            value = re.sub(r"\\(.)", lambda e: ESCAPES.get(e.group(1), e.group(1)), value[1:-1])
        yield kind, value


class Reader:
    def __init__(self, text):
        self.toks = list(tokens(text))
        self.i = 0

    def peek(self):
        return self.toks[self.i] if self.i < len(self.toks) else (None, None)

    def take(self, value=None):
        tok = self.toks[self.i]
        if value is not None and tok[1] != value:
            raise ValueError(f"expected {value!r}, got {tok!r}")
        self.i += 1
        return tok

    def value(self):
        kind, value = self.take()
        if kind == "sym" and value == "{":
            return self.table()
        if kind == "word":
            return {"nil": None, "true": True, "false": False}[value]
        return value

    # positional values keep their index (a nil holds its place)
    def table(self):
        out, n = {}, 0
        while self.peek()[1] != "}":
            kind, value = self.peek()
            if kind == "sym" and value == "[":
                self.take()
                key = self.value()
                self.take("]")
                self.take("=")
                out[key] = self.value()
            elif kind == "word" and self.toks[self.i + 1][1] == "=" and value not in ("nil", "true", "false"):
                self.take()
                self.take("=")
                out[value] = self.value()
            else:
                n += 1
                v = self.value()
                if v is not None:
                    out[n] = v
            if self.peek()[1] in (",", ";"):
                self.take()
        self.take("}")
        return out


def data_string(path, name):
    text = path.read_text(encoding="utf-8")
    m = re.search(re.escape(name) + r"\s*=\s*\[(=*)\[\s*return\s*(.*?)\]\1\]", text, re.S)
    if not m:
        raise ValueError(f"{name} not found in {path.name}")
    reader = Reader(m.group(2))
    reader.take("{")
    return reader.table()


def as_list(v):
    if v is None:
        return []
    if isinstance(v, dict):
        return [v[k] for k in sorted(k for k in v if isinstance(k, int))]
    return [v]


# ---------------------------------------------------------------------------
# Rows
# ---------------------------------------------------------------------------
def text(v):
    s = "" if v is None else str(v)
    if "|" in s or "\n" in s:
        s = s.replace("|", "/").replace("\n", " ")
    return s


def num(v):
    if v is None:
        return ""
    if isinstance(v, float):
        return f"{v:.1f}".rstrip("0").rstrip(".")
    return str(v)


def ids(v):
    return ",".join(str(i) for i in as_list(v))


def spawns(v):
    parts = []
    for zone in sorted(k for k in (v or {}) if isinstance(k, int)):
        points = []
        for p in as_list(v[zone])[:SPAWNS_PER_ZONE]:
            xy = as_list(p)
            if len(xy) >= 2:
                points += [num(xy[0]), num(xy[1])]
        if points:
            parts.append(f"{zone}:" + ",".join(points))
    return ";".join(parts)


def lua_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


# ---------------------------------------------------------------------------
# Creatures' looks: cMaNGOS's creature_template (Entry, ..., ModelId1-4 are
# its 1st and 6th-9th columns), checked against the client's display table
# ---------------------------------------------------------------------------
def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "ImprovedForever-tools"})
    with urllib.request.urlopen(req, timeout=300) as r:
        return r.read()


def sql_rows(statement):
    """The value tuples of one INSERT statement, as lists of raw strings."""
    rows, row, field, quoted, i = [], None, [], False, statement.index("VALUES") + 6
    while i < len(statement):
        c = statement[i]
        if quoted:
            if c == "\\":
                field.append(statement[i + 1])
                i += 1
            elif c == "'":
                quoted = False
            else:
                field.append(c)
        elif c == "'":
            quoted = True
        elif c == "(":
            row, field = [], []
        elif c in ",)" and row is not None:
            row.append("".join(field).strip())
            field = []
            if c == ")":
                rows.append(row)
                row = None
        elif row is not None:
            field.append(c)
        i += 1
    return rows


def wago_table(name):
    build = json.loads(fetch(f"{WAGO}/api/builds"))["wow_classic_era"][0]["version"]
    return list(csv.DictReader(io.StringIO(fetch(f"{WAGO}/db2/{name}/csv?build={build}").decode("utf-8"))))


def cmangos():
    """creature_template (entry -> row, its column names) and the trainers'
    rows, from the dump read once."""
    text = gzip.decompress(fetch(CMANGOS_DUMP)).decode("utf-8", errors="replace")
    create = re.search(r"CREATE TABLE `creature_template` \((.*?)\n\)", text, re.S).group(1)
    columns = re.findall(r"^\s+`(\w+)`", create, re.M)
    tables = {"creature_template": [], "npc_trainer": [], "npc_trainer_template": []}
    for line in text.splitlines():
        m = re.match(r"INSERT INTO `(\w+)`", line)
        if m and m.group(1) in tables:
            tables[m.group(1)] += sql_rows(line)
    creatures = {int(r[0]): r for r in tables["creature_template"]}
    return creatures, columns, tables["npc_trainer"], tables["npc_trainer_template"]


def displays(npc_ids, creatures):
    known = {int(r["ID"]) for r in wago_table("CreatureDisplayInfo")}
    found = {}
    for entry in npc_ids:
        row = creatures.get(entry)
        for model in (row[5:9] if row else ()):
            model = int(float(model or 0))
            if model > 0 and model in known:
                found[entry] = model
                break
    return found


def trainers(creatures, columns, own, shared):
    """recipe spell -> trainer npc ids, profession skill line -> trainer npc ids,
    recipe spell -> the skill rank trainers ask for it (the lowest), recipe spell ->
    the level they ask (the lowest)"""
    recipes = {}
    for spell, skill in re.findall(r"^\[(\d+)\]=\{(\d+),", (ROOT / "ImprovedForever_Library" / "LibraryRecipes.lua").read_text(), re.M):
        recipes[int(spell)] = int(skill)
    teaches = {}
    for row in wago_table("SpellEffect"):
        if row["Effect"] == "36" and int(row["EffectTriggerSpell"]) > 0:
            teaches.setdefault(int(row["SpellID"]), []).append(int(row["EffectTriggerSpell"]))
    templates = {}
    for row in shared:
        templates.setdefault(int(row[0]), []).append((int(row[1]), int(row[4] or 0), int(row[5] or 0)))
    template_col = columns.index("TrainerTemplateId")
    taught = {}
    for row in own:
        taught.setdefault(int(row[0]), []).append((int(row[1]), int(row[4] or 0), int(row[5] or 0)))
    for entry, row in creatures.items():
        template = int(row[template_col] or 0)
        if template in templates:
            taught.setdefault(entry, []).extend(templates[template])
    by_recipe, by_skill, rank, level = {}, {}, {}, {}
    for npc, spells in taught.items():
        for spell, needs, minimum in spells:
            for recipe in [spell] + teaches.get(spell, []):
                if recipe in recipes:
                    by_recipe.setdefault(recipe, set()).add(npc)
                    by_skill.setdefault(recipes[recipe], set()).add(npc)
                    rank[recipe] = min(rank.get(recipe, needs), needs)
                    level[recipe] = min(level.get(recipe, minimum), minimum)
    return by_recipe, by_skill, rank, level


def emit(name, rows):
    body = "\n".join(f"[{k}]={lua_string(rows[k])}," for k in sorted(rows))
    return f"{name} = {{\n{body}\n}},\n"


def main():
    forever = QDB / "data" / "Forever"
    if not forever.is_dir():
        raise SystemExit("vendor/QuestieDB missing: git submodule update --init")
    items = data_string(forever / "foreverItemDB.lua", "QuestieDB.itemData")
    npcs = data_string(forever / "foreverNpcDB.lua", "QuestieDB.npcData")
    objects = data_string(forever / "foreverObjectDB.lua", "QuestieDB.objectData")
    quests = data_string(forever / "foreverQuestDB.lua", "QuestieDB.questData")

    item_rows, want_npc, want_obj, want_quest = {}, set(), set(), set()
    for iid, row in items.items():
        f = {k: row.get(i) for k, i in ITEM.items()}
        if not any(f.values()):
            continue
        item_rows[iid] = "|".join([ids(f["npcDrops"]), ids(f["objectDrops"]), ids(f["itemDrops"]),
                                   ids(f["vendors"]), ids(f["questRewards"]), num(f["startQuest"]),
                                   ids(f["relatedQuests"])])
        want_npc.update(as_list(f["npcDrops"]) + as_list(f["vendors"]))
        want_obj.update(as_list(f["objectDrops"]))
        want_quest.update(as_list(f["questRewards"]) + as_list(f["relatedQuests"]))
        if f["startQuest"]:
            want_quest.add(f["startQuest"])

    creatures, columns, own, shared = cmangos()
    by_recipe, by_skill, ranks, levels = trainers(creatures, columns, own, shared)
    starter_spells = {int(r["Spell"]) for r in wago_table("SkillLineAbility") if r["AcquireMethod"] == "1"}
    for npcs_ in list(by_recipe.values()) + list(by_skill.values()):
        want_npc.update(npcs_)

    npc_rows = {}
    for nid in want_npc:
        row = npcs.get(nid)
        if row:
            npc_rows[nid] = "|".join([text(row.get(NPC["name"])), num(row.get(NPC["minLevel"])),
                                      num(row.get(NPC["maxLevel"])), num(row.get(NPC["rank"])),
                                      num(row.get(NPC["zoneID"])), text(row.get(NPC["subName"])),
                                      text(row.get(NPC["friendlyToFaction"])), spawns(row.get(NPC["spawns"]))])
    obj_rows = {}
    for oid in want_obj:
        row = objects.get(oid)
        if row:
            obj_rows[oid] = "|".join([text(row.get(OBJECT["name"])), num(row.get(OBJECT["zoneID"])),
                                      spawns(row.get(OBJECT["spawns"]))])
    quest_rows = {}
    for qid in want_quest:
        row = quests.get(qid)
        if row:
            quest_rows[qid] = "|".join([text(row.get(QUEST["name"])), num(row.get(QUEST["questLevel"])),
                                        num(row.get(QUEST["zoneOrSort"]))])

    # Zones: area id -> UiMap id (the base table, Forever's overrides on top)
    zones_file = QDB / "support" / "Forever" / "Zones" / "areaIdToUiMapId.lua"
    area_to_ui = {}
    for name in ("ZoneDB.private.areaIdToUiMapId", "ZoneDB.private.areaIdToUiMapIdOverride"):
        area_to_ui.update({k: v for k, v in data_string(zones_file, name).items() if isinstance(v, int)})

    version = re.search(r"^## Version:\s*(\S+)", (QDB / "QuestieDB.toc").read_text(encoding="utf-8"), re.M)
    commit = subprocess.run(["git", "-C", str(QDB), "rev-parse", "--short", "HEAD"],
                            capture_output=True, text=True).stdout.strip()
    source = f"QuestieDB {version.group(1) if version else '?'} ({commit or '?'})"

    zones = ",".join(f"[{k}]={area_to_ui[k]}" for k in sorted(area_to_ui))
    looks = displays(set(npc_rows), creatures)
    # (trainers only those the NPC data has; a list kept once, shared)
    sets, set_index = [], {}
    def shared_set(npcs_):
        key = ",".join(str(n) for n in sorted(n for n in npcs_ if n in npc_rows))
        if not key:
            return None
        if key not in set_index:
            sets.append(key)
            set_index[key] = len(sets)
        return set_index[key]
    recipe_trainers = {r: shared_set(n) for r, n in by_recipe.items()}
    skill_trainers = {k: shared_set(n) for k, n in by_skill.items()}
    def table(rows):
        return ",".join(f"[{k}]={v}" for k, v in sorted(rows.items()) if v)
    looks_lua = ",".join(f"[{k}]={looks[k]}" for k in sorted(looks))
    OUT.write_text(
        "-- GENERATED by tools/make_library_data.py from QuestieDB's Forever data\n"
        "-- (github.com/Questie/QuestieDB, by the Questie team); creatures' display ids\n"
        "-- from cMaNGOS's Classic database (github.com/cmangos/classic-db, GPL-3.0).\n"
        "-- Do not edit by hand.\n"
        "local IF = ImprovedForever\n"
        f"IF.LibraryData = {{ source = {lua_string(source)},\n"
        + emit("items", item_rows) + emit("npcs", npc_rows) + emit("objects", obj_rows)
        + emit("quests", quest_rows) + f"areaToUi = {{ {zones} }},\n"
        + f"displays = {{ {looks_lua} }},\n"
        + "trainerSets = {\n" + "\n".join(f"{lua_string(x)}," for x in sets) + "\n},\n"
        + f"trainers = {{ {table(recipe_trainers)} }},\n"
        + f"professionTrainers = {{ {table(skill_trainers)} }},\n"
        + f"trainerSkill = {{ {table(ranks)} }},\n"
        + f"trainerLevel = {{ {table(levels)} }},\n"
        + "starters = { " + ",".join(f"[{k}]=1" for k in sorted(starter_spells)) + " },\n}\n",
        encoding="utf-8",
    )
    size = OUT.stat().st_size / 1e6
    print(f"{source}: {len(item_rows)} items, {len(npc_rows)} npcs, {len(obj_rows)} objects, "
          f"{len(quest_rows)} quests, {len(area_to_ui)} zones, {len(looks)} looks, {sum(1 for v in recipe_trainers.values() if v)} recipes with trainers ({len(sets)} trainer lists) -> {OUT.name} ({size:.1f} MB)")


if __name__ == "__main__":
    main()
