-- The Library's page (Library.lua knows what is shown): a page of a book,
-- in Forever's spellbook window (its frame, its page). The item is the page's title (its
-- icon in the spellbook's frame), under the rule its notes: what a traveller
-- wrote about it, then an entry a subject (where it is found, its people,
-- what it's crafted from, what it's a reagent for, its quests): Cross opens
-- that list. A list: the creatures, objects and people by zone (Cross: a
-- waypoint at the nearest spawn; a container: its page), the recipes by
-- profession (Cross: the other item's page), the quests; Circle goes back to
-- the notes, then to the item before.
-- Entries in two columns as the spellbook's spells (an item in a square
-- frame, a creature, a place, a quest or a subject in a round one), as many
-- pages as they need: the D-pad reads on from page to page, L2 / R2 turn
-- them.
-- Never in combat.
local IF = ImprovedForever

local K = IF.ConfigKit
local A = IF.Auction
local BY = IF.AuctionBuy
local LB = IF.Library

---------------------------------------------------------------------------
-- The book's looks
---------------------------------------------------------------------------
local PARCHMENT = "spellbook-Page-Right-C60"
local WINDOW_W = 680                     -- (the spellbook window, made smaller)
local TITLE_H, INSET_X, INSET_Y = 15, 2, 3   -- (where the window's page sits: PlayerSpellsFrame)
local ART_W = WINDOW_W - 2 * INSET_X - 1
local ART_H = math.floor(ART_W * 682 / 810 + 0.5)      -- (the page atlas's proportions)
local BAND = math.floor(ART_H * 0.085 + 0.5)           -- (its dark strip on top: the tabs', left empty)
local PAGE_W, PAGE_H = ART_W, ART_H - BAND             -- the parchment, where everything is written
local LEFT, RIGHT = 66, 58               -- the writing's margins (room left for the cursor)
local TOP = 112                          -- the notes' top, under the rule
local AREA_W = PAGE_W - LEFT - RIGHT
local AREA_H = PAGE_H - TOP - 62
local GAP = 20
local CELL_W, CELL_H = (AREA_W - GAP) / 2, 58
local HEAD_H = 34
local CELLS = 2 * math.floor(AREA_H / CELL_H)
local HEADS = math.floor(AREA_H / HEAD_H)
local HEADING_FONT = "Fonts\\MORPHEUS.TTF"

-- The lists: what they're about (the page's top right), their entry's icon
local ICON = "Interface\\Icons\\"
local LISTS = {
    creatures = "Creatures", gathering = "Gathering", containers = "Containers", people = "People",
    trainers = "Trainers",
    profession = "Profession", quests = "Quests",
}
-- (their entry in the notes)
local ENTRY_NAMES = LISTS
-- A profession's own icon (Craft, Reagent: the profession of their first recipe)
-- A gathering's own icon, its gatherers, how they gather
local GATHERING = {
    herb = { icon = ICON .. "Trade_Herbalism", people = "Herbalists", verb = "pick it from", short = "Picked from",
        nodes = "plants" },
    ore = { icon = ICON .. "Trade_Mining", people = "Miners", verb = "take it from", short = "Mined from",
        nodes = "veins" },
    fish = { icon = ICON .. "Trade_Fishing", people = "Fishermen", verb = "draw it from", short = "Fished from",
        nodes = "pools" },
}
local PROFESSION_ICONS = {
    [164] = ICON .. "Trade_BlackSmithing", [165] = ICON .. "Trade_LeatherWorking", [171] = ICON .. "Trade_Alchemy",
    [185] = ICON .. "INV_Misc_Food_15", [186] = ICON .. "Trade_Mining", [197] = ICON .. "Trade_Tailoring",
    [202] = ICON .. "Trade_Engineering", [333] = ICON .. "Trade_Engraving", [129] = ICON .. "Spell_Holy_SealOfSacrifice",
}
local LIST_ICONS = {
    creatures = ICON .. "INV_Misc_Bone_HumanSkull_01", chests = ICON .. "INV_Box_02",
    people = ICON .. "INV_Misc_GroupLooking", quests = ICON .. "INV_Misc_Note_01",
}

-- The spellbook's ink (SPELLBOOK_FONT_COLOR), and darker accents of it
local INK = { 0.23, 0.16, 0.09 }
if _G.SPELLBOOK_FONT_COLOR and SPELLBOOK_FONT_COLOR.GetRGB then INK = { SPELLBOOK_FONT_COLOR:GetRGB() } end
local ACCENT_RGB = { 0.43, 0.16, 0.05 }
local ACCENT = "|cff6e2a0c"
-- An item's quality, in an ink that reads on parchment
local QUALITY_INK = { [0] = "|cff5c5c5c", [1] = "|cff3b2a1a", [2] = "|cff1a6b12", [3] = "|cff0b4c96",
    [4] = "|cff6a1b9a", [5] = "|cffa64b00", [6] = "|cff8a6d2b" }
local QUALITY_NAMES = { [0] = "Poor", [1] = "Common", [2] = "Uncommon", [3] = "Rare", [4] = "Epic",
    [5] = "Legendary", [6] = "Artifact" }

local function Atlas(tex, name)
    if IF.HasAtlas(name) then
        tex:SetAtlas(name)
        return true
    end
end

-- A font of the game's (the spellbook's), in its ink, no shadow
local function Ink(fs, font, fallback, color)
    local object = _G[font] or _G[fallback]
    if object then fs:SetFontObject(object) end
    local c = color or INK
    fs:SetTextColor(c[1], c[2], c[3])
    fs:SetShadowOffset(0, 0)
    return fs
end

local function Text(parent, font, fallback, layer)
    return Ink(parent:CreateFontString(nil, layer or "ARTWORK"), font, fallback)
end

-- The page's subject (top right): the game's book font (Morpheus), in the
-- accent
local function Heading(parent, size)
    local fs = Text(parent, "QuestTitleFont", "GameFontNormalLarge")
    pcall(fs.SetFont, fs, HEADING_FONT, size, "")
    fs:SetTextColor(ACCENT_RGB[1], ACCENT_RGB[2], ACCENT_RGB[3])
    return fs
end

-- The notes' writing: the spellbook's own (Friz), easy to read
local function Body(parent)
    local fs = Text(parent, "SystemFont_Med3", "GameFontNormal")
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetSpacing(4)
    fs:SetWidth(AREA_W)
    return fs
end

local function Sound(kit)
    local id = SOUNDKIT and SOUNDKIT[kit]
    if id and PlaySound then pcall(PlaySound, id) end
end

local function Glyph(key, size) return IF.GlyphText(key, size) end

---------------------------------------------------------------------------
-- The window: the spellbook's (PortraitFrameTemplate: its gold frame, a
-- book in its portrait, "Library" on its title bar), its page inside; the
-- page's strip on top, where the spellbook has its tabs, left empty
---------------------------------------------------------------------------
local ok, window = pcall(K.NewFrame, "Frame", "ImprovedForeverLibrary", UIParent, "PortraitFrameTemplate")
if not ok then window = K.NewFrame("Frame", "ImprovedForeverLibrary", UIParent) end
window:SetSize(WINDOW_W, ART_H + INSET_Y + TITLE_H)
-- (over the auction window, a DIALOG)
window:SetFrameStrata("FULLSCREEN_DIALOG")
window:SetPoint("CENTER")
window:EnableMouse(true)
window:SetClampedToScreen(true)
window:Hide()
pcall(function()
    if window.SetTitle then window:SetTitle("Library") end
    if window.SetPortraitToAsset then window:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Book_09") end
end)

local art = window:CreateTexture(nil, "BACKGROUND", nil, 2)
art:SetPoint("BOTTOMLEFT", INSET_X, INSET_Y)
art:SetSize(ART_W, ART_H)
if not Atlas(art, PARCHMENT) then art:SetColorTexture(0.85, 0.75, 0.58, 1) end

-- The parchment under the strip: everything on the page is placed on it
local page = K.NewFrame("Frame", nil, window)
page:SetPoint("BOTTOMLEFT", INSET_X, INSET_Y)
page:SetSize(PAGE_W, PAGE_H)
-- (whose tooltips are the Library's: Library.lua's focus leaves them out)
LB.panel = page

-- A spellbook icon: the spell's frame round a masked icon (square: an item;
-- round: a creature, a place, a quest), its hover glow for the focus. f =
-- IconFrame(parent, size); f:Set(icon, round); f:SetFocus(on)
local function IconFrame(parent, size)
    local f = K.NewFrame("Frame", nil, parent)
    f:SetSize(size, size)
    local k = size / 40
    f.shadow = f:CreateTexture(nil, "ARTWORK", nil, 1)
    Atlas(f.shadow, "spellbook-item-iconframe-shadow")
    f.shadow:SetPoint("TOPLEFT", -12 * k, 3 * k)
    f.shadow:SetPoint("BOTTOMRIGHT", 2 * k, -8 * k)
    f.icon = f:CreateTexture(nil, "ARTWORK", nil, -1)
    f.icon:SetSize(36 * k, 36 * k)
    f.icon:SetPoint("CENTER")
    local function Mask(atlas)
        if not (f.CreateMaskTexture and IF.HasAtlas(atlas)) then return nil end
        local m = f:CreateMaskTexture()
        m:SetAtlas(atlas)
        m:SetAllPoints(f.icon)
        return m
    end
    f.masks = { square = Mask("spellbook-item-spellicon-mask"), round = Mask("talents-node-circle-mask") }
    f.border = f:CreateTexture(nil, "OVERLAY", nil, 1)
    f.glow = f:CreateTexture(nil, "OVERLAY", nil, 2)
    f.glow:SetAllPoints()
    f.glow:SetBlendMode("ADD")
    f.glow:Hide()
    function f:Set(icon, round)
        self.icon:SetTexture(icon or LB.ICONS.none)
        local mask = self.masks[round and "round" or "square"]
        if self.mask ~= mask then
            if self.mask then self.icon:RemoveMaskTexture(self.mask) end
            if mask then self.icon:AddMaskTexture(mask) end
            self.mask = mask
        end
        self.icon:SetTexCoord(mask and 0 or 0.07, mask and 1 or 0.93, mask and 0 or 0.07, mask and 1 or 0.93)
        self.border:ClearAllPoints()
        if round then
            if not Atlas(self.border, "spellbook-passive-iconframe") then Atlas(self.border, "talents-node-circle-gray") end
            self.border:SetPoint("TOPLEFT", -3 * k, 3 * k)
            self.border:SetPoint("BOTTOMRIGHT", 3 * k, -3 * k)
            Atlas(self.glow, "spellbook-item-iconframe-passive-hover")
        else
            Atlas(self.border, "spellbook-item-iconframe")
            self.border:SetPoint("TOPLEFT", -11 * k, 1 * k)
            self.border:SetPoint("BOTTOMRIGHT", 1 * k, -7 * k)
            Atlas(self.glow, "spellbook-item-iconframe-hover")
        end
        self.shadow:SetShown(not round)
    end
    function f:SetFocus(on)
        self.glow:SetShown(on and true or false)
        self.glow:SetAlpha(0.5)
    end
    return f
end

-- The game's gamepad cursor (its large arrow, bobbing) left of the focus
local function Pointer(parent)
    local holder = K.NewFrame("Frame", nil, parent)
    holder:SetSize(10, 10)
    holder:SetFrameLevel(parent:GetFrameLevel() + 6)
    local arrow = holder:CreateTexture(nil, "ARTWORK", nil, 2)
    arrow:SetSize(42 * 0.7, 70 * 0.7)
    arrow:SetPoint("RIGHT", holder, "RIGHT", 0, 0)
    if not Atlas(arrow, "gamepad-largecursor-white") then
        arrow:SetSize(22, 22)
        arrow:SetTexture("Interface\\AddOns\\ImprovedForever\\textures\\ic_tri")
        arrow:SetRotation(math.pi / 2)
    end
    local cursor = GAMEPAD_SMARTNAV_CURSOR_COLOR
    if cursor and cursor.GetRGBA then arrow:SetVertexColor(cursor:GetRGBA()) else arrow:SetVertexColor(1, 0.82, 0.2) end
    local bob = arrow:CreateAnimationGroup()
    bob:SetLooping("REPEAT")
    local out = bob:CreateAnimation("Translation")
    out:SetOffset(4, 0)
    out:SetDuration(0.8)
    out:SetSmoothing("IN_OUT")
    out:SetOrder(1)
    local back = bob:CreateAnimation("Translation")
    back:SetOffset(-4, 0)
    back:SetDuration(0.8)
    back:SetSmoothing("IN_OUT")
    back:SetOrder(2)
    bob:Play()
    holder:Hide()
    return holder
end

-- The title: the item's icon, its name, what it is, the rule under them
local head = IconFrame(page, 46)
head:SetPoint("TOPLEFT", LEFT + 2, -34)
local title = Text(page, "SystemFont_Huge2", "GameFontNormalHuge")
title:SetPoint("TOPLEFT", head, "TOPRIGHT", 16, 2)
title:SetPoint("RIGHT", page, "RIGHT", -RIGHT - 150, 0)
title:SetJustifyH("LEFT")
title:SetWordWrap(false)
local kind = Text(page, "SystemFont_Med1", "GameFontNormal")
kind:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
kind:SetPoint("RIGHT", page, "RIGHT", -RIGHT, 0)
kind:SetJustifyH("LEFT")
kind:SetWordWrap(false)
local owned = Text(page, "SystemFont_Med1", "GameFontNormal")
owned:SetPoint("TOPLEFT", kind, "BOTTOMLEFT", 0, -3)
owned:SetPoint("RIGHT", page, "RIGHT", -RIGHT, 0)
owned:SetJustifyH("LEFT")
owned:SetAlpha(0.75)
-- What is read: "Field Notes", or the list's subject, at the top right
local chapter = Heading(page, 17)
chapter:SetPoint("TOPRIGHT", -RIGHT, -38)
chapter:SetJustifyH("RIGHT")
local rule = page:CreateTexture(nil, "ARTWORK")
rule:SetHeight(11)
rule:SetPoint("TOPLEFT", LEFT - 30, -TOP + 22)
rule:SetPoint("TOPRIGHT", -RIGHT + 6, -TOP + 22)
if not Atlas(rule, "spellbook-divider") then rule:SetColorTexture(INK[1], INK[2], INK[3], 0.5) rule:SetHeight(1) end

-- "Page 1/3", at the bottom right, as the spellbook's
local pageNo = Text(page, "SystemFont_Med3", "GameFontNormalLarge")
pageNo:SetPoint("BOTTOMRIGHT", -RIGHT - 6, 30)

local emptyText = Text(page, "SystemFont_Med3", "GameFontNormalLarge")
emptyText:SetPoint("TOP", page, "TOP", 0, -TOP - 60)
emptyText:SetAlpha(0.7)

-- A list's entry: its icon in its frame, its name, a line under it; the
-- spellbook's faint backplate behind it, full under the focus
local cells = {}
for i = 1, CELLS do
    local c = K.NewFrame("Button", nil, page)
    c:SetSize(CELL_W, CELL_H - 6)
    c.backplate = c:CreateTexture(nil, "BACKGROUND", nil, 1)
    c.backplate:SetSize(CELL_W + 36, 64)
    c.backplate:SetPoint("CENTER", 5, -5)
    if not Atlas(c.backplate, "spellbook-item-backplate") then c.backplate:Hide() end
    c.icon = IconFrame(c, 40)
    c.icon:SetPoint("LEFT", 0, 0)
    c.name = Text(c, "SystemFont_Large", "GameFontNormalLarge")
    c.name:SetPoint("RIGHT", c, "RIGHT", -4, 0)
    c.name:SetJustifyH("LEFT")
    c.name:SetWordWrap(false)
    c.sub = Text(c, "SystemFont_Med1", "GameFontNormal")
    c.sub:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -2)
    c.sub:SetPoint("RIGHT", c, "RIGHT", -4, 0)
    c.sub:SetJustifyH("LEFT")
    c.sub:SetWordWrap(true)
    if c.sub.SetMaxLines then c.sub:SetMaxLines(2) end
    c.pointer = Pointer(c)
    c.pointer:SetPoint("RIGHT", c.icon, "LEFT", 2, 0)
    c:SetScript("OnClick", function(self)
        if self.index then LB.Pick(self.index, true) end
    end)
    cells[i] = c
end

-- A list's section header (a zone, a profession): its name, how many, a
-- faint rule
local heads = {}
for i = 1, HEADS do
    local h = K.NewFrame("Frame", nil, page)
    h:SetSize(AREA_W, HEAD_H)
    h.text = Text(h, "SystemFont_Med3", "GameFontNormalLarge")
    h.text:SetPoint("BOTTOMLEFT", 0, 10)
    h.text:SetPoint("RIGHT", -60, 0)
    h.text:SetJustifyH("LEFT")
    h.text:SetWordWrap(false)
    h.info = Text(h, "SystemFont_Med1", "GameFontNormal")
    h.info:SetPoint("BOTTOMRIGHT", 0, 11)
    h.info:SetAlpha(0.7)
    h.rule = h:CreateTexture(nil, "ARTWORK")
    h.rule:SetHeight(6)
    h.rule:SetPoint("BOTTOMLEFT", -10, 2)
    h.rule:SetPoint("BOTTOMRIGHT", 6, 2)
    if not Atlas(h.rule, "spellbook-divider") then h.rule:SetColorTexture(INK[1], INK[2], INK[3], 0.4) h.rule:SetHeight(1) end
    h.rule:SetAlpha(0.55)
    heads[i] = h
end

-- The notes' paragraphs, made as they're needed
local function Pool(make)
    local pool = { used = 0 }
    function pool:Next()
        self.used = self.used + 1
        local f = self[self.used]
        if not f then
            f = make()
            self[self.used] = f
        end
        return f
    end
    function pool:Reset() self.used = 0 end
    function pool:HideRest()
        for i = self.used + 1, #self do self[i]:Hide() end
    end
    return pool
end

local paragraphs = Pool(function() return Body(page) end)
-- (a paragraph's height before it's placed)
local measure = Body(page)
measure:Hide()

local legend = IF.InputLegend(window)
legend:SetPoint("TOP", window, "BOTTOM", 0, -4)

---------------------------------------------------------------------------
-- The notes: written from what is known (a traveller's words, a section a
-- subject, each with a link to its list)
---------------------------------------------------------------------------
local function Count(lines)
    local n = 0
    for _, l in ipairs(lines or {}) do
        if not l.header then n = n + 1 end
    end
    return n
end

local function Plural(n, one, many)
    return n .. " " .. (n == 1 and one or many)
end

local function Capital(text)
    return text:sub(1, 1):upper() .. text:sub(2)
end

-- "a, b and c"
local function Names(list)
    if #list <= 1 then return list[1] or "" end
    return table.concat(list, ", ", 1, #list - 1) .. " and " .. list[#list]
end

local function Name(s) return ACCENT .. s .. "|r" end

-- "a Battered Chest", "an Alliance Chest" (A_: the name in the accent)
local function A_plain(name)
    return (name:match("^[AEIOUaeiou]") and "an " or "a ") .. name
end

local function A_(name)
    return (name:match("^[AEIOUaeiou]") and "an " or "a ") .. Name(name)
end

local function ItemName(id)
    local name = LB.ItemInfo(id)
    return name and Name(name) or "another item"
end

-- 6420 -> "64 silver 20 copper" (words read better in a sentence than coins)
local function Coins(copper)
    copper = math.floor(copper or 0)
    local parts = {}
    local gold, silver, rest = math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100
    if gold > 0 then parts[#parts + 1] = gold .. " gold" end
    if silver > 0 then parts[#parts + 1] = silver .. " silver" end
    if rest > 0 or #parts == 0 then parts[#parts + 1] = rest .. " copper" end
    return table.concat(parts, " ")
end

local PEOPLE = {
    [164] = "Blacksmiths", [165] = "Leatherworkers", [171] = "Alchemists", [185] = "Cooks", [186] = "Miners",
    [197] = "Tailors", [202] = "Engineers", [333] = "Enchanters", [129] = "Those trained in first aid",
}

-- Who works these recipes: "Tailors and blacksmiths"
local function People(list)
    local seen, names = {}, {}
    for _, l in ipairs(list or {}) do
        local who = PEOPLE[l.skill]
        if who and not seen[who] then
            seen[who] = true
            names[#names + 1] = #names == 0 and who or who:lower()
        end
    end
    local text = Names(names)
    return text ~= "" and text or "Craftsmen"
end

-- A recipe's reagents in words: "2 Linen Cloth and 1 Coarse Thread"
local function ReagentWords(row)
    local parts = {}
    for i = 5, #(row or {}), 2 do parts[#parts + 1] = row[i + 1] .. " " .. ItemName(row[i]) end
    return Names(parts)
end

-- What each section of a list holds: { [header] = { lines } }
local function Sections(lines)
    local out, section = {}, ""
    for _, l in ipairs(lines or {}) do
        if l.header then
            section = l.header
        else
            out[section] = out[section] or {}
            table.insert(out[section], l)
        end
    end
    return out
end

-- Recipes under their profession's header (the index keeps them in
-- profession order): prefix ("Made with "), lines (added to)
local function ByProfession(list, prefix, lines)
    local header
    lines = lines or {}
    for _, l in ipairs(list or {}) do
        if not header or header.skill ~= l.skill then
            header = { header = (prefix or "") .. LB.SkillName(l.skill), info = 0, skill = l.skill }
            lines[#lines + 1] = header
        end
        header.info = header.info + 1
        lines[#lines + 1] = l
    end
    return lines
end

local function Signature()
    if UnitFactionGroup("player") == "Horde" then return "— from the journal of a Horde field scout" end
    return "— from the field notes of the Explorers' League"
end

-- A list's entries (its headers left out), and how many there are in all
local function Entries(lines)
    local out = {}
    for _, l in ipairs(lines or {}) do
        if not l.header then out[#out + 1] = l end
    end
    return out
end

local function Total(lines)
    return math.max(Count(lines), lines and lines.total or 0)
end

-- A list by zone read back: its zones' names (three at most), the entry in
-- the player's zone and that zone
local function Places(lines)
    local zones, here, hereZone, section = {}, nil, nil, nil
    for _, l in ipairs(lines or {}) do
        if l.header then
            section = l.header
            local zone = section:gsub("  %(here%)", "")
            if section ~= "Elsewhere" and section ~= "Around the world" and #zones < 3 then
                zones[#zones + 1] = Name(zone)
            end
            if section:find("%(here%)") then hereZone = zone end
        elseif not here and hereZone and section and section:find("%(here%)") then
            here = l
        end
    end
    return zones, here, hereZone
end

-- The names in a list, each once (a node is in several zones)
local function Unique(lines)
    local seen, names = {}, {}
    for _, l in ipairs(Entries(lines)) do
        if not seen[l.plain] then
            seen[l.plain] = true
            names[#names + 1] = l.plain
        end
    end
    return names
end

-- "a, b, c and 4 more" (names put in the accent)
local function Shorten(names, keep)
    local out = {}
    for i = 1, math.min(#names, keep) do
        out[i] = names[i]:find("|c") and names[i] or Name(names[i])
    end
    if #names > keep then out[#out + 1] = (#names - keep) .. " more" end
    return out
end

-- What is written about it, a traveller's words (not a list), by subject:
-- { creatures, chests, gathering, items, here, people, profession, quests,
-- trainers, worth } (each a list of sentences; here: hereFrom, the subject
-- the place to look is in)
local function Said(p)
    local t = p.tabs
    local said = { creatures = {}, chests = {}, gathering = {}, items = {}, here = {}, people = {},
        profession = {}, quests = {}, trainers = {}, worth = {}, contents = {} }

    -- Where it is found: creatures, chests and the like, herbs, veins and
    -- pools, containers
    local drops = p.drops or {}
    local creatures, chests = Total(drops.creatures), Total(drops.chests)
    local zones, here, hereZone = Places(drops.creatures)
    if creatures > 0 then
        table.insert(said.creatures, (creatures == 1 and "A single creature is known to drop it" or
            (creatures .. " creatures are known to drop it"))
            .. (#zones > 0 and (", most readily in " .. Names(zones)) or "") .. ".")
    end
    if chests > 0 then
        local first = Entries(drops.chests)[1]
        table.insert(said.chests, chests == 1 and ("It can be found in " .. A_(first.plain) .. ".")
            or ("It turns up in " .. chests .. " chests and the like, " .. A_(first.plain) .. " among them."))
    end
    for _, how in ipairs({ "herb", "ore", "fish" }) do
        local names = Unique(drops[how])
        if #names > 0 then
            table.insert(said.gathering, GATHERING[how].people .. " " .. GATHERING[how].verb .. " "
                .. Names(Shorten(names, 3)) .. ".")
        end
    end
    local items = {}
    for _, l in ipairs(drops.items or {}) do items[#items + 1] = ItemName(l.item) end
    if #items > 0 then table.insert(said.items, "It also turns up inside " .. Names(Shorten(items, 3)) .. ".") end
    said.hereFrom = here and "creatures"
    if not here then
        local _, there, thereZone = Places(drops.chests)
        here, hereZone = there, thereZone
        said.hereFrom = here and "chests"
    end
    if here then
        table.insert(said.here, "Here in " .. Name(hereZone) .. ", look for " .. Name(here.plain or here.name)
            .. (here.level and (", around level " .. here.level) or "") .. ".")
    end
    local total = creatures + chests + Total(drops.herb) + Total(drops.ore) + Total(drops.fish) + #items

    -- Who sells it
    local sellers = Entries(t.people)
    if #sellers > 0 then
        local v = sellers[1]
        table.insert(said.people, Name(v.plain or v.name) .. (v.sub and (" (" .. v.sub .. ")") or "")
            .. " sells it" .. (v.zone and (" in " .. LB.ZoneName(v.zone)) or "")
            .. (#sellers > 1 and ("; " .. Plural(#sellers - 1, "other merchant does", "other merchants do") .. " too")
                or "") .. ".")
    elseif total > 0 then
        table.insert(said.people, "No merchant is known to sell it.")
    end

    -- Crafted from, a reagent for, taught
    local made, teaches, used = p.recipes["Made by"], p.recipes["Teaches"], p.recipes["Used in"]
    local making, using
    -- (its reagents and where it's learnt: the recipe's block under the notes)
    if made then
        making = People(made) .. (#made == 1 and " make it" or (" know " .. #made .. " ways to make it"))
    end
    if used then
        local first = used[1].make
        using = (#used == 1 and first) and (" to make " .. ItemName(first))
            or (" in " .. Plural(#used, "recipe", "recipes") .. (first and (", " .. ItemName(first) .. " among them") or ""))
    end
    if making and using and People(made) == People(used) then
        -- (the same hands: one sentence)
        table.insert(said.profession, making .. ", and use it" .. using .. ".")
    else
        if making then table.insert(said.profession, making .. ".") end
        if using then table.insert(said.profession, People(used) .. " use it" .. using .. ".") end
    end
    if teaches and teaches[1] then table.insert(said.profession, "Studied, it teaches " .. Name(teaches[1].name) .. ".") end

    -- Its trainers (the recipe that makes it): "It comes with Alchemy: any
    -- of its 25 trainers starts you on it", "24 trainers teach it, Milla
    -- Fairancora in Darnassus among them"
    local trainers = Entries(t.trainers)
    if #trainers > 0 then
        local first = trainers[1]
        local who = Name(first.plain) .. (first.zone and first.zone > 0 and (" in " .. LB.ZoneName(first.zone)) or "")
        if p.starter then
            table.insert(said.trainers, "It comes with " .. LB.SkillName(made[1].skill) .. " itself: "
                .. (#trainers == 1 and who or ("any of its " .. #trainers .. " trainers, " .. who .. " among them,"))
                .. " starts you on it.")
        else
            table.insert(said.trainers, #trainers == 1 and ("Only " .. who .. " teaches it.")
                or (#trainers .. " trainers teach it, " .. who .. " among them."))
        end
    end

    -- Quests: one sentence a role, a few named
    local roles = { starts = {}, reward = {}, objective = {} }
    for _, l in ipairs(t.quests or {}) do
        if roles[l.role] then table.insert(roles[l.role], "“" .. l.name .. "”") end
    end
    if #roles.starts > 0 then
        table.insert(said.quests, "Reading it begins the quest " .. Names(Shorten(roles.starts, 1)) .. ".")
    end
    if #roles.reward > 0 then
        table.insert(said.quests, "It is given as the reward for " .. Names(Shorten(roles.reward, 3)) .. ".")
    end
    if #roles.objective > 0 then
        table.insert(said.quests, Names(Shorten(roles.objective, 3)) .. (#roles.objective == 1 and " calls" or " call")
            .. " for it.")
    end

    -- What it holds (a container item)
    local inside = t.contents or {}
    if #inside > 0 then
        local names = {}
        for i = 1, math.min(2, #inside) do names[i] = ItemName(inside[i].item) end
        table.insert(said.contents, "Opened, it yields " .. (#inside == 1 and names[1]
            or (Plural(#inside, "item", "items") .. ", " .. Names(names) .. " among them")) .. ".")
    end

    -- Its worth
    local usual = A and A.MarketPrice(p.id, A.Settings().chartDays)
    local sell = select(11, LB.ItemInfo(p.id))
    if usual then
        table.insert(said.worth, "At the auction house it usually fetches " .. Name(Coins(usual))
            .. (sell and sell > 0 and ("; a merchant pays " .. Name(Coins(sell))) or "") .. ".")
    elseif sell and sell > 0 then
        table.insert(said.worth, "A merchant would pay " .. Name(Coins(sell)) .. " for it.")
    end
    return said
end

-- Sentences of these subjects, one paragraph
local function Paragraph(said, ...)
    local out = {}
    for _, key in ipairs({ ... }) do
        for _, sentence in ipairs(said[key] or {}) do out[#out + 1] = sentence end
    end
    return #out > 0 and table.concat(out, " ") or nil
end

-- The notes: { paragraph, ... }; where it is found and who sells it, then
-- what is made of it and its worth
local function Notes(p)
    local said = Said(p)
    local paragraphs = {}
    paragraphs[#paragraphs + 1] = Paragraph(said, "creatures", "chests", "gathering", "items", "here", "people")
    paragraphs[#paragraphs + 1] = Paragraph(said, "contents", "profession", "quests", "worth")
    if #paragraphs == 0 then
        paragraphs[1] = "Little is written of it yet. Perhaps a traveller will add to these pages one day."
    end
    return paragraphs
end


-- Who works a list of recipes, for a subtitle: verb "Made" -> "Made by
-- Alchemists", "Made by Tailors and blacksmiths", "Made by 4 professions",
-- "Made with First Aid" (no people of its own)
local FIRST_AID = 129
local function Workers(verb, list)
    local seen, n = {}, 0
    for _, l in ipairs(list or {}) do
        if l.skill and not seen[l.skill] then
            seen[l.skill] = true
            n = n + 1
        end
    end
    if n > 2 then return verb .. " by " .. n .. " professions" end
    if n == 1 and seen[FIRST_AID] then return verb .. " with " .. LB.SkillName(FIRST_AID) end
    return verb .. " by " .. People(list)
end

-- The quests' roles in a few words: "Rewarded from 7 tasks", "Rewarded
-- from 2 tasks, needed for 1"
local function QuestRoles(quests)
    local n = { reward = 0, objective = 0, starts = 0 }
    for _, l in ipairs(quests or {}) do
        if n[l.role] then n[l.role] = n[l.role] + 1 end
    end
    -- (the entry's title says "Quests": "tasks" here)
    local parts = {}
    if n.reward > 0 then parts[#parts + 1] = "rewarded from " .. Plural(n.reward, "task", "tasks") end
    if n.objective > 0 then
        parts[#parts + 1] = "needed for " .. (#parts > 0 and n.objective or Plural(n.objective, "task", "tasks"))
    end
    if n.starts > 0 then parts[#parts + 1] = "starts " .. (n.starts == 1 and "one" or n.starts) end
    local text = table.concat(parts, ", ")
    return text:sub(1, 1):upper() .. text:sub(2)
end

-- The notes' entries: one a list that has something (Cross: that list)
local function Subjects(p)
    local t, lines = p.tabs, {}
    local function add(key, line, icon)
        lines[#lines + 1] = { go = key, icon = icon or LIST_ICONS[key], name = ENTRY_NAMES[key], line = line }
    end
    -- What drops it, who sells it: the entry's line says how they come by
    -- it, in a word other than its title's ("Creatures: Dropped by 247
    -- foes"), or the one there is ("Dropped by Hogger")
    local drops = p.drops or {}
    local function some(verb, lines, noun)
        local n = Total(lines)
        return verb .. " " .. (n == 1 and Entries(lines)[1].plain or (n .. " " .. noun))
    end
    -- (only one: its face, once known)
    local function face(list)
        local only = Total(list) == 1 and Entries(list)[1]
        lines[#lines].portrait = only and only.kind == "npc" and only.id or nil
    end
    if Total(drops.creatures) > 0 then
        add("creatures", some("Dropped by", drops.creatures, "foes"))
        face(drops.creatures)
    end
    -- Gathering: herbs, veins, pools ("Mined from Copper Vein and 2 more",
    -- "Picked from Peacebloom, fished from School of Fish")
    local gathered, gatherIcon = {}, nil
    for _, kind in ipairs({ "herb", "ore", "fish" }) do
        local names = Unique(drops[kind])
        if #names > 0 then
            gathered[#gathered + 1] = GATHERING[kind].short:lower() .. " "
                .. (#names == 1 and names[1] or (names[1] .. " and " .. (#names - 1) .. " more"))
            gatherIcon = gatherIcon or GATHERING[kind].icon
        end
    end
    if #gathered > 0 then add("gathering", Capital(table.concat(gathered, ", ")), gatherIcon) end
    -- Containers: chests, and the items it comes inside ("Found in 14
    -- chests and 5 items", "Opened from Battered Box")
    local chests, items = Unique(drops.chests), drops.items or {}
    if #chests > 0 or #items > 0 then
        local text
        local chestCount = #Entries(drops.chests)
        if #items == 0 then
            text = #chests == 1 and ("Found in " .. A_plain(chests[1])) or ("Found in " .. chestCount .. " chests")
        elseif #chests == 0 then
            text = "Opened from " .. (#items == 1 and (LB.ItemInfo(items[1].item) or "an item") or (#items .. " items"))
        else
            text = "Found in " .. Plural(chestCount, "chest", "chests") .. " and " .. Plural(#items, "item", "items")
        end
        add("containers", text, #chests > 0 and LIST_ICONS.chests or LB.ItemIcon(items[1].item))
    end
    if Count(t.people) > 0 then
        add("people", some("Sold by", t.people, "vendors"))
        face(t.people)
    end
    -- Profession: made by, used by, taught ("Made by Tailors, used by
    -- cooks", "Used by Cooks and engineers")
    local made, used, teaches = p.recipes["Made by"], p.recipes["Used in"], p.recipes["Teaches"]
    local crafts = {}
    local making, using = made and Workers("Made", made), used and Workers("Used", used)
    if making and using and making:sub(5) == using:sub(5) then
        -- (the same hands: "Made and used by Tailors")
        crafts[1] = "Made and used" .. making:sub(5)
    else
        crafts[#crafts + 1] = making
        crafts[#crafts + 1] = using
    end
    if teaches and teaches[1] then crafts[#crafts + 1] = "Teaches " .. LB.SkillName(teaches[1].skill) end
    if #crafts > 0 then
        for i = 2, #crafts do crafts[i] = crafts[i]:sub(1, 1):lower() .. crafts[i]:sub(2) end
        local first = (made or used or teaches)[1]
        add("profession", table.concat(crafts, ", "), PROFESSION_ICONS[first.skill])
    end
    if Count(t.quests) > 0 then add("quests", QuestRoles(t.quests)) end
    return lines
end

---------------------------------------------------------------------------
-- What is shown: a stack of items (Cross on another item: its page; Circle:
-- back), each { id, link, tab ("notes" or a list's), tabs = { [key] = lines
-- }, views = { [key] = { pages, cells, sel, page } } }
---------------------------------------------------------------------------
LB.stack = {}

-- The tooltip shows as everywhere else: the game's own setting (CVar
-- GamepadDisableTooltips), which R3 turns on and off here as in the bags
local function TipsOn()
    local get = C_CVar and C_CVar.GetCVarBool or GetCVarBool
    return not (get and get("GamepadDisableTooltips"))
end

local function ToggleTips()
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    if set then set("GamepadDisableTooltips", TipsOn() and "1" or "0") end
end

local function Top() return LB.stack[#LB.stack] end

-- A merged list's section: its title, then a list's entries (one by zone
-- read flat: each entry names its zone)
local function Section(into, title, lines)
    local entries, zone = {}, nil
    for _, l in ipairs(lines or {}) do
        if l.header then
            zone = (l.header ~= "Elsewhere" and l.header ~= "Around the world") and l.header:gsub("  %(here%)", "") or nil
        else
            if zone then l.line = LB.Join({ zone, l.line }) end
            entries[#entries + 1] = l
        end
    end
    if #entries == 0 then return end
    into[#into + 1] = { header = title, info = #entries }
    for _, l in ipairs(entries) do into[#into + 1] = l end
end

-- A creature's page: its places, what it drops and sells
-- Item classes, in the order a page shows them (Enum.ItemClass); the rest
-- after these
local CLASS_ORDER = { 2, 4, 0, 7, 9, 12, 1, 5, 3, 6, 11, 13, 15 }

-- Items by their class: { { class, name, lines } }, in CLASS_ORDER (each
-- list as given: the best first)
local function ByClass(lines)
    local groups, byClass = {}, {}
    for _, l in ipairs(lines) do
        local get = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
        local _, itemType, _, _, _, class = get(l.item)
        class = class or 15
        local g = byClass[class]
        if not g then
            g = { class = class, name = itemType or "Miscellaneous", lines = {} }
            byClass[class] = g
            groups[#groups + 1] = g
        end
        table.insert(g.lines, l)
    end
    local rank = {}
    for i, class in ipairs(CLASS_ORDER) do rank[class] = i end
    table.sort(groups, function(a, b) return (rank[a.class] or 99) < (rank[b.class] or 99) end)
    return groups
end

-- Items a page lists by class: a list a class ("loot2", "wares4"), titled
-- with the class's name
local function Grouped(p, what, lines)
    p.tabs, p.titles, p.groups = p.tabs or {}, p.titles or {}, p.groups or {}
    p.tabs[what] = lines
    p.groups[what] = ByClass(lines)
    for _, g in ipairs(p.groups[what]) do
        g.key = what .. g.class
        p.tabs[g.key] = g.lines
        p.titles[g.key] = g.name
    end
end

-- What a page's item groups say: an entry a class ("Hogger's Trophy and 11
-- more"; Cross, that class's list)
local function GroupEntries(p, what)
    local entries = {}
    for _, g in ipairs(p.groups and p.groups[what] or {}) do
        local best = LB.ItemInfo(g.lines[1].item)
        entries[#entries + 1] = { go = g.key, icon = LB.ItemIcon(g.lines[1].item), name = g.name,
            line = best and (best .. (#g.lines > 1 and (" and " .. (#g.lines - 1) .. " more") or ""))
                or Plural(#g.lines, "item", "items") }
    end
    return entries
end

-- A creature's page (p.npc) or a chest's, a node's (p.object): where it is,
-- what it drops, sells, teaches (a trainer: what its recipes make), holds
local LOOTS = {
    npc = { { "loot", "Loot" }, { "wares", "Wares" }, { "teaches", "Teaches", flat = true } },
    object = { { "holds", "Loot" } },
}
local function BuildCreature(p)
    p.creature = p.npc and LB.Creature(p.npc) or LB.Thing(p.object)
    p.tabs, p.titles, p.groups = {}, {}, {}
    if p.npc then
        Grouped(p, "loot", LB.Loot(p.npc))
        Grouped(p, "wares", LB.Wares(p.npc))
        Grouped(p, "teaches", LB.Teaches(p.npc))
    else
        Grouped(p, "holds", LB.Holds(p.object))
    end
    p.views = {}
end

-- What is written about a creature, a chest, a node, by subject ({ places,
-- loot, wares, teaches, holds })
local function CreatureSaid(p)
    local c, t = p.creature, p.tabs
    local said = { places = {}, loot = {}, wares = {}, teaches = {}, holds = {} }
    if not c then return said end
    local zones, inside = {}, false
    for _, l in ipairs(c.places) do
        if l.spot then zones[#zones + 1] = l.plain else inside = true end
    end
    if #zones > 0 then
        table.insert(said.places, Name(c.name) .. " is found in " .. Names(Shorten(zones, 3)) .. ".")
    elseif inside then
        table.insert(said.places, Name(c.name) .. " dwells inside an instance.")
    end
    local function some(key, verb)
        local n = #(t[key] or {})
        if n == 0 then return end
        local names = {}
        for i = 1, math.min(2, n) do names[i] = ItemName(t[key][i].item) end
        table.insert(said[key], "It " .. verb .. " " .. (n == 1 and names[1]
            or (Plural(n, "item", "items") .. ", " .. Names(names) .. " among them")) .. ".")
    end
    some("loot", "is known to drop")
    some("wares", "sells")
    some("teaches", "teaches the making of")
    some("holds", c.how and "yields" or "holds")
    return said
end

local function CreatureNotes(p)
    local text = Paragraph(CreatureSaid(p), "places", "loot", "wares", "teaches", "holds")
    return { text or "Little is written of it yet. Perhaps a traveller will add to these pages one day." }
end

-- A list's own paragraph, on top of it: what the notes say of its subject
local ABOUT = {
    creatures = { "creatures" }, gathering = { "gathering" }, containers = { "chests", "items" },
    people = { "people" }, profession = { "profession" }, quests = { "quests" }, trainers = { "trainers" },
}
local function About(p, key)
    if p.creature or p.questInfo then return nil end   -- (a creature's, a chest's, a quest's page: no lists)
    local said = Said(p)
    local keys = { unpack(ABOUT[key] or {}) }
    -- (where to look, with the subject it's in)
    if said.hereFrom == "creatures" and key == "creatures" or said.hereFrom == "chests" and key == "containers" then
        keys[#keys + 1] = "here"
    end
    return Paragraph(said, unpack(keys))
end

-- Its sections: where it is (a zone a line: Cross, a waypoint), what it
-- drops, what it sells (every item: Cross, its page)
local function CreatureLines(p)
    local lines = {}
    local function section(title, list, count)
        if #list == 0 then return end
        lines[#lines + 1] = { header = title, info = count or #list }
        for _, l in ipairs(list) do lines[#lines + 1] = l end
    end
    section("Locate", p.creature and p.creature.places or {})
    -- (by class, an entry each; a trainer's teachings: every item)
    for _, what in ipairs(LOOTS[p.npc and "npc" or "object"]) do
        local items = p.tabs[what[1]] or {}
        section(what[2], what.flat and items or GroupEntries(p, what[1]), #items)
    end
    return lines
end

-- A quest's page: who gives it and takes it back, what it rewards, the
-- quests before and after it
local function BuildQuest(p)
    p.questInfo = LB.Quest(p.quest)
    p.tabs, p.views = {}, {}
end

-- Its notes: what the quest asks, in its own words, then who and what
local function QuestNotes(p)
    local q, out = p.questInfo, {}
    if #q.objectives > 0 then out[#out + 1] = "“" .. table.concat(q.objectives, " ") .. "”" end
    local said = {}
    local giver, ender = q.givers[1], q.enders[1]
    if giver then
        local name = giver.plain or LB.ItemInfo(giver.item) or "an item"
        said[#said + 1] = (giver.kind == "item" and ("Reading " .. Name(name) .. " begins it")
            or (Name(name) .. (giver.zone and giver.zone > 0 and (" in " .. LB.ZoneName(giver.zone)) or "") .. " gives it"))
            .. (ender and ender.plain and ender.plain ~= giver.plain and ("; " .. Name(ender.plain) .. " takes it back") or "") .. "."
    elseif ender and ender.plain then
        said[#said + 1] = Name(ender.plain) .. " takes it back."
    end
    if #q.rewards > 0 then
        local names = {}
        for i = 1, math.min(2, #q.rewards) do names[i] = ItemName(q.rewards[i].item) end
        said[#said + 1] = "Completing it rewards " .. (#q.rewards == 1 and names[1]
            or (Plural(#q.rewards, "item", "items") .. ", " .. Names(names) .. " among them")) .. "."
    end
    if q.before[1] then said[#said + 1] = "It follows " .. Name("“" .. q.before[1].name .. "”") .. "." end
    if q.after[1] then said[#said + 1] = Name("“" .. q.after[1].name .. "”") .. " comes next." end
    if #said > 0 then out[#out + 1] = table.concat(said, " ") end
    if #out == 0 then out[1] = "Little is written of it yet. Perhaps a traveller will add to these pages one day." end
    return out
end

-- Its sections: where it begins, rewards, the chain (Cross: their pages;
-- Square: a giver on the map)
local function QuestLines(p)
    local q, lines = p.questInfo, {}
    local function section(title, list)
        if #list == 0 then return end
        lines[#lines + 1] = { header = title, info = #list }
        for _, l in ipairs(list) do lines[#lines + 1] = l end
    end
    -- (where it begins: who gives it, the item that starts it; who takes it
    -- back is in the notes)
    section("Giver", q.givers)
    section("Rewards", q.rewards)
    local chain = {}
    for _, l in ipairs(q.before) do chain[#chain + 1] = l end
    for _, l in ipairs(q.after) do chain[#chain + 1] = l end
    section("Chain", chain)
    return lines
end

local function Build(p)
    if p.quest then return BuildQuest(p) end
    if p.npc or p.object then return BuildCreature(p) end
    local id = p.id
    p.recipes = Sections(LB.Recipes(id))
    p.drops = LB.Drops(id)
    local d = p.drops
    local gathering = {}
    Section(gathering, "Herbs", d.herb)
    Section(gathering, "Mining", d.ore)
    Section(gathering, "Fishing", d.fish)
    local containers = {}
    Section(containers, "Chests", d.chests)
    Section(containers, "Items", d.items)
    local profession = ByProfession(p.recipes["Made by"], "Made with ")
    ByProfession(p.recipes["Used in"], "Used in ", profession)
    if p.recipes["Teaches"] then Section(profession, "Teaches", p.recipes["Teaches"]) end
    p.tabs = {
        creatures = d.creatures or {}, gathering = gathering, containers = containers,
        people = LB.People(id), quests = LB.Quests(id), profession = profession,
    }
    -- (a container item: what it holds, by class)
    Grouped(p, "contents", LB.Contents(id))
    -- (the trainers of the recipe that makes it: its Learning entry's list)
    local made = p.recipes["Made by"]
    p.tabs.trainers = {}
    if made and not made[1].taught then p.tabs.trainers, p.starter = LB.Trainers(made[1].spell, made[1].skill) end
    p.views = {}
end

-- A list laid out in pages: headers across, entries two a row; a section
-- going on over a page has its header again there. (pages, list, y: going
-- on from the notes)
local function ListLayout(lines, pages, list, startY)
    pages, list = pages or {}, list or {}
    local current = pages[#pages]
    local y, col, header = startY or 0, 0, nil
    local function newPage()
        current = { items = {} }
        pages[#pages + 1] = current
        y, col = 0, 0
        if header then
            current.items[#current.items + 1] = { header = header.header, info = "continued", y = y }
            y = y + HEAD_H
        end
    end
    if not current then newPage() end
    for _, line in ipairs(lines) do
        if line.header then
            if col > 0 then y, col = y + CELL_H, 0 end
            header = nil
            if y + HEAD_H + CELL_H > AREA_H then newPage() end
            header = line
            current.items[#current.items + 1] = { header = line.header, info = line.info, y = y }
            y = y + HEAD_H
        else
            if col == 0 and y + CELL_H > AREA_H then newPage() end
            local c = { line = line, page = #pages, col = col, x = col * (CELL_W + GAP), y = y }
            current.items[#current.items + 1] = c
            list[#list + 1] = c
            c.index = #list
            col = col + 1
            if col == 2 then y, col = y + CELL_H, 0 end
        end
    end
    return pages, list
end

-- An item a profession makes: its recipe's sections under the notes, as a
-- list's (the first recipe's, when there are several): its reagents (Cross:
-- their pages), where it's learnt (the recipe item: its page; a trainer)
local function Recipe(p)
    local made = p.recipes["Made by"]
    if not made then return {} end
    local first, lines = made[1], {}
    local row = first.row or {}
    if #row > 4 then
        lines[#lines + 1] = { header = "Reagents", info = #made > 1 and ("1 of " .. #made .. " recipes") or nil }
        for i = 5, #row, 2 do
            lines[#lines + 1] = { kind = "item", item = row[i], tip = row[i], line = "× " .. row[i + 1] .. " needed" }
        end
    end
    lines[#lines + 1] = { header = "Learning" }
    if first.taught then
        lines[#lines + 1] = { kind = "item", item = first.taught, tip = first.taught, line = "Teaches the recipe" }
    else
        -- (its trainers: Cross, their list; one: their face; none known: just said)
        local trainers = Entries(p.tabs.trainers)
        local who = #trainers == 1 and trainers[1].plain or (#trainers .. " trainers")
        local text = #trainers == 0 and "Teaches the recipe"
            or p.starter and ("Comes with the profession, from " .. who) or ("Taught by " .. who)
        lines[#lines + 1] = { kind = "trainer", icon = PROFESSION_ICONS[first.skill],
            name = LB.SkillName(first.skill) .. " Trainer", line = text,
            go = #trainers > 0 and "trainers" or nil, portrait = #trainers == 1 and trainers[1].id or nil }
    end
    return lines
end

-- A page laid out: its paragraphs (and who wrote them), then its lines
local PARA_GAP = 10
local function PageLayout(paragraphs, signed, lines)
    local current = { items = {} }
    local pages, y = { current }, 0
    local function place(kind, text, h)
        if y > 0 and y + h > AREA_H then
            current = { items = {} }
            pages[#pages + 1] = current
            y = 0
        end
        current.items[#current.items + 1] = { doc = kind, text = text, y = y }
        y = y + h
    end
    for _, text in ipairs(paragraphs) do
        measure:SetText(text)
        place("para", text, math.ceil(measure:GetStringHeight()) + PARA_GAP)
    end
    if signed then place("sign", Signature(), 34) end
    return ListLayout(lines, pages, {}, y)
end

-- The notes: the paragraphs, who wrote them, the recipe's sections, then the
-- entries (under "See Also" after those)
local function NotesLayout(p)
    if p.creature then return PageLayout(CreatureNotes(p), true, CreatureLines(p)) end
    if p.questInfo then return PageLayout(QuestNotes(p), true, QuestLines(p)) end
    local lines = Recipe(p)
    -- (a container item: what it holds, an entry a class)
    local contents = GroupEntries(p, "contents")
    if #contents > 0 then
        lines[#lines + 1] = { header = "Contents", info = #p.tabs.contents }
        for _, l in ipairs(contents) do lines[#lines + 1] = l end
    end
    local subjects = Subjects(p)
    if #lines > 0 and #subjects > 0 then lines[#lines + 1] = { header = "See Also" } end
    for _, l in ipairs(subjects) do lines[#lines + 1] = l end
    return PageLayout(Notes(p), true, lines)
end

-- (laid out again each time, the picked entry and page kept: names come in
-- late)
local function View(p)
    local key = p.tab
    local old = p.views[key]
    local pages, list
    if key == "notes" then
        pages, list = NotesLayout(p)
    else
        pages, list = PageLayout({ About(p, key) }, false, p.tabs[key] or {})
    end
    local view = { pages = pages, cells = list, sel = old and math.min(old.sel, math.max(1, #list)) or 1,
        page = old and old.page or 1 }
    p.views[key] = view
    return view
end

-- A list opened from the notes (Circle: back to them)
function LB.OpenList(key)
    local p = Top()
    if not p or Count(p.tabs[key]) == 0 then return end
    p.tab = key
    Sound("IG_ABILITY_PAGE_TURN")
    LB.Render()
end

-- An entry picked (its page turned to); activate: Cross on it too
function LB.Pick(index, activate)
    local p = Top()
    local view = p and View(p)
    local c = view and view.cells[index]
    if not c then return end
    view.sel = index
    if c.page ~= view.page then
        view.page = c.page
        Sound("IG_ABILITY_PAGE_TURN")
    end
    if activate then return LB.Activate() end
    LB.Render()
end

-- The D-pad: left / right reads on (over the page's edge too), up / down
-- the row above / below (the same column when it has one)
local function Move(name)
    local p = Top()
    local view = p and View(p)
    if not view or #view.cells == 0 then return end
    local cur = view.cells[view.sel]
    if name == "LEFT" or name == "RIGHT" then return LB.Pick(view.sel + (name == "RIGHT" and 1 or -1)) end
    local down = name == "DOWN"
    local function after(c)
        if c.page ~= cur.page then return (c.page > cur.page) == down end
        return c.y ~= cur.y and (c.y > cur.y) == down
    end
    local from, to, step = 1, #view.cells, 1
    if not down then from, to, step = #view.cells, 1, -1 end
    for i = from, to, step do
        local c = view.cells[i]
        if after(c) then
            -- (that row: the same column, else its nearest)
            local pick = c
            for j = i, to, step do
                local d = view.cells[j]
                if d.page ~= c.page or d.y ~= c.y then break end
                if d.col == cur.col then pick = d end
            end
            return LB.Pick(pick.index)
        end
    end
end

-- L2 / R2: the page before / after (its first entry)
local function Turn(dir)
    local p = Top()
    local view = p and View(p)
    if not view then return end
    local want = view.page + dir
    if want < 1 or want > #view.pages then return end
    for _, c in ipairs(view.cells) do
        if c.page == want then return LB.Pick(c.index) end
    end
    view.page = want
    Sound("IG_ABILITY_PAGE_TURN")
    LB.Render()
end

-- Cross on the picked entry
function LB.Activate()
    local p = Top()
    local view = p and View(p)
    local c = view and view.cells[view.sel]
    local line = c and c.line
    if not line then return end
    if line.go then return LB.OpenList(line.go) end
    if line.item then return LB.Push(line.item) end
    if line.kind == "npc" or line.kind == "object" then return LB.PushCreature(line.kind, line.id) end
    if line.kind == "quest" then return LB.PushQuest(line.id) end
    if line.kind == "place" then return LB.ShowOnMap(line) end
end

-- Square: the picked entry on the map (a creature, a person, a chest, a
-- node, a place: LibraryMap.lua)
local function MapPicked()
    local p = Top()
    local view = p and View(p)
    local c = view and view.cells[view.sel]
    if c and c.line and c.line.spot then LB.ShowOnMap(c.line) end
end

function LB.PushQuest(questID)
    if not questID then return end
    local p = { quest = questID, tab = "notes" }
    Build(p)
    if not p.questInfo then return end
    LB.stack[#LB.stack + 1] = p
    Sound("IG_ABILITY_PAGE_TURN")
    LB.Render()
end

-- kind: "npc" (a creature, a person) or "object" (a chest, a node)
function LB.PushCreature(kind, id)
    if not id then return end
    local p = { npc = kind == "npc" and id or nil, object = kind == "object" and id or nil, tab = "notes" }
    Build(p)
    if not p.creature then return end
    LB.stack[#LB.stack + 1] = p
    Sound("IG_ABILITY_PAGE_TURN")
    LB.Render()
end

function LB.Push(item)
    local id = LB.ItemID(item)
    if not id then return end
    local p = { id = id, link = type(item) == "string" and item or nil, tab = "notes" }
    Build(p)
    LB.stack[#LB.stack + 1] = p
    if #LB.stack > 1 then Sound("IG_ABILITY_PAGE_TURN") end
    LB.Render()
end

-- Circle: from a list its notes, from the notes the item before, or the book
-- closed
function LB.Back()
    local p = Top()
    if p and p.tab ~= "notes" then
        p.tab = "notes"
    else
        table.remove(LB.stack)
        if #LB.stack == 0 then return LB.Close() end
    end
    Sound("IG_ABILITY_PAGE_TURN")
    LB.Render()
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
-- (a chest, a node: what it is)
local THING_KIND = { herb = "Herb", ore = "Mining node", fish = "Fishing pool" }

local function RenderCreatureTitle(p)
    local c = p.creature
    if p.npc then
        head:Set(LB.ICONS.npc, true)
        LB.Portrait(p.npc, head.icon)
    else
        head:Set(c.how and GATHERING[c.how].icon or LB.ICONS.object, true)
    end
    title:SetText(c.name)
    kind:SetText(p.npc and c.entry.line or THING_KIND[c.how] or "Chest")
    local zones = {}
    for _, l in ipairs(c.places) do zones[#zones + 1] = l.plain end
    owned:SetText(#zones == 0 and "" or ("Found in " .. zones[1] .. (#zones > 1 and (" and " .. (#zones - 1) .. " more") or "")))
    chapter:SetText(LISTS[p.tab] or p.titles and p.titles[p.tab] or "Field Notes")
end

local function RenderQuestTitle(p)
    local q = p.questInfo
    head:Set(LB.ICONS.quest, true)
    title:SetText(q.name)
    kind:SetText(LB.Join({ q.level and q.level > 0 and ("Level " .. q.level .. " Quest") or "Quest",
        q.required and q.required > 1 and ("Requires Level " .. q.required) }))
    owned:SetText(q.zone and LB.ZoneName(q.zone) or "")
    chapter:SetText("Field Notes")
end

local function RenderTitle(p)
    if p.questInfo then return RenderQuestTitle(p) end
    if p.creature then return RenderCreatureTitle(p) end
    local name, link, quality, level, need, itemType, subType, _, _, _, sell = LB.ItemInfo(p.id)
    p.link = p.link or link
    head:Set(LB.ItemIcon(p.id), false)
    title:SetText(name or ("Item " .. p.id))
    local q = quality or 1
    kind:SetText(LB.Join({ (QUALITY_INK[q] or "") .. (QUALITY_NAMES[q] or "") .. "|r"
        .. ((subType or itemType) and (" " .. (subType or itemType)) or ""),
        level and level > 1 and ("Item Level " .. level), need and need > 1 and ("Requires Level " .. need) }))
    local carried = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(p.id, true) or 0
    owned:SetText(LB.Join({ carried > 0 and ("You carry " .. carried) or "You carry none",
        sell and sell > 0 and ("sells for " .. (A and A.Money(sell) or GetCoinTextureString(sell))) }))
    chapter:SetText(LISTS[p.tab] or p.titles and p.titles[p.tab] or "Field Notes")
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(p.id) end
end

local function PlaceTip()
    GameTooltip:SetOwner(page, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    if (page:GetRight() or 0) + 320 < (UIParent:GetRight() or 0) then
        GameTooltip:SetPoint("TOPLEFT", page, "TOPRIGHT", 4, -20)
    else
        GameTooltip:SetPoint("TOPRIGHT", page, "TOPLEFT", -4, -20)
    end
end

local function RenderTip(line)
    if not TipsOn() or not line or line.go then
        if GameTooltip:GetOwner() == page then GameTooltip:Hide() end
        return
    end
    local tip = line.tip or line.item
    if line.kind == "npc" or line.kind == "object" or line.kind == "place" then
        PlaceTip()
        GameTooltip:SetText(line.plain or "")
        if line.sub then GameTooltip:AddLine("<" .. line.sub .. ">", 1, 1, 1) end
        if line.spot then GameTooltip:AddLine(LB.SpotText(line.spot), 1, 1, 1) end
        GameTooltip:AddLine(Glyph(line.kind == "place" and "A" or "X", 16) .. " Show on Map", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    elseif tip then
        PlaceTip()
        if pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. tip) then GameTooltip:Show() else GameTooltip:Hide() end
    elseif GameTooltip:GetOwner() == page then
        GameTooltip:Hide()
    end
end

local function Hints(p, view, line)
    local defs = { { glyph = "DPAD", text = "Move" } }
    if view and #view.pages > 1 then
        defs[#defs + 1] = { { "PADLTRIGGER", "PADRTRIGGER" }, { "LT", "RT" }, "Turn Page" }
    end
    local verb = line and (line.go and "Read"
        or (line.item or line.kind == "npc" or line.kind == "object" or line.kind == "quest") and "Open"
        or line.kind == "place" and "Show on Map")
    if verb then defs[#defs + 1] = { "PAD1", "A", verb } end
    if line and (line.kind == "npc" or line.kind == "object") and line.spot then
        defs[#defs + 1] = { "PAD3", "X", "Show on Map" }
    end
    if line and not line.go then defs[#defs + 1] = { "PADRSTICK", "RS", TipsOn() and "Hide Tooltip" or "Tooltip" } end
    defs[#defs + 1] = { "PAD2", "B", p.tab ~= "notes" and "Notes" or #LB.stack > 1 and "Back" or "Close" }
    return defs
end

-- (legend defs are kept by identity: one table a shape)
local hintSets = {}
local function SetHints(defs)
    local key = {}
    for _, d in ipairs(defs) do key[#key + 1] = d.text or d[3] end
    key = table.concat(key, "|")
    hintSets[key] = hintSets[key] or defs
    legend:Set(hintSets[key])
end

-- A list entry's words: its name, then its line (an NPC's own <title> on it)
local function Fill(c, line)
    local round = line.kind == "npc" or line.kind == "object" or line.kind == "quest" or line.kind == "trainer"
        or line.kind == "place"
        or line.go ~= nil
    local name, sub = line.name, line.line
    if line.kind == "item" and line.item then
        local itemName, _, quality, _, _, itemType, subType = LB.ItemInfo(line.item)
        name = itemName or ("Item " .. line.item)
        -- (a creature's loot, its wares: what each is, "Uncommon Cloth")
        sub = line.describe and ((QUALITY_INK[quality or 1] or "") .. (QUALITY_NAMES[quality or 1] or "") .. "|r"
            .. ((subType or itemType) and (" " .. (subType or itemType)) or "")) or line.line or "a container"
    elseif line.kind == "recipe" then
        name, sub = LB.RecipeName(line), nil
    end
    c.icon:Set(line.icon or (line.item and LB.ItemIcon(line.item)), round)
    -- A creature, a person: its own face
    if line.kind == "npc" or line.portrait then LB.Portrait(line.portrait or line.id, c.icon.icon) end
    c.name:SetText(name or "")
    c.sub:SetText((sub and sub ~= "") and sub or "")
    c.name:ClearAllPoints()
    if sub and sub ~= "" then
        c.name:SetPoint("BOTTOMLEFT", c, "LEFT", 52, 1)
    else
        c.name:SetPoint("LEFT", c, "LEFT", 52, 0)
    end
    c.name:SetPoint("RIGHT", c, "RIGHT", -4, 0)
end

local function At(frame, x, y)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT + x, -TOP - y)
    frame:Show()
end

function LB.Render()
    local p = Top()
    if not p or not window:IsShown() then return end
    RenderTitle(p)
    local view = View(p)
    view.page = math.max(1, math.min(view.page, #view.pages))
    local nc, nh = 0, 0
    paragraphs:Reset()
    local picked = view.cells[view.sel]
    for _, item in ipairs(view.pages[view.page].items) do
        local on = item == picked
        if item.doc then
            local fs = paragraphs:Next()
            fs:SetText(item.text)
            fs:SetJustifyH(item.doc == "sign" and "RIGHT" or "LEFT")
            fs:SetAlpha(item.doc == "sign" and 0.7 or 1)
            At(fs, 0, item.y)
        elseif item.header then
            nh = nh + 1
            local h = heads[nh]
            if h then
                h.text:SetText(item.header)
                h.info:SetText(item.info and tostring(item.info) or "")
                At(h, 0, item.y)
            end
        else
            nc = nc + 1
            local c = cells[nc]
            if c then
                c.index = item.index
                Fill(c, item.line)
                c.icon:SetFocus(on)
                c.pointer:SetShown(on)
                c.backplate:SetAlpha(on and 0.9 or 0.25)
                At(c, item.x, item.y + 2)
            end
        end
    end
    for i = nc + 1, #cells do cells[i]:Hide() end
    for i = nh + 1, #heads do heads[i]:Hide() end
    paragraphs:HideRest()
    emptyText:SetShown(p.tab ~= "notes" and #view.cells == 0)
    emptyText:SetText("Nothing is written here yet.")
    pageNo:SetShown(#view.pages > 1)
    pageNo:SetText("Page " .. view.page .. "/" .. #view.pages)
    local line = picked and picked.page == view.page and picked.line or nil
    RenderTip(line)
    SetHints(Hints(p, view, line))
end

---------------------------------------------------------------------------
-- The pad, while it's up: a catcher frame takes the buttons (ahead of the
-- bag and loot windows' own navigation); only Escape is bound
---------------------------------------------------------------------------
local KEYS = {
    PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT",
    PAD1 = "A", PAD2 = "B", PAD3 = "X", PADLTRIGGER = "LT", PADRTRIGGER = "RT", PADRSTICK = "RS",
}

function LB.Press(name, down)
    -- Circle on its release: closing on the press would hand the release to
    -- the window under it (the bags: closed)
    if name == "B" then
        -- (Circle let go after closing the map: not ours)
        if not down and LB.skipRelease then
            LB.skipRelease = nil
            return
        end
        if not down then LB.Back() end
        return
    end
    if not down then return end
    if name == "UP" or name == "DOWN" or name == "LEFT" or name == "RIGHT" then Move(name)
    elseif name == "LT" then Turn(-1)
    elseif name == "RT" then Turn(1)
    elseif name == "A" then LB.Activate()
    elseif name == "X" then MapPicked()
    elseif name == "RS" then
        ToggleTips()
        LB.Render()
    end
end

local catcher = K.NewFrame("Frame", nil, window)
catcher:SetAllPoints(window)
if catcher.EnableGamePadButton then
    catcher:SetScript("OnGamePadButtonDown", function(_, button)
        if KEYS[button] then LB.Press(KEYS[button], true) end
    end)
    catcher:SetScript("OnGamePadButtonUp", function(_, button)
        if KEYS[button] then LB.Press(KEYS[button], false) end
    end)
    -- (setting a gamepad handler switches the frame's input on by itself: off
    -- until it is wanted, else a frame on screen takes the pad from login)
    catcher:EnableGamePadButton(false)
end

local function TakePad(on)
    if catcher.EnableGamePadButton and not IF.InCombat() then catcher:EnableGamePadButton(on and true or false) end
end

-- (on its release, as Circle)
local escape = K.NewFrame("Button", "ImprovedForeverLibraryEscape")
escape:RegisterForClicks("AnyUp")
escape:SetScript("OnClick", function() LB.Back() end)

function LB.IsShown()
    return window:IsShown()
end

-- Where the spellbook opens (a UI panel, "centerOrLeft", yoffset 75: with
-- nothing else open, the screen's middle at the top, kept 140 above the
-- bottom; UIParentPanelManager.lua), worked out the same way rather than
-- handed to the game's panel manager (an addon's panel there taints it)
local SPELLBOOK_Y, BOTTOM_CLAMP, MIN_Y = 75, 140, -10
local function Place()
    local layout = _G.UIPanelLayoutFrame
    local top = tonumber(layout and layout:GetAttribute("TOP_OFFSET")) or -116
    local y = SPELLBOOK_Y + top
    local bottom = (UIParent:GetTop() or 0) + y - window:GetHeight() * window:GetScale()
    if bottom < BOTTOM_CLAMP then y = y + (BOTTOM_CLAMP - bottom) end
    y = math.min(y, MIN_Y)
    window:ClearAllPoints()
    window:SetPoint("TOP", UIParent, "TOP", 0, y / window:GetScale())
end

-- item: an id or a link; origin: "bags", "loot", "auction" (where it's opened from)
function LB.Open(item, origin)
    if IF.InCombat() or not LB.ItemID(item) then return end
    wipe(LB.stack)
    LB.origin = origin
    Place()
    window:Show()
    Sound("IG_SPELLBOOK_OPEN")
    TakePad(true)
    ClearOverrideBindings(window)
    SetOverrideBindingClick(window, true, "ESCAPE", escape:GetName())
    if origin ~= "auction" and IF.Destroy then IF.Destroy.HideNativeFocus(true) end
    LB.Push(item)
end

function LB.Close()
    if window:IsShown() then Sound("IG_SPELLBOOK_CLOSE") end
    window:Hide()
end

-- Out of the way while the map is up (LibraryMap.lua), its pages kept; back
-- once it's closed (in combat: gone)
local suspended = false
function LB.Suspend()
    suspended = true
    window:Hide()
end

function LB.Resume()
    if not suspended then return end
    suspended = false
    if IF.InCombat() or #LB.stack == 0 then return wipe(LB.stack) end
    window:Show()
    TakePad(true)
    ClearOverrideBindings(window)
    SetOverrideBindingClick(window, true, "ESCAPE", escape:GetName())
    LB.skipRelease = IsKeyDown and IsKeyDown("PAD2") or nil
    LB.Render()
end

window:SetScript("OnHide", function()
    TakePad(false)
    if LB.origin ~= "auction" and IF.Destroy then IF.Destroy.HideNativeFocus(false) end
    if not suspended then wipe(LB.stack) end
    if GameTooltip:GetOwner() == page then GameTooltip:Hide() end
    if not IF.InCombat() then ClearOverrideBindings(window) end
    if LB.origin == "auction" and BY and BY.Render then BY.Render() end
end)
